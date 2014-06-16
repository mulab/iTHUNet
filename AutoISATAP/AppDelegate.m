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

#import <Security/Security.h>
#import <ServiceManagement/ServiceManagement.h>
#import <sys/socket.h>
#import <sys/un.h>


static NSDictionary * defaultValues() {
    static NSDictionary * values = nil;
    if (values != nil) return values;
    values = @{@"enableAutoLogin": @YES,
               @"enableAutoISATAP": @YES,
               @"showNotification": @YES,
               @"sendStatistic": @YES,
               @"enabledISATAPNetworks": @[@{@"network": @"59.66.0.0", @"prefixlen": @"16"},
                                           @{@"network": @"166.111.0.0", @"prefixlen": @"16"},
                                           @{@"network": @"101.5.0.0", @"prefixlen": @"16"}],
               };
    return values;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues()];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultValues()];
    
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
    
    CFStringRef jobLabel = CFSTR("blahgeek.TunetISATAPHelper");
    CFDictionaryRef helperJob = SMJobCopyDictionary(kSMDomainSystemLaunchd, jobLabel);
    if(helperJob){
        NSLog(@"Helper job already exists");
        CFRelease(helperJob);
    } else {
        AuthorizationItem authItem = {
            .name = kSMRightBlessPrivilegedHelper,
            .valueLength = 0,
            .value = NULL,
            .flags = kAuthorizationFlagDefaults };
        
        AuthorizationRights authRights	= { .count = 1,
            .items = &authItem };
        
        AuthorizationRef authorization = NULL;
        OSStatus authResult = AuthorizationCreate(&authRights,
                                                  kAuthorizationEmptyEnvironment,
                                                  kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
                                                  kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights,
                                                  &authorization);
        if (authResult != errAuthorizationSuccess) {
            NSLog(@"couldn't create AuthorizationRef: error %i", authResult);
        } else {
            // got authorization, so deploy the helper
            CFErrorRef error = NULL;
            BOOL blessResult = SMJobBless(kSMDomainSystemLaunchd, jobLabel, authorization, &error);
            AuthorizationFree(authorization, kAuthorizationFlagDefaults);
            if (!blessResult) {
                CFStringRef errorString = CFErrorCopyDescription(error);
                NSLog(@"couldn't install privileged helper: %@", (__bridge id)errorString);
                CFRelease(errorString);
            }
        }
    }
    
}

- (void) awakeFromNib {
    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusBar.title = @"ISATAP";
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
}

- (IBAction)itemClickFrom:(NSMenuItem *)sender {
    NSString * command = @"/usr/bin/touch /42.txt";
    NSLog(@"Click from %@", sender);
    int socket_descriptor = socket(PF_LOCAL, SOCK_STREAM, 0);
    if (socket_descriptor == -1) {
        NSLog(@"error creating socket: %s", strerror(errno));
        return;
    }
    struct sockaddr_un address = {
        .sun_family = PF_LOCAL,
        .sun_path = "/var/run/TunetISATAPHelper.socket",
    };
    if (connect(socket_descriptor, (const struct sockaddr *)&address, sizeof(address)) != 0) {
        NSLog(@"error connecting to socket: %s", strerror(errno));
        goto done;
    }
    //send the command
    size_t bytes_written = send(socket_descriptor,
                                [command cStringUsingEncoding:NSUTF8StringEncoding],
                                [command length], 0);
    if (bytes_written != [command length]) {
        NSLog(@"couldn't write to socket: %s", strerror(errno));
        goto done;
    }
    size_t bytes_read = 0;
    char *buffer = malloc(4096);
    while((bytes_read = recv(socket_descriptor, buffer, 4096, 0)) > 0) {
        NSString *logContent =
        [[NSString alloc] initWithBytes: buffer length: bytes_read encoding: NSUTF8StringEncoding];
        NSLog(@"%@", logContent);
    }
    
    free(buffer);
done:
    if (socket_descriptor != -1) {
        close(socket_descriptor);
    }
}

@end
