/*
 * LoggerClient.m
 *
 * version 1.0b10 2011-02-18
 *
 * Main implementation of the NSLogger client side code
 * Part of NSLogger (client side)
 * https://github.com/fpillet/NSLogger
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2011 Florent Pillet All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 * 
 */
#import <sys/time.h>
#if !TARGET_OS_IPHONE
	#import <sys/types.h>
	#import <sys/sysctl.h>
	#import <dlfcn.h>
#elif ALLOW_COCOA_USE
	#import <UIKit/UIKit.h>
#endif
#import <fcntl.h>

#import "LoggerClient.h"
#import "LoggerCommon.h"

/* --------------------------------------------------------------------------------
 * IMPLEMENTATION NOTES:
 *
 * The logger runs in a separate thread. It is written
 * in straight C for maximum compatibility with all runtime environments
 * (does not use the Objective-C runtime, only uses unix and CoreFoundation
 * calls, except for get the thread name and device information, but these
 * can be disabled by setting ALLOW_COCOA_USE to 0).
 * 
 * It is suitable for use in both Cocoa and low-level code. It does not activate
 * Cocoa multi-threading (no call to [NSThread detachNewThread...]). You can start
 * logging very early (as soon as your code starts running), logs will be
 * buffered and sent to the log viewer as soon as a connection is acquired.
 * This makes the logger suitable for use in conditions where you usually
 * don't have a connection to a remote machine yet (early wakeup, network
 * down, etc).
 *
 * When you call one of the public logging functions, the logger is designed
 * to return to your application as fast as possible. It enqueues logs to
 * send for processing by its own thread, while your application keeps running.
 *
 * The logger does buffer logs while not connected to a desktop
 * logger. It uses Bonjour to find a logger on the local network, and can
 * optionally connect to a remote logger identified by an IP address / port
 * or a Host Name / port.
 *
 * The logger can optionally output its log to the console, like NSLog().
 *
 * The logger can optionally buffer its logs to a file for which you specify the
 * full path. Upon connection to the desktop viewer, the file contents are
 * transmitted to the viewer prior to sending new logs. When the whole file
 * content has been transmitted, it is emptied.
 *
 * Multiple loggers can coexist at the same time. You can perfectly use a
 * logger for your debug traces, and another that connects remotely to help
 * diagnostic issues while the application runs on your user's device.
 *
 * Using the logger's flexible packet format, you can customize logging by
 * creating your own log types, and customize the desktop viewer to display
 * runtime information panels for your application.
 * --------------------------------------------------------------------------------
 */

/* Logger internal debug flags */
// Set to 0 to disable internal debug completely
// Set to 1 to activate console logs when running the logger itself
// Set to 2 to see every logging call issued by the app, too
#define LOGGER_DEBUG 0
#ifdef NSLog
	#undef NSLog
#endif

// Internal debugging stuff for the logger itself
#if LOGGER_DEBUG
	#define LOGGERDBG LoggerDbg
	#if LOGGER_DEBUG > 1
		#define LOGGERDBG2 LoggerDbg
	#else
		#define LOGGERDBG2(format, ...) do{}while(0)
	#endif
	// Internal logging function prototype
	static void LoggerDbg(CFStringRef format, ...);
#else
	#define LOGGERDBG(format, ...) do{}while(0)
	#define LOGGERDBG2(format, ...) do{}while(0)
#endif

/* Local prototypes */
static void* LoggerWorkerThread(Logger *logger);
static void LoggerWriteMoreData(Logger *logger);
static void LoggerPushMessageToQueue(Logger *logger, CFDataRef message);

// Bonjour management
static void LoggerStartBonjourBrowsing(Logger *logger);
static void LoggerStopBonjourBrowsing(Logger *logger);
static BOOL LoggerBrowseBonjourForServices(Logger *logger, CFStringRef domainName);
static void LoggerServiceBrowserCallBack(CFNetServiceBrowserRef browser, CFOptionFlags flags, CFTypeRef domainOrService, CFStreamError* error, void *info);

// Reachability and reconnect timer
static void LoggerStartReachabilityChecking(Logger *logger);
static void LoggerStopReachabilityChecking(Logger *logger);
static void LoggerReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);
static void LoggerTimedReconnectCallback(CFRunLoopTimerRef timer, void *info);

// Connection & stream management
static void LoggerTryConnect(Logger *logger);
static void LoggerWriteStreamCallback(CFWriteStreamRef ws, CFStreamEventType event, void* info);
#if LOGGER_DEBUG
static void LoggerReadStreamCallback(CFReadStreamRef ws, CFStreamEventType event, void* info);
#endif

// File buffering
static void LoggerCreateBufferWriteStream(Logger *logger);
static void LoggerCreateBufferReadStream(Logger *logger);
static void LoggerEmptyBufferFile(Logger *logger);
static void LoggerFileBufferingOptionsChanged(Logger *logger);
static void LoggerFlushQueueToBufferStream(Logger *logger, BOOL firstEntryIsClientInfo);

// Encoding functions
static void	LoggerPushClientInfoToFrontOfQueue(Logger *logger);
static void LoggerMessageAddTimestampAndThreadID(CFMutableDataRef encoder);
static void LogDataInternal(Logger *logger, NSString *domain, int level, NSData *data, int binaryOrImageType);

static CFMutableDataRef LoggerMessageCreate();
static void LoggerMessageUpdateDataHeader(CFMutableDataRef data);
static void LoggerMessageAddInt16(CFMutableDataRef data, int16_t anInt, int key);
static void LoggerMessageAddInt32(CFMutableDataRef data, int32_t anInt, int key);
static void LoggerMessageAddInt64(CFMutableDataRef data, int64_t anInt, int key);
static void LoggerMessageAddString(CFMutableDataRef data, CFStringRef aString, int key);
static void LoggerMessageAddData(CFMutableDataRef data, CFDataRef theData, int key, int partType);
static uint32_t LoggerMessageGetSeq(CFDataRef message);

/* Static objects */
static Logger* volatile sDefaultLogger = NULL;
static pthread_mutex_t sDefaultLoggerMutex = PTHREAD_MUTEX_INITIALIZER;

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Default logger
// -----------------------------------------------------------------------------
void LoggerSetDefautLogger(Logger *defaultLogger)
{
	pthread_mutex_lock(&sDefaultLoggerMutex);
	sDefaultLogger = defaultLogger;
	pthread_mutex_unlock(&sDefaultLoggerMutex);
}

Logger *LoggerGetDefaultLogger()
{
	if (sDefaultLogger == NULL)
	{
		pthread_mutex_lock(&sDefaultLoggerMutex);
		Logger *logger = LoggerInit();
		if (sDefaultLogger == NULL)
		{
			sDefaultLogger = logger;
			logger = NULL;
		}
		pthread_mutex_unlock(&sDefaultLoggerMutex);
		if (logger != NULL)
			LoggerStop(logger);
	}
	return sDefaultLogger;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Initialization and setup
// -----------------------------------------------------------------------------
Logger *LoggerInit()
{
	LOGGERDBG(CFSTR("LoggerInit defaultLogger=%p"), sDefaultLogger);
	
	Logger *logger = (Logger *)malloc(sizeof(Logger));
	bzero(logger, sizeof(Logger));

	logger->logQueue = CFArrayCreateMutable(NULL, 32, &kCFTypeArrayCallBacks);
	pthread_mutex_init(&logger->logQueueMutex, NULL);
	pthread_cond_init(&logger->logQueueEmpty, NULL);

	logger->bonjourServiceBrowsers = CFArrayCreateMutable(NULL, 4, &kCFTypeArrayCallBacks);
	logger->bonjourServices = CFArrayCreateMutable(NULL, 4, &kCFTypeArrayCallBacks);

	// for now we don't grow the send buffer, just use one page of memory which should be enouh
	// (bigger messages will be sent separately)
	logger->sendBuffer = (uint8_t *)malloc(4096);
	logger->sendBufferSize = 4096;
	
	logger->options = LOGGER_DEFAULT_OPTIONS;

	logger->quit = NO;
	
	// Set this logger as the default logger is none exist already
	if (!pthread_mutex_trylock(&sDefaultLoggerMutex))
	{
		if (sDefaultLogger == NULL)
			sDefaultLogger = logger;
		pthread_mutex_unlock(&sDefaultLoggerMutex);
	}
	
	return logger;
}

void LoggerSetOptions(Logger *logger, uint32_t options)
{
	LOGGERDBG(CFSTR("LoggerSetOptions options=0x%08lx"), options);
	
	if (logger == NULL)
		logger = LoggerGetDefaultLogger();
	if (logger != NULL)
		logger->options = options;
}

void LoggerSetupBonjour(Logger *logger, CFStringRef bonjourServiceType, CFStringRef bonjourServiceName)
{
	LOGGERDBG(CFSTR("LoggerSetupBonjour serviceType=%@ serviceName=%@"), bonjourServiceType, bonjourServiceName);

	if (logger == NULL)
		logger = LoggerGetDefaultLogger();
	if (logger != NULL)
	{
		if (bonjourServiceType != NULL)
			CFRetain(bonjourServiceType);
		if (bonjourServiceName != NULL)
			CFRetain(bonjourServiceName);
		if (logger->bonjourServiceType != NULL)
			CFRelease(logger->bonjourServiceType);
		if (logger->bonjourServiceName != NULL)
			CFRelease(logger->bonjourServiceName);
		logger->bonjourServiceType = bonjourServiceType;
		logger->bonjourServiceName = bonjourServiceName;
	}
}

void LoggerSetViewerHost(Logger *logger, CFStringRef hostName, UInt32 port)
{
	if (logger == NULL)
		logger = LoggerGetDefaultLogger();
	if (logger == NULL)
		return;
	
	if (logger->host != NULL)
	{
		CFRelease(logger->host);
		logger->host = NULL;
	}
	if (hostName != NULL)
	{
		logger->host = CFStringCreateCopy(NULL, hostName);
		logger->port = port;
	}
}

void LoggerSetBufferFile(Logger *logger, CFStringRef absolutePath)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		if (logger == NULL)
			return;
	}

	BOOL change = ((logger->bufferFile != NULL && absolutePath == NULL) ||
				   (logger->bufferFile == NULL && absolutePath != NULL) ||
				   (logger->bufferFile != NULL && absolutePath != NULL && CFStringCompare(logger->bufferFile, absolutePath, 0) != kCFCompareEqualTo));
	if (change)
	{
		if (logger->bufferFile != NULL)
		{
			CFRelease(logger->bufferFile);
			logger->bufferFile = NULL;
		}
		if (absolutePath != NULL)
			logger->bufferFile = CFStringCreateCopy(NULL, absolutePath);
		if (logger->bufferFileChangedSource != NULL)
			CFRunLoopSourceSignal(logger->bufferFileChangedSource);
	}
}

