//
//  Preferences.m
//  AutoISATAP
//
//  Created by BlahGeek on 14-6-15.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "Preferences.h"
#import "AppDelegate.h"
#import "PDKeychainBindingsController.h"

@interface Preferences ()

@end

@implementation Preferences

/* We do this to catch the case where the user enters a value into one of the text fields but closes the window without hitting enter or tab.
 */
- (BOOL)windowShouldClose:(NSWindow *)window {
    return [window makeFirstResponder:nil]; // validate editing
}


- (id)init {
    self = [super initWithWindowNibName:@"Preferences"];
    [self.window setLevel:NSMainMenuWindowLevel];
    
    [self.usernameField bind:@"value"
                    toObject:[PDKeychainBindingsController sharedKeychainBindingsController]
                 withKeyPath:[NSString stringWithFormat:@"values.%@", @"loginUsername"]
                     options:[NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption,
                              @"zhangting12", NSNullPlaceholderBindingOption, nil]];
    
    for(NSTextField * textField in [NSArray arrayWithObjects:self.passwordField,
                                    self.shownPasswordField, nil]){
        [textField bind:@"value"
               toObject:[PDKeychainBindingsController sharedKeychainBindingsController]
            withKeyPath:[NSString stringWithFormat:@"values.%@", @"loginPassword"]
                options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                    forKey:NSContinuouslyUpdatesValueBindingOption]];
    }

    self->showingPassword = NO;
    return self;
}


- (IBAction)togglePasswordShowing:(NSButton *)sender {
    NSInteger state = [sender state];
    BOOL show = (state == NSOnState);
    [self.shownPasswordField setHidden:(!show)];
    [self.passwordField setHidden:show];
}

@end
