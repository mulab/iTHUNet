//
//  TunetNetworkUtils.h
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TunetISATAPHelper.h"

#define ISATAP_IF_NAME "gif0"

@interface TunetNetworkUtils : NSObject

+ (NSString *)md5: (NSString *)input;
+ (BOOL)checkIPInNetworks: (NSArray *)networks forIP: (NSString *) ipaddr;

// for ISATAP
+ (BOOL)destroyInterfaceWithHelper: (TunetISATAPHelper *)helper;
+ (BOOL)createInterfaceForIP: (NSString *)localIP atGateway: (NSString *)gateway withLinkPrefix: (NSString *)linkPrefix andGlobalPrefix: (NSString *)globalPrefix withHelper: (TunetISATAPHelper *)helper;

@end
