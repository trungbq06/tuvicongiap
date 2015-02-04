//
//  SqlGenerator.m
//  JhonSell
//
//  Created by Mario Montoya on 9/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "SqlGenerator.h"

@implementation SqlGenerator

+(NSString *)optimizeLike:(NSString *)name value:(NSString *)value indexColumn:(NSString *)indexColumn;
{
	NSMutableString * sql = [NSMutableString string];
	BOOL generateSql = YES;
	
	//Return a optimized query that mimic a LIKE
	if (indexColumn) {
		[sql appendFormat:@"(%@ = '%@')", indexColumn, [[value substringToIndex:1] uppercaseString]];
		if ([value length]==1) {
			generateSql = NO;
		} else {
			[sql appendString:@" AND "];
		}
	}
	
	if (generateSql) {
		[sql appendFormat:@"(%@ > '%@' AND %@ < '%@~') OR %@ = '%@'",name,value,name,value,name,value];		
	}
	ALog(sql);
	return sql;
}

+(NSString *) buildFilterCriteria: (NSArray *)filterList {
	NSMutableString * sql = [NSMutableString string];
	int count;
	int i;

	[sql appendString :@" WHERE "];
	
	count = [filterList count];
	
	for (i = 0; i < count; i++) { 
		if (i + 1 == count) {
			[sql appendFormat:@"(%@)", [filterList objectAtIndex:i] ];
		}
		else {
			[sql appendFormat:@"(%@) AND ", [filterList objectAtIndex:i] ];
		}
	} 
	
	return sql;
}

+(NSString *) buildSelect: (NSString *)tableName fields:(NSArray *)fields filters:(NSArray *)filterList orders:(NSArray *)orderList {
	NSMutableString * sql = [NSMutableString string];	

	[sql appendString :@"SELECT "];

	//Get the list of fields
	if (fields) {
		[sql appendString:[NSString arrayToString :fields]];
	}
	else
	{
		[sql appendString :@"*"];
	}
	
	[sql appendString:@" FROM "];
	[sql appendString:[NSString stringWithFormat:@"[%@]",tableName]];
	
	//Add the filters
	if (filterList) {
		[sql appendString: [SqlGenerator buildFilterCriteria:filterList]];
	}
	
	//Add the order
	if (orderList) {
		[sql appendString :@" ORDER BY "];
		[sql appendString:[NSString arrayToString :orderList]];
	}

	return sql;
}

+(NSString *) buildDelete: (NSString *)tableName filters:(NSArray *)filterList {
	NSMutableString * sql = [NSMutableString string];	

	[sql appendFormat: @"DELETE FROM [%@]", tableName];

	//Add the filters
	if (filterList) {
		[sql appendString: [SqlGenerator buildFilterCriteria:filterList]];
	}
	
	return sql;	
}

+(NSString *) quoteValue: (id)Value {
    static NSLocale *US_LOCALE = nil;
    
    if (!US_LOCALE) {
        US_LOCALE = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_us"]
                     autorelease];
    }

	NSString *strValue = nil;
	
	if ([Value isKindOfClass:[NSNull class]]) 
	{
		strValue = @"NULL";
	}
	else if ([Value isKindOfClass:[NSString class]]) 
	{
		strValue = [NSString stringWithFormat: @"'%@'", Value];
	} 
	else if ([Value isKindOfClass:[NSDecimalNumber class]]) 
    {
        strValue = [(NSDecimalNumber *)Value descriptionWithLocale:US_LOCALE];
    } 
	else if ([Value isKindOfClass:[NSNumber class]]) 
    {
        strValue = [(NSNumber *)Value descriptionWithLocale:US_LOCALE];
    } 
	else if ([Value isKindOfClass:[NSDate class]]) 
	{
		NSDate *date = Value;

		strValue = [NSString stringWithFormat:@"'%@'",[date formatAsISODate]];
	}
	else if ([Value isKindOfClass:[DbObject class]]) 
	{
		DbObject *hold = Value;
		strValue = [NSString stringWithFormat: @"%@", hold.Id];
	}
	else
	{
		strValue = [NSString stringWithFormat: @"%@", Value];
	}

	return strValue;
}

+(NSString *) buildInsertUpdate: (NSString *)tableName fieldsAndValues:(NSDictionary *)fieldsAndValues {
	NSMutableString * sql = [NSMutableString string];
	NSMutableArray *values = [NSMutableArray array];
	NSString *key;
	id Value;
	
	[sql appendFormat: @"INSERT OR REPLACE INTO [%@] (%@", tableName, [NSString arrayToString :[fieldsAndValues allKeys]]];
	
	//Make sure to set the timestamp field if exist
	for (key in [fieldsAndValues allKeys]) {
		if ([[key lowercaseString] isEqualToString:@"timestamp"]) {
			[fieldsAndValues setValue:[NSDate date] forKey:key];
			break;
		}
	}
	
	for (Value in [fieldsAndValues allValues]) {
		[values addObject:[self quoteValue:Value]];
	}

	[sql appendFormat: @") VALUES (%@)", [NSString arrayToString :values]];

	return sql;		
}

@end
