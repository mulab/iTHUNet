//
//  TunetLogin.h
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TunetLogin : NSObject

@property BOOL isRunning;

typedef enum {
    TunetStatusInit,
    TunetStatusError,
    TunetStatusOK
} TunetStatus;

@property TunetStatus loginStatus;
@property TunetStatus isatapStatus;
@property NSString * locationBuildingName;
@property NSString * locationBuildingFloor;
@property NSError * loginError;


@property (weak) IBOutlet NSMenuItem *loginStatusMenuItem;
@property (weak) IBOutlet NSMenuItem *isatapStatusMenuItem;

- (void)reset;

- (void)doLoginFromUserCmd: (BOOL)fromUser;

- (void)updateMenuItem;
- (void)sendUserNotification;

- (NSError *)getErrorFromResponse: (NSString *)response;

- (IBAction)doLogin:(id)sender;

@end
