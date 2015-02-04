//
//  NSDate+DateFunctions.h
//  JhonSell
//
//  Created by Mario Montoya on 22/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (DateFunctions) 

+ (NSDate *) dateFromISOString:(NSString *)dateStr;

- (NSString *) formatAsISODate;
- (NSString *) formatAsString;

- (NSDate *) addDays:(NSInteger)numDays;

+ (NSInteger) daysBetweenDates: (NSDate *)fromDate ToDate:(NSDate *)toDate;
+ (NSDate *) addMonths: (NSDate *)toDate Months:(NSInteger)months;
+ (NSDate *) dateFromString:(NSString *)strDate;
+ (NSDate *) dateWithString:(NSString *)strDate;

- (NSDate *) addMonths: (NSInteger)months;

@end
