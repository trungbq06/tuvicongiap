//
//  Db.h
//  JhonSell
//
//  Created by Mario Montoya on 7/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DbObject.h"
#import "FuncionesGlobales.h"
#import "SqlGenerator.h"
#import "FMResultSet+Additions.h"

@interface Db : NSObject {
	NSString *path;
	FMDatabase* theDb;
	BOOL isOpen;
}

@property (retain, nonatomic) FMDatabase *theDb;
@property (retain, nonatomic) NSString *path;
@property (nonatomic) BOOL isOpen;

+(BOOL) dbIsSet;
+(Db *)currentDb;
+(Db *)currentDb: (NSString *)name;

-(void) beginTransaction;
-(void) rollbackTransaction;
-(void) commitTransaction;
-(BOOL) inTransaction;

-(void) createDb;
-(void) openDb;
-(void) closeDb;
-(BOOL) existDb;
+(BOOL) existDb:(NSString *)dbPath;

-(void) checkError;

-(id) valueForField: (FMResultSet *)rs Name:(NSString *)fieldName Type:(NSString *)fieldType;
-(FieldType) typeForField:(NSString *)fieldName Type:(NSString *)fieldType;

-(NSString *) buildUpdateSql: (DbObject *)ds;
-(NSString *) buildDeleteSql: (DbObject *)ds forceDelete:(BOOL)forceDelete;

-(NSArray *) saveList: (NSArray *)list;
-(NSArray *) deleteList: (NSArray *)list;

-(BOOL) save: (DbObject *)ds;
-(void) fill: (DbObject *)ds resultset:(FMResultSet *)rs;
-(BOOL) del: (DbObject *)ds;
-(BOOL) forceDel: (DbObject *)ds;

-(id) loadFirst: (NSString *)sql theClass:(Class)cls;
-(id) loadById: (Class)cls theId:(NSInteger)theId;
-(id) loadByFieldAndValue: (Class)cls fieldName:(NSString *)fieldName value:(id)value;

-(NSArray *) loadAndFill: (NSString *)sql theClass:(Class)cls;
-(NSMutableArray *) loadAndFillDict: (NSString *)sql fields:(NSArray *)fields theClass:(Class)cls;
-(FMResultSet *) load: (NSString *)sql;
-(NSArray *) loadAsDictArray: (NSString *)sql;

-(void) execute: (NSString *)sql;

-(NSInteger) lastRowId;
-(NSInteger) count: (NSString *)tableName;
-(NSInteger) intValue: (NSString *)sql;
-(NSNumber *) numericValue: (NSString *)sql;
-(NSDecimalNumber *) decimalValue: (NSString *)sql;

- (id)initWithName:(NSString *)name;

#pragma mark Pragma functions
-(NSInteger) userDatabaseVersion;

@end
