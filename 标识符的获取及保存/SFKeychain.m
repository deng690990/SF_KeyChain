


#import "SFKeychain.h"
#import <Security/Security.h>


#define USE_MAC_KEYCHAIN_API !TARGET_OS_IPHONE || (TARGET_IPHONE_SIMULATOR && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0)

static NSString *BCCKeychainErrorDomain = @"BCCKeychainErrorDomain";


#if USE_MAC_KEYCHAIN_API

@interface SFKeychain ()

+ (SecKeychainItemRef)getKeychainItemReferenceForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;

@end

#endif


@implementation SFKeychain


#pragma mark - iOS Keychain Implementation

+ (NSString *)getPasswordStringForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error
{
    NSData *passwordData = [SFKeychain getValueDataForKey:key andServiceName:serviceName error:error];
    return [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
}
+ (NSString *)getUserNameStringForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error{
    NSData *passwordData = [SFKeychain getValueDataForKey:key andServiceName:serviceName error:error];
    return [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
}
+ (NSData *)getValueDataForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error
{
	if (!key || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return nil;
	}
	
	
	NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass, kSecAttrAccount, kSecAttrService, nil];
	NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword, key, serviceName, nil];
	
	NSMutableDictionary *query = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys];
	
	
	CFDataRef attributeResult = nil;
	NSMutableDictionary *attributeQuery = [query mutableCopy];
	[attributeQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attributeQuery, (CFTypeRef *)&attributeResult);
	
	if (status != noErr) {
		// No existing item found--simply return nil for the password
		if (status != errSecItemNotFound && error) {
			//Only return an error if a real exception happened--not simply for "not found."
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
	
	// We have an existing item, now query for the password data associated with it.
	
	CFDataRef resultData = nil;
	NSMutableDictionary *passwordQuery = [query mutableCopy];
	[passwordQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
	status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	
	if (status != noErr) {
		if (status == errSecItemNotFound) {
			// We found attributes for the item previously, but no password now, so return a special error.
			// Users of this API will probably want to detect this error and prompt the user to
			// re-enter their credentials.  When you attempt to store the re-entered credentials
			// using storeUsername:andPassword:forServiceName:updateExisting:error
			// the old, incorrect entry will be deleted and a new one with a properly encrypted
			// password will be added.
			if (error) {
				*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-1999 userInfo:nil];
			}
		} else if (error) {
			// Something else went wrong. Simply return the normal Keychain API error code.
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
    
	NSData *passwordData = nil;
    
	if (resultData) {
		passwordData = (__bridge NSData *)(resultData);
	}
	else if (error) {
		// There is an existing item, but we weren't able to get password data for it for some reason,
		// Possibly as a result of an item being incorrectly entered by the previous code.
		// Set the -1999 error so the code above us can prompt the user again.
        *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-1999 userInfo:nil];
	}
    
	return passwordData;
}
+ (void)storeUsername:(NSString *)username forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error{
    [SFKeychain storeValue:[username dataUsingEncoding:NSUTF8StringEncoding] forKey:key forServiceName:serviceName updateExisting:updateExisting error:error];
}
+ (void)storePassword:(NSString *)password forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{
    [SFKeychain storeValue:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:key forServiceName:serviceName updateExisting:updateExisting error:error];
}

+ (BOOL)storeValue:(NSData *)value forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{		
	if (!key || !value || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		
        return NO;
	}
	
	// See if we already have a password entered for these credentials.
	NSError *getError = nil;
	NSData *existingPassword = [SFKeychain getValueDataForKey:key andServiceName:serviceName error:&getError];
    
	if ([getError code] == -1999) {
		// There is an existing entry without a password properly stored (possibly as a result of the previous incorrect version of this code.
		// Delete the existing item before moving on entering a correct one.
        
		getError = nil;
		
		[self deleteItemForUsername:key andServiceName:serviceName error:&getError];
        
		if ([getError code] != noErr) {
			if (error) {
				*error = getError;
			}
			return NO;
		}
	} else if ([getError code] != noErr) {
		if (error) {
			*error = getError;
		}
		return NO;
	}
	
	/*if (error != nil) {
		*error = nil;
	}*/
	
	OSStatus status = noErr;
    
	if (existingPassword) {
		// We have an existing, properly entered item with a password.
		// Update the existing item.
		
		if (updateExisting) {
			//Only update if we're allowed to update existing.  If not, simply do nothing.
			
			NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass,
                              kSecAttrService, 
                              kSecAttrLabel, 
                              kSecAttrAccount, 
                              nil];
			
			NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword,
                                 serviceName,
                                 serviceName,
                                 key,
                                 nil];
			
			NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
			
			status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)[NSDictionary dictionaryWithObject:value forKey:(__bridge NSString *)kSecValueData]);
		}
	}
	else {
		// No existing entry (or an existing, improperly entered, and therefore now
		// deleted, entry).  Create a new entry.
		
		NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass,
                          kSecAttrService,
                          kSecAttrLabel, 
                          kSecAttrAccount, 
                          kSecValueData, 
                          nil];
		
		NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword,
                             serviceName,
                             serviceName,
                             key,
                             value,
                             nil];
		
		NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
        
		status = SecItemAdd((__bridge CFDictionaryRef) query, NULL);
	}
	
	if (status != noErr) {
		// Something went wrong with adding the new item. Return the Keychain error code.
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
        	return NO;
	}
    
    return YES;
}

+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error 
{
	if (!username || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return NO;
	}
	
	/*if (error != nil) {
		*error = nil;
	}*/
    
	NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass, kSecAttrAccount, kSecAttrService, kSecReturnAttributes, nil];
	NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword, username, serviceName, kCFBooleanTrue, nil];
	
	NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
	
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef) query);
	
	if (status != noErr) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
        
        return NO;
	}
    
    return YES;
}


@end
