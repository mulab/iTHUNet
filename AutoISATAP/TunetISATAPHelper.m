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
                               userInfo:[NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}

+ (NSString *) runCommand: (NSString *)cmd {
    int socket_descriptor = socket(PF_LOCAL, SOCK_STREAM, 0);
    if (socket_descriptor == -1) {
        NSLog(@"error creating socket: %s", strerror(errno));
        return nil;
    }
    struct sockaddr_un address = {
        .sun_family = PF_LOCAL,
        .sun_path = HELPER_SOCKET,
    };
    NSMutableString * ret = [NSMutableString stringWithString:@""];
    if (connect(socket_descriptor, (const struct sockaddr *)&address, sizeof(address)) != 0) {
        NSLog(@"error connecting to socket: %s", strerror(errno));
        ret = nil;
        goto done;
    }
    //send the command
    size_t bytes_written = send(socket_descriptor,
                                [cmd cStringUsingEncoding:NSUTF8StringEncoding],
                                [cmd length], 0);
    if (bytes_written != [cmd length]) {
        NSLog(@"couldn't write to socket: %s", strerror(errno));
        ret = nil;
        goto done;
    }
    size_t bytes_read = 0;
    char *buffer = malloc(4096);
    while((bytes_read = recv(socket_descriptor, buffer, 4096, 0)) > 0) {
        NSString *content =
        [[NSString alloc] initWithBytes: buffer length: bytes_read encoding: NSUTF8StringEncoding];
        NSLog(@"Got: %@", content);
        [ret appendString:content];
    }
    
    free(buffer);
done:
    if (socket_descriptor != -1) {
        close(socket_descriptor);
    }
    return ret;
}

@end
