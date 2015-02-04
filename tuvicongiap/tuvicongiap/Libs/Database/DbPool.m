//
//  DbPool.h
//  BestSeller
//
//  Created by Mario Montoya  on 9/04/10.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "DbPool.h"

static DbPool *sharedInstance = nil;

@implementation DbPool

@synthesize pool,paths;

- (id)init {
    if ((self = [super init])) {
        self.pool = [[NSMutableDictionary alloc] init];
		self.paths = [[NSMutableDictionary alloc] init];
    }
	
	return self;
}

- (void)dealloc
{ 
	ALog(@"Releasing pool");
	for (Db *db in self.pool) {
		[db closeDb];
	}
    
    [pool release];
    [paths release];

    [super dealloc];
} 

#pragma mark Global access
+ (DbPool *)sharedInstance {
    @synchronized(self)
    {
        if (sharedInstance == nil)
			sharedInstance = [[DbPool alloc] init];
    }
    return sharedInstance;	
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

#pragma mark Pooling methods
- (Db *) getConn {
	return [self getConn:@"default"];
}

- (BOOL) existConn:(NSString *)name {
	Db *db = [self.pool objectForKey:name];

	if (!db) {
		return NO;
	} else {
		return YES;
	}
}

- (Db *) getConn:(NSString *)name {
	if ([self existConn:name] == NO) {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:NSLocalizedString(@"The database is not set in the poll of connections",@"Error Db: database is not set")
						  userInfo:nil];
		@throw e;
	}

	return [self.pool objectForKey:name];
}

- (Db *) addConn:(NSString *)name path:(NSString *)path {
	Db *db = [self.pool objectForKey:name];

	if (!db) {
		db = [[[Db alloc] initWithName :path] autorelease];
		
		ALog(@"Adding %@ to pool",name);
		@synchronized(self) {
			[self.pool setObject:db forKey:name];
			[self.paths setObject:path forKey:name];
		}
	} else {
		ALog(@"%@ already exist on pool",name);
	}

	return db;
}

- (Db *) cloneConn:(NSString *)oldName newName:(NSString *)newName {
	NSString*path = [self.paths objectForKey:oldName];

	if (!path) {
		NSException *e = [NSException						  
						  exceptionWithName:@"DBError"						  
						  reason:NSLocalizedString(@"The database is not set globally",@"Error Db: database is not set")
						  userInfo:nil];
		@throw e;
	}
	
	return [self addConn:newName path:path];
}

- (void) clear {
	@synchronized(self) {
		[self.pool removeAllObjects];
		[self.paths removeAllObjects];
	}	
}

@end
