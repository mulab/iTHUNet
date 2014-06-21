//
//  TunetISATAPHelper.m
//  iTHUNet
//
//  Created by BlahGeek on 14-6-19.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#import "TunetISATAPHelper.h"

#import <Security/Security.h>
#import <ServiceManagement/ServiceManagement.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <time.h>

@implementation TunetISATAPHelper

+ (NSError *) installHelper {
    CFStringRef jobLabel = CFSTR(HELPER_IDENTIFY);
    CFDictionaryRef helperJob = SMJobCopyDictionary(kSMDomainSystemLaunchd, jobLabel);
    if(helperJob){
        NSLog(@"Helper job already exists");
        CFRelease(helperJob);
        return nil;
    }
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
        return [NSError errorWithDomain:@"installHelper"
                                   code:0
                               userInfo:[NSDictionary
                                         dictionaryWithObject:[NSString stringWithFormat:@"couldn't create AuthorizationRef: error %i", authResult]
                                         forKey:NSLocalizedDescriptionKey]];
    }
    // got authorization, so deploy the helper
    CFErrorRef error = NULL;
    BOOL blessResult = SMJobBless(kSMDomainSystemLaunchd, jobLabel, authorization, &error);
    AuthorizationFree(authorization, kAuthorizationFlagDefaults);
    if (!blessResult) {
        CFStringRef errorString = CFErrorCopyDescription(error);
        NSString * msg = [NSString stringWithFormat:@"couldn't install privileged helper: %@", (__bridge id)errorString];
        CFRelease(errorString);
        return [NSError errorWithDomain:@"installHelper" code:0
                               userInfo:[NSDictionary dictionaryWithObject:msg
                                                                    forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}

- (BOOL) start {
    NSLog(@"Start connection to helper...");
    self.error = nil;
    self.sock = socket(PF_LOCAL, SOCK_STREAM, 0);
    if (self.sock < 0) {
        NSLog(@"error creating socket: %s", strerror(errno));
        self.error = [NSError errorWithDomain:@"helperError" code:0 userInfo:nil];
        return NO;
    }
    struct sockaddr_un address = {
        .sun_family = PF_LOCAL,
        .sun_path = HELPER_SOCKET,
    };
    if (connect(self.sock, (const struct sockaddr *)&address, sizeof(address)) != 0) {
        NSLog(@"error connecting to socket: %s", strerror(errno));
        self.error = [NSError errorWithDomain:@"helperError" code:1 userInfo:nil];
        if(self.sock > 0){
            close(self.sock);
            self.sock = -1;
        }
        return NO;
    }
    return YES;
}

- (void) end {
    NSLog(@"Closing connection to helper...");
    if(self.sock > 0) close(self.sock);
    self.sock = -1;
}

- (NSString *) runCommand: (NSString *)cmd {
    NSLog(@"Running command: `%@`", cmd);
    if(self.sock < 0){
        NSLog(@"Socket not good, return.");
        self.error = [NSError errorWithDomain:@"helperError" code:0 userInfo:nil];
        return nil;
    }
    char command[1024];
    [cmd getCString:command maxLength:1023 encoding:NSUTF8StringEncoding];
    unsigned long command_len = strlen(command);
    //send the command
    size_t bytes_written = send(self.sock, command, command_len, 0);
    if (bytes_written != command_len) {
        NSLog(@"couldn't write to socket: %s", strerror(errno));
        self.error = [NSError errorWithDomain:@"helperError" code:2 userInfo:nil];
        return nil;
    }
    char *buffer = malloc(4096);
    
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 200000; // 0.2s
    setsockopt(self.sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(tv)); // set timeout
    
//    NSLog(@"Waiting for recv...");
    NSString * ret = nil;
    size_t bytes_read = recv(self.sock, buffer, 4095, 0);
    if(bytes_read <= 0) {
        NSLog(@"Ops! Nothing recved, continue.");
        self.error = [NSError errorWithDomain:@"helperError" code:3 userInfo:nil];
        ret = nil;
    } else {
        ret = [[NSString alloc] initWithBytes: buffer length: bytes_read encoding: NSUTF8StringEncoding];
    }

//    NSLog(@"Recv: %zu bytes: %@", bytes_read, ret);
    free(buffer);

    return ret;
}

@end
