//
//  Preferences.h
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-15.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PDKeychainBindingsController.h"

@interface Preferences : NSWindowController {
    BOOL showingPassword;
}

@property (weak) IBOutlet NSTextField *usernameField;

@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSTextField *shownPasswordField;
- (IBAction)togglePasswordShowing:(NSButton *)sender;

@end
