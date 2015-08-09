//
//  TunetLogin.m
//  iTHUNet
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "TunetLogin.h"
#import "PDKeychainBindings.h"
#import "AFNetworking.h"
#import "TunetNetworkUtils.h"
#import <CoreWLAN/CoreWLAN.h>
#import "NSURL+QueryDictionary.h"
#import "TunetISATAPHelper.h"

#define TUNET_LOGIN_URL "http://net.tsinghua.edu.cn/do_login.php"
#define TUNET_LOCATION_URL "http://location.sip6.edu.cn:9090/lbs/getStationLocationJSON/"

@interface AFPlaintextResponseSerializer : AFHTTPResponseSerializer

@end

@implementation AFPlaintextResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    [super responseObjectForResponse:response data:data error:error]; //BAD SIDE EFFECTS BAD BUT NECESSARY TO CATCH 500s ETC
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)([response textEncodingName] ?: @"utf-8")));
    return [[NSString alloc] initWithData:data encoding:encoding];
}

@end

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
        case TunetStatusInit: text = NSLocalizedString(@"Not Login", nil); break;
        case TunetStatusError: text = NSLocalizedString(@"Login Error", nil); break;
        case TunetStatusOK: text = NSLocalizedString(@"Login OK", nil); break;
        default: break;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState)
        text = NSLocalizedString(@"Auto Login Disabled", nil);
    [self.loginStatusMenuItem setTitle:text];
    
    switch (self.isatapStatus) {
        case TunetStatusInit: text = NSLocalizedString(@"ISATAP Not Configured", nil); break;
        case TunetStatusOK: text = NSLocalizedString(@"ISATAP OK", nil); break;
        case TunetStatusError: text = NSLocalizedString(@"ISATAP Error", nil); break;
        default: break;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOffState)
        text = NSLocalizedString(@"ISATAP Disabled", nil);
    [self.isatapStatusMenuItem setTitle:text];
}

- (void)sendUserNotification {
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"showNotification"] == NSOffState) {
        NSLog(@"showNotification Disabled");
        return;
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState &&
       [[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOffState &&
       self.loginStatus == TunetStatusInit) {
        NSLog(@"Nothing to notify");
        return;
    }
    NSUserNotification * noti = [[NSUserNotification alloc] init];
    noti.title = NSLocalizedString(@"iTHUNet Auto Login", @"Notification title");
    noti.soundName = NSUserNotificationDefaultSoundName;
    NSMutableString * text = [NSMutableString stringWithString:@""];
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOnState || self.loginStatus != TunetStatusInit) {
        if(self.loginStatus == TunetStatusOK) {
            [text appendString:NSLocalizedString(@"Login OK", nil)];
            if (self.locationBuildingName) [text appendFormat:@" @ %@", self.locationBuildingName];
            if (self.locationBuildingFloor) [text appendFormat:@",%@", self.locationBuildingFloor];
        } else {
            [text appendString:NSLocalizedString(@"Login Failed", nil)];
            if (self.loginError) [text appendFormat:@": %@", [self.loginError localizedDescription]];
        }
        [text appendString:@"; "];
    }
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoISATAP"] == NSOnState) {
        if(self.isatapStatus == TunetStatusOK) [text appendString:NSLocalizedString(@"ISATAP OK", nil)];
        else [text appendString:NSLocalizedString(@"ISATAP Not Configured", nil)];
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
    for(NSString * ipaddr in [TunetNetworkUtils getIPAddress]) {
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
    BOOL create_success = [TunetNetworkUtils createInterfaceForIP:ip
                                                        atGateway:[defaults stringForKey:@"isatapGateway"]
                                                   withLinkPrefix:[defaults stringForKey:@"isatapLinkPrefix"]
                                                  andGlobalPrefix:[defaults stringForKey:@"isatapPrefix"]
                                                       withHelper:helper];
    [helper end];
    if(create_success) self.isatapStatus = TunetStatusOK;
    else self.isatapStatus = TunetStatusError;
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
    NSString * bssid = [[CWInterface interface] bssid];
    NSString * hwaddr = [[CWInterface interface] hardwareAddress];
    if(!bssid || !hwaddr) {
        NSLog(@"BSSID or HWAddr not available, not querying location.");
        return [self doISATAP];
    }
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [manager.requestSerializer setTimeoutInterval:1];
    NSDictionary *parameters = @{@"bssid": bssid,
                                 @"mac": hwaddr};
    [manager GET:@TUNET_LOCATION_URL
      parameters:parameters
         success:^(AFHTTPRequestOperation *operation, id responseObject) {
             NSDictionary * building = [responseObject valueForKey:@"building"];
             self.locationBuildingName = [building valueForKey:@"name"];
             self.locationBuildingFloor = [building valueForKey:@"floor"];
             NSLog(@"Building: %@, %@", self.locationBuildingName, self.locationBuildingFloor);
             return [self doISATAP];
       } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             NSLog(@"Request LocationError: %@", error);
             return [self doISATAP];
       }];
}

