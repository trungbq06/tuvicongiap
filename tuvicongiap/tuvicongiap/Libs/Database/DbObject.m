//
//  DbObject.m
//  JhonSell
//
//  Created by Mario Montoya on 7/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "DbObject.h"

@implementation DbObject

@synthesize Id, errors = _errors;

-(id)init {
	if ((self = [super init])) {
		[self setDefaults];
		self.errors = [[[NSMutableArray alloc] init] autorelease];
	}
	
	return self;
}

- (void)dealloc
{
	[_errors release];
	
	[super dealloc];
}

#pragma mark Validation
- (BOOL)validateForInsertAndUpdate:(NSError **)error {
	return YES;
}

- (BOOL)validateForDelete:(NSError **)error {
	return YES;
}

-(BOOL) isValid{
	BOOL isOk = YES;
	NSDictionary *fieldsAndValues =[self asDict];
	NSError *error=nil;

	[self.errors removeAllObjects];
	
	for (NSString *key in [fieldsAndValues allKeys]) {
		id value= [fieldsAndValues objectForKey:key];

		if ([self validateValue :&value forKey :key error :&error]==NO) {
			if (error==nil) {
				NSException *e = [NSException						  
								  exceptionWithName:@"DBError"						  
								  reason:[NSString stringWithFormat: @"NSError is nil for %@", key]
								  userInfo:nil];
				@throw e;			
			}
			
			[self.errors addObject:error];

			isOk = isOk && NO;
		}
	}
	//Only invoke validation for row if properties are Ok
	if (isOk && [self validateForInsertAndUpdate:&error]==NO) {
		[self.errors addObject:error];
		isOk = isOk && NO;		
	}
	
	return isOk;
}

- (NSString *)errorsAsString {
	NSMutableString *errors = [NSMutableString string];

	for (NSError *error in self.errors) {
		[errors appendString:[error localizedDescription]];
		[errors appendString:@"\n\n"];
	}
		
	return errors;
}

-(BOOL) isNew{
	if (self.Id) {
		return NO;
	}
	else {
		return YES;
	}
}

-(BOOL) beforeSave {
	//Override in childrens...
	return YES;
}

-(BOOL) beforeDelete {
	//Override in childrens...
	return YES;
}

-(BOOL) afterSave {
	//Override in childrens...
	return YES;
}

-(BOOL) afterDelete {
	//Override in childrens...
	return YES;
}


-(void) setDefaults{
	//Override in childrens...
}

#pragma mark Introspection
-(NSDictionary *) asDict {
	NSMutableDictionary * info = [NSMutableDictionary dictionary];
	NSDictionary *props = [self properties];
	DbObject *hold;
	
	id fieldValue;
	
	for (NSString *fieldName in props) {	
		fieldValue = [self valueForKey :fieldName];
		
		if (fieldValue == nil) {
			fieldValue = [NSNull null];
		} else {
			//Is a array? then ignore
			if ([fieldValue isKindOfClass:[NSArray class]]) {
				continue;
			}
			//Is a one-to-one?
			//Then change the name and get the Id...
			if ([fieldValue isKindOfClass:[DbObject class]]) {
				fieldName = [[fieldValue class] relationName];
				hold = fieldValue;
				fieldValue = [NSNumber numberWithInt: hold.Id];
			}			
		}
		
		[info setObject:fieldValue forKey: fieldName];
	}
	
	return info;
}

+(NSString *) getTableName: (Class)cls {
	return [NSString stringWithFormat:@"%@",[NSString stringWithUTF8String :class_getName(cls)]];
}

+(NSString *) tableName {
	return [self getTableName:self];
}

-(NSString *) tableName {
	return [[self class] tableName];
}

+(NSString *) relationName {
	return [@"Id" stringByAppendingString:[self tableName]];
}

+(NSString *)propertiesAsStringList {
	NSDictionary *theProps = [self properties];
	NSArray * props = [theProps allKeys];
	
	return [NSString arrayToString:props];
}

-(NSDictionary *)properties {	
	return [[self class] properties];
}

//This code is based from http://code.google.com/p/sqlitepersistentobjects/
+(NSDictionary *)loadProperties {
	// Recurse up the classes, but stop at NSObject. Each class only reports its own properties, not those inherited from its superclass
	NSMutableDictionary *theProps=nil;
	
	if ([self superclass] != [NSObject class])
		theProps = (NSMutableDictionary *)[[self superclass] loadProperties];
	else
		theProps = [NSMutableDictionary dictionary];
	
	unsigned int outCount;
	
	objc_property_t *propList = class_copyPropertyList([self class], &outCount);
	
	int i;
	
	// Loop through properties and add declarations for the create
	for (i=0; i < outCount; i++)
	{
		objc_property_t * oneProp = propList + i;
		NSString *propName = [NSString stringWithUTF8String:property_getName(*oneProp)];
		NSString *attrs = [NSString stringWithUTF8String: property_getAttributes(*oneProp)];
		NSArray *attrParts = [attrs componentsSeparatedByString:@","];
		
		//ignore the internal properties...
		if ([propName hasPrefix:@"_"]) {
			continue;
		}
		
		if (attrParts != nil)
		{
			if ([attrParts count] > 0)
			{
				NSString *propType = [[attrParts objectAtIndex:0] substringFromIndex:1];
				//Ignore arrays.
				if ([propType hasPrefix:@"@"] ) // Object
				{
					NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
					if ([className isEqualToString:@"NSMutableArray"]) {
						continue;
					}					
				}	
				
				[theProps setObject:propType forKey:propName];
			}
		}
	}
	
	free( propList );
	
	return theProps;
}

+(NSDictionary *)properties{
	NSString *key = [self tableName];
	NSDictionary* theProps = [[DbCache currentDbCache] value:key];
	
	if (theProps==nil) {
		theProps = [self loadProperties];
		[[DbCache currentDbCache] save:key value:theProps];
	}
	return theProps;
}

@end

@implementation DbObjectTime

@synthesize timeStamp;

- (void)dealloc
{
	[timeStamp release];
	
	[super dealloc];
}

@end
