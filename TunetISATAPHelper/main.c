//
//  main.c
//  TunetISATAPHelper
//
//  Created by BlahGeek on 14-6-16.
//  Copyright (c) 2014年 BlahGeek. All rights reserved.
//

#include <sys/event.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <errno.h>
#include <fcntl.h>
#include <launch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sysexits.h>
#include <unistd.h>
#include <Security/Security.h>

void exit_error(const char *message, const int error) __attribute__((noreturn));
int listen_to_launchd_sockets();
void log_time();

int main(int argc, const char * argv[])
{
    log_time();
    printf("I'm running...\n");
    int kernel_queue = listen_to_launchd_sockets();
    
    struct kevent listening_event;
    int connected_socket = kevent(kernel_queue, NULL, 0, &listening_event, 1, NULL);
    if (connected_socket == -1) {
        exit_error("couldn't get the connected socket", errno);
    }
    
    //accept the connection
    struct sockaddr accepted_address = { 0 };
    socklen_t address_length = 0;
    
    int accepted_socket = accept((int)listening_event.ident, &accepted_address, &address_length);
    if (accepted_socket == -1) {
        exit_error("couldn't accept the socket connection", errno);
    }
    log_time();
    printf("Socket accepted, recving command...\n");
    
    while(true) {
        
        char recv_cmd[1024];
        ssize_t recv_cmd_len = recv(accepted_socket, recv_cmd, 1023, 0);
        if(recv_cmd_len < 2) {
            printf("No more command, return");
            break;
        }
        log_time();
        printf("Got command:%s\n", recv_cmd);
        
        FILE * popen_file = popen(recv_cmd, "r");
        if(popen_file == NULL) exit_error("Error when popen", errno);
        
        char fgets_str[4096];
        if(fgets(fgets_str, 4000, popen_file) == NULL)
            fgets_str[0] = '\0';
        unsigned long fgets_str_len = strlen(fgets_str);
        fgets_str[fgets_str_len] = '\n';
        fgets_str[fgets_str_len+1] = '\0';
        fgets_str_len += 1;
        send(accepted_socket, fgets_str, fgets_str_len, 0);
        
        log_time();
        printf("Done, return\n");
        
        pclose(popen_file);
        
    }

    close(accepted_socket);
    close(kernel_queue);

    return 0;
}


void exit_error(const char *message, const int error) {
    if (error == 0) {
        fprintf(stderr, "%s\n", message);
    } else {
        fprintf(stderr, "%s: %s\n", message, strerror(errno));
    }
    exit(EX_OSERR);
}

int listen_to_launchd_sockets() {
    //check-in with launchd
    launch_data_t checkin_message = launch_data_new_string(LAUNCH_KEY_CHECKIN);
    if (checkin_message == NULL) {
        exit_error("couldn't create launchd checkin message", errno);
    }
    launch_data_t checkin_result = launch_msg(checkin_message);
    if (checkin_result == NULL) {
        exit_error("couldn't check in with launchd", errno);
    }
    if (launch_data_get_type(checkin_result) == LAUNCH_DATA_ERRNO) {
        exit_error("error on launchd checkin",launch_data_get_errno(checkin_result));
        return EX_OSERR;
    }
    launch_data_t socket_info = launch_data_dict_lookup(checkin_result, LAUNCH_JOBKEY_SOCKETS);
    if (socket_info == NULL) {
        exit_error("couldn't find socket information", 0);
    }
    launch_data_t listening_sockets = launch_data_dict_lookup(socket_info, "Listener");
    if (listening_sockets == NULL) {
        exit_error("couldn't find my socket", 0);
    }
    //set up a kevent for our socket
    int kernel_queue = kqueue();
    if (kernel_queue == -1) {
        exit_error("couldn't create kernel queue", errno);
    }
    for (int i = 0; i < launch_data_array_get_count(listening_sockets); i++) {
        launch_data_t this_socket = launch_data_array_get_index(listening_sockets, i);
        struct kevent kev_init;
        EV_SET(&kev_init, launch_data_get_fd(this_socket), EVFILT_READ, EV_ADD, 0, 0, NULL);
        if (kevent(kernel_queue, &kev_init, 1, NULL, 0, NULL) == -1) {
            exit_error("couldn't create kernel event", errno);
        }
    }
    launch_data_free(checkin_result);
    return kernel_queue;
}

void log_time() {
    time_t t;
    time(&t);
    printf("[%s] ", ctime(&t));
}