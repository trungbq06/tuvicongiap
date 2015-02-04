//
//  Db.m
//  JhonSell
//
//  Created by Mario Montoya on 7/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "Db.h"
#import "DbPool.h"

@implementation Db

@synthesize path, theDb,isOpen;

- (id)init {
    if ((self = [super init])) {
        self.path = @"";
		isOpen = NO;
    }
	
	return self;
}

- (id)initWithName:(NSString *)name{
    if ((self = [super init])) {
		self.path = [name copy];
		isOpen = NO;
    }
	
	return self;
}

- (void)dealloc
{ 
	[self closeDb];
	
	[theDb release];
	[path release];
	
    [super dealloc];
}

+(BOOL) dbIsSet {
	return [[DbPool sharedInstance] existConn:@"default"];
}

+(id)currentDb {
	return [self currentDb:@"default"];
}

+(id)currentDb: (NSString *)name {
	return [[DbPool sharedInstance] getConn: name];
}

#pragma mark DbAdmin
-(void) createDb{
	if ([self existDb]) {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:[NSString stringWithFormat:NSLocalizedString(@"The database file %@ already exist.",@"Error Db: Database file exist"),self.path]
						  userInfo:nil];
		@throw e;
	}
	
	self.theDb = [FMDatabase databaseWithPath: self.path];

	if (![self.theDb open]) {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:NSLocalizedString(@"Can't create database.",@"Error Db: Database can't be created")
						  userInfo:nil];
		@throw e;
	}
	[self.theDb close];
}

-(void) openDb{
	if (!isOpen) {
		if (![self existDb]) {
			NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Database file %@ not exist.",@"Error Db: File not exist"),self.path];
			NSException *e = [NSException						  
							  exceptionWithName:@"DBError"						  
							  reason:msg				  
							  userInfo:nil];
			@throw e;			
		}

		self.theDb = [FMDatabase databaseWithPath: self.path];

		if (![self.theDb open]) {
			[self checkError];
			NSException *e = [NSException						  
							  exceptionWithName:@"DBError"						  
							  reason:NSLocalizedString(@"Can't open database. Unknow reason",@"Error Db: Database can't be open")
							  userInfo:nil];
			@throw e;
		}
		
		isOpen = YES;
		//Some optimization tweaks
		[self execute:@"PRAGMA cache_size=100"];
		[self execute:@"PRAGMA foreign_keys = ON"];

		ALog(@"Db: %@",self.path);
	}
}

-(void) closeDb{
	if (isOpen) {
		[self.theDb close];
		isOpen = NO;
	}
}

-(BOOL) existDb {
	return [Db existDb:self.path];
}

+(BOOL) existDb:(NSString *)dbPath {
	if (dbPath) {
		//
	} else {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:NSLocalizedString(@"Bad data type.",@"Error Db: Database can't be created")
						  userInfo:nil];
		@throw e;			
	}
	
	return [[NSFileManager defaultManager] fileExistsAtPath: dbPath];
}

-(void) checkError{
    if ([self.theDb hadError]) {
		ALog(@"Err %d: %@", [self.theDb lastErrorCode], [self.theDb lastErrorMessage]);
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:[self.theDb lastErrorMessage]						  
						  userInfo:nil];
		
		@throw e;
    }
}

#pragma mark SqlGeneration
-(NSString *) buildDeleteSql: (DbObject *)ds forceDelete:(BOOL)forceDelete {
	if ([ds isNew]) {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:NSLocalizedString(@"Try to delete a non-existant record",@"Error Db:Try to delete a non-existant record")
						  userInfo:nil];
		@throw e;
	}

	NSString *filter = [NSString stringWithFormat:@"Id = %ld", ds.Id ];
	NSMutableArray *filterList = [NSMutableArray array];
	
	[filterList addObject:filter];
	
	return [SqlGenerator buildDelete:[ds tableName] filters:filterList];
}

-(NSString *) buildUpdateSql: (DbObject *)ds {
	NSDictionary *fieldsAndValues = [ds asDict];
	
	if (ds.Id==0) {
		[fieldsAndValues setValue:[NSNull null] forKey:@"Id"];
	}
	
	return [SqlGenerator buildInsertUpdate:[ds tableName] fieldsAndValues:fieldsAndValues];
}

