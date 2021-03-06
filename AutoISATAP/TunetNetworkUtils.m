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
#import "TunetISATAPHelper.h"

#include <ifaddrs.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

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
        NSArray * nums = [[address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"."];
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

+ (NSArray *)getIPAddress
{
    NSMutableArray * ret = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    if(getifaddrs(&interfaces) != 0) return ret;
    
    for(temp_addr = interfaces ; temp_addr != NULL ; temp_addr = temp_addr->ifa_next) {
        if(temp_addr->ifa_addr->sa_family != AF_INET) continue;
        NSString * addr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
        [ret addObject:addr];
    }
    
    freeifaddrs(interfaces);
    
    return ret;
}


// for ISATAP
+ (BOOL)destroyInterfaceWithHelper:(TunetISATAPHelper *)helper {
    NSLog(@"Destroying ISATAP interface...");
    NSString * cmd = [NSString stringWithFormat:@"/sbin/ifconfig %@ destroy", @ISATAP_IF_NAME];
    [helper runCommand:cmd];
    return helper.error == nil;
}

+ (BOOL)createInterfaceForIP: (NSString *)localIP atGateway: (NSString *)gateway withLinkPrefix: (NSString *)linkPrefix andGlobalPrefix: (NSString *)globalPrefix withHelper:(TunetISATAPHelper *)helper{
    NSLog(@"Creating ISATAP: local: %@, remote: %@", localIP, gateway);
    NSString * basecmd = [NSString stringWithFormat:@"/sbin/ifconfig %@ ", @ISATAP_IF_NAME];
    [helper runCommand:[basecmd stringByAppendingString:@"create"]];
    [helper runCommand:[basecmd stringByAppendingFormat:@"tunnel %@ %@", localIP, gateway]];
    [helper runCommand:[basecmd stringByAppendingFormat:@"inet6 %@:%@ prefixlen 64", linkPrefix, localIP]];
    [helper runCommand:[basecmd stringByAppendingFormat:@"inet6 %@:%@ prefixlen 64", globalPrefix, localIP]];
    [helper runCommand:@"/sbin/route delete -inet6 default"];
    [helper runCommand:[NSString stringWithFormat:@"/sbin/route add -inet6 default %@:%@", globalPrefix, gateway]];
    return helper.error == nil; // FIXME
}

@end
