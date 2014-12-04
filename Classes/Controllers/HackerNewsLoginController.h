//
//  HackerNewsLoginController.h
//  newsyc
//
//  Created by Grant Paul on 4/6/11.
//  Copyright 2011 Xuzz Productions, LLC. All rights reserved.
//

#import <HNKit/HNKit.h>
#import "LoginController.h"

@interface HackerNewsLoginController : LoginController <HNSessionAuthenticatorDelegate> {
    HNSession *session;
}

@property (nonatomic, retain, readonly) HNSession *session;

@end
