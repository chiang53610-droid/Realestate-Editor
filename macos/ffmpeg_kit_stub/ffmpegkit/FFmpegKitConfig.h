// Stub header for macOS desktop development
// FFmpeg is not used on macOS (mock mode) — this satisfies compile-time dependencies only

#import <Foundation/Foundation.h>

// ====== Enums ======

typedef NS_ENUM(NSUInteger, SessionState) {
  SessionStateCreated = 0,
  SessionStateRunning = 1,
  SessionStateFailed = 2,
  SessionStateCompleted = 3
};

typedef NS_ENUM(NSUInteger, LogRedirectionStrategy) {
  LogRedirectionStrategyAlwaysPrintLogs = 0,
  LogRedirectionStrategyPrintLogsWhenNoCallbacksDefined = 1,
  LogRedirectionStrategyPrintLogsWhenGlobalCallbackNotDefined = 2,
  LogRedirectionStrategyPrintLogsWhenSessionCallbackNotDefined = 3,
  LogRedirectionStrategyNeverPrintLogs = 4
};

typedef NS_ENUM(NSUInteger, Signal) {
  SignalInt = 0,
  SignalQuit = 1,
  SignalPipe = 2,
  SignalTerm = 3,
  SignalXcpu = 4,
  SignalXfsz = 5
};

// ====== Log ======

@interface Log : NSObject
- (long)getSessionId;
- (int)getLevel;
- (NSString*)getMessage;
@end

// ====== Statistics ======

@interface Statistics : NSObject
- (long)getSessionId;
- (int)getVideoFrameNumber;
- (float)getVideoFps;
- (float)getVideoQuality;
- (long)getSize;
- (double)getTime;
- (double)getBitrate;
- (double)getSpeed;
@end

// ====== ReturnCode ======

@interface ReturnCode : NSObject
- (int)getValue;
+ (BOOL)isSuccess:(ReturnCode*)code;
+ (BOOL)isCancel:(ReturnCode*)code;
@end

// ====== MediaInformation ======

@interface StreamInformation : NSObject
@end

@interface Chapter : NSObject
@end

@interface MediaInformation : NSObject
- (NSArray*)getStreams;
- (NSArray*)getChapters;
- (NSDictionary*)getAllProperties;
@end

// ====== MediaInformationJsonParser ======

@interface MediaInformationJsonParser : NSObject
+ (MediaInformation*)from:(NSString*)ffprobeJsonOutput;
+ (MediaInformation*)fromWithError:(NSString*)ffprobeJsonOutput;
@end

// ====== Packages ======

@interface Packages : NSObject
+ (NSString*)getPackageName;
+ (NSArray*)getExternalLibraries;
@end

// ====== Session Protocol ======

@protocol Session <NSObject>
- (long)getSessionId;
- (NSDate*)getCreateTime;
- (NSDate*)getStartTime;
- (NSDate*)getEndTime;
- (long)getDuration;
- (NSString*)getCommand;
- (NSArray*)getArguments;
- (NSArray*)getLogs;
- (NSArray*)getAllLogs;
- (NSArray*)getAllLogsWithTimeout:(int)timeout;
- (NSString*)getOutput;
- (NSString*)getAllLogsAsString;
- (NSString*)getAllLogsAsStringWithTimeout:(int)timeout;
- (SessionState)getState;
- (ReturnCode*)getReturnCode;
- (NSString*)getFailStackTrace;
- (BOOL)isFFmpeg;
- (BOOL)isFFprobe;
- (BOOL)isMediaInformation;
- (BOOL)thereAreAsynchronousMessagesInTransmit;
- (void)cancel;
@end

// ====== AbstractSession ======

@interface AbstractSession : NSObject<Session>
@end

// ====== Forward declare callbacks ======

@class FFmpegSession;
@class FFprobeSession;
@class MediaInformationSession;

typedef void (^FFmpegSessionCompleteCallback)(FFmpegSession* session);
typedef void (^FFprobeSessionCompleteCallback)(FFprobeSession* session);
typedef void (^MediaInformationSessionCompleteCallback)(MediaInformationSession* session);
typedef void (^LogCallback)(Log* log);
typedef void (^StatisticsCallback)(Statistics* statistics);

// ====== FFmpegSession ======

@interface FFmpegSession : AbstractSession
+ (instancetype)create:(NSArray*)arguments
  withCompleteCallback:(FFmpegSessionCompleteCallback)completeCallback
       withLogCallback:(LogCallback)logCallback
withStatisticsCallback:(StatisticsCallback)statisticsCallback
withLogRedirectionStrategy:(LogRedirectionStrategy)logRedirectionStrategy;
- (NSArray*)getAllStatistics;
- (NSArray*)getAllStatisticsWithTimeout:(int)timeout;
- (NSArray*)getStatistics;
@end

