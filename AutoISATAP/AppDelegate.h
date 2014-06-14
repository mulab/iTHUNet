//
//  AppDelegate.h
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-14.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCNetworkReachability.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    GCNetworkReachability * reach;
}

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusBar;

- (IBAction)toggleAutoSetup:(NSMenuItem *)sender;

@end
