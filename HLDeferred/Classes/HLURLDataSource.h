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

@property (nonatomic, retain) NSDictionary *context;
@property (nonatomic, retain) NSMutableData *responseData;

// designated initializer
- (id) initWithContext: (NSDictionary *)aContext;

// convenience initializers
- (id) initWithURL: (NSURL *)url;
- (id) initWithURLString: (NSString *)urlString;

- (NSInteger) responseStatusCode;

#pragma mark -
#pragma mark Public API: template methods, override these to customize behaviour (do NOT call directly)

- (NSURLRequest *) urlRequest;

- (BOOL) responseBegan;
- (void) responseReceivedData: (NSData *)data;
- (void) responseFinished;
- (void) responseFailed;

@end