void LoggerStart(Logger *logger)
{
	// will do nothing if logger is already started
	if (logger == NULL)
		logger = LoggerGetDefaultLogger();

	if (logger->workerThread == NULL)
	{
		// Start the work thread which performs the Bonjour search,
		// connects to the logging service and forwards the logs
		LOGGERDBG(CFSTR("LoggerStart logger=%p"), logger);
		pthread_create(&logger->workerThread, NULL, (void *(*)(void *))&LoggerWorkerThread, logger);
	}
}

void LoggerStop(Logger *logger)
{
	LOGGERDBG(CFSTR("LoggerStop"));

	pthread_mutex_lock(&sDefaultLoggerMutex);
	if (logger == NULL || logger == sDefaultLogger)
	{
		logger = sDefaultLogger;
		sDefaultLogger = NULL;
	}
	pthread_mutex_unlock(&sDefaultLoggerMutex);

	if (logger != NULL)
	{
		if (logger->workerThread != NULL)
		{
			logger->quit = YES;
			pthread_join(logger->workerThread, NULL);
		}

		CFRelease(logger->bonjourServiceBrowsers);
		CFRelease(logger->bonjourServices);
		free(logger->sendBuffer);
		if (logger->host != NULL)
			CFRelease(logger->host);
		if (logger->bufferFile != NULL)
			CFRelease(logger->bufferFile);
		if (logger->bonjourServiceType != NULL)
			CFRelease(logger->bonjourServiceType);
		if (logger->bonjourServiceName != NULL)
			CFRelease(logger->bonjourServiceName);

		// to make sure potential errors are catched, set the whole structure
		// to a value that will make code crash if it tries using pointers to it.
		memset(logger, 0x55, sizeof(logger));

		free(logger);
	}
}

void LoggerFlush(Logger *logger, BOOL waitForConnection)
{
	// Special case: if nothing has ever been logged, don't bother
	if (logger == NULL && sDefaultLogger == NULL)
		return;
	if (logger == NULL)
		logger = LoggerGetDefaultLogger();
	if (logger != NULL &&
		pthread_self() != logger->workerThread &&
		(logger->connected || logger->bufferFile != NULL || waitForConnection))
	{
		pthread_mutex_lock(&logger->logQueueMutex);
		if (CFArrayGetCount(logger->logQueue) > 0)
			pthread_cond_wait(&logger->logQueueEmpty, &logger->logQueueMutex);
		pthread_mutex_unlock(&logger->logQueueMutex);
	}
}

static void LoggerDbg(CFStringRef format, ...)
{
	// Internal debugging function
	// (what do you think, that we use the Logger to debug itself ??)
	if (format != NULL)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		va_list	args;	
		va_start(args, format);
		CFStringRef s = CFStringCreateWithFormatAndArguments(NULL, NULL, (CFStringRef)format, args);
		va_end(args);
		if (s != NULL)
		{
			CFShow(s);
			CFRelease(s);
		}
		[pool drain];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Main processing
// -----------------------------------------------------------------------------
static void *LoggerWorkerThread(Logger *logger)
{
	LOGGERDBG(CFSTR("Start LoggerWorkerThread"));

#if !TARGET_OS_IPHONE
	// Register thread with Garbage Collector on Mac OS X if we're running an OS version that has GC
    void (*registerThreadWithCollector_fn)(void);
    registerThreadWithCollector_fn = (void(*)(void)) dlsym(RTLD_NEXT, "objc_registerThreadWithCollector");
    if (registerThreadWithCollector_fn)
        (*registerThreadWithCollector_fn)();
#endif

	// Create and get the runLoop for this thread
	CFRunLoopRef runLoop = CFRunLoopGetCurrent();

	// Create the run loop source that signals when messages have been added to the runloop
	// this will directly trigger a WriteMoreData() call, which will or won't write depending
	// on whether we're connected and there's space available in the stream
	CFRunLoopSourceContext context;
	bzero(&context, sizeof(context));
	context.info = logger;
	context.perform = (void *)&LoggerWriteMoreData;
	logger->messagePushedSource = CFRunLoopSourceCreate(NULL, 0, &context);
	if (logger->messagePushedSource == NULL)
	{
		// Failing to create the runloop source for pushing messages is a major failure.
		// This NSLog is intentional. We WANT console output in this case
		NSLog(@"*** NSLogger: Worker thread failed creating runLoop source, switching to console logging.");
		logger->options |= kLoggerOption_LogToConsole;
		logger->workerThread = NULL;
		return NULL;
	}
	CFRunLoopAddSource(runLoop, logger->messagePushedSource, kCFRunLoopDefaultMode);

	// Create the buffering stream if needed
	if (logger->bufferFile != NULL)
		LoggerCreateBufferWriteStream(logger);
	
	// Create the runloop source that lets us know when file buffering options change
	context.perform = (void *)&LoggerFileBufferingOptionsChanged;
	logger->bufferFileChangedSource = CFRunLoopSourceCreate(NULL, 0, &context);
	if (logger->bufferFileChangedSource == NULL)
	{
		// This failure MUST be logged to console
		NSLog(@"*** NSLogger Warning: failed creating a runLoop source for file buffering options change.");
	}
	else
		CFRunLoopAddSource(runLoop, logger->bufferFileChangedSource, kCFRunLoopDefaultMode);

	// Start Bonjour browsing, wait for remote logging service to be found
	if (logger->host == NULL && (logger->options & kLoggerOption_BrowseBonjour))
	{
		LOGGERDBG(CFSTR("-> logger configured for Bonjour, no direct host set -- trying Bonjour first"));
		LoggerStartBonjourBrowsing(logger);
	}
	else if (logger->host != NULL)
	{
		LOGGERDBG(CFSTR("-> logger configured with direct host, trying it first"));
		LoggerTryConnect(logger);
	}

	// Run logging thread until LoggerStop() is called
	while (!logger->quit)
	{
		int result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.10, true);
		if (result == kCFRunLoopRunFinished || result == kCFRunLoopRunStopped)
			break;
		
		// Make sure we restart connection attempts if we get disconnected
		if (!logger->connected &&
			!CFArrayGetCount(logger->bonjourServices) &&
			!CFArrayGetCount(logger->bonjourServiceBrowsers) &&
			!CFArrayGetCount(logger->bonjourServices))
		{
			if (logger->options & kLoggerOption_BrowseBonjour)
				LoggerStartBonjourBrowsing(logger);
			else if (logger->host != NULL && logger->reachability == NULL && logger->checkHostTimer == NULL)
				LoggerTryConnect(logger);
		}
	}

	// Cleanup
	if (logger->options & kLoggerOption_BrowseBonjour)
		LoggerStopBonjourBrowsing(logger);
	LoggerStopReachabilityChecking(logger);

	if (logger->logStream != NULL)
	{
		CFWriteStreamSetClient(logger->logStream, 0, NULL, NULL);
		CFWriteStreamClose(logger->logStream);
		CFRelease(logger->logStream);
		logger->logStream = NULL;
	}

	if (logger->bufferWriteStream == NULL && logger->bufferFile != NULL)
	{
		// If there are messages in the queue and LoggerStop() was called and
		// a buffer file was set just before LoggerStop() was called, flush
		// the log queue to the buffer file
		pthread_mutex_lock(&logger->logQueueMutex);
		CFIndex outstandingMessages = CFArrayGetCount(logger->logQueue);
		pthread_mutex_unlock(&logger->logQueueMutex);
		if (outstandingMessages)
			LoggerCreateBufferWriteStream(logger);
	}

	if (logger->bufferWriteStream != NULL)
	{
		CFWriteStreamClose(logger->bufferWriteStream);
		CFRelease(logger->bufferWriteStream);
		logger->bufferWriteStream = NULL;
	}

	if (logger->messagePushedSource != NULL)
	{
		CFRunLoopSourceInvalidate(logger->messagePushedSource);
		CFRelease(logger->messagePushedSource);
		logger->messagePushedSource = NULL;
	}
	
	if (logger->bufferFileChangedSource != NULL)
	{
		CFRunLoopSourceInvalidate(logger->bufferFileChangedSource);
		CFRelease(logger->bufferFileChangedSource);
		logger->bufferFileChangedSource = NULL;
	}

	// if the client ever tries to log again against us, make sure that logs at least
	// go to console
	logger->options |= kLoggerOption_LogToConsole;
	logger->workerThread = NULL;
	return NULL;
}

static CFStringRef LoggerCreateStringRepresentationFromBinaryData(CFDataRef data)
{
	CFMutableStringRef s = CFStringCreateMutable(NULL, 0);
	unsigned int offset = 0;
	unsigned int dataLen = (unsigned int)CFDataGetLength(data);
	char buffer[1+6+16*3+1+16+1+1+1];
	buffer[0] = '\0';
	const unsigned char *q = (unsigned char *)CFDataGetBytePtr(data);
	if (dataLen == 1)
		CFStringAppend(s, CFSTR("Raw data, 1 byte:\n"));
	else
		CFStringAppendFormat(s, NULL, CFSTR("Raw data, %u bytes:\n"), dataLen);
	while (dataLen)
	{
		int i, j, b = sprintf(buffer," %04x: ", offset);
		for (i=0; i < 16 && i < (int)dataLen; i++)
			sprintf(&buffer[b+3*i], "%02x ", (int)q[i]);
		for (j=i; j < 16; j++)
			strcat(buffer, "   ");
		
		b = strlen(buffer);
		buffer[b++] = '\'';
		for (i=0; i < 16 && i < (int)dataLen; i++, q++)
		{
			if (*q >= 32 && *q < 128)
				buffer[b++] = *q;
			else
				buffer[b++] = ' ';
		}
		for (j=i; j < 16; j++)
			buffer[b++] = ' ';
		buffer[b++] = '\'';
		buffer[b++] = '\n';
		buffer[b] = 0;
		
		CFStringRef bufferStr = CFStringCreateWithBytesNoCopy(NULL, (const UInt8 *)buffer, strlen(buffer), kCFStringEncodingISOLatin1, false, kCFAllocatorNull);
		CFStringAppend(s, bufferStr);
		CFRelease(bufferStr);
		
		dataLen -= i;
		offset += i;
	}
	return s;
}

