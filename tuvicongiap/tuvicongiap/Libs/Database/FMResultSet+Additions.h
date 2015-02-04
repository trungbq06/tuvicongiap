//
//  FMResultSet+Additions.h
//  JhonSell
//
//  Created by Mario Montoya on 30/05/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMResultSet.h"

@interface FMResultSet (info) 

- (NSInteger) columnCount;
- (NSArray *) columnsName;

@end
