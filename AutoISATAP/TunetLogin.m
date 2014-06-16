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

#define TUNET_LOGIN_URL "http://net.tsinghua.edu.cn/cgi-bin/do_login"
#define TUNET_LOCATION_URL "http://location.sip6.edu.cn:9090/lbs/getStationLocationJSON/"

@implementation TunetLogin

- (void)loginDoneWithError: (NSError *)error {
    NSLog(@"Error: %@", error);
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"showNotification"] == NSOffState) {
        NSLog(@"Do not show notification.");
        return;
    }
    NSUserNotification * noti = [[NSUserNotification alloc] init];
    noti.title = @"iTHUNet Auto Login";
    noti.soundName = NSUserNotificationDefaultSoundName;
    if(error){
        NSString * text = @"Login Failed: ";
        noti.informativeText = [text stringByAppendingString:[error localizedDescription]];
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:noti];
        return;
    }
    NSMutableString * text = [NSMutableString stringWithString:@"Login OK"];
    noti.informativeText = text;
    NSURL * url = [NSURL URLWithString:@TUNET_LOCATION_URL];
    url = [url uq_URLByAppendingQueryDictionary: @{@"bssid": [[CWInterface interface] bssid],
                                                   @"mac": [[CWInterface interface] hardwareAddress]}];
    __unsafe_unretained __block ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL: url];
    [request setTimeOutSeconds: 1];
    void (^completeBlock)(void) = ^{
        void (^send)(void) = ^{
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:noti];
        };
        NSError * error = [request error];
        if(error) {
            NSLog(@"Error: %@", error);
            return send();
        }
        NSDictionary * jsonResponse = [NSJSONSerialization JSONObjectWithData:[request responseData]
                                                                      options:0
                                                                        error:&error];
        if(error) {
            NSLog(@"Json Parse Error: %@", error);
            return send();
        }
        NSDictionary * building = [jsonResponse valueForKey:@"building"];
        NSString * buildingName = [building valueForKey:@"name"];
        NSString * buildingFloor = [building valueForKey:@"floor"];
        NSLog(@"Building: %@, %@", buildingName, buildingFloor);
        if(buildingName) {
            [text appendFormat:@" @ %@", buildingName];
            if(buildingFloor)
                [text appendFormat:@", %@", buildingFloor];
        }
        noti.informativeText = text;
        return send();
    };
    [request setCompletionBlock:completeBlock];
    [request setFailedBlock:completeBlock];
    [request startAsynchronous];
}

- (IBAction)doLogin:(id)sender {
    NSString * password = [[PDKeychainBindings sharedKeychainBindings] stringForKey:@"loginPassword"];
    NSString * username = [[NSUserDefaults standardUserDefaults] stringForKey:@"loginUsername"];
    NSLog(@"Before login, Username: %@, Password: %@", username, password);
    
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