static void LoggerLogToConsole(CFDataRef data)
{
	// Decode and log a message to the console. Doing this from the worker thread
	// allow us to serialize logging, which is a benefit that NSLog() doesn't have.
	// Only drawback is that we have to decode our own message, but that is a minor hassle.

	struct timeval timestamp;
	bzero(&timestamp, sizeof(timestamp));
	int type = LOGMSG_TYPE_LOG, contentsType = PART_TYPE_STRING;
	int imgWidth=0, imgHeight=0;
	CFStringRef message = NULL;
	CFStringRef thread = NULL;

	// decode message contents
	uint8_t *p = (uint8_t *)CFDataGetBytePtr(data) + 4;
	uint16_t partCount;
	memcpy(&partCount, p, 2);
	partCount = ntohs(partCount);
	p += 2;
	while (partCount--)
	{
		uint8_t partKey = *p++;
		uint8_t partType = *p++;
		uint32_t partSize;
		if (partType == PART_TYPE_INT16)
			partSize = 2;
		else if (partType == PART_TYPE_INT32)
			partSize = 4;
		else if (partType == PART_TYPE_INT64)
			partSize = 8;
		else
		{
			memcpy(&partSize, p, 4);
			p += 4;
			partSize = ntohl(partSize);
		}
		CFTypeRef part = NULL;
		uint32_t value32 = 0;
		uint64_t value64 = 0;
		if (partSize > 0)
		{
			if (partType == PART_TYPE_STRING)
			{
				// trim whitespace and newline at both ends of the string
				uint8_t *q = p;
				uint32_t l = partSize;
				while (l && (*q == ' ' || *q == '\t' || *q == '\n' || *q == '\r'))
					q++, l--;
				uint8_t *r = q + l - 1;
				while (l && (*r == ' ' || *r == '\t' || *r == '\n' || *r == '\r'))
					r--, l--;
				part = CFStringCreateWithBytesNoCopy(NULL, q, l, kCFStringEncodingUTF8, false, kCFAllocatorNull);
			}
			else if (partType == PART_TYPE_BINARY)
			{
				part = CFDataCreateWithBytesNoCopy(NULL, p, partSize, kCFAllocatorNull);
			}
			else if (partType == PART_TYPE_IMAGE)
			{
				// ignore image data, we can't log it to console
			}
			else if (partType == PART_TYPE_INT32)
			{
				memcpy(&value32, p, 4);
				value32 = ntohl(value32);
			}
			else if (partType == PART_TYPE_INT64)
			{
				memcpy(&value64, p, 8);
				value64 = CFSwapInt64BigToHost(value64);
			}
			p += partSize;
		}
		switch (partKey)
		{
			case PART_KEY_MESSAGE_TYPE:
				type = (int)value32;
				break;
			case PART_KEY_TIMESTAMP_S:			// timestamp with seconds-level resolution
				timestamp.tv_sec = (partType == PART_TYPE_INT64) ? (__darwin_time_t)value64 : (__darwin_time_t)value32;
				break;
			case PART_KEY_TIMESTAMP_MS:			// millisecond part of the timestamp (optional)
				timestamp.tv_usec = ((partType == PART_TYPE_INT64) ? (__darwin_suseconds_t)value64 : (__darwin_suseconds_t)value32) * 1000;
				break;
			case PART_KEY_TIMESTAMP_US:			// microsecond part of the timestamp (optional)
				timestamp.tv_usec = (partType == PART_TYPE_INT64) ? (__darwin_suseconds_t)value64 : (__darwin_suseconds_t)value32;
				break;
			case PART_KEY_THREAD_ID:
				if (thread == NULL)				// useless test, we know what we're doing but clang analyzer doesn't...
				{
					if (partType == PART_TYPE_INT32)
						thread = CFStringCreateWithFormat(NULL, NULL, CFSTR("thread 0x%08x"), value32);
					else if (partType == PART_TYPE_INT64)
						thread = CFStringCreateWithFormat(NULL, NULL, CFSTR("thread 0x%qx"), value64);
					else if (partType == PART_TYPE_STRING && part != NULL)
						thread = CFRetain(part);
				}
				break;
			case PART_KEY_MESSAGE:
				if (part != NULL)
				{
					if (partType == PART_TYPE_STRING)
						message = CFRetain(part);
					else if (partType == PART_TYPE_BINARY)
						message = LoggerCreateStringRepresentationFromBinaryData(part);
				}
				contentsType = partType;
				break;
			case PART_KEY_IMAGE_WIDTH:
				imgWidth = (partType == PART_TYPE_INT32 ? (int)value32 : (int)value64);
				break;
			case PART_KEY_IMAGE_HEIGHT:
				imgHeight = (partType == PART_TYPE_INT32 ? (int)value32 : (int)value64);
				break;
			default:
				break;
		}
		if (part != NULL)
			CFRelease(part);
	}

	// Prepare the final representation and log to console
	CFMutableStringRef s = CFStringCreateMutable(NULL, 0);

	char buf[32];
	struct tm t;
	gmtime_r(&timestamp.tv_sec, &t);
	strftime(buf, sizeof(buf)-1, "%T", &t);
	CFStringRef ts = CFStringCreateWithBytesNoCopy(NULL, (const UInt8 *)buf, strlen(buf), kCFStringEncodingASCII, false, kCFAllocatorNull);
	CFStringAppend(s, ts);
	CFRelease(ts);

	if (contentsType == PART_TYPE_IMAGE)
		message = CFStringCreateWithFormat(NULL, NULL, CFSTR("<image width=%d height=%d>"), imgWidth, imgHeight);

	char threadNamePadding[16];
	threadNamePadding[0] = 0;
	if (CFStringGetLength(thread) < 16)
	{
		int n = 16 - CFStringGetLength(thread);
		memset(threadNamePadding, ' ', n);
		threadNamePadding[n] = 0;
	}
	CFStringAppendFormat(s, NULL, CFSTR(".%04d %s%@ | %@"),
						 (int)(timestamp.tv_usec / 1000),
						 threadNamePadding, thread,
						 message ? message : CFSTR(""));

	if (thread != NULL)
		CFRelease(thread);
	if (message)
		CFRelease(message);

	if (type == LOGMSG_TYPE_LOG)
		CFShow(s);

	CFRelease(s);
}

