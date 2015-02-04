//
//  NSString+Clean.m
//  JhonSell
//
//  Created by Mario Montoya on 9/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "NSString+Clean.h"


@implementation NSString (clean) 

+ (NSString *) arrayToString: (NSArray *)array {
	NSMutableString * list = [NSMutableString string];
	
	int count = [array count];
	int i;
	
	for (i = 0; i < count; i++) { 
		if (i + 1 == count) {
			[list appendFormat:@"%@", [array objectAtIndex:i] ];
		}
		else {
			[list appendFormat:@"%@, ", [array objectAtIndex:i] ];
		}
	} 
	
	return list;
}

- (NSString *) trim {
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end
