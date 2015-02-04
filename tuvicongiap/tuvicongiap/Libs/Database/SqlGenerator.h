//
//  SqlGenerator.h
//  JhonSell
//
//  Created by Mario Montoya on 9/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <objc/runtime.h>
#import <objc/message.h>
#import "DbObject.h"
#import "NSString+Clean.h"
#import "NSDate+DateFunctions.h"

@interface SqlGenerator : NSObject {

}

+(NSString *)optimizeLike:(NSString *)name value:(NSString *)value indexColumn:(NSString *)indexColumn;

+(NSString *) quoteValue: (id)Value;
+(NSString *) buildSelect: (NSString *)tableName fields:(NSArray *)fields filters:(NSArray *)filterList orders:(NSArray *)orderList;
+(NSString *) buildDelete: (NSString *)tableName filters:(NSArray *)filterList;
+(NSString *) buildInsertUpdate: (NSString *)tableName fieldsAndValues:(NSDictionary *)fieldsAndValues;

+(NSString *) buildFilterCriteria: (NSArray *)filterList;

@end
