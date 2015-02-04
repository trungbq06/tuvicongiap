/*
 *  DebugLog.h
 *  DebugLog
 *
 *  Created by Karl Kraft on 3/22/09.
 *  Copyright 2009 Karl Kraft. All rights reserved.
 *
 */

#import "LoggerClient.h"

#define ALog(args...) _ALog(__FILE__,__LINE__,args);

#define LOG_NETWORK(level, ...)    LogMessageF(__FILE__,__LINE__,__FUNCTION__,@"network",level,__VA_ARGS__)
#define LOG_GENERAL(level, ...)    LogMessageF(__FILE__,__LINE__,__FUNCTION__,@"general",level,__VA_ARGS__)
#define LOG_GRAPHICS(level, ...)   LogMessageF(__FILE__,__LINE__,__FUNCTION__,@"graphics",level,__VA_ARGS__)

void _ALog(const char *file, int lineNumber, NSString *format,...);
