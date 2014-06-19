//
//  TunetISATAPHelper.h
//  iTHUNet
//
//  Created by BlahGeek on 14-6-19.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HELPER_IDENTIFY "com.blahgeek.TunetISATAPHelper"
#define HELPER_SOCKET "/var/run/TunetISATAPHelper.socket"

@interface TunetISATAPHelper : NSObject

+ (NSError *) installHelper;

@property int sock;

- (BOOL) start;
- (void) end;
- (NSString *) runCommand: (NSString *)cmd;

@end