static void LoggerWriteMoreData(Logger *logger)
{
	if (!logger->connected)
	{
		if (logger->options & kLoggerOption_LogToConsole)
		{
			pthread_mutex_lock(&logger->logQueueMutex);
			while (CFArrayGetCount(logger->logQueue))
			{
				LoggerLogToConsole((CFDataRef)CFArrayGetValueAtIndex(logger->logQueue, 0));
				CFArrayRemoveValueAtIndex(logger->logQueue, 0);
			}
			pthread_mutex_unlock(&logger->logQueueMutex);
			pthread_cond_broadcast(&logger->logQueueEmpty);
		}
		else if (logger->bufferWriteStream != NULL)
		{
			LoggerFlushQueueToBufferStream(logger, NO);
		}
		return;
	}
	
	if (CFWriteStreamCanAcceptBytes(logger->logStream))
	{
		// prepare archived data with log queue contents, unblock the queue as soon as possible
		CFMutableDataRef sendFirstItem = NULL;
		if (logger->sendBufferUsed == 0)
		{
			// pull more data from the log queue
			if (logger->bufferReadStream != NULL)
			{
				if (!CFReadStreamHasBytesAvailable(logger->bufferReadStream))
				{
					CFReadStreamClose(logger->bufferReadStream);
					CFRelease(logger->bufferReadStream);
					logger->bufferReadStream = NULL;
					LoggerEmptyBufferFile(logger);
				}
				else
				{
					logger->sendBufferUsed = CFReadStreamRead(logger->bufferReadStream, logger->sendBuffer, logger->sendBufferSize);
				}
			}
			else
			{
				pthread_mutex_lock(&logger->logQueueMutex);
				while (CFArrayGetCount(logger->logQueue))
				{
					CFDataRef d = (CFDataRef)CFArrayGetValueAtIndex(logger->logQueue, 0);
					CFIndex dsize = CFDataGetLength(d);
					if ((logger->sendBufferUsed + dsize) > logger->sendBufferSize)
						break;
					memcpy(logger->sendBuffer + logger->sendBufferUsed, CFDataGetBytePtr(d), dsize);
					logger->sendBufferUsed += dsize;
					CFArrayRemoveValueAtIndex(logger->logQueue, 0);
					logger->incompleteSendOfFirstItem = NO;
				}
				pthread_mutex_unlock(&logger->logQueueMutex);
			}
			if (logger->sendBufferUsed == 0) 
			{
				// are we done yet?
				pthread_mutex_lock(&logger->logQueueMutex);
				if (CFArrayGetCount(logger->logQueue) == 0)
				{
					pthread_mutex_unlock(&logger->logQueueMutex);
					pthread_cond_broadcast(&logger->logQueueEmpty);
					return;
				}

				// first item is too big to fit in a single packet, send it separately
				sendFirstItem = (CFMutableDataRef)CFArrayGetValueAtIndex(logger->logQueue, 0);
				logger->incompleteSendOfFirstItem = YES;
				pthread_mutex_unlock(&logger->logQueueMutex);
				logger->sendBufferOffset = 0;
			}
		}

		// send data over the socket. We try hard to be failsafe and if we have to send
		// data in fragments, we make sure that in case a disconnect occurs we restart
		// sending the whole message(s)
		if (logger->sendBufferUsed != 0)
		{
			CFIndex written = CFWriteStreamWrite(logger->logStream,
												 logger->sendBuffer + logger->sendBufferOffset,
												 logger->sendBufferUsed - logger->sendBufferOffset);
			if (written < 0)
			{
				// We'll get an event if the stream closes on error. Don't discard the data,
				// it will be sent as soon as a connection is re-acquired.
				return;
			}
			if ((logger->sendBufferOffset + written) < logger->sendBufferUsed)
			{
				// everything couldn't be sent at once
				logger->sendBufferOffset += written;
			}
			else
			{
				logger->sendBufferUsed = 0;
				logger->sendBufferOffset = 0;
			}
		}
		else if (sendFirstItem)
		{
			CFIndex length = CFDataGetLength(sendFirstItem) - logger->sendBufferOffset;
			CFIndex written = CFWriteStreamWrite(logger->logStream,
												 CFDataGetBytePtr(sendFirstItem) + logger->sendBufferOffset,
												 length);
			if (written < 0)
			{
				// We'll get an event if the stream closes on error
				return;
			}
			if (written < length)
			{
				// The output pipe is full, and the first item has not been sent completely
				// We need to reduce the remaining data on the first item so it can be taken
				// care of at the next iteration. We take advantage of the fact that each item
				// in the queue is actually a mutable data block
				// @@@ NOTE: IF WE GET DISCONNECTED WHILE DOING THIS, THINGS WILL GO WRONG
				// NEED TO UPDATE THIS LOGIC
				CFDataReplaceBytes((CFMutableDataRef)sendFirstItem, CFRangeMake(0, written), NULL, 0);
				return;
			}
			
			// we are done sending the first item in the queue, remove it now
			pthread_mutex_lock(&logger->logQueueMutex);
			CFArrayRemoveValueAtIndex(logger->logQueue, 0);
			logger->incompleteSendOfFirstItem = NO;
			pthread_mutex_unlock(&logger->logQueueMutex);
			logger->sendBufferOffset = 0;
		}
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark File buffering functions
// -----------------------------------------------------------------------------
static void LoggerCreateBufferWriteStream(Logger *logger)
{
	LOGGERDBG(CFSTR("LoggerCreateBufferWriteStream to file %@"), logger->bufferFile);
	CFURLRef fileURL = CFURLCreateWithFileSystemPath(NULL, logger->bufferFile, kCFURLPOSIXPathStyle, false);
	if (fileURL != NULL)
	{
		// Create write stream to file
		logger->bufferWriteStream = CFWriteStreamCreateWithFile(NULL, fileURL);
		CFRelease(fileURL);
		if (logger->bufferWriteStream != NULL)
		{
			// Set flag to append new data to buffer file
			CFWriteStreamSetProperty(logger->bufferWriteStream, kCFStreamPropertyAppendToFile, kCFBooleanTrue);

			// Open the buffer stream for writing
			if (!CFWriteStreamOpen(logger->bufferWriteStream))
			{
				CFRelease(logger->bufferWriteStream);
				logger->bufferWriteStream = NULL;
			}
			else
			{
				// Write client info and flush the queue contents to buffer file
				LoggerPushClientInfoToFrontOfQueue(logger);
				LoggerFlushQueueToBufferStream(logger, YES);
			}
		}
	}
	if (logger->bufferWriteStream == NULL)
	{
		CFShow(CFSTR("NSLogger Warning: failed opening buffer file for writing:"));
		CFShow(logger->bufferFile);
	}
}

static void LoggerCreateBufferReadStream(Logger *logger)
{
	LOGGERDBG(CFSTR("LoggerCreateBufferReadStream from file %@"), logger->bufferFile);
	CFURLRef fileURL = CFURLCreateWithFileSystemPath(NULL, logger->bufferFile, kCFURLPOSIXPathStyle, false);
	if (fileURL != NULL)
	{
		// Create read stream from file
		logger->bufferReadStream = CFReadStreamCreateWithFile(NULL, fileURL);
		CFRelease(fileURL);
		if (logger->bufferReadStream != NULL)
		{
			if (!CFReadStreamOpen(logger->bufferReadStream))
			{
				CFRelease(logger->bufferReadStream);
				logger->bufferReadStream = NULL;
			}
		}
	}
}

static void LoggerEmptyBufferFile(Logger *logger)
{
	// completely remove the buffer file from storage
	LOGGERDBG(CFSTR("LoggerEmptyBufferFile %@"), logger->bufferFile);
	if (logger->bufferFile != NULL)
	{
		CFIndex bufferSize = 1 + CFStringGetLength(logger->bufferFile) * 3;
		char *buffer = (char *)malloc(bufferSize);
		if (buffer != NULL)
		{
			if (CFStringGetFileSystemRepresentation(logger->bufferFile, buffer, bufferSize))
			{
				// remove file
				unlink(buffer);
			}
			free(buffer);
		}
	}
}

static void LoggerFileBufferingOptionsChanged(Logger *logger)
{
	// File buffering options changed:
	// - close the current buffer file stream, if any
	// - create a new one, if needed
	LOGGERDBG(CFSTR("LoggerFileBufferingOptionsChanged bufferFile=%@"), logger->bufferFile);
	if (logger->bufferWriteStream != NULL)
	{
		CFWriteStreamClose(logger->bufferWriteStream);
		CFRelease(logger->bufferWriteStream);
		logger->bufferWriteStream = NULL;
	}
	if (logger->bufferFile  != NULL)
		LoggerCreateBufferWriteStream(logger);
}

static void LoggerFlushQueueToBufferStream(Logger *logger, BOOL firstEntryIsClientInfo)
{
	LOGGERDBG(CFSTR("LoggerFlushQueueToBufferStream"));
	pthread_mutex_lock(&logger->logQueueMutex);
	if (logger->incompleteSendOfFirstItem)
	{
		// drop anything being sent
		logger->sendBufferUsed = 0;
		logger->sendBufferOffset = 0;
	}
	logger->incompleteSendOfFirstItem = NO;

	// Write outstanding messages to the buffer file (streams don't detect disconnection
	// until the next write, where we could lose one or more messages)
	if (!firstEntryIsClientInfo && logger->sendBufferUsed)
		CFWriteStreamWrite(logger->bufferWriteStream, logger->sendBuffer + logger->sendBufferOffset, logger->sendBufferUsed - logger->sendBufferOffset);
	
	int n = 0;
	while (CFArrayGetCount(logger->logQueue))
	{
		CFDataRef data = CFArrayGetValueAtIndex(logger->logQueue, 0);
		CFIndex dataLength = CFDataGetLength(data);
		CFIndex written = CFWriteStreamWrite(logger->bufferWriteStream, CFDataGetBytePtr(data), dataLength);
		if (written != dataLength)
		{
			// couldn't write all data to file, maybe storage run out of space?
			CFShow(CFSTR("NSLogger Error: failed flushing the whole queue to buffer file:"));
			CFShow(logger->bufferFile);
			break;
		}
		CFArrayRemoveValueAtIndex(logger->logQueue, 0);
		if (n == 0 && firstEntryIsClientInfo && logger->sendBufferUsed)
		{
			// try hard: write any outstanding messages to the buffer file, after the client info
			CFWriteStreamWrite(logger->bufferWriteStream, logger->sendBuffer + logger->sendBufferOffset, logger->sendBufferUsed - logger->sendBufferOffset);
		}
		n++;
	}
	logger->sendBufferUsed = 0;
	logger->sendBufferOffset = 0;
	pthread_mutex_unlock(&logger->logQueueMutex);	
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Bonjour browsing
// -----------------------------------------------------------------------------
static void LoggerStartBonjourBrowsing(Logger *logger)
{
	LOGGERDBG(CFSTR("LoggerStartBonjourBrowsing"));
	
	if (logger->options & kLoggerOption_BrowseOnlyLocalDomain)
	{
		LOGGERDBG(CFSTR("Logger configured to search only the local domain, searching for services on: local."));
		if (!LoggerBrowseBonjourForServices(logger, CFSTR("local.")) && logger->host == NULL)
		{
			LOGGERDBG(CFSTR("*** Logger: could not browse for services in domain local., no remote host configured: reverting to console logging. ***"));
			logger->options |= kLoggerOption_LogToConsole;
		}
	}
	else
	{
		LOGGERDBG(CFSTR("Logger configured to search all domains, browsing for domains first"));
		CFNetServiceClientContext context = {0, (void *)logger, NULL, NULL, NULL};
		CFRunLoopRef runLoop = CFRunLoopGetCurrent();
		logger->bonjourDomainBrowser = CFNetServiceBrowserCreate(NULL, &LoggerServiceBrowserCallBack, &context);
		CFNetServiceBrowserScheduleWithRunLoop(logger->bonjourDomainBrowser, runLoop, kCFRunLoopCommonModes);
		if (!CFNetServiceBrowserSearchForDomains(logger->bonjourDomainBrowser, false, NULL))
		{
			// An error occurred, revert to console logging if there is no remote host
			LOGGERDBG(CFSTR("*** Logger: could not browse for domains, reverting to console logging. ***"));
			CFNetServiceBrowserUnscheduleFromRunLoop(logger->bonjourDomainBrowser, runLoop, kCFRunLoopCommonModes);
			CFRelease(logger->bonjourDomainBrowser);
			logger->bonjourDomainBrowser = NULL;
			if (logger->host == NULL)
				logger->options |= kLoggerOption_LogToConsole;
		}
	}
}

static void LoggerStopBonjourBrowsing(Logger *logger)
{
	LOGGERDBG(CFSTR("LoggerStopBonjourBrowsing"));
	
	// stop browsing for domains
	if (logger->bonjourDomainBrowser != NULL)
	{
		CFNetServiceBrowserStopSearch(logger->bonjourDomainBrowser, NULL);
		CFNetServiceBrowserUnscheduleFromRunLoop(logger->bonjourDomainBrowser, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFNetServiceBrowserInvalidate(logger->bonjourDomainBrowser);
		CFRelease(logger->bonjourDomainBrowser);
		logger->bonjourDomainBrowser = NULL;
	}
	
	// stop browsing for services
	CFIndex idx;
	for (idx = 0; idx < CFArrayGetCount(logger->bonjourServiceBrowsers); idx++)
	{
		CFNetServiceBrowserRef browser = (CFNetServiceBrowserRef)CFArrayGetValueAtIndex(logger->bonjourServiceBrowsers, idx);
		CFNetServiceBrowserStopSearch(browser, NULL);
		CFNetServiceBrowserUnscheduleFromRunLoop(browser, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFNetServiceBrowserInvalidate(browser);
	}
	CFArrayRemoveAllValues(logger->bonjourServiceBrowsers);
	
	// Forget all services
	CFArrayRemoveAllValues(logger->bonjourServices);
}

static BOOL LoggerBrowseBonjourForServices(Logger *logger, CFStringRef domainName)
{
	BOOL result = NO;
	CFNetServiceClientContext context = {0, (void *)logger, NULL, NULL, NULL};
	CFRunLoopRef runLoop = CFRunLoopGetCurrent();
	
	CFNetServiceBrowserRef browser = CFNetServiceBrowserCreate(NULL, (CFNetServiceBrowserClientCallBack)&LoggerServiceBrowserCallBack, &context);
	CFNetServiceBrowserScheduleWithRunLoop(browser, runLoop, kCFRunLoopCommonModes);
	CFStreamError error;

	// try to use the user-specfied service type if any, fallback on our
	// default service type
	CFStringRef serviceType = logger->bonjourServiceType;
	if (serviceType == NULL)
	{
		if (logger->options & kLoggerOption_UseSSL)
			serviceType = LOGGER_SERVICE_TYPE_SSL;
		else
			serviceType = LOGGER_SERVICE_TYPE;
	}
	if (!CFNetServiceBrowserSearchForServices(browser, domainName, serviceType, &error))
	{
		LOGGERDBG(CFSTR("Logger can't start search on domain: %@ (error %d)"), domainName, error.error);
		CFNetServiceBrowserUnscheduleFromRunLoop(browser, runLoop, kCFRunLoopCommonModes);
		CFNetServiceBrowserInvalidate(browser);
	}
	else
	{
		LOGGERDBG(CFSTR("Logger started search for services of type %@ in domain %@"), serviceType, domainName);
		CFArrayAppendValue(logger->bonjourServiceBrowsers, browser);
		result = YES;
	}
	CFRelease(browser);
	return result;
}

static void LoggerServiceBrowserCallBack (CFNetServiceBrowserRef browser,
										  CFOptionFlags flags,
										  CFTypeRef domainOrService,
										  CFStreamError* error,
										  void* info)
{
	LOGGERDBG(CFSTR("LoggerServiceBrowserCallback browser=%@ flags=0x%04x domainOrService=%@ error=%d"), browser, flags, domainOrService, error==NULL ? 0 : error->error);
	
	Logger *logger = (Logger *)info;
	assert(logger != NULL);
	
	if (flags & kCFNetServiceFlagRemove)
	{
		if (!(flags & kCFNetServiceFlagIsDomain))
		{
			CFNetServiceRef service = (CFNetServiceRef)domainOrService;
			CFIndex idx;
			for (idx = 0; idx < CFArrayGetCount(logger->bonjourServices); idx++)
			{
				if (CFArrayGetValueAtIndex(logger->bonjourServices, idx) == service)
				{
					CFNetServiceUnscheduleFromRunLoop(service, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					CFNetServiceClientContext context = {0, NULL, NULL, NULL, NULL};
					CFNetServiceSetClient(service, NULL, &context);
					CFNetServiceCancel(service);
					CFArrayRemoveValueAtIndex(logger->bonjourServices, idx);
					break;
				}
			}
		}
	}
	else
	{
		if (flags & kCFNetServiceFlagIsDomain)
		{
			// start searching for services in this domain
			LoggerBrowseBonjourForServices(logger, (CFStringRef)domainOrService);
		}
		else
		{
			// a service has been found
			LOGGERDBG(CFSTR("Logger found service: %@"), domainOrService);
			CFNetServiceRef service = (CFNetServiceRef)domainOrService;
			if (service != NULL)
			{
				// if the user has specified that Logger shall only connect to the specified
				// Bonjour service name, check it now. This makes things easier in a teamwork
				// environment where multiple instances of NSLogger viewer may run on the
				// same network
				if (logger->bonjourServiceName != NULL)
				{
					LOGGERDBG(CFSTR("-> looking for services of name %@"), logger->bonjourServiceName);
					CFStringRef name = CFNetServiceGetName(service);
					if (name == NULL || kCFCompareEqualTo != CFStringCompare(name, logger->bonjourServiceName, kCFCompareCaseInsensitive | kCFCompareDiacriticInsensitive))
					{
						LOGGERDBG(CFSTR("-> service name %@ does not match requested service name, ignoring."), name, logger->bonjourServiceName);
						return;
					}
				}
				CFArrayAppendValue(logger->bonjourServices, service);
				LoggerTryConnect(logger);
			}
		}
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Reachability
// -----------------------------------------------------------------------------
static void LoggerStartReachabilityChecking(Logger *logger)
{
	if (logger->host != NULL && logger->reachability == NULL)
	{
		LOGGERDBG(CFSTR("Starting SCNetworkReachability to wait for host %@ to be reachable"), logger->host);

		CFIndex length = CFStringGetLength(logger->host) * 3;
		char *buffer = (char *)malloc(length + 1);
		CFStringGetBytes(logger->host, CFRangeMake(0, CFStringGetLength(logger->host)), kCFStringEncodingUTF8, '?', false, (UInt8 *)buffer, length, &length);
		buffer[length] = 0;

		logger->reachability = SCNetworkReachabilityCreateWithName(NULL, buffer);
		
		SCNetworkReachabilityContext context = {0, logger, NULL, NULL, NULL};
		SCNetworkReachabilitySetCallback(logger->reachability, &LoggerReachabilityCallBack, &context);
		SCNetworkReachabilityScheduleWithRunLoop(logger->reachability, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

		free(buffer);

		// Also start a timer that will try to reconnect every N seconds
		if (logger->checkHostTimer == NULL)
		{
			CFRunLoopTimerContext context = {
				.version = 0,
				.info = logger,
				.retain = NULL,
				.release = NULL,
				.copyDescription = NULL
			};
			logger->checkHostTimer = CFRunLoopTimerCreate(NULL,
														  CFAbsoluteTimeGetCurrent() + 5,
														  5, // reconnect interval
														  0,
														  0,
														  &LoggerTimedReconnectCallback,
														  &context);
			if (logger->checkHostTimer != NULL)
			{
				LOGGERDBG(CFSTR("Starting the TimedReconnect timer to regularly retry the connection"));
				CFRunLoopAddTimer(CFRunLoopGetCurrent(), logger->checkHostTimer, kCFRunLoopCommonModes);
			}
		}
	}
}

static void LoggerStopReachabilityChecking(Logger *logger)
{
	if (logger->reachability != NULL)
	{
		LOGGERDBG(CFSTR("Stopping SCNetworkReachability"));
		SCNetworkReachabilityUnscheduleFromRunLoop(logger->reachability, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFRelease(logger->reachability);
		logger->reachability = NULL;
	}
	if (logger->checkHostTimer != NULL)
	{
		CFRunLoopTimerInvalidate(logger->checkHostTimer);
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), logger->checkHostTimer, kCFRunLoopCommonModes);
		CFRelease(logger->checkHostTimer);
		logger->checkHostTimer = NULL;
	}
}

static void LoggerReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	Logger *logger = (Logger *)info;
	assert(logger != NULL);
	LOGGERDBG(CFSTR("LoggerReachabilityCallBack called with flags=0x%08lx"), flags);
	if (flags & kSCNetworkReachabilityFlagsReachable)
	{
		// target host became reachable. If we have not other open connection,
		// try direct connection to the host
		if (logger->logStream == NULL && logger->host != NULL)
		{
			LOGGERDBG(CFSTR("-> host %@ became reachable, trying to connect."), logger->host);
			LoggerTryConnect(logger);
		}
	}
}

static void LoggerTimedReconnectCallback(CFRunLoopTimerRef timer, void *info)
{
	Logger *logger = (Logger *)info;
	assert(logger != NULL);
	LOGGERDBG(CFSTR("LoggerTimedReconnectCallback"));
	if (logger->logStream == NULL && logger->host != NULL)
	{
		LOGGERDBG(CFSTR("-> trying to reconnect to host %@"), logger->host);
		LoggerTryConnect(logger);
	}
	else
	{
		LOGGERDBG(CFSTR("-> timer not needed anymore, removing it form runloop"));
		CFRunLoopTimerInvalidate(timer);
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), logger->checkHostTimer, kCFRunLoopCommonModes);
		CFRelease(timer);
		logger->checkHostTimer = NULL;
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Stream management
// -----------------------------------------------------------------------------
static BOOL LoggerConfigureAndOpenStream(Logger *logger)
{
	// configure and open stream
	LOGGERDBG(CFSTR("LoggerConfigureAndOpenStream configuring and opening log stream"));
	CFStreamClientContext context = {0, (void *)logger, NULL, NULL, NULL};
	if (CFWriteStreamSetClient(logger->logStream,
							   (kCFStreamEventOpenCompleted |
								kCFStreamEventCanAcceptBytes |
								kCFStreamEventErrorOccurred |
								kCFStreamEventEndEncountered),
							   &LoggerWriteStreamCallback,
							   &context))
	{
		if (logger->options & kLoggerOption_UseSSL)
		{
			// Configure stream to require a SSL connection
			LOGGERDBG(CFSTR("-> configuring SSL"));
			const void *SSLKeys[] = {
				kCFStreamSSLLevel,
				kCFStreamSSLValidatesCertificateChain,
				kCFStreamSSLIsServer,
				kCFStreamSSLPeerName
			};
			const void *SSLValues[] = {
				kCFStreamSocketSecurityLevelNegotiatedSSL,
				kCFBooleanFalse,			// no certificate chain validation (we use a self-signed certificate)
				kCFBooleanFalse,			// not a server
				kCFNull
			};
			CFDictionaryRef SSLDict = CFDictionaryCreate(NULL, SSLKeys, SSLValues, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
			CFWriteStreamSetProperty(logger->logStream, kCFStreamPropertySSLSettings, SSLDict);
			CFRelease(SSLDict);
		}

		CFWriteStreamScheduleWithRunLoop(logger->logStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		
		if (CFWriteStreamOpen(logger->logStream))
		{
			LOGGERDBG(CFSTR("-> stream open attempt, waiting for open completion"));
			return YES;
		}

		LOGGERDBG(CFSTR("-> stream open failed."));
		
		CFWriteStreamSetClient(logger->logStream, kCFStreamEventNone, NULL, NULL);
		if (CFWriteStreamGetStatus(logger->logStream) == kCFStreamStatusOpen)
			CFWriteStreamClose(logger->logStream);
		CFWriteStreamUnscheduleFromRunLoop(logger->logStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
	else
	{
		LOGGERDBG(CFSTR("-> stream set client failed."));
	}
	CFRelease(logger->logStream);
	logger->logStream = NULL;
	return NO;
}

static void LoggerTryConnect(Logger *logger)
{
	// Try connecting to the next address in the sConnectAttempts array
	LOGGERDBG(CFSTR("LoggerTryConnect, %d services registered, current stream=%@"), CFArrayGetCount(logger->bonjourServices), logger->logStream);
	
	// If we already have a connection established or being attempted, stop here
	if (logger->logStream != NULL)
	{
		LOGGERDBG(CFSTR("-> another connection is opened or in progress, giving up for now"));
		return;
	}

	// If there are discovered Bonjour services, try them now
	while (CFArrayGetCount(logger->bonjourServices))
	{
		CFNetServiceRef service = (CFNetServiceRef)CFArrayGetValueAtIndex(logger->bonjourServices, 0);
		LOGGERDBG(CFSTR("-> Trying to open write stream to service %@"), service);
		CFStreamCreatePairWithSocketToNetService(NULL, service, NULL, &logger->logStream);
		CFArrayRemoveValueAtIndex(logger->bonjourServices, 0);
		if (logger->logStream == NULL)
		{
			// create pair failed
			LOGGERDBG(CFSTR("-> failed."));
		}
		else if (LoggerConfigureAndOpenStream(logger))
		{
			// open is now in progress
			return;
		}
	}

	// If there is a host to directly connect to, try it now (this will happen before
	// Bonjour kicks in, Bonjour being handled as a fallback solution if direct Host
	// fails)
	if (logger->host != NULL)
	{
		LOGGERDBG(CFSTR("-> Trying to open direct connection to host %@ port %u"), logger->host, logger->port);
		CFStreamCreatePairWithSocketToHost(NULL, logger->host, logger->port, NULL, &logger->logStream);
		if (logger->logStream == NULL)
		{
			// Create stream failed
			LOGGERDBG(CFSTR("-> failed."));
			if (logger->logStream != NULL)
			{
				CFRelease(logger->logStream);
				logger->logStream = NULL;
			}
		}
		else if (LoggerConfigureAndOpenStream(logger))
		{
			// open is now in progress
			return;
		}
		
		// Could not connect to host: start Reachability so we know when target host becomes reachable
		// and can try to connect again
		LoggerStartReachabilityChecking(logger);
	}
	
	// Finally, if Bonjour is enabled and not started yet, start it now.
	if ((logger->options & kLoggerOption_BrowseBonjour) &&
		(logger->bonjourDomainBrowser == NULL || CFArrayGetCount(logger->bonjourServiceBrowsers) == 0))
	{
		LoggerStartBonjourBrowsing(logger);
	}
}

static void LoggerWriteStreamCallback(CFWriteStreamRef ws, CFStreamEventType event, void* info)
{
	Logger *logger = (Logger *)info;
	assert(ws == logger->logStream);
	switch (event)
	{
		case kCFStreamEventOpenCompleted:
			// A stream open was complete. Cancel all bonjour browsing,
			// service resolution and connection attempts, and try to
			// write existing buffer contents
			LOGGERDBG(CFSTR("Logger CONNECTED"));
			logger->connected = YES;
			LoggerStopBonjourBrowsing(logger);
			LoggerStopReachabilityChecking(logger);
			if (logger->bufferWriteStream != NULL)
			{
				// now that a connection is acquired, we can stop logging to a file
				CFWriteStreamClose(logger->bufferWriteStream);
				CFRelease(logger->bufferWriteStream);
				logger->bufferWriteStream = NULL;
			}
			if (logger->bufferFile != NULL)
			{
				// if a buffer file was defined, try to read its contents
				LoggerCreateBufferReadStream(logger);
			}
			LoggerPushClientInfoToFrontOfQueue(logger);
			LoggerWriteMoreData(logger);
			break;
			
		case kCFStreamEventCanAcceptBytes:
			LoggerWriteMoreData(logger);
			break;
			
		case kCFStreamEventErrorOccurred: {
			CFErrorRef error = CFWriteStreamCopyError(ws);
			LOGGERDBG(CFSTR("Logger stream error: %@"), error);
			CFRelease(error);
			// Fall-thru
		}
			
		case kCFStreamEventEndEncountered:
			if (logger->connected)
			{
				LOGGERDBG(CFSTR("Logger DISCONNECTED"));
				logger->connected = NO;
			}
			CFWriteStreamSetClient(logger->logStream, 0, NULL, NULL);
			CFWriteStreamUnscheduleFromRunLoop(logger->logStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
			CFWriteStreamClose(logger->logStream);
			
			CFRelease(logger->logStream);
			logger->logStream = NULL;

			if (logger->bufferReadStream != NULL)
			{
				// In the case the connection drops before we have flushed the
				// whole contents of the file, we choose to keep it integrally
				// and retransmit it when reconnecting to the viewer. The reason
				// of this choice is that we may have transmitted only part of
				// a message, and this may cause errors on the desktop side.
				CFReadStreamClose(logger->bufferReadStream);
				CFRelease(logger->bufferReadStream);
				logger->bufferReadStream = NULL;
			}
			if (logger->bufferFile != NULL && logger->bufferWriteStream == NULL)
				LoggerCreateBufferWriteStream(logger);
			
			if (logger->host != NULL && !(logger->options & kLoggerOption_BrowseBonjour))
				LoggerStartReachabilityChecking(logger);
			else
				LoggerTryConnect(logger);
			break;
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Internal encoding functions
// -----------------------------------------------------------------------------
static void LoggerMessageAddTimestamp(CFMutableDataRef encoder)
{
	struct timeval t;
	if (gettimeofday(&t, NULL) == 0)
	{
#if __LP64__
		LoggerMessageAddInt64(encoder, t.tv_sec, PART_KEY_TIMESTAMP_S);
		LoggerMessageAddInt64(encoder, t.tv_usec, PART_KEY_TIMESTAMP_US);
#else
		LoggerMessageAddInt32(encoder, t.tv_sec, PART_KEY_TIMESTAMP_S);
		LoggerMessageAddInt32(encoder, t.tv_usec, PART_KEY_TIMESTAMP_US);
#endif
	}
	else
	{
		time_t ts = time(NULL);
#if __LP64__
		LoggerMessageAddInt64(encoder, ts, PART_KEY_TIMESTAMP_S);
#else
		LoggerMessageAddInt32(encoder, ts, PART_KEY_TIMESTAMP_S);
#endif
	}
}

static void LoggerMessageAddTimestampAndThreadID(CFMutableDataRef encoder)
{
	LoggerMessageAddTimestamp(encoder);

	BOOL hasThreadName = NO;
#if ALLOW_COCOA_USE
	// Getting the thread number is tedious, to say the least. Since there is
	// no direct way to get it, we have to do it sideways. Note that it can be dangerous
	// to use any Cocoa call when in a multithreaded application that only uses non-Cocoa threads
	// and for which Cocoa's multithreading has not been activated. We test for this case.
	if ([NSThread isMultiThreaded] || [NSThread isMainThread])
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSThread *thread = [NSThread currentThread];
		NSString *name = [thread name];
		if (name == nil)
		{
			if ([thread isMainThread])
				name = @"Main thread";
			else
			{
				name = [thread description];
				NSRange range = [name rangeOfString:@"num = "];
				if (range.location != NSNotFound)
				{
					name = [NSString stringWithFormat:@"Thread %@",
							[name substringWithRange:NSMakeRange(range.location + range.length,
																 [name length] - range.location - range.length - 1)]];
				}
			}
		}
		if (name != nil)
		{
			LoggerMessageAddString(encoder, (CFStringRef)name, PART_KEY_THREAD_ID);
			hasThreadName = YES;
		}
		[pool drain];
	}
#endif
	if (!hasThreadName)
	{
#if __LP64__
		LoggerMessageAddInt64(encoder, (int64_t)pthread_self(), PART_KEY_THREAD_ID);
#else
		LoggerMessageAddInt32(encoder, (int32_t)pthread_self(), PART_KEY_THREAD_ID);
#endif
	}
}

static void LoggerMessageUpdateDataHeader(CFMutableDataRef data)
{
	// update the data header with updated part count and size
	UInt8 *p = CFDataGetMutableBytePtr(data);
	uint32_t size = htonl(CFDataGetLength(data) - 4);
	uint16_t partCount = htons(ntohs(*(uint16_t *)(p + 4)) + 1);
	memcpy(p, &size, 4);
	memcpy(p+4, &partCount, 2);
}

static CFMutableDataRef LoggerMessageCreate()
{
	CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
	CFDataIncreaseLength(data, 6);
	UInt8 *p = CFDataGetMutableBytePtr(data);
	p[3] = 2;		// size 0x00000002 in big endian
	return data;
}

static void LoggerMessageAddInt16(CFMutableDataRef data, int16_t anInt, int key)
{
	uint16_t partData = htonl(anInt);
	uint8_t keyAndType[2] = {(uint8_t)key, PART_TYPE_INT16};
	CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
	CFDataAppendBytes(data, (const UInt8 *)&partData, 2);
	LoggerMessageUpdateDataHeader(data);
}

static void LoggerMessageAddInt32(CFMutableDataRef data, int32_t anInt, int key)
{
	uint32_t partData = htonl(anInt);
	uint8_t keyAndType[2] = {(uint8_t)key, PART_TYPE_INT32};
	CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
	CFDataAppendBytes(data, (const UInt8 *)&partData, 4);
	LoggerMessageUpdateDataHeader(data);
}

static void LoggerMessageAddInt64(CFMutableDataRef data, int64_t anInt, int key)
{
	uint32_t partData[2] = {htonl((uint32_t)(anInt >> 32)), htonl((uint32_t)anInt)};
	uint8_t keyAndType[2] = {(uint8_t)key, PART_TYPE_INT64};
	CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
	CFDataAppendBytes(data, (const UInt8 *)&partData, 8);
	LoggerMessageUpdateDataHeader(data);
}

static void LoggerMessageAddCString(CFMutableDataRef data, const char *aString, int key)
{
	if (aString == NULL || *aString == 0)
		return;
	
	// convert to UTF-8
	int len = strlen(aString);
	uint8_t *buf = malloc(2 * len);
	if (buf != NULL)
	{
		int i, n = 0;
		for (i = 0; i < len; i++)
		{
			uint8_t c = (uint8_t)(*aString++);
			if (c < 0x80)
				buf[n++] = c;
			else {
				buf[n++] = 0xC0 | (c >> 6);
				buf[n++] = (c & 0x6F) | 0x80;
			}
		}
		if (n)
		{
			uint32_t partSize = htonl(n);
			uint8_t keyAndType[2] = {(uint8_t)key, PART_TYPE_STRING};
			CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
			CFDataAppendBytes(data, (const UInt8 *)&partSize, 4);
			CFDataAppendBytes(data, buf, n);
			LoggerMessageUpdateDataHeader(data);
		}
		free(buf);
	}
}

static void LoggerMessageAddString(CFMutableDataRef data, CFStringRef aString, int key)
{
	if (aString == NULL)
		aString = CFSTR("");

	// All strings are UTF-8 encoded
	uint8_t keyAndType[2] = {(uint8_t)key, PART_TYPE_STRING};
	uint32_t partSize = 0;
	uint8_t *bytes = NULL;
	
	CFIndex stringLength = CFStringGetLength(aString);
	CFIndex bytesLength = stringLength * 4;
	if (stringLength)
	{
		bytes = (uint8_t *)malloc(stringLength * 4 + 4);
		CFStringGetBytes(aString, CFRangeMake(0, stringLength), kCFStringEncodingUTF8, '?', false, bytes, bytesLength, &bytesLength);
		partSize = htonl(bytesLength);
	}
	
	CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
	CFDataAppendBytes(data, (const UInt8 *)&partSize, 4);
	if (partSize)
		CFDataAppendBytes(data, bytes, bytesLength);
	
	if (bytes != NULL)
		free(bytes);
	LoggerMessageUpdateDataHeader(data);
}

static void LoggerMessageAddData(CFMutableDataRef data, CFDataRef theData, int key, int partType)
{
	uint8_t keyAndType[2] = {(uint8_t)key, (uint8_t)partType};
	CFIndex dataLength = CFDataGetLength(theData);
	uint32_t partSize = htonl(dataLength);
	CFDataAppendBytes(data, (const UInt8 *)&keyAndType, 2);
	CFDataAppendBytes(data, (const UInt8 *)&partSize, 4);
	if (partSize)
		CFDataAppendBytes(data, CFDataGetBytePtr(theData), dataLength);
	LoggerMessageUpdateDataHeader(data);
}

static uint32_t LoggerMessageGetSeq(CFDataRef message)
{
	// Extract the sequence number from a message. When pushing messages to the queue,
	// we use this to guarantee the logging order according to the seq#
	uint32_t seq = 0;
	uint8_t *p = (uint8_t *)CFDataGetBytePtr(message) + 4;
	uint16_t partCount;
	memcpy(&partCount, p, 2);
	partCount = ntohs(partCount);
	p += 2;
	while (partCount--)
	{
		uint8_t partKey = *p++;
		uint8_t partType = *p++;
		uint32_t partSize;
		if (partType == PART_TYPE_INT16)
			partSize = 2;
		else if (partType == PART_TYPE_INT32)
			partSize = 4;
		else if (partType == PART_TYPE_INT64)
			partSize = 8;
		else
		{
			memcpy(&partSize, p, 4);
			p += 4;
			partSize = ntohl(partSize);
		}
		if (partKey == PART_KEY_MESSAGE_SEQ)
		{
			memcpy(&seq, p, sizeof(uint32_t));
			seq = ntohl(seq);
			break;
		}
		p += partSize;
	}
	return seq;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Private logging functions
// -----------------------------------------------------------------------------
static void	LoggerPushClientInfoToFrontOfQueue(Logger *logger)
{
	// Extract client information from the main bundle, as well as platform info,
	// and assmble it to a message that will be put in front of the queue
	// Helps desktop viewer display who's talking to it
	// Note that we must be called from the logger work thread, as we don't
	// run through the message port to transmit this message to the queue
	CFBundleRef bundle = CFBundleGetMainBundle();
	if (bundle == NULL)
		return;
	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestamp(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_CLIENTINFO, PART_KEY_MESSAGE_TYPE);

		CFStringRef version = (CFStringRef)CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleVersionKey);
		if (version != NULL && CFGetTypeID(version) == CFStringGetTypeID())
			LoggerMessageAddString(encoder, version, PART_KEY_CLIENT_VERSION);
		CFStringRef name = (CFStringRef)CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleNameKey);
		if (name != NULL)
			LoggerMessageAddString(encoder, name, PART_KEY_CLIENT_NAME);

#if TARGET_OS_IPHONE && ALLOW_COCOA_USE
		if ([NSThread isMultiThreaded] || [NSThread isMainThread])
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			UIDevice *device = [UIDevice currentDevice];
			LoggerMessageAddString(encoder, (CFStringRef)device.identifierForVendor.UUIDString, PART_KEY_UNIQUEID);
			LoggerMessageAddString(encoder, (CFStringRef)device.systemVersion, PART_KEY_OS_VERSION);
			LoggerMessageAddString(encoder, (CFStringRef)device.systemName, PART_KEY_OS_NAME);
			LoggerMessageAddString(encoder, (CFStringRef)device.model, PART_KEY_CLIENT_MODEL);
			[pool release];
		}
#elif TARGET_OS_MAC
		SInt32 versionMajor, versionMinor, versionFix;
		Gestalt(gestaltSystemVersionMajor, &versionMajor);
		Gestalt(gestaltSystemVersionMinor, &versionMinor);
		Gestalt(gestaltSystemVersionBugFix, &versionFix);
		CFStringRef osVersion = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d.%d.%d"), versionMajor, versionMinor, versionFix);
		LoggerMessageAddString(encoder, osVersion, PART_KEY_OS_VERSION);
		CFRelease(osVersion);
		LoggerMessageAddString(encoder, CFSTR("Mac OS X"), PART_KEY_OS_NAME);

		char buf[64];
		size_t len;
		int ncpu = 0;
		bzero(buf, sizeof(buf));
		len = sizeof(buf)-1;
		sysctlbyname("hw.model", buf, &len, NULL, 0);
		len = sizeof(ncpu);
		sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
		sprintf(buf+strlen(buf), " - %d * ", ncpu);
		len = sizeof(buf)-strlen(buf)-1;
		sysctlbyname("hw.machine", buf+strlen(buf), &len, NULL, 0);
		
		CFStringRef s = CFStringCreateWithCString(NULL, buf, kCFStringEncodingASCII);
		LoggerMessageAddString(encoder, s, PART_KEY_CLIENT_MODEL);
		CFRelease(s);
#endif
		pthread_mutex_lock(&logger->logQueueMutex);
		CFArrayInsertValueAtIndex(logger->logQueue, logger->incompleteSendOfFirstItem ? 1 : 0, encoder);
		pthread_mutex_unlock(&logger->logQueueMutex);

		CFRelease(encoder);
	}
}

static void LoggerPushMessageToQueue(Logger *logger, CFDataRef message)
{
	// Add the message to the log queue and signal the runLoop source that will trigger
	// a send on the worker thread.
	pthread_mutex_lock(&logger->logQueueMutex);
	CFIndex idx = CFArrayGetCount(logger->logQueue);
	if (idx)
	{
		// to prevent out-of-order messages (as much as possible), we try to transmit messages in the
		// order their sequence number was generated. Since the seq is generated first-thing,
		// we can provide fine-grained ordering that gives a reasonable idea of the order
		// the logging calls were made (useful for precise information about multithreading code)
		uint32_t lastSeq, seq = LoggerMessageGetSeq(message);
		do {
			lastSeq = LoggerMessageGetSeq(CFArrayGetValueAtIndex(logger->logQueue, idx-1));
		} while (lastSeq > seq && --idx > 0);
	}
	if (idx >= 0)
		CFArrayInsertValueAtIndex(logger->logQueue, idx, message);
	else
		CFArrayAppendValue(logger->logQueue, message);
	pthread_mutex_unlock(&logger->logQueueMutex);
	
	if (logger->messagePushedSource != NULL)
	{
		// One case where the pushed source may be NULL is if the client code
		// immediately starts logging without initializing the logger first.
		// In this case, the worker thread has not completed startup, so we don't need
		// to fire the runLoop source
		CFRunLoopSourceSignal(logger->messagePushedSource);
	}
	else if (logger->workerThread == NULL && (logger->options & kLoggerOption_LogToConsole))
	{
		// In this case, a failure creating the message runLoop source forces us
		// to always log to console
		pthread_mutex_lock(&logger->logQueueMutex);
		while (CFArrayGetCount(logger->logQueue))
		{
			LoggerLogToConsole(CFArrayGetValueAtIndex(logger->logQueue, 0));
			CFArrayRemoveValueAtIndex(logger->logQueue, 0);
		}
		pthread_mutex_unlock(&logger->logQueueMutex);
	}
}

static void LogMessageTo_internal(Logger *logger,
								  const char *filename,
								  int lineNumber,
								  const char *functionName,
								  NSString *domain,
								  int level,
								  NSString *format,
								  va_list args)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		LoggerStart(logger);
	}

	int32_t seq = OSAtomicIncrement32Barrier(&logger->messageSeq);
	LOGGERDBG2(CFSTR("%ld LogMessage"), seq);

	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestampAndThreadID(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_LOG, PART_KEY_MESSAGE_TYPE);
		LoggerMessageAddInt32(encoder, seq, PART_KEY_MESSAGE_SEQ);
		if (domain != nil && [domain length])
			LoggerMessageAddString(encoder, (CFStringRef)domain, PART_KEY_TAG);
		if (level)
			LoggerMessageAddInt32(encoder, level, PART_KEY_LEVEL);
		if (filename != NULL)
			LoggerMessageAddCString(encoder, filename, PART_KEY_FILENAME);
		if (lineNumber)
			LoggerMessageAddInt32(encoder, lineNumber, PART_KEY_LINENUMBER);
		if (functionName != NULL)
			LoggerMessageAddCString(encoder, functionName, PART_KEY_FUNCTIONNAME);

#if ALLOW_COCOA_USE
		// Go though NSString to avoid low-level logging of CF datastructures (i.e. too detailed NSDictionary, etc)
		NSString *msgString = [[NSString alloc] initWithFormat:format arguments:args];
		if (msgString != nil)
		{
			LoggerMessageAddString(encoder, (CFStringRef)msgString, PART_KEY_MESSAGE);
			[msgString release];
		}
#else
		CFStringRef msgString = CFStringCreateWithFormatAndArguments(NULL, NULL, (CFStringRef)format, args);
		if (msgString != NULL)
		{
			LoggerMessageAddString(encoder, msgString, PART_KEY_MESSAGE);
			CFRelease(msgString);
		}
#endif

		LoggerPushMessageToQueue(logger, encoder);
		CFRelease(encoder);
	}
	else
	{
		LOGGERDBG2(CFSTR("-> failed creating encoder"));
	}
}

static void LogImageTo_internal(Logger *logger,
								const char *filename,
								int lineNumber,
								const char *functionName,
								NSString *domain,
								int level,
								int width,
								int height,
								NSData *data)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		LoggerStart(logger);
	}

	int32_t seq = OSAtomicIncrement32Barrier(&logger->messageSeq);
	LOGGERDBG2(CFSTR("%ld LogImage"), seq);

	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestampAndThreadID(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_LOG, PART_KEY_MESSAGE_TYPE);
		LoggerMessageAddInt32(encoder, seq, PART_KEY_MESSAGE_SEQ);
		if (domain != nil && [domain length])
			LoggerMessageAddString(encoder, (CFStringRef)domain, PART_KEY_TAG);
		if (level)
			LoggerMessageAddInt32(encoder, level, PART_KEY_LEVEL);
		if (width && height)
		{
			LoggerMessageAddInt32(encoder, width, PART_KEY_IMAGE_WIDTH);
			LoggerMessageAddInt32(encoder, height, PART_KEY_IMAGE_HEIGHT);
		}
		if (filename != NULL)
			LoggerMessageAddCString(encoder, filename, PART_KEY_FILENAME);
		if (lineNumber)
			LoggerMessageAddInt32(encoder, lineNumber, PART_KEY_LINENUMBER);
		if (functionName != NULL)
			LoggerMessageAddCString(encoder, functionName, PART_KEY_FUNCTIONNAME);
		LoggerMessageAddData(encoder, (CFDataRef)data, PART_KEY_MESSAGE, PART_TYPE_IMAGE);

		LoggerPushMessageToQueue(logger, encoder);
		CFRelease(encoder);
	}
	else
	{
		LOGGERDBG2(CFSTR("-> failed creating encoder"));
	}
}

static void LogDataTo_internal(Logger *logger,
							   const char *filename,
							   int lineNumber,
							   const char *functionName,
							   NSString *domain,
							   int level, NSData *data)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		LoggerStart(logger);
	}

	int32_t seq = OSAtomicIncrement32Barrier(&logger->messageSeq);
	LOGGERDBG2(CFSTR("%ld LogData"), seq);

	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestampAndThreadID(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_LOG, PART_KEY_MESSAGE_TYPE);
		LoggerMessageAddInt32(encoder, seq, PART_KEY_MESSAGE_SEQ);
		if (domain != nil && [domain length])
			LoggerMessageAddString(encoder, (CFStringRef)domain, PART_KEY_TAG);
		if (level)
			LoggerMessageAddInt32(encoder, level, PART_KEY_LEVEL);
		if (filename != NULL)
			LoggerMessageAddCString(encoder, filename, PART_KEY_FILENAME);
		if (lineNumber)
			LoggerMessageAddInt32(encoder, lineNumber, PART_KEY_LINENUMBER);
		if (functionName != NULL)
			LoggerMessageAddCString(encoder, functionName, PART_KEY_FUNCTIONNAME);
		LoggerMessageAddData(encoder, (CFDataRef)data, PART_KEY_MESSAGE, PART_TYPE_BINARY);
		
		LoggerPushMessageToQueue(logger, encoder);
		CFRelease(encoder);
	}
	else
	{
		LOGGERDBG2(CFSTR("-> failed creating encoder"));
	}
}

static void LogStartBlockTo_internal(Logger *logger, NSString *format, va_list args)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		LoggerStart(logger);
	}

	int32_t seq = OSAtomicIncrement32Barrier(&logger->messageSeq);
	LOGGERDBG2(CFSTR("%ld LogStartBlock"), seq);

	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestampAndThreadID(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_BLOCKSTART, PART_KEY_MESSAGE_TYPE);
		LoggerMessageAddInt32(encoder, seq, PART_KEY_MESSAGE_SEQ);

		CFStringRef msgString = NULL;
		if (format != nil)
		{
			msgString = CFStringCreateWithFormatAndArguments(NULL, NULL, (CFStringRef)format, args);
			if (msgString != NULL)
			{
				LoggerMessageAddString(encoder, msgString, PART_KEY_MESSAGE);
				CFRelease(msgString);
			}
		}
		
		LoggerPushMessageToQueue(logger, encoder);
		CFRelease(encoder);
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Public logging functions
// -----------------------------------------------------------------------------
void LogMessageCompat(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogMessageTo_internal(NULL, NULL, 0, NULL, nil, 0, format, args);
	va_end(args);
}

