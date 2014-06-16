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


- (id)init {
    self = [super initWithWindowNibName:@"Preferences"];
    [self.window setLevel:NSMainMenuWindowLevel];
    
    for(NSTextField * textField in [NSArray arrayWithObjects:self.passwordField,
                                    self.shownPasswordField, nil]){
        [textField bind:@"value"
               toObject:[PDKeychainBindingsController sharedKeychainBindingsController]
            withKeyPath:[NSString stringWithFormat:@"values.%@", @"password"]
                options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                    forKey:@"NSContinuouslyUpdatesValue"]];
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
