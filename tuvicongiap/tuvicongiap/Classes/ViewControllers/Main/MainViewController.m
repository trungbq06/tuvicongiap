//
//  MainViewController.m
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/3/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import "MainViewController.h"
#import "Calendar.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _hourData = [NSMutableArray arrayWithArray:@[@"Giờ Tý (23h-1h)",
                                                 @"Giờ Sửu (1h-3h)",
                                                 @"Giờ Dần (3h-5h)",
                                                 @"Giờ Mão (5h-7h)",
                                                 @"Giờ Thìn (7h-9h)",
                                                 @"Giờ Tỵ (9h-11h)",
                                                 @"Giờ Ngọ (11h-13h)",
                                                 @"Giờ Mùi (13h-15h)",
                                                 @"Giờ Thân (15h-17h)",
                                                 @"Giờ Dậu (17h-19h)",
                                                 @"Giờ Tuất (19h-21h)",
                                                 @"Giờ Hợi (21h-23h)"]];
    CGRect hourFrame = _txtBirthhour.frame;
    _hourTableView = [[UITableView alloc] initWithFrame:CGRectMake(hourFrame.origin.x, hourFrame.origin.y + hourFrame.size.height, hourFrame.size.width, 120) style:UITableViewStylePlain];
    _hourTableView.dataSource = self;
    _hourTableView.delegate = self;
    [_hourTableView setSeparatorInset:UIEdgeInsetsZero];
    
    _hourTableView.layer.borderWidth = 1.0;
    _hourTableView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    _hourTableView.layer.cornerRadius = 3.0;
    
    [self.view addSubview:_hourTableView];
    
    _hourTableView.hidden = TRUE;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSString *date = @"1900-01-01";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    NSDate *minDate = [dateFormatter dateFromString:date];
    
    CGRect dateFrame = _txtBirthday.frame;
    _datePicker = [[TBDatePicker alloc] initWithFrame:dateFrame maxDate:[NSDate date] minDate:minDate showValidDatesOnly:NO];
    
    _datePicker.delegate = self;
    [self.view addSubview:_datePicker];
    
    _datePicker.layer.borderWidth = 1.0;
    _datePicker.layer.borderColor = [[UIColor grayColor] CGColor];
    _datePicker.layer.cornerRadius = 3.0;
    
    CGRect hourFrame = _txtBirthhour.frame;
    _hourTableView.frame = CGRectMake(hourFrame.origin.x, hourFrame.origin.y + hourFrame.size.height, hourFrame.size.width, 120);
    [_hourTableView setSeparatorInset:UIEdgeInsetsZero];
    [_hourTableView setLayoutMargins:UIEdgeInsetsZero];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)btnConfirmClick:(id)sender {
    _cType = _datePicker.cType;
    _sDate = _datePicker.date;
    
    NSString *username = _txtUsername.text;
    NSString *birthDay = _txtBirthday.text;
    NSString *birthHour = _txtBirthhour.text;
    
    if (!_sDate) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Ngày không hợp lệ !" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    } else {
        int day, month, year;
        if (_cType == 0) {
            // Convert to lunar date
            NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:_sDate];
            day = (int) [components day];
            month = (int) [components month];
            year = (int) [components year];
            
            NSArray *convertDate = [Calendar convertSolar2Lunar:day mm:month yy:year timeZone:7.0];
            if ([convertDate count] > 0) {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                
                NSString *date = [NSString stringWithFormat:@"%@-%@-%@", convertDate[2], convertDate[1], convertDate[0]];
                _sDate = [dateFormatter dateFromString:date];
            }
        }
        
        // Start loading data from database
        Db *db = [Db currentDb];
        
        Tuvi *tuvi = [[Tuvi alloc] init];
        NSArray * data = [db loadAsDictArray:[NSString stringWithFormat:@"SELECT * FROM tbl_tuvi WHERE duonglich LIKE '%%%d%%'", year]];
        
    }
}

#pragma mark - TBDATE PICKER DELEGATE
- (void)dateChanged:(id)sender
{
}

#pragma mark - TABLE VIEW DATASOURCE
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _hourData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 30;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
    cell.separatorInset = UIEdgeInsetsZero;
    cell.textLabel.font = [UIFont systemFontOfSize:13];
    cell.textLabel.text = [_hourData objectAtIndex:indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _hourTableView.hidden = TRUE;
    
    _txtBirthhour.text = [_hourData objectAtIndex:indexPath.row];
}

#pragma mark - TEXTFIELD DELEGATE
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField == _txtBirthhour) {
        _hourTableView.hidden = FALSE;
        
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return TRUE;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
