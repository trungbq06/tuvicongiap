//
//  DbBackground.h
//  BestSeller
//
//  Created by Mario Montoya  on 9/04/10.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "DbPool.h"

@interface DbBackground : NSOperation {
	id delegate;
	NSString *sql;
	Db *db;
}

@property (nonatomic, retain) NSString *sql;
@property (nonatomic, retain) Db *db;
@property (nonatomic, retain) id delegate;

-(id)initWithSQL:(NSString *)theSql name:(NSString *)name;

@end
