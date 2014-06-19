//
//  TunetLogin.m
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "TunetLogin.h"
#import "PDKeychainBindings.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "TunetNetworkUtils.h"
#import <CoreWLAN/CoreWLAN.h>
#import "NSURL+QueryDictionary.h"
#import "TunetISATAPHelper.h"

#define TUNET_LOGIN_URL "http://net.tsinghua.edu.cn/cgi-bin/do_login"
#define TUNET_LOCATION_URL "http://location.sip6.edu.cn:9090/lbs/getStationLocationJSON/"

@implementation TunetLogin

- (id)init {
    self = [super init];
    [self reset];
    return self;
}

- (void)reset {
    self.isRunning = NO;
    self.loginStatus = TunetStatusInit;
    self.isatapStatus = TunetStatusInit;
    self.locationBuildingFloor = nil;
    self.locationBuildingName = nil;
    self.loginError = nil;
    [self updateMenuItem];
}

- (void)updateMenuItem {
    NSString * text = nil;
    switch (self.loginStatus) {
        case TunetStatusInit: text = @"Not Login"; break;
        case TunetStatusError: text = @"Login Error"; break;
        case TunetStatusOK: text = @"Login OK"; break;
        default: break;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState)
        text = @"Auto Login Disabled";
    [self.loginStatusMenuItem setTitle:text];
    
    switch (self.isatapStatus) {
        case TunetStatusInit: text = @"ISATAP Not Configured"; break;
        case TunetStatusOK: text = @"ISATAP OK"; break;
        case TunetStatusError: text = @"ISATAP Error"; break;
        default: break;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOffState)
        text = @"ISATAP Disabled";
    [self.isatapStatusMenuItem setTitle:text];
}

- (void)sendUserNotification {
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"showNotification"] == NSOffState) {
        NSLog(@"showNotification Disabled");
        return;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState &&
       [[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOffState) {
        NSLog(@"Nothing to notify");
        return;
    }
    NSUserNotification * noti = [[NSUserNotification alloc] init];
    noti.title = @"iTHUNet Auto Login";
    noti.soundName = NSUserNotificationDefaultSoundName;
    NSMutableString * text = [NSMutableString stringWithString:@""];
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOnState) {
        if(self.loginStatus == TunetStatusOK) {
            [text appendString:@"Login OK"];
            if (self.locationBuildingName) [text appendFormat:@" @ %@", self.locationBuildingName];
            if (self.locationBuildingFloor) [text appendFormat:@",%@", self.locationBuildingFloor];
        } else {
            [text appendString:@"Login Failed"];
            if (self.loginError) [text appendFormat:@": %@", [self.loginError localizedDescription]];
        }
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOnState) {
        [text appendString:@"; "];
        if(self.isatapStatus == TunetStatusOK) [text appendString:@"ISATAP OK"];
        else [text appendString:@"ISATAP Not Configured"];
    }
    noti.informativeText = text;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:noti];
}

- (void)doFinish {
    self.isRunning = NO;
    [self updateMenuItem];
    [self sendUserNotification];
}

- (void)doISATAP {
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOffState) {
        NSLog(@"ISATAP Disabled, continue.");
        return [self doFinish];
    }
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * ip = nil;
    for(NSString * ipaddr in [[NSHost currentHost] addresses]) {
        NSLog(@"Got local IP: %@, checking...", ipaddr);
        if([TunetNetworkUtils checkIPInNetworks:[defaults arrayForKey:@"enabledISATAPNetworks"] forIP:ipaddr]) {
            NSLog(@"Match! Use this one.");
            ip = ipaddr;
            break;
        }
    }
    TunetISATAPHelper * helper = [[TunetISATAPHelper alloc] init];
    [helper start];
    [TunetNetworkUtils destroyInterfaceWithHelper:helper];
    if(ip == nil){
        NSLog(@"No valid IP found for ISATAP, destroy it");
        self.isatapStatus = TunetStatusInit;
        return [self doFinish];
    }
    [TunetNetworkUtils createInterfaceForIP:ip
                                  atGateway:[defaults stringForKey:@"isatapGateway"]
                             withLinkPrefix:[defaults stringForKey:@"isatapLinkPrefix"]
                            andGlobalPrefix:[defaults stringForKey:@"isatapPrefix"]
                                 withHelper:helper];
    [helper end];
    self.isatapStatus = TunetStatusOK;
    return [self doFinish];
}

