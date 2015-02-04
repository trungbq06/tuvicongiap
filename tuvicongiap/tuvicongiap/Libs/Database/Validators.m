//
//  Validators.m
//  JhonSell
//
//  Created by Mario Montoya on 13/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "Validators.h"


@implementation Validators

static NSString *VALIDATOR_DOMAIN = @"Validators";
static NSInteger ERR_NOTEMPTY = 15;
static NSInteger ERR_COMPARE = 16;

+(BOOL)validateNotEmpty:(id *)ioValue propName:(NSString *)name error:(NSError **)outError {
	if (*ioValue==nil) {
		return YES;
	}
	
	NSString *strValue = [[NSString stringWithFormat:@"%@", *ioValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	if ([strValue isEqualToString:@""] ||
		[strValue isEqualToString:@"<null>"] ||
		[strValue isEqualToString:@"0"] ) {
		
		if (outError!=NULL) {
			NSDictionary *infoDict = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"%@ must not be empty",@"Error:%@ must not be empty"),name] forKey:NSLocalizedDescriptionKey];

			*outError = [NSError errorWithDomain:VALIDATOR_DOMAIN
											code:ERR_NOTEMPTY 
										userInfo:infoDict];
		}
			
		return NO;
	}
		
	return YES;
}

+(BOOL)validateCompareDate:(NSComparisonResult)compare propName:(NSString *)name 
			dateOne:(NSDate *)dateOne dateTwo:(NSDate *)dateTwo error:(NSError **)outError 
{
	BOOL result = YES;
	NSString *msg = nil;

	switch (compare) {
		case NSOrderedSame:
			if (![dateOne isEqualToDate:dateTwo]) {
				msg = [NSString stringWithFormat:NSLocalizedString(@"Date for %@ is not equal to %@",@"Error:Date not equal"),name,[dateTwo formatAsString]];
				result = NO;
			}
			break;
		case NSOrderedAscending:
			if ([dateOne compare:dateTwo]==NSOrderedDescending) {
				msg = [NSString stringWithFormat:NSLocalizedString(@"Date for %@ must be higer than %@",@"Error:Date must be higher"),name,[dateTwo formatAsString]];
				result = NO;
			}			
			break;
		case NSOrderedDescending:
			if ([dateOne compare:dateTwo]==NSOrderedAscending) {
				msg = [NSString stringWithFormat:NSLocalizedString(@"Date for %@ must be lower than %@",@"Error:Date must be lower"),name,[dateTwo formatAsString]];
				result = NO;
			}
			break;
	}

	if (!result) {
		if (outError!=NULL) {
			NSDictionary *infoDict = [NSDictionary dictionaryWithObject:msg
																 forKey:NSLocalizedDescriptionKey];

			*outError = [NSError 
					 errorWithDomain:VALIDATOR_DOMAIN
					 code:ERR_COMPARE 
					 userInfo:infoDict];	
		}
	}
	
	return result;
}

+(BOOL)validateRegex:(id *)ioValue regex:(NSString *)regex propName:(NSString *)name error:(NSError **)outError {
	return YES;
}

@end
