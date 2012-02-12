//
//  HLURLDataSource.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredConcurrentDataSource.h"

@interface HLURLDataSource : HLDeferredConcurrentDataSource
{
    NSURLConnection *conn_;
    NSURLResponse *response_;
    NSMutableData *responseData_;
    NSDictionary *context_;
}

@property (nonatomic, strong) NSDictionary *context;
@property (nonatomic, strong) NSMutableData *responseData;

// designated initializer
- (id) initWithContext: (NSDictionary *)aContext;

// convenience initializers
- (id) initWithURL: (NSURL *)url;
- (id) initWithURLString: (NSString *)urlString;

+ (HLURLDataSource *) postToURL: (NSURL *)url
                       withBody: (NSString *)body;

- (NSString *) responseHeaderValueForKey: (NSString *)key;
- (NSInteger) responseStatusCode;

- (BOOL) entityWasOK;
- (BOOL) entityWasNotModified;
- (BOOL) entityWasNotFound;

#pragma mark -
#pragma mark Public API: template methods, override these to customize behaviour (do NOT call directly)

- (NSMutableURLRequest *) urlRequest;

- (BOOL) responseBegan;
- (void) responseReceivedData: (NSData *)data;
- (void) responseFinished;
- (void) responseFailed;

@end