-(FieldType) typeForField:(NSString *)fieldName Type:(NSString *)fieldType {
	FieldType result = FIELDTYPE_INTEGER;
	
	if ([fieldType isEqualToString:@"i"] || // int
		[fieldType isEqualToString:@"I"] || // unsigned int
		[fieldType isEqualToString:@"s"] || // short
		[fieldType isEqualToString:@"S"] || // unsigned short
		[fieldType isEqualToString:@"f"] || // float
		[fieldType isEqualToString:@"d"] )  // double
	{
		result = FIELDTYPE_INTEGER;
	}	
	else if ([fieldType isEqualToString:@"B"]) // bool or _Bool
	{
		result = FIELDTYPE_BOOLEAN;
	}
	else if ([fieldType isEqualToString:@"l"] || // long
			 [fieldType isEqualToString:@"L"] || // usigned long
			 [fieldType isEqualToString:@"q"] || // long long
			 [fieldType isEqualToString:@"Q"] ) // unsigned long long
	{
		result = FIELDTYPE_NUMBER;
	}
	else if ([fieldType isEqualToString:@"c"] || // char
			 [fieldType isEqualToString:@"C"] ) // unsigned char
		
	{
		result = FIELDTYPE_BOOLEAN;
	}
	else if ([fieldType hasPrefix:@"@"] ) // Object
	{
		NSString *className = [fieldType substringWithRange:NSMakeRange(2, [fieldType length]-3)];
		
		if ([className isEqualToString:@"NSString"]) {
			result = FIELDTYPE_STRING;
		} 
		else if ([className isEqualToString:@"NSDate"]) {
			result = FIELDTYPE_DATETIME;
		}
		else if ([className isEqualToString:@"NSInteger"]) {
			result = FIELDTYPE_INTEGER;
		}
		else if ([className isEqualToString:@"NSDecimalNumber"]) {
			result = FIELDTYPE_DECIMAL;
		}
		else if ([className isEqualToString:@"NSNumber"]) {
			result = FIELDTYPE_NUMBER;
		}
		else 
		{
			//Is a relationship one-to-one?
			if (![fieldType hasPrefix:@"NS"]) {
				result = FIELDTYPE_OBJECT;
			} else {
				NSString *msg = NSLocalizedString(@"Err Can't get value for field %@ of type %@", @"Error Db: Failed to introspect field type");
				
				NSString *error = [NSString stringWithFormat:msg, fieldName, fieldType];

				NSException *e = [NSException						  
								  exceptionWithName:@"DBError"						  
								  reason:error					  
								  userInfo:nil];
				
				@throw e;
			}
		}
	}
	
	return result;	
}

-(id) valueForField: (FMResultSet *)rs Name:(NSString *)fieldName Type:(NSString *)fieldType {
	id fieldValue = nil;
	id rel = nil;
	NSString *className;
	NSString *dateStr;
	FieldType type = [self typeForField:fieldName Type:fieldType];
	
	switch (type) {
		case FIELDTYPE_STRING:
			fieldValue = [rs stringForColumn:fieldName];
			break;
		case FIELDTYPE_INTEGER:
			fieldValue = [NSNumber numberWithInt: [rs longForColumn:fieldName]];			
			break;
		case FIELDTYPE_NUMBER:
			fieldValue = [NSNumber numberWithDouble: [rs doubleForColumn:fieldName]];
			break;
		case FIELDTYPE_BOOLEAN:
			fieldValue = [rs stringForColumn:fieldName];
			//Is really a boolean?
			if ([fieldValue isEqualToString:@"0"] || [fieldValue isEqualToString:@"1"]) {
				fieldValue = [NSNumber numberWithInt: [fieldValue intValue]];
			} else {
                fieldValue = [NSNumber numberWithInt: 0];
            }
			break;
		case FIELDTYPE_DATETIME:
			dateStr = [rs stringForColumn:fieldName];
			
			if (dateStr) {
				fieldValue  = [NSDate dateFromISOString:dateStr];
			} 
			else
			{
				fieldValue = nil;
			}
			break;
		case FIELDTYPE_DECIMAL:
			fieldValue = [rs stringForColumn :fieldName];
			if (fieldValue) {
				fieldValue = [NSDecimalNumber decimalNumberWithString:fieldValue];
			} else {
				fieldValue = [NSDecimalNumber zero];
			}

			break;
		case FIELDTYPE_OBJECT:
			className = [fieldType substringWithRange:NSMakeRange(2, [fieldType length]-3)];
			rel =  class_createInstance(NSClassFromString(className), sizeof(unsigned));
			Class theClass = [rel class];
			
			if ([rel isKindOfClass:[DbObject class]]) {
				fieldValue = [rel init];
				//Load the record...
				NSInteger Id = [rs intForColumn:[theClass relationName]];
				if (Id>0) {
					[fieldValue release];
					
					Db *db = [Db currentDb];
					
					fieldValue = [db loadById: theClass theId:Id];
				}
			}
			break;
	}

	return fieldValue;	
}

