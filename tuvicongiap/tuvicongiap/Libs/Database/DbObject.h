//
//  DbObject.h
//  JhonSell
//
//  Created by Mario Montoya on 7/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSString+Clean.h"
#import "DbCache.h"

typedef enum { 
	FIELDTYPE_STRING=0, FIELDTYPE_INTEGER=1,FIELDTYPE_NUMBER=2, FIELDTYPE_DECIMAL=3,
	FIELDTYPE_BOOLEAN=4,FIELDTYPE_DATETIME=5,FIELDTYPE_OBJECT=6
} FieldType;

@interface DbObject : NSObject {
	NSInteger Id;
	NSMutableArray *_errors;
}

@property (nonatomic) NSInteger Id;
@property (nonatomic, retain) NSMutableArray *errors;

- (BOOL)validateForInsertAndUpdate:(NSError **)error;
- (BOOL)validateForDelete:(NSError **)error;
- (NSString *)errorsAsString;

-(BOOL) isValid;
-(BOOL) isNew;
-(void) setDefaults;

-(BOOL) beforeSave;
-(BOOL) beforeDelete;
-(BOOL) afterSave;
-(BOOL) afterDelete;

-(NSDictionary *) asDict;
-(NSString *) tableName;
+(NSString *) tableName;
+(NSString *) getTableName: (Class)cls;
+(NSString *) relationName;

-(NSDictionary *)properties;
+(NSDictionary *)properties;
+(NSDictionary *)loadProperties;
+(NSString *)propertiesAsStringList;

@end

@interface DbObjectTime : DbObject {
	NSDate* timeStamp;
}

@property (nonatomic, retain) NSDate *timeStamp;

@end