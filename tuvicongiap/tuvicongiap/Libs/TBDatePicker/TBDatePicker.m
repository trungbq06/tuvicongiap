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
    self.clipsToBounds = YES;
    [self setBackgroundColor:[UIColor whiteColor]];
    
    self.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    self.picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, -28.5, self.frame.size.width, self.frame.size.height)];
    self.picker.backgroundColor = [UIColor clearColor];
    self.picker.dataSource = self;
    self.picker.delegate = self;
    
    [self initDate];
    
    [self showDateOnPicker:self.date];
    
    [self addSubview:self.picker];
}

-(void)showDateOnPicker:(NSDate *)date
{
    self.date = date;
    
    NSDateComponents *components = [self.calendar components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:self.date];
    
    NSInteger month = [components month];
    NSInteger year = [components year];
    NSInteger day = [components day];
    
    [self.picker selectRow:day - 1 inComponent:0 animated:YES];
    [self.picker selectRow:month - 1 inComponent:1 animated:YES];
    [self.picker selectRow:year - 1900 - 1 inComponent:2 animated:YES];
    
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
    
    self.date = dateToPresent;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 4;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (component == 0)
    {
        return 31;
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
            return 35;
            break;
        case 1:
            return 35;
            break;
        case 2:
            return 35;
            break;
        case 3:
            return 80;
            break;
        default:
            return 0;
            break;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 20;
}
-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *lblDate = [[UILabel alloc] init];
    [lblDate setFont:[UIFont systemFontOfSize:14.0]];
    [lblDate setTextColor:[UIColor blackColor]];
    [lblDate setBackgroundColor:[UIColor clearColor]];
    lblDate.textAlignment = NSTextAlignmentCenter;
    
    if (component == 0) // Day
    {
        [lblDate setText:[NSString stringWithFormat:@"%ld", (long)row + 1]];
    }
    else if (component == 1) // Month
    {
        [lblDate setText:[NSString stringWithFormat:@"%ld", (long)row + 1]];
    }
    else if (component == 2) // Year
    {
        [lblDate setText:[NSString stringWithFormat:@"%ld", (long)row + 1900]];
    } else {
        if (row == 0) {
            lblDate.text = @"Dương Lịch";
        } else {
            lblDate.text = @"Âm Lịch   ";
        }
    }
    
    return lblDate;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSDate *chosenDate;
    
    NSInteger day = [pickerView selectedRowInComponent:0];
    NSInteger month = [pickerView selectedRowInComponent:1];
    NSInteger year = [pickerView selectedRowInComponent:2];
    self.cType = (int) [pickerView selectedRowInComponent:3];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    day = day + 1;
    month = month + 1;
    year = year + 1900;
    NSString *_sDate = [NSString stringWithFormat:@"%02ld-%02ld-%02ld", (long)year, (long)month, (long)day];
    
    chosenDate = [dateFormatter dateFromString:_sDate];
    NSLog(@"Selected Date %@", chosenDate);
    
    self.date = chosenDate;
    
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
