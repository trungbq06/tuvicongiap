//
//  DbBackground.h
//  BestSeller
//
//  Created by Mario Montoya  on 9/04/10.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "DbBackground.h"

@implementation DbBackground

@synthesize sql, db, delegate;

-(id)initWithSQL:(NSString *)theSql name:(NSString *)name 
{
    if ((self = [super init])) {
		self.sql = theSql;
		self.db = [[DbPool sharedInstance] getConn:name];
    }

	return self;
}

- (void)dealloc
{
	[sql release];
	[db release];

	[super dealloc];
}

-(void)main {
	NSArray *results = [self.db loadAsDictArray:sql];

	if( [delegate respondsToSelector:@selector(handleSqlResult:)])
	{
		[delegate performSelectorOnMainThread:@selector(handleSqlResult:) withObject:results waitUntilDone:YES];
	}	
}

@end
