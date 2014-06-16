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

+ (BOOL)checkIPInNetworks:(NSArray *)networks forIP:(NSString *)ipaddr {
    NSUInteger (^parseIP)(NSString *) = ^ NSUInteger (NSString * address) {
        NSArray * nums = [[address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@":"];
        if([nums count] != 4) return 0;
        NSUInteger ret = 0;
        for(NSString * s in nums) {
            ret <<= 8;
            ret += [s integerValue];
        }
        return ret;
    };
    NSUInteger ip_addr = parseIP(ipaddr);
    for(NSDictionary * network in networks) {
        NSUInteger network_addr = parseIP([network objectForKey:@"network"]);
        if(network_addr == 0) continue;
        NSInteger network_prefixlen = [(NSString *)[network objectForKey:@"prefixlen"] integerValue];
        NSInteger mask_len = 32 - network_prefixlen;
        if((network_addr >> mask_len) == (ip_addr >> mask_len))
            return YES;
    }
    return NO;
}

@end
