//
//  SplitViewController.m
//  newsyc
//
//  Created by Grant Paul on 3/21/12.
//  Copyright (c) 2012 Xuzz Productions, LLC. All rights reserved.
//

#import "SplitViewController.h"

@implementation SplitViewController

- (UIViewController *)childViewControllerForStatusBarStyle {
    return [[self viewControllers] firstObject];
}

AUTOROTATION_FOR_PAD_ONLY;

@end