#pragma mark Transactions
-(void) beginTransaction {
	if ([self inTransaction]==NO) {
		[self.theDb beginTransaction];
	}
}

-(void) rollbackTransaction {
	if ([self inTransaction]) {
		[self.theDb rollback];
	}
}

-(void) commitTransaction {
	if ([self inTransaction]) {
		[self.theDb commit];
	}
}

-(BOOL) inTransaction {
	[self openDb];
	return [self.theDb inTransaction];
}

#pragma mark Save & retrieval
-(NSArray *) saveList: (NSArray *)list {
	[self beginTransaction];
	DbObject *record;
	NSMutableArray *errors  = [NSMutableArray array];
	BOOL isOk = YES;
	
	@try {
		for (record in list) {
			if (![self save:record]) {
				
				[errors addObject:[record errorsAsString]];				
				
				isOk =  NO;
			}
		}
		
		if (isOk == NO) {
			[self rollbackTransaction];			
		}

		return errors;
	}
	@catch (NSException * e) {
		[self rollbackTransaction];
		
		@throw e;
	}
	@finally {
		[self commitTransaction];
		return errors;
	}
}


-(NSArray *) deleteList: (NSArray *)list {
	[self beginTransaction];
	DbObject *record;
	NSMutableArray *errors  = [NSMutableArray array];
	BOOL isOk = YES;
	
	@try {
		for (record in list) {
			if (![self del:record]) {
				
				[errors addObject:[record errorsAsString]];				
				
				isOk =  NO;
			}
		}
		
		if (isOk == NO) {
			[self rollbackTransaction];			
		}
		
		return errors;
	}
	@catch (NSException * e) {
		[self rollbackTransaction];
		
		@throw e;
	}
	@finally {
		[self commitTransaction];
		return errors;
	}	
}

-(BOOL) save: (DbObject *) ds {
	if ([ds isValid] == NO) {
		return NO;
	}
	
	[self openDb];
	BOOL isNew = [ds isNew];

	if (![ds beforeSave]) {
		[self checkError];
		
		return NO;
	}

	NSString *sql = [self buildUpdateSql:ds];
	
	[self execute:sql];
	
	[self checkError];
	
	if (isNew) {
		ds.Id = [self lastRowId];
	}

	if (![ds afterSave]) {
		[self checkError];
		
		return NO;
	}
	return YES;
}

-(void) fill: (DbObject *)ds resultset:(FMResultSet *)rs{
	[self openDb];
	
	NSDictionary *props = [ds properties];
	NSString *fieldType = nil;
	
	id fieldValue;
	
	for (NSString *fieldName in [props allKeys]) {
		fieldType = [props objectForKey: fieldName];

		fieldValue = [self valueForField:rs Name:fieldName Type:fieldType];
		
		[ds setValue:fieldValue forKey:fieldName];
	}
}

// Determinar si hace un delete logico
-(BOOL) del: (DbObject *)ds {
	[self openDb];

	if (![ds beforeDelete]) {
		[self checkError];
		
		return NO;
	}
	
	NSString *sql = [self buildDeleteSql :ds forceDelete:NO];
	
	[self execute:sql];
	
	[self checkError];	

	if (![ds afterDelete]) {
		[self checkError];
		
		return NO;
	}

	return YES;
}

-(BOOL) forceDel: (DbObject *)ds {
	[self openDb];

	if (![ds beforeDelete]) {
		[self checkError];
		
		return NO;
	}
	
	NSString *sql = [self buildDeleteSql:ds forceDelete:YES];
	
	[self execute:sql];
		
	[self checkError];

	if (![ds afterDelete]) {
		[self checkError];
		
		return NO;
	}

	return YES;
}

-(id) loadByFieldAndValue: (Class)cls fieldName:(NSString *)fieldName value:(id)value {
	NSString *sql = [NSString stringWithFormat: @"SELECT * FROM [%@] WHERE %@ = %@", [DbObject getTableName:cls], fieldName, [SqlGenerator quoteValue:value]];
	DbObject *result = nil;
	
	NSArray *list = [self loadAndFill:sql theClass:cls];
	
	if ([list count] == 1) {
		result = [list objectAtIndex:0];
	}

	return result;							
}

