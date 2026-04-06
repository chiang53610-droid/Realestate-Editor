// Stub implementations for macOS desktop — all methods return nil/0/NO
// FFmpeg runs in mock mode on desktop, so none of these are actually called

#import "FFmpegKitConfig.h"

int AbstractSessionDefaultTimeoutForAsynchronousMessagesInTransmit = 5000;

@implementation Log
- (long)getSessionId { return 0; }
- (int)getLevel { return 0; }
- (NSString*)getMessage { return @""; }
@end

@implementation Statistics
- (long)getSessionId { return 0; }
- (int)getVideoFrameNumber { return 0; }
- (float)getVideoFps { return 0; }
- (float)getVideoQuality { return 0; }
- (long)getSize { return 0; }
- (double)getTime { return 0; }
- (double)getBitrate { return 0; }
- (double)getSpeed { return 0; }
@end

@implementation ReturnCode
- (int)getValue { return 0; }
+ (BOOL)isSuccess:(ReturnCode*)code { return NO; }
+ (BOOL)isCancel:(ReturnCode*)code { return NO; }
@end

@implementation StreamInformation @end
@implementation Chapter @end

@implementation MediaInformation
- (NSArray*)getStreams { return @[]; }
- (NSArray*)getChapters { return @[]; }
- (NSDictionary*)getAllProperties { return @{}; }
@end

@implementation MediaInformationJsonParser
+ (MediaInformation*)from:(NSString*)json { return nil; }
+ (MediaInformation*)fromWithError:(NSString*)json { return nil; }
@end

@implementation Packages
+ (NSString*)getPackageName { return @"stub"; }
+ (NSArray*)getExternalLibraries { return @[]; }
@end

@implementation AbstractSession
- (long)getSessionId { return 0; }
- (NSDate*)getCreateTime { return [NSDate date]; }
- (NSDate*)getStartTime { return [NSDate date]; }
- (NSDate*)getEndTime { return [NSDate date]; }
- (long)getDuration { return 0; }
- (NSString*)getCommand { return @""; }
- (NSArray*)getArguments { return @[]; }
- (NSArray*)getLogs { return @[]; }
- (NSArray*)getAllLogs { return @[]; }
- (NSArray*)getAllLogsWithTimeout:(int)timeout { return @[]; }
- (NSString*)getOutput { return @""; }
- (NSString*)getAllLogsAsString { return @""; }
- (NSString*)getAllLogsAsStringWithTimeout:(int)timeout { return @""; }
- (SessionState)getState { return SessionStateCompleted; }
- (ReturnCode*)getReturnCode { return nil; }
- (NSString*)getFailStackTrace { return nil; }
- (BOOL)isFFmpeg { return NO; }
- (BOOL)isFFprobe { return NO; }
- (BOOL)isMediaInformation { return NO; }
- (BOOL)thereAreAsynchronousMessagesInTransmit { return NO; }
- (void)cancel {}
@end

@implementation FFmpegSession
+ (instancetype)create:(NSArray*)arguments withCompleteCallback:(FFmpegSessionCompleteCallback)c withLogCallback:(LogCallback)l withStatisticsCallback:(StatisticsCallback)s withLogRedirectionStrategy:(LogRedirectionStrategy)r { return nil; }
- (NSArray*)getAllStatistics { return @[]; }
- (NSArray*)getAllStatisticsWithTimeout:(int)timeout { return @[]; }
- (NSArray*)getStatistics { return @[]; }
@end

@implementation FFprobeSession
+ (instancetype)create:(NSArray*)arguments withCompleteCallback:(FFprobeSessionCompleteCallback)c withLogCallback:(LogCallback)l withLogRedirectionStrategy:(LogRedirectionStrategy)r { return nil; }
@end

@implementation MediaInformationSession
+ (instancetype)create:(NSArray*)arguments withCompleteCallback:(MediaInformationSessionCompleteCallback)c withLogCallback:(LogCallback)l { return nil; }
- (MediaInformation*)getMediaInformation { return nil; }
@end

@implementation ArchDetect
+ (NSString*)getArch { return @"stub"; }
@end

