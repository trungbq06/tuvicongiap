//
//  GlobalTextField.m
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/4/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import "GlobalTextField.h"

@implementation GlobalTextField

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.layer.cornerRadius = 3.0;
}

@end
