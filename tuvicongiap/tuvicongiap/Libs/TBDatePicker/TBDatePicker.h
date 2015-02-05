//
//  AADatePicker.h
//  CustomDatePicker
//
//  Created by Amit Attias on 3/26/14.
//  Copyright (c) 2014 I'm IT. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TBDatePickerDelegate <NSObject>

@optional

-(void)dateChanged:(id)sender;

@end

@interface TBDatePicker : UIControl

@property (nonatomic, strong) id<TBDatePickerDelegate> delegate;
@property (nonatomic, strong) NSDate *date;

- (id)initWithFrame:(CGRect)frame maxDate:(NSDate *)maxDate minDate:(NSDate *)minDate showValidDatesOnly:(BOOL)showValidDatesOnly;
@end
