//
//  DbCache.h
//  JhonSell
//
//  Created by Mario Montoya on 30/03/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DbCache : NSObject {
	NSMutableDictionary *propertyCache;
}

@property (retain,nonatomic) NSMutableDictionary *propertyCache;

+(id)currentDbCache;

-(id) value:(NSString *)key;
-(void) save:(NSString *)key value:(id)dict;

- (void) clear;

@end