-(id) loadFirst: (NSString *)sql theClass:(Class)cls {
	DbObject *result = nil;
	
	NSArray *list = [self loadAndFill:sql theClass:cls];
	
	if ([list count]) {
		result = [list objectAtIndex:0];
	}
	
	return result;	
}

-(id) loadById: (Class)cls theId:(NSInteger)theId {
	return [self loadByFieldAndValue:cls fieldName:@"Id" value: [NSNumber numberWithInt: theId]];
}

-(NSArray *) loadAndFill: (NSString *)sql theClass: (Class)cls {
	[self openDb];
	
	NSMutableArray *list = [NSMutableArray array];

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	DbObject *ds;
	Class myClass = NSClassFromString([DbObject getTableName:cls]);
	
	FMResultSet *rs = [self load:sql];
		
	while ([rs next]) {
		ds = [[myClass alloc] init];
		
		[self fill:ds resultset:rs];
		
		[list addObject :ds];
		
		[ds release];
	}
	[rs close];

	[pool drain];
	return list;
}

-(NSMutableArray *) loadAndFillDict: (NSString *)sql  fields:(NSArray *)fields theClass:(Class)cls {
	[self openDb];
	NSMutableArray *list = [NSMutableArray array];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	Class myClass = NSClassFromString([DbObject getTableName:cls]);
	DbObject *ds = [[[myClass alloc] init] autorelease];
	NSString *fieldType = nil;
	id fieldValue;

	NSDictionary *props = [ds properties];

	FMResultSet *rs = [self load:sql];

	while ([rs next]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];

		for (NSString *fieldName in [props allKeys]) {
			if ([fields indexOfObject:fieldName] == NSNotFound) {
				continue;
			}
			
			fieldType = [props objectForKey: fieldName];
			
			fieldValue = [self valueForField:rs Name:fieldName Type:fieldType];

			[dict setValue:fieldValue forKey:fieldName];
		}
		
		[list addObject :dict];
	}
	[rs close];
	
	[pool drain];

	return list;
}

#pragma mark DbCommands
-(NSArray *) loadAsDictArray: (NSString *)sql {
	NSMutableArray *list = [[NSMutableArray alloc] init];
	//NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	id value;

	FMResultSet *rs = [self load:sql];
	
	while ([rs next]) {
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		
		for (NSString *fieldName in [rs columnsName]) {
			value = [rs stringForColumn:fieldName];
			if (value) {
				[dict setObject:value forKey:fieldName];
			} else {
				[dict setObject:@"" forKey:fieldName];
			}
		}
		
		[list addObject :dict];
		
		[dict release];
	}
	[rs close];

	//[pool drain];
	
	return [list autorelease];
}

-(FMResultSet *) load: (NSString *)sql{
	[self openDb];
	FMResultSet *rs;
	ALog(sql);
	rs = [self.theDb executeQuery :sql];
	
	[self checkError];
	
	return rs;
}

-(void) execute: (NSString *)sql{
	[self openDb];
	ALog(sql);	
	[self.theDb executeUpdate :sql];
	
	[self checkError];
}

-(NSInteger) lastRowId {
	[self openDb];
	
	NSInteger rowId;

	rowId = [self.theDb lastInsertRowId];
	
	[self checkError];
	
	return rowId;
}

-(NSInteger) count: (NSString *)tableName{
	[self openDb];
	
	NSInteger count;
	
	count = [self.theDb intForQuery:[NSString stringWithFormat: @"SELECT count(1) FROM [%@]",tableName]];
	
	[self checkError];
	
	return count;
}

-(NSInteger) intValue: (NSString *)sql {
	[self openDb];
	
	NSInteger count;
	
	count = [self.theDb intForQuery:sql];
	
	[self checkError];
	
	return count;	
}

-(NSNumber *) numericValue: (NSString *)sql {
	[self openDb];
	NSNumber *value;
	
	value = [NSNumber numberWithDouble:[self.theDb doubleForQuery:sql]];
	
	[self checkError];
	
	return value;
}

-(NSDecimalNumber *) decimalValue: (NSString *)sql {
	NSNumber *value = [self numericValue:sql];

	return [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];;
}

#pragma mark Pragma functions
-(NSInteger) userDatabaseVersion {
	return [[self numericValue:@"PRAGMA user_version"] intValue];
}


@end
