//
//  AADatePicker.m
//  CustomDatePicker
//
//  Created by Amit Attias on 3/26/14.
//  Copyright (c) 2014 I'm IT. All rights reserved.
//

#import "TBDatePicker.h"

@interface TBDatePicker () <UIPickerViewDataSource, UIPickerViewDelegate>
{
    NSInteger nDays;
    NSInteger nMonths;
    NSInteger nYears;
}

@property (nonatomic, strong) UIPickerView *picker;
@property (nonatomic, strong) NSCalendar *calendar;
@property (nonatomic, strong) NSDate *minDate;
@property (nonatomic, strong) NSDate *maxDate;
@property (readonly, strong) NSDate *earliestPresentedDate;
@property (nonatomic) BOOL showOnlyValidDates;

@end

@implementation TBDatePicker

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.minDate = [NSDate dateWithTimeIntervalSince1970:0];

    [self commonInit];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame maxDate:(NSDate *)maxDate minDate:(NSDate *)minDate showValidDatesOnly:(BOOL)showValidDatesOnly
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    assert((((minDate) && (maxDate)) && ([minDate compare:maxDate] != NSOrderedDescending)));
        
    self.minDate = minDate;
    self.maxDate = maxDate;
    self.showOnlyValidDates = showValidDatesOnly;
    
    [self commonInit];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    
    if (!self) {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

-(NSDate *)earliestPresentedDate
{
    return self.showOnlyValidDates ? self.minDate : [NSDate dateWithTimeIntervalSince1970:0];
}

- (void)commonInit {
    [self setBackgroundColor:[UIColor whiteColor]];
    
    self.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    self.picker = [[UIPickerView alloc] initWithFrame:self.bounds];
    self.picker.dataSource = self;
    self.picker.delegate = self;
    
    [self initDate];
    
    [self showDateOnPicker:self.date];
    
    [self addSubview:self.picker];
}

-(void)showDateOnPicker:(NSDate *)date
{
    self.date = date;
    
    NSDateComponents *components = [self.calendar
                                    components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay
                                    fromDate:self.earliestPresentedDate];
    
    NSDate *fromDate = [self.calendar dateFromComponents:components];
    
    
    components = [self.calendar components:(NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute)
                                  fromDate:fromDate
                                    toDate:date
                                   options:0];
    
    NSInteger hour = [components hour] + 24 * (INT16_MAX / 120);
    NSInteger minute = [components minute] + 60 * (INT16_MAX / 120);
    NSInteger day = [components day];
    
    [self.picker selectRow:day inComponent:0 animated:YES];
    [self.picker selectRow:hour inComponent:1 animated:YES];
    [self.picker selectRow:minute inComponent:2 animated:YES];
    
}

-(void)initDate
{
    NSInteger startDayIndex = 0;
    NSInteger startHourIndex = 0;
    NSInteger startMinuteIndex = 0;
    
    if ((self.minDate) && (self.maxDate) && self.showOnlyValidDates) {
        NSDateComponents *components = [self.calendar components:NSCalendarUnitDay
                                                        fromDate:self.minDate
                                                          toDate:self.maxDate
                                                         options:0];
    
        nDays = components.day + 1;
    } else {
        nDays = INT16_MAX;
    }
    nMonths = 12;
    NSDateComponents *components = [self.calendar components:NSCalendarUnitYear fromDate:self.minDate];
    NSDateComponents *maxComponents = [self.calendar components:NSCalendarUnitYear fromDate:self.maxDate];
    nYears = maxComponents.year - components.year;
    NSDate *dateToPresent;
    
    if ([self.minDate compare:[NSDate date]] == NSOrderedDescending) {
        dateToPresent = self.minDate;
    } else if ([self.maxDate compare:[NSDate date]] == NSOrderedAscending) {
        dateToPresent = self.maxDate;
    } else {
        dateToPresent = [NSDate date];
    }
    
    NSDateComponents *todaysComponents = [self.calendar components:NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute
                                                          fromDate:self.earliestPresentedDate
                                                            toDate:dateToPresent
                                                           options:0];
    
    startDayIndex = todaysComponents.day;
    startHourIndex = todaysComponents.hour;
    startMinuteIndex = todaysComponents.minute;
    
    self.date = [NSDate dateWithTimeInterval:startDayIndex*24*60*60+startHourIndex*60*60+startMinuteIndex*60 sinceDate:self.earliestPresentedDate];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 4;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (component == 0)
    {
        return nDays;
    }
    else if (component == 1)
    {
        return nMonths;
    }
    else if (component == 2)
    {
        return nYears;
    } else {
        return 2;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    switch (component) {
        case 0:
            return 60;
            break;
        case 1:
            return 60;
            break;
        case 2:
            return 60;
            break;
        case 3:
            return 100;
            break;
        default:
            return 0;
            break;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 35;
}
-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *lblDate = [[UILabel alloc] init];
    [lblDate setFont:[UIFont systemFontOfSize:16.0]];
    [lblDate setTextColor:[UIColor blackColor]];
    [lblDate setBackgroundColor:[UIColor clearColor]];
    
    if (component == 0) // Day
    {
        [lblDate setText:[NSString stringWithFormat:@"%ld", (long)row]];
    }
    else if (component == 1) // Month
    {
        [lblDate setText:[NSString stringWithFormat:@"%ld", (long)row]];
    }
    else if (component == 2) // Year
    {
        int max = (int)[self.calendar maximumRangeOfUnit:NSCalendarUnitMinute].length;
        [lblDate setText:[NSString stringWithFormat:@"%02ld",(row % max)]];
        lblDate.textAlignment = NSTextAlignmentLeft;
    } else {
        if (row == 0) {
            lblDate.text = @"Dương Lịch";
        } else {
            lblDate.text = @"Âm Lịch";
        }
    }
    
    return lblDate;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSInteger daysFromStart;
    NSDate *chosenDate;
    
    daysFromStart = [pickerView selectedRowInComponent:0];
    chosenDate = [NSDate dateWithTimeInterval:daysFromStart*24*60*60 sinceDate:self.earliestPresentedDate];
    
    NSInteger hour = [pickerView selectedRowInComponent:1];
    NSInteger minute = [pickerView selectedRowInComponent:2];
    
    // Build date out of the components we got
    NSDateComponents *components = [self.calendar components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:chosenDate];
    
    components.hour = hour % 24;
    components.minute = minute % 60;
    
    self.date = [self.calendar dateFromComponents:components];
    
    if ([self.date compare:self.minDate] == NSOrderedAscending) {
        [self showDateOnPicker:self.minDate];
    } else if ([self.date compare:self.maxDate] == NSOrderedDescending) {
        [self showDateOnPicker:self.maxDate];
    }
    
    if ((self.delegate) && ([self.delegate respondsToSelector:@selector(dateChanged:)])) {
        [self.delegate dateChanged:self];
    }
}
@end
