//
//  DbPool.h
//  BestSeller
//
//  Created by Mario Montoya  on 9/04/10.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "Db.h"

@interface DbPool : NSObject {
	NSMutableDictionary *pool;
	NSMutableDictionary *paths;	
}

@property (retain) NSMutableDictionary *pool;
@property (retain) NSMutableDictionary *paths;

+ (DbPool *)sharedInstance;

- (Db *) getConn;
- (Db *) getConn:(NSString *)name;

- (BOOL) existConn:(NSString *)name;
- (Db *) addConn:(NSString *)name path:(NSString *)path;
- (Db *) cloneConn:(NSString *)oldName newName:(NSString *)newName;

- (void) clear;

@end
