//
//  Calendar.m
//  tuvicongiap
//
//  Created by Trung. Bui Quang on 2/4/15.
//  Copyright (c) 2015 Trung. Bui Quang. All rights reserved.
//

#import "Calendar.h"

@implementation Calendar

+ (int) toInt:(float) d {
    return floor(d);
}

+ (int) jdFromDate:(int) dd mm:(int) mm yy:(int) yy {
    int a = [self toInt:((14 - mm) / 12)];
    int y = yy + 4800 - a;
    int m = mm + 12 * a - 3;
    int jd = dd + [self toInt:((153 * m + 2) / 5)] + 365 * y + [self toInt:(y / 4)] - [self toInt:(y / 100)] + [self toInt:(y / 400)] - 32045;
    if (jd < 2299161) {
        jd = dd + [self toInt:((153* m + 2)/5)] + 365 * y + [self toInt:(y / 4)] - 32083;
    }
    return jd;
}

+ (NSArray*) jdToDate:(int) jd {
    int a = 0;
    int b = 0;
    int c = 0;
    if (jd > 2299160) { // After 5/10/1582, Gregorian calendar
        a = jd + 32044;
        b = [self toInt:(4*a+3)/146097];
        c = a - [self toInt:(b*146097)/4];
    } else {
        b = 0;
        c = jd + 32082;
    }
    int d = [self toInt:(4*c+3)/1461];
    int e = c - [self toInt:(1461*d)/4];
    int m = [self toInt:(5*e+2)/153];
    int day = e - [self toInt:((153*m+2)/5)] + 1;
    int month = m + 3 - 12*[self toInt:m/10];
    int year = b*100 + d - 4800 + [self toInt:m/10];
    
    NSArray* ret = [NSArray arrayWithObjects:[NSNumber numberWithInt:day], [NSNumber numberWithInt:month], [NSNumber numberWithInt:year], nil];
    
    return ret;
}

+ (int) getNewMoonDay:(int) k timeZone:(float) timeZone {
    float T = k/1236.85; // Time in Julian centuries from 1900 January 0.5
    float T2 = T * T;
    float T3 = T2 * T;
    float dr = M_PI/180;
    float Jd1 = 2415020.75933 + 29.53058868*k + 0.0001178*T2 - 0.000000155*T3;
    Jd1 = Jd1 + 0.00033*sin((166.56 + 132.87*T - 0.009173*T2)*dr); // Mean new moon
    float M = 359.2242 + 29.10535608*k - 0.0000333*T2 - 0.00000347*T3; // Sun's mean anomaly
    float Mpr = 306.0253 + 385.81691806*k + 0.0107306*T2 + 0.00001236*T3; // Moon's mean anomaly
    float F = 21.2964 + 390.67050646*k - 0.0016528*T2 - 0.00000239*T3; // Moon's argument of latitude
    float C1=(0.1734 - 0.000393*T)*sin(M*dr) + 0.0021*sin(2*dr*M);
    C1 = C1 - 0.4068*sin(Mpr*dr) + 0.0161*sin(dr*2*Mpr);
    C1 = C1 - 0.0004*sin(dr*3*Mpr);
    C1 = C1 + 0.0104*sin(dr*2*F) - 0.0051*sin(dr*(M+Mpr));
    C1 = C1 - 0.0074*sin(dr*(M-Mpr)) + 0.0004*sin(dr*(2*F+M));
    C1 = C1 - 0.0004*sin(dr*(2*F-M)) - 0.0006*sin(dr*(2*F+Mpr));
    C1 = C1 + 0.0010*sin(dr*(2*F-Mpr)) + 0.0005*sin(dr*(2*Mpr+M));
    float deltat;
    if (T < -11) {
        deltat= 0.001 + 0.000839*T + 0.0002261*T2 - 0.00000845*T3 - 0.000000081*T*T3;
    } else {
        deltat= -0.000278 + 0.000265*T + 0.000262*T2;
    };
    float JdNew = Jd1 + C1 - deltat;
    
    return [self toInt:(JdNew + 0.5 + timeZone/24)];
}

+ (int) getSunLongitude:(float) jdn timeZone:(float) timeZone {
    float T = (jdn - 2451545.5 - timeZone/24) / 36525; // Time in Julian centuries from 2000-01-01 12:00:00 GMT
    float T2 = T * T;
    float dr = M_PI/180; // degree to radian
    float M = 357.52910 + 35999.05030*T - 0.0001559*T2 - 0.00000048*T*T2; // mean anomaly, degree
    float L0 = 280.46645 + 36000.76983*T + 0.0003032*T2; // mean longitude, degree
    float DL = (1.914600 - 0.004817*T - 0.000014*T2)*sin(dr*M);
    DL = DL + (0.019993 - 0.000101*T)*sin(dr*2*M) + 0.000290*sin(dr*3*M);
    float L = L0 + DL; // true longitude, degree
    //echo "\ndr = dr, M = M, T = T, DL = DL, L = L, L0 = L0\n";
    // obtain apparent longitude by correcting for nutation and aberration
    float omega = 125.04 - 1934.136 * T;
    L = L - 0.00569 - 0.00478 * sin(omega * dr);
    L = L*dr;
    L = L - M_PI*2*[self toInt:(L/(M_PI*2))]; // Normalize to (0, 2*PI)
    return [self toInt:L/M_PI*6];
}

