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
    
    _datePicker = [[TBDatePicker alloc] initWithFrame:CGRectMake(0, 20, 320, 264) maxDate:[NSDate dateWithTimeIntervalSinceNow:7*24*60*60] minDate:[NSDate date] showValidDatesOnly:NO];
    
    _datePicker.delegate = self;
    [self.view addSubview:_datePicker];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGRect dateFrame = _txtBirthday.frame;
    _datePicker.frame = dateFrame;
    _datePicker.layer.borderWidth = 1.0;
    _datePicker.layer.borderColor = [[UIColor grayColor] CGColor];
    
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
    NSString *username = _txtUsername.text;
    NSString *birthDay = _txtBirthday.text;
    NSString *birthHour = _txtBirthhour.text;
    
    
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
