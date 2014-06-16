//
//  TunetNetworkUtils.h
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TunetNetworkUtils : NSObject

+ (NSString *)md5: (NSString *)input;
+ (BOOL)checkIPInNetworks: (NSArray *)networks forIP: (NSString *) ipaddr;
@end