// ====== FFprobeSession ======

@interface FFprobeSession : AbstractSession
+ (instancetype)create:(NSArray*)arguments
  withCompleteCallback:(FFprobeSessionCompleteCallback)completeCallback
       withLogCallback:(LogCallback)logCallback
withLogRedirectionStrategy:(LogRedirectionStrategy)logRedirectionStrategy;
@end

// ====== MediaInformationSession ======

@interface MediaInformationSession : AbstractSession
+ (instancetype)create:(NSArray*)arguments
  withCompleteCallback:(MediaInformationSessionCompleteCallback)completeCallback
       withLogCallback:(LogCallback)logCallback;
- (MediaInformation*)getMediaInformation;
@end

// ====== ArchDetect ======

@interface ArchDetect : NSObject
+ (NSString*)getArch;
@end

// ====== FFmpegKitConfig ======

@interface FFmpegKitConfig : NSObject

+ (void)enableRedirection;
+ (void)disableRedirection;

+ (int)getLogLevel;
+ (void)setLogLevel:(int)level;

+ (LogRedirectionStrategy)getLogRedirectionStrategy;
+ (void)setLogRedirectionStrategy:(LogRedirectionStrategy)strategy;

+ (int)getSessionHistorySize;
+ (void)setSessionHistorySize:(int)size;

+ (id)getSession:(long)sessionId;
+ (id)getLastSession;
+ (id)getLastCompletedSession;
+ (NSArray*)getSessions;
+ (void)clearSessions;
+ (NSArray*)getSessionsByState:(SessionState)state;

+ (void)enableFFmpegSessionCompleteCallback:(FFmpegSessionCompleteCallback)callback;
+ (void)enableFFprobeSessionCompleteCallback:(FFprobeSessionCompleteCallback)callback;
+ (void)enableMediaInformationSessionCompleteCallback:(MediaInformationSessionCompleteCallback)callback;
+ (void)enableLogCallback:(LogCallback)callback;
+ (void)enableStatisticsCallback:(StatisticsCallback)callback;

+ (void)ffmpegExecute:(FFmpegSession*)session;
+ (void)ffprobeExecute:(FFprobeSession*)session;
+ (void)getMediaInformationExecute:(MediaInformationSession*)session withTimeout:(int)timeout;
+ (void)asyncFFmpegExecute:(FFmpegSession*)session;
+ (void)asyncFFprobeExecute:(FFprobeSession*)session;
+ (void)asyncGetMediaInformationExecute:(MediaInformationSession*)session withTimeout:(int)timeout;

+ (void)setFontconfigConfigurationPath:(NSString*)path;
+ (void)setFontDirectory:(NSString*)fontDirectoryPath with:(NSDictionary*)fontNameMapping;
+ (void)setFontDirectoryList:(NSArray*)fontDirectoryList with:(NSDictionary*)fontNameMapping;
+ (void)setEnvironmentVariable:(NSString*)variableName value:(NSString*)variableValue;
+ (void)ignoreSignal:(Signal)signal;

+ (int)messagesInTransmit:(long)sessionId;

+ (NSString*)getFFmpegVersion;
+ (BOOL)isLTSBuild;
+ (NSString*)getBuildDate;
+ (NSString*)getVersion;

+ (NSString*)registerNewFFmpegPipe;
+ (void)closeFFmpegPipe:(NSString*)ffmpegPipePath;

+ (NSArray*)parseArguments:(NSString*)command;
+ (NSString*)argumentsToString:(NSArray*)arguments;

+ (NSString*)sessionStateToString:(SessionState)state;

+ (void)cancelSession:(long)sessionId;

+ (NSString*)writeToPipe:(NSString*)inputPath onPipe:(NSString*)pipePath;
+ (NSString*)selectDocumentForRead:(NSString*)type extra:(NSArray*)extraTypes;
+ (NSString*)selectDocumentForWrite:(NSString*)title type:(NSString*)type extra:(NSArray*)extraTypes;
+ (NSString*)getSafParameter:(NSString*)path openMode:(NSString*)mode;

+ (NSString*)getPlatform;

@end

// ====== FFmpegKit ======

@interface FFmpegKit : NSObject
+ (FFmpegSession*)execute:(NSString*)command;
+ (void)cancel;
+ (void)cancel:(long)sessionId;
+ (NSArray*)listSessions;
@end

// ====== FFprobeKit ======

@interface FFprobeKit : NSObject
+ (FFprobeSession*)execute:(NSString*)command;
+ (MediaInformationSession*)getMediaInformation:(NSString*)path;
+ (NSArray*)listFFprobeSessions;
+ (NSArray*)listMediaInformationSessions;
@end