void LogMessageTo(Logger *logger, NSString *domain, int level, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogMessageTo_internal(logger, NULL, 0, NULL, domain, level, format, args);
	va_end(args);
}

void LogMessageToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogMessageTo_internal(logger, filename, lineNumber, functionName, domain, level, format, args);
	va_end(args);
}

void LogMessageTo_va(Logger *logger, NSString *domain, int level, NSString *format, va_list args)
{
	LogMessageTo_internal(logger, NULL, 0, NULL, domain, level, format, args);
}

void LogMessageToF_va(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, va_list args)
{
	LogMessageTo_internal(logger, filename, lineNumber, functionName, domain, level, format, args);
}

void LogMessage(NSString *domain, int level, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogMessageTo_internal(NULL, NULL, 0, NULL, domain, level, format, args);
	va_end(args);
}

void LogMessageF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogMessageTo_internal(NULL, filename, lineNumber, functionName, domain, level, format, args);
	va_end(args);
}

void LogMessage_va(NSString *domain, int level, NSString *format, va_list args)
{
	LogMessageTo_internal(NULL, NULL, 0, NULL, domain, level, format, args);
}

void LogMessageF_va(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSString *format, va_list args)
{
	LogMessageTo_internal(NULL, filename, lineNumber, functionName, domain, level, format, args);
}