@implementation FFmpegKitConfig
+ (void)enableRedirection {}
+ (void)disableRedirection {}
+ (int)getLogLevel { return 0; }
+ (void)setLogLevel:(int)level {}
+ (LogRedirectionStrategy)getLogRedirectionStrategy { return LogRedirectionStrategyNeverPrintLogs; }
+ (void)setLogRedirectionStrategy:(LogRedirectionStrategy)strategy {}
+ (int)getSessionHistorySize { return 0; }
+ (void)setSessionHistorySize:(int)size {}
+ (id)getSession:(long)sessionId { return nil; }
+ (id)getLastSession { return nil; }
+ (id)getLastCompletedSession { return nil; }
+ (NSArray*)getSessions { return @[]; }
+ (void)clearSessions {}
+ (NSArray*)getSessionsByState:(SessionState)state { return @[]; }
+ (void)enableFFmpegSessionCompleteCallback:(FFmpegSessionCompleteCallback)callback {}
+ (void)enableFFprobeSessionCompleteCallback:(FFprobeSessionCompleteCallback)callback {}
+ (void)enableMediaInformationSessionCompleteCallback:(MediaInformationSessionCompleteCallback)callback {}
+ (void)enableLogCallback:(LogCallback)callback {}
+ (void)enableStatisticsCallback:(StatisticsCallback)callback {}
+ (void)ffmpegExecute:(FFmpegSession*)session {}
+ (void)ffprobeExecute:(FFprobeSession*)session {}
+ (void)getMediaInformationExecute:(MediaInformationSession*)session withTimeout:(int)timeout {}
+ (void)asyncFFmpegExecute:(FFmpegSession*)session {}
+ (void)asyncFFprobeExecute:(FFprobeSession*)session {}
+ (void)asyncGetMediaInformationExecute:(MediaInformationSession*)session withTimeout:(int)timeout {}
+ (void)setFontconfigConfigurationPath:(NSString*)path {}
+ (void)setFontDirectory:(NSString*)fontDirectoryPath with:(NSDictionary*)fontNameMapping {}
+ (void)setFontDirectoryList:(NSArray*)fontDirectoryList with:(NSDictionary*)fontNameMapping {}
+ (void)setEnvironmentVariable:(NSString*)variableName value:(NSString*)variableValue {}
+ (void)ignoreSignal:(Signal)signal {}
+ (int)messagesInTransmit:(long)sessionId { return 0; }
+ (NSString*)getFFmpegVersion { return @"stub"; }
+ (BOOL)isLTSBuild { return NO; }
+ (NSString*)getBuildDate { return @"stub"; }
+ (NSString*)getVersion { return @"stub"; }
+ (NSString*)registerNewFFmpegPipe { return @""; }
+ (void)closeFFmpegPipe:(NSString*)ffmpegPipePath {}
+ (NSArray*)parseArguments:(NSString*)command { return @[]; }
+ (NSString*)argumentsToString:(NSArray*)arguments { return @""; }
+ (NSString*)sessionStateToString:(SessionState)state { return @""; }
+ (void)cancelSession:(long)sessionId {}
+ (NSString*)writeToPipe:(NSString*)inputPath onPipe:(NSString*)pipePath { return @""; }
+ (NSString*)selectDocumentForRead:(NSString*)type extra:(NSArray*)extraTypes { return @""; }
+ (NSString*)selectDocumentForWrite:(NSString*)title type:(NSString*)type extra:(NSArray*)extraTypes { return @""; }
+ (NSString*)getSafParameter:(NSString*)path openMode:(NSString*)mode { return @""; }
+ (NSString*)getPlatform { return @"macos"; }
@end

@implementation FFmpegKit
+ (FFmpegSession*)execute:(NSString*)command { return nil; }
+ (void)cancel {}
+ (void)cancel:(long)sessionId {}
+ (NSArray*)listSessions { return @[]; }
@end

@implementation FFprobeKit
+ (FFprobeSession*)execute:(NSString*)command { return nil; }
+ (MediaInformationSession*)getMediaInformation:(NSString*)path { return nil; }
+ (NSArray*)listFFprobeSessions { return @[]; }
+ (NSArray*)listMediaInformationSessions { return @[]; }
@end