- (void)loginDoneWithError: (NSError *)error {
    if(error) {
        self.loginError = error;
        self.loginStatus = TunetStatusError;
        return [self doISATAP];
    }
    self.loginStatus = TunetStatusOK;

    // query location
    NSURL * url = [NSURL URLWithString:@TUNET_LOCATION_URL];
    url = [url uq_URLByAppendingQueryDictionary: @{@"bssid": [[CWInterface interface] bssid],
                                                   @"mac": [[CWInterface interface] hardwareAddress]}];
    __unsafe_unretained __block ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL: url];
    [request setTimeOutSeconds: 1];
    void (^completeBlock)(void) = ^{
        NSError * error = [request error];
        if(error) {
            NSLog(@"Error: %@", error);
            return [self doISATAP];
        }
        NSDictionary * jsonResponse = [NSJSONSerialization JSONObjectWithData:[request responseData]
                                                                      options:0
                                                                        error:&error];
        if(error) {
            NSLog(@"Json Parse Error: %@", error);
            return [self doISATAP];
        }
        NSDictionary * building = [jsonResponse valueForKey:@"building"];
        self.locationBuildingName = [building valueForKey:@"name"];
        self.locationBuildingFloor = [building valueForKey:@"floor"];
        NSLog(@"Building: %@, %@", self.locationBuildingName, self.locationBuildingFloor);
        return [self doISATAP];
    };
    [request setCompletionBlock:completeBlock];
    [request setFailedBlock:completeBlock];
    [request startAsynchronous];
}

- (IBAction)doLogin:(id)sender {
    if (self.isRunning) {
        NSLog(@"Already running, return.");
        return;
    }
    [self reset];
    self.isRunning = YES;
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState) {
        NSLog(@"Auto login disabled, goto isatap");
        [self doISATAP];
        return;
    }
    NSString * password = [[PDKeychainBindings sharedKeychainBindings] stringForKey:@"loginPassword"];
    NSString * username = [[NSUserDefaults standardUserDefaults] stringForKey:@"loginUsername"];
    NSLog(@"Before login, Username: %@, Password: %@", username, password);
    if (!username || !password) {
        NSLog(@"Username/Password is null, goto isatap");
        [self doISATAP];
        return;
    }
    
    __unsafe_unretained __block ASIFormDataRequest * request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@TUNET_LOGIN_URL]];
    [request setTimeOutSeconds: 1];
    [request setPostValue:username forKey:@"username"];
    [request setPostValue:[TunetNetworkUtils md5: password] forKey:@"password"];
    [request setPostValue:@"100" forKey:@"n"];
    [request setPostValue:@"0" forKey:@"drop"];
    [request setPostValue:@"10" forKey:@"type"];
    
    [request setCompletionBlock: ^{
        NSString * response = [request responseString];
        NSLog(@"Response: %@", response);
        NSError * error = nil;
        NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+,"
                                                                                options:0
                                                                                  error:&error];
        NSUInteger match = [regex numberOfMatchesInString:response
                                                  options:0
                                                    range:NSMakeRange(0, [response length])];
        if(match == 0) {
            NSArray * substrings = [response componentsSeparatedByString:@"@"];
            NSString * errorString = [substrings objectAtIndex:0];
            NSError * error = [NSError errorWithDomain:@"loginError"
                                                  code:0
                                              userInfo:[NSDictionary dictionaryWithObject:errorString
                                                                                   forKey:NSLocalizedDescriptionKey]];
            [self loginDoneWithError:error];
        } else {
            [self loginDoneWithError:nil];
        }
    }];
    
    [request setFailedBlock:^{
        [self loginDoneWithError:[NSError errorWithDomain:@"loginError"
                                                     code:1
                                                 userInfo:[NSDictionary dictionaryWithObject:@"Unknown error"
                                                                                      forKey:NSLocalizedDescriptionKey]]];
    }];
    
    [request startAsynchronous];
}

@end
