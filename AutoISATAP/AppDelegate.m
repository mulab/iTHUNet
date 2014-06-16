//
//  AppDelegate.m
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-14.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "AppDelegate.h"
#import "GCNetworkReachability.h"
#import "PDKeychainBindings.h"
#import "TunetNetworkUtils.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self->reachv4 = [GCNetworkReachability reachabilityWithInternetAddressString:@"166.111.8.28"];
    self->reachv6 = [GCNetworkReachability reachabilityWithIPv6AddressString:@"2001:4860:4860::8888"];
    [self->reachv4 startMonitoringNetworkReachabilityWithHandler:^(GCNetworkReachabilityStatus status) {
        switch (status) {
            case GCNetworkReachabilityStatusNotReachable:
                NSLog(@"Not reachable!");
                break;
                
            case GCNetworkReachabilityStatusWiFi:
                NSLog(@"Reachable via WiFi!");
                break;
                
            case GCNetworkReachabilityStatusWWAN:
                NSLog(@"Reachable via WWAN");
                
            default:
                break;
        }
    }];
    
}

- (void) awakeFromNib {
    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusBar.title = @"ISATAP";
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
}

- (IBAction)itemClickFrom:(NSMenuItem *)sender {
    NSLog(@"Click from %@", sender);
    NSString * password = [[PDKeychainBindings sharedKeychainBindings] stringForKey:@"loginPassword"];
    NSString * username = [[NSUserDefaults standardUserDefaults] stringForKey:@"loginUsername"];
    NSLog(@"Username: %@, Password: %@", username, password);
}

@end
