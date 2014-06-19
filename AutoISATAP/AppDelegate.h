//
//  AppDelegate.h
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-14.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCNetworkReachability.h"
#import "Preferences.h"
#import "TunetLogin.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    GCNetworkReachability * reachv4;
    GCNetworkReachability * reachv6;
    NSImage * statusBarIcon;
}

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusBar;
@property (weak) IBOutlet TunetLogin *tunetLogin;

- (IBAction)itemClickFrom:(NSMenuItem *)sender;


@end
