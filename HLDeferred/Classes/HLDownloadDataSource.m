//
//  HLDownloadDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDownloadDataSource.h"


@implementation HLDownloadDataSource

- (id) initWithSourceURL: (NSURL *)sourceURL destinationPath: (NSString *)destinationPath
{
    self = [super initWithContext: [NSDictionary dictionaryWithObjectsAndKeys:
                                    sourceURL, @"sourceURL",
                                    destinationPath, @"destinationPath",
                                    nil]];
    if (self) {
        fileHandle_ = nil;
    }
    return self;
}

- (void) dealloc
{
     fileHandle_ = nil;
}

#pragma mark -
#pragma mark Private API

- (NSURL *) sourceURL
{
    return [[self context] objectForKey: @"sourceURL"];
}

- (NSString *) destinationPath
{
    return [[self context] objectForKey: @"destinationPath"];
}

#pragma mark -
#pragma mark Public API: template methods

- (NSMutableURLRequest *) urlRequest
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [self sourceURL]
                                                           cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval: 240.0];
    [request setHTTPMethod: @"GET"];
    [request setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    NSString *lastModified = [[self context] objectForKey: @"requestIfModifiedSince"];
    if (lastModified) [request setValue: lastModified forHTTPHeaderField: @"If-Modified-Since"];
    return request;
}

- (void) execute
{
    if ([[NSFileManager defaultManager] fileExistsAtPath: [self destinationPath]]) {
        [self setResult: [self destinationPath]];
        [self asyncCompleteOperationResult];
    } else {
        [super execute];
    }
}

- (BOOL) responseBegan
{
    if ([super responseBegan]) {
        [self setResponseData: nil];
        if ([[NSFileManager defaultManager] createFileAtPath: [self destinationPath]
                                                    contents: [NSData data]
                                                  attributes: nil]) {
            fileHandle_ = [NSFileHandle fileHandleForWritingAtPath: [self destinationPath]];
            return YES;
        }
    }
    return NO;
}

- (void) responseReceivedData: (NSData *)data
{
    if (fileHandle_) {
        [fileHandle_ writeData: data];
    }
}

- (void) responseFinished
{
    if (fileHandle_) {
         fileHandle_ = nil;
        [self setResult: [self destinationPath]];
    }
	[super responseFinished];
}

#pragma mark -
#pragma mark NSOperation support

- (void) cancelOnRunLoopThread
{
    if (fileHandle_) {
         fileHandle_ = nil;
        [[NSFileManager defaultManager] removeItemAtPath: [self destinationPath]
                                                   error: NULL];
    }
    [super cancelOnRunLoopThread];
}

@end
