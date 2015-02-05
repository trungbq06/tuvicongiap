//
//  Calendar.h
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/4/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Calendar : NSObject

+ (NSArray*) convertSolar2Lunar:(int) dd mm:(int) mm yy:(int) yy timeZone:(float) timeZone;
+ (NSArray*) convertLunar2Solar:(int) lunarDay lunarMonth:(int) lunarMonth lunarYear:(int) lunarYear lunarLeap:(int) lunarLeap timeZone:(float) timeZone;

@end