void LogData(NSString *domain, int level, NSData *data)
{
	LogDataTo_internal(NULL, NULL, 0, NULL, domain, level, data);
}

void LogDataF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSData *data)
{
	LogDataTo_internal(NULL, filename, lineNumber, functionName, domain, level, data);
}

void LogDataTo(Logger *logger, NSString *domain, int level, NSData *data)
{
	LogDataTo_internal(logger, NULL, 0, NULL, domain, level, data);
}

void LogDataToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, NSData *data)
{
	LogDataTo_internal(logger, filename, lineNumber, functionName, domain, level, data);
}

void LogImageData(NSString *domain, int level, int width, int height, NSData *data)
{
	LogImageTo_internal(NULL, NULL, 0, NULL, domain, level, width, height, data);
}

void LogImageDataF(const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, int width, int height, NSData *data)
{
	LogImageTo_internal(NULL, filename, lineNumber, functionName, domain, level, width, height, data);
}

void LogImageDataTo(Logger *logger, NSString *domain, int level, int width, int height, NSData *data)
{
	LogImageTo_internal(logger, NULL, 0, NULL, domain, level, width, height, data);
}

void LogImageDataToF(Logger *logger, const char *filename, int lineNumber, const char *functionName, NSString *domain, int level, int width, int height, NSData *data)
{
	LogImageTo_internal(logger, filename, lineNumber, functionName, domain, level, width, height, data);
}