+ (int) getLunarMonth11:(int) yy timeZone:(float) timeZone {
    int off = [self jdFromDate:31 mm:12 yy:yy] - 2415021;
    float k = [self toInt:(off / 29.530588853)];
    int nm = [self getNewMoonDay:k timeZone:timeZone];
    int sunLong = [self getSunLongitude:nm timeZone:timeZone]; // sun longitude at local midnight
    if (sunLong >= 9) {
        nm = [self getNewMoonDay:k-1 timeZone:timeZone];
    }
    return nm;
}

+ (int) getLeapMonthOffset:(int) a11 timeZone:(float) timeZone {
    float k = [self toInt:((a11 - 2415021.076998695) / 29.530588853 + 0.5)];
    int last = 0;
    int i = 1; // We start with the month following lunar month 11
    int arc = [self getSunLongitude:[self getNewMoonDay:k + i timeZone:timeZone] timeZone:timeZone];
    do {
        last = arc;
        i = i + 1;
        arc = [self getSunLongitude:[self getNewMoonDay:k + i timeZone:timeZone] timeZone:timeZone];
    } while (arc != last && i < 14);
    return i - 1;
}

/* Comvert solar date dd/mm/yyyy to the corresponding lunar date */
+ (NSArray*) convertSolar2Lunar:(int) dd mm:(int) mm yy:(int) yy timeZone:(float) timeZone {
    int dayNumber = [self jdFromDate:dd mm:mm yy:yy];
    int k = [self toInt:((dayNumber - 2415021.076998695) / 29.530588853)];
    int monthStart = [self getNewMoonDay:k+1 timeZone:timeZone];
    if (monthStart > dayNumber) {
        monthStart = [self getNewMoonDay:k timeZone:timeZone];
    }
    int a11 = [self getLunarMonth11:yy timeZone:timeZone];
    int b11 = a11;
    
    int lunarYear = 0;
    int lunarMonth = 0;
    int lunarDay = 0;
    
    if (a11 >= monthStart) {
        lunarYear = yy;
        a11 = [self getLunarMonth11:yy-1 timeZone:timeZone];
    } else {
        lunarYear = yy+1;
        b11 = [self getLunarMonth11:yy+1 timeZone:timeZone];
    }
    lunarDay = dayNumber - monthStart + 1;
    int diff = [self toInt:((monthStart - a11)/29)];
    int lunarLeap = 0;
    lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
        int leapMonthDiff = [self getLeapMonthOffset:a11 timeZone:timeZone];
        if (diff >= leapMonthDiff) {
            lunarMonth = diff + 10;
            if (diff == leapMonthDiff) {
                lunarLeap = 1;
            }
        }
    }
    if (lunarMonth > 12) {
        lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
        lunarYear -= 1;
    }
    
    return [NSArray arrayWithObjects:[NSNumber numberWithInt:lunarDay], [NSNumber numberWithInt:lunarMonth], [NSNumber numberWithInt:lunarYear], [NSNumber numberWithInt:lunarLeap], nil];
}

/* Convert a lunar date to the corresponding solar date */
+ (NSArray*) convertLunar2Solar:(int) lunarDay lunarMonth:(int) lunarMonth lunarYear:(int) lunarYear lunarLeap:(int) lunarLeap timeZone:(float) timeZone {
    int a11 = 0;
    int b11 = 0;
    if (lunarMonth < 11) {
        a11 = [self getLunarMonth11:lunarYear-1 timeZone:timeZone];
        b11 = [self getLunarMonth11:lunarYear timeZone:timeZone];
    } else {
        a11 = [self getLunarMonth11:lunarYear timeZone:timeZone];
        b11 = [self getLunarMonth11:lunarYear+1 timeZone:timeZone];
    }
    int k = [self toInt:(0.5 + (a11 - 2415021.076998695) / 29.530588853)];
    int off = lunarMonth - 11;
    if (off < 0) {
        off += 12;
    }
    if (b11 - a11 > 365) {
        int leapOff = [self getLeapMonthOffset:a11 timeZone:timeZone];
        int leapMonth = leapOff - 2;
        if (leapMonth < 0) {
            leapMonth += 12;
        }
        if (lunarLeap != 0 && lunarMonth != leapMonth) {
            return @[@0, @0, @0];
        } else if (lunarLeap != 0 || off >= leapOff) {
            off += 1;
        }
    }
    int monthStart = [self getNewMoonDay:k + off timeZone:timeZone];
    return [self jdToDate:monthStart + lunarDay - 1];
}

@end
