//
//  TunetNetworkUtils.m
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "TunetNetworkUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreWLAN/CoreWLAN.h>

@implementation TunetNetworkUtils


+ (NSString *)md5: (NSString *)input {
    const char *cStr = [input UTF8String];
    unsigned char digest[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return  output;
}

+ (NSString *)getBSSID {
    return [[CWInterface interface] bssid];
}

+ (NSString *)getMACAddr {
    return [[CWInterface interface] hardwareAddress];
}


@end
