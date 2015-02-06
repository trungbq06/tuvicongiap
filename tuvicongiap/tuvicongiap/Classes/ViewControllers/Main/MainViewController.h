//
//  MainViewController.h
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/3/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Db.h"
#import "TBDatePicker.h"
#import "Tuvi.h"
#import "GlobalTextField.h"

@interface MainViewController : UIViewController <TBDatePickerDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, retain) TBDatePicker *datePicker;
@property (nonatomic, retain) UITableView *hourTableView;
@property (nonatomic, retain) NSMutableArray *hourData;

@property (nonatomic, retain) NSDate         *sDate;
@property (nonatomic, assign) int            cType;

@property (weak, nonatomic) IBOutlet GlobalTextField *txtUsername;
@property (weak, nonatomic) IBOutlet GlobalTextField *txtBirthday;
@property (weak, nonatomic) IBOutlet GlobalTextField *txtBirthhour;

@end
