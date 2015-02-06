//
//  Tuvi.h
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/6/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import "DbObject.h"

@interface Tuvi : DbObjectTime

@property (nonatomic, strong) NSString *solar;
@property (nonatomic, strong) NSString *lunar;
@property (nonatomic, strong) NSString *sex;
@property (nonatomic, strong) NSString *tuvi2015;
@property (nonatomic, strong) NSString *tuviTrondoi;
@property (nonatomic, strong) NSString *ageType;
@property (nonatomic)         BOOL     isOK;

@end
