//
//  NSDate+DateFunctions.m
//  JhonSell
//
//  Created by Mario Montoya on 22/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "NSDate+DateFunctions.h"

@implementation NSDate (DateFunctions) 

+ (NSDate *) dateFromISOString:(NSString *)dateStr {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSLocale* locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
	[dateFormatter setLocale:locale];
	[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
	
	NSDate *date = [dateFormatter dateFromString: dateStr];
	
	[dateFormatter release];
	
	return date;
}

- (NSString *) formatAsISODate {
	NSDateComponents *dateComp;
	NSCalendar *cal = [NSCalendar currentCalendar];

	dateComp = [cal 
			components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit 
						| NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) 
			fromDate:self];

	return [NSString stringWithFormat:@"%02d-%02d-%02dT%02d:%02d:%02d",dateComp.year,
			dateComp.month,dateComp.day,dateComp.hour,dateComp.minute,dateComp.second];
}

- (NSString *) formatAsString {
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	
	return [dateFormatter stringFromDate: self];
}

- (NSDate *) addDays:(NSInteger)numDays {
	NSDate *now = self;
	
		// set up date components
	NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
	[components setDay:numDays];
	
		// create a calendar
	NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	
	NSDate *newDate2 = [gregorian dateByAddingComponents:components toDate:now options:0];
	
	return newDate2;
}

+(NSInteger) daysBetweenDates: (NSDate *)fromDate ToDate:(NSDate *)toDate {
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	int days=0;
	
	NSDateComponents *components = [gregorian components:NSDayCalendarUnit									
												fromDate:fromDate									
												  toDate:toDate options:0];

	days = [components day];
	
	[gregorian release];

	return days;
}

+ (NSDate *) addMonths: (NSDate *)toDate Months:(NSInteger)months {
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDateComponents *components = [[NSDateComponents alloc] init];
	components.month = months;
	NSDate *nextMonth = [gregorian dateByAddingComponents:components toDate:toDate options:0];
	[components release];
	
	NSDateComponents *nextMonthComponents = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit fromDate:nextMonth];
	NSDateComponents *todayDayComponents = [gregorian components:NSDayCalendarUnit fromDate:toDate];
	
	nextMonthComponents.day = todayDayComponents.day;
	NSDate *nextMonthDay = [gregorian dateFromComponents:nextMonthComponents];
	
	[gregorian release];
	
	return nextMonthDay;
}

+ (NSDate *) dateFromString:(NSString *)strDate {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd"];
	
	NSDate *date = [dateFormatter dateFromString: strDate];
	
	[dateFormatter release];
	
	return date;
}

+ (NSDate *) dateWithString:(NSString *)strDate {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ssZ"];

	NSDate *date = [dateFormatter dateFromString: strDate];
	
	[dateFormatter release];
	
	return date;	
}

- (NSDate *) addMonths: (NSInteger)months {
	return [NSDate addMonths:self Months:months];
}

@end
