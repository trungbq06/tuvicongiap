//
//  DbCache.m
//  JhonSell
//
//  Created by Mario Montoya on 30/03/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "DbCache.h"

@implementation DbCache

@synthesize propertyCache;

static DbCache *sharedInstance = nil;

- (id)init {
    if ((self = [super init])) {
        self.propertyCache = [NSMutableDictionary dictionary];
    }
	
	return self;
}

- (void)dealloc
{ 
	[propertyCache dealloc];
	
    [super dealloc];
} 

#pragma mark Utilities
- (void) clear {
	[self.propertyCache removeAllObjects];
}

-(id) value:(NSString *)key {
	return [self.propertyCache objectForKey:key];	
}

-(void) save:(NSString *)key value:(id)dict {
	[self.propertyCache setObject:dict forKey:key];
}

#pragma mark Global access
+(id)currentDbCache {
    @synchronized(self)
    {
        if (sharedInstance == nil)
			sharedInstance = [[DbCache alloc] init];
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

@end
