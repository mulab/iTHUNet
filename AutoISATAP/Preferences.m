//
//  Preferences.m
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-15.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "Preferences.h"
#import "AppDelegate.h"

@interface Preferences ()

@end

@implementation Preferences


- (id)init {
    self = [super initWithWindowNibName:@"Preferences"];
    [self.window setLevel:NSMainMenuWindowLevel];
    return self;
}


@end
