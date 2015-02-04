//
//  FuncionesGlobales.m
//  JhonSell
//
//  Created by Mario Montoya on 6/01/09.
//  Copyright 2009 El malabarista. All rights reserved.
//

#import "FuncionesGlobales.h"


@implementation FuncionesGlobales

+ (NSString *) docPath {
	NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

	return docsPath;		
}
@end
