//
//  AppDelegate.m
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-14.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "AppDelegate.h"
#import "GCNetworkReachability.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self->reach = [GCNetworkReachability reachabilityWithIPv6AddressString:@"2001:4860:4860::8888"];
    [self->reach startMonitoringNetworkReachabilityWithHandler:^(GCNetworkReachabilityStatus status) {
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

- (IBAction)toggleAutoSetup:(NSMenuItem *)sender {
    NSInteger state = [sender state];
    if (state == NSOffState)
        [sender setState:NSOnState];
    else
        [sender setState:NSOffState];
}
@end
