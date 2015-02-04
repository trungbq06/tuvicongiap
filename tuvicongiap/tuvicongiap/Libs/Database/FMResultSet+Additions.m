//
//  FMResultSet+Additions.m
//  JhonSell
//
//  Created by Mario Montoya on 30/05/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "FMResultSet+Additions.h"

@implementation FMResultSet (info)

- (NSInteger) columnCount {
    if (!columnNamesSetup) {
        [self columnIndexForName:@"id"];
    }	
	return [columnNameToIndexMap count];
}

- (NSArray *) columnsName {
	if (!columnNamesSetup) {
        [self columnIndexForName:@"id"];
    }
	return [columnNameToIndexMap allKeys];
}

@end
