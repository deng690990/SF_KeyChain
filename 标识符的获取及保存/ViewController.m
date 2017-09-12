//
//  ViewController.m
//  标识符的获取及保存
//
//  Created by 首牛 on 2017/9/5.
//  Copyright © 2017年 ShouNew.com. All rights reserved.
//

#import "ViewController.h"
#import <AdSupport/AdSupport.h>
//钥匙串获取
#import "SFKeychain.h"
@interface ViewController ()

@end
static NSString * const kDeviceIdentifier = @"kDeviceIdentifier";
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *idfa = [self getDeviceIdentifier];
    NSLog(@"手机唯一标示符%@",idfa);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}
- (NSString *)getDeviceIdentifier {
    //从钥匙串中获取唯一设备标识
    NSString * deviceIdentifier = [SFKeychain getPasswordStringForUsername:kDeviceIdentifier andServiceName:[[NSBundle mainBundle] bundleIdentifier] error:nil];
    //这个方法在第一次运行的时候，返回的始终是空字符串，所以不能用判断控制的方法判断
    if (deviceIdentifier.length != 0) {
        //如果钥匙串中存在唯一标识，则直接返回
        return deviceIdentifier;
    }
    //获取IDFA
    NSString *IDFA = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    //判断IDFA是否为空
    BOOL isEmpty = [[IDFA stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@"0" withString:@""].length;
    if (isEmpty) {
        //不为空，将IDFA作为唯一标识
        deviceIdentifier = IDFA;
    }
    else {
        //为空，获取UUID作为唯一标识
        deviceIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    //保存唯一设备标识,如已存在则不进行任何处理
    [SFKeychain storeUsername:kDeviceIdentifier andPasswordString:deviceIdentifier forServiceName:[[NSBundle mainBundle] bundleIdentifier] updateExisting:NO error:nil];
    //返回唯一标识
    return deviceIdentifier;
}

@end
