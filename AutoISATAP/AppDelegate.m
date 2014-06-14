//
//  AppDelegate.m
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-14.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void) awakeFromNib {
    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusBar.title = @"ISATAP";
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
}

@end
