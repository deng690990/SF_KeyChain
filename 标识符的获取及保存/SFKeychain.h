

#import <Foundation/Foundation.h>


@interface SFKeychain : NSObject
/**
 取出密码
 */
+ (NSString *)getPasswordStringForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error;
/**
 取出账号
 */
+ (NSString *)getUserNameStringForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error;
/**
 取出data
 */
+ (NSData *)getValueDataForKey:(NSString *)key andServiceName:(NSString *)serviceName error:(NSError **)error;
/**
 存储账号
 */
+ (void)storeUsername:(NSString *)username forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error;
/**
 存储密码
 */
+ (void)storePassword:(NSString *)password forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error;
/**
 存储其他内容，比如UDID
 */
+ (BOOL)storeValue:(NSData *)value forKey:(NSString *)key forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error;
/**
 删除某一项
 */
+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;

@end