void LogStartBlock(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogStartBlockTo_internal(NULL, format, args);
	va_end(args);
}

void LogStartBlockTo(Logger *logger, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	LogStartBlockTo_internal(logger, format, args);
	va_end(args);
}

void LogEndBlockTo(Logger *logger)
{
	if (logger == NULL)
	{
		logger = LoggerGetDefaultLogger();
		LoggerStart(logger);
	}

	if (logger->options & kLoggerOption_LogToConsole)
		return;
	
	int32_t seq = OSAtomicIncrement32Barrier(&logger->messageSeq);
	LOGGERDBG2(CFSTR("%ld LogEndBlock"), seq);

	CFMutableDataRef encoder = LoggerMessageCreate();
	if (encoder != NULL)
	{
		LoggerMessageAddTimestampAndThreadID(encoder);
		LoggerMessageAddInt32(encoder, LOGMSG_TYPE_BLOCKEND, PART_KEY_MESSAGE_TYPE);
		LoggerMessageAddInt32(encoder, seq, PART_KEY_MESSAGE_SEQ);
		LoggerPushMessageToQueue(logger, encoder);
		CFRelease(encoder);
	}
	else
	{
		LOGGERDBG2(CFSTR("-> failed creating encoder"));
	}
}

void LogEndBlock()
{
	LogEndBlockTo(NULL);
}
