//
//  Validators.h
//  JhonSell
//
//  Created by Mario Montoya on 13/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "NSDate+DateFunctions.h"

//Generic validators

@interface Validators : NSObject {

}

+(BOOL)validateNotEmpty:(id *)ioValue propName:(NSString *)name error:(NSError **)outError;
+(BOOL)validateCompareDate:(NSComparisonResult)compare propName:(NSString *)name dateOne:(NSDate *)dateOne dateTwo:(NSDate *)dateTwo 	error:(NSError **)outError;
+(BOOL)validateRegex:(id *)ioValue regex:(NSString *)regex propName:(NSString *)name error:(NSError **)outError;


@end
