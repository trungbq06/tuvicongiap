//
//  DetailViewController.h
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/6/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Tuvi.h"

@interface DetailViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextView *content;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *sex;
@property (nonatomic, retain) NSString *birthDay;
@property (nonatomic, retain) NSString *birthHour;

@property (nonatomic, retain) Tuvi *tuvi;

- (IBAction)backClick:(id)sender;

@end