- (void)doLoginFromUserCmd: (BOOL)fromUser {
    if (self.isRunning) {
        NSLog(@"Already running, return.");
        return;
    }
    [self reset];
    self.isRunning = YES;
    if (!fromUser && [[NSUserDefaults standardUserDefaults] integerForKey:@"enableAutoLogin"] == NSOffState) {
        NSLog(@"Auto login disabled, goto isatap");
        [self doISATAP];
        return;
    }
    NSString * password = [[PDKeychainBindings sharedKeychainBindings] stringForKey:@"loginPassword"];
    NSString * username = [[PDKeychainBindings sharedKeychainBindings] stringForKey:@"loginUsername"];
    
    if(!fromUser && username == nil) {
        NSLog(@"Username not configured, ignore.");
        self.isRunning = NO;
        return;
    }
    
    NSLog(@"Before login, Username: %@", username);
    if(username == nil) username = @"";
    if(password == nil) password = @"";
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFPlaintextResponseSerializer serializer];
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [manager.requestSerializer setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10)" forHTTPHeaderField:@"User-Agent"];
    [manager.requestSerializer setTimeoutInterval:1];
    NSDictionary *parameters = @{@"username": username,
                                 @"password": [NSString stringWithFormat:@"{MD5_HEX}%@", [TunetNetworkUtils md5: password]],
                                 @"ac_id": @"1",
                                 @"action": @"login"};
    [manager POST:@TUNET_LOGIN_URL parameters:parameters
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSString * response = (NSString *)responseObject;
              NSLog(@"Response: %@", response);
              [self loginDoneWithError:[self getErrorFromResponse:response]];
          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              [self loginDoneWithError:error];
          }];
}

- (IBAction)doLogin:(id)sender {
    [self doLoginFromUserCmd:YES];
}

#define LOGIN_SUCCESS_RESPONSE "Login is successful."
#define LOGIN_ALREADY_ONLINE_RESPONSE "IP has been online, please logout."

- (NSError *)getErrorFromResponse: (NSString *)response {
    NSError * err = nil;
    if([response isEqualToString: @LOGIN_SUCCESS_RESPONSE])
        return err;
    
    NSString * errorString = nil;
    if([response isEqualToString: @LOGIN_ALREADY_ONLINE_RESPONSE])
        errorString = NSLocalizedString(@LOGIN_ALREADY_ONLINE_RESPONSE, nil);
    else {
        NSInteger error_num = [[response substringFromIndex:1] integerValue];
        switch(error_num) {
            case 3001: errorString = NSLocalizedString(@"Quota outage", nil); break;
            case 3004:
            case 2616: errorString = NSLocalizedString(@"Insufficient balance", nil); break;
            case 2531: errorString = NSLocalizedString(@"User does not exist", nil); break;
            case 2532: errorString = NSLocalizedString(@"Too fast", nil); break;
            case 2533: errorString = NSLocalizedString(@"Too much times", nil); break;
            case 2553: errorString = NSLocalizedString(@"Wrong password", nil); break;
            case 2620: errorString = NSLocalizedString(@"Already online", nil); break;
            case 2840: errorString = NSLocalizedString(@"Internal address", nil); break;
            case 2842: errorString = NSLocalizedString(@"Authorization not required", nil); break;
            default: errorString = NSLocalizedString(@"Unknown error", nil); break;
                
        }
    }
    return [NSError errorWithDomain:@"loginError" code:0 userInfo:[NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey]];
}

@end
