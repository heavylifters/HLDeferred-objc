//
//  HLURLDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLURLDataSource.h"

@implementation HLURLDataSource

@synthesize context=context_;
@synthesize responseData=responseData_;

- (id) initWithContext: (NSDictionary *)aContext
{
    self = [super init];
    if (self) {
        conn_ = nil;
        response_ = nil;
        responseData_ = nil;
        context_ = [aContext retain];
    }
    return self;
}

- (id) initWithURL: (NSURL *)url
{
	self = [self initWithContext: [NSDictionary dictionaryWithObject: url forKey: @"requestURL"]];
	return self;
}

- (id) initWithURLString: (NSString *)urlString
{
	self = [self initWithContext: [NSDictionary dictionaryWithObject: urlString forKey: @"requestURL"]];
	return self;
}

- (void) dealloc
{
    [conn_ release]; conn_ = nil;
    [response_ release]; response_ = nil;
    [responseData_ release]; responseData_ = nil;
    [context_ release]; context_ = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Public API: template methods, override these to customize behaviour

- (NSMutableURLRequest *) urlRequest
{
    NSMutableURLRequest *result = nil;
    id requestURL = [context_ objectForKey: @"requestURL"];
    if (requestURL) {
        if ([requestURL isKindOfClass: [NSString class]]) {
            requestURL = [NSURL URLWithString: requestURL];
        }
        result = [NSMutableURLRequest requestWithURL: requestURL
                                         cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval: 240.0];
        // allow response to be gzip compressed
        [result setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
        NSString *requestMethod = [context_ objectForKey: @"requestMethod"];
        [result setHTTPMethod: requestMethod ? requestMethod : @"GET"];
        NSData *requestBody = [context_ objectForKey: @"requestBody"];
        if (requestBody) [result setHTTPBody: requestBody];
        NSString *requestBodyContentType = [context_ objectForKey: @"requestBodyContentType"];
        if (requestBodyContentType) [result setValue: requestBodyContentType forHTTPHeaderField: @"content-type"];
        NSString *lastModified = [context_ objectForKey: @"requestIfModifiedSince"];
		if (lastModified) [result setValue: lastModified forHTTPHeaderField: @"If-Modified-Since"];
    }
    return result;
}

- (void) execute
{
	[conn_ release];
    conn_ = [[NSURLConnection alloc] initWithRequest: [self urlRequest]
                                            delegate: self];
}

- (void) deferredWillCancel: (HLDeferred *)d
{
    [conn_ cancel];
    [super deferredWillCancel: d];
}

- (void) responseFailed
{
    [self asyncCompleteOperationError];
}

- (BOOL) responseBegan
{
    BOOL result = NO;
    if ([response_ isKindOfClass: [NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response_;
		NSInteger statusCode = [httpResponse statusCode];
        if ((statusCode >= 200) && (statusCode < 300)) {
			[responseData_ release];
            responseData_ = [[NSMutableData alloc] init]; // YAY!
            result = YES;
        }
    } else {
		[responseData_ release];
        responseData_ = [[NSMutableData alloc] init]; // YAY!
        result = YES;
    }
    return result;
}

- (void) responseReceivedData: (NSData *)data
{
    if (responseData_) {
        [responseData_ appendData: data];
    }
}

- (void) responseFinished
{
	[self asyncCompleteOperationResult];
}

#pragma mark -
#pragma mark Private API

- (void) connection: (NSURLConnection *)connection didFailWithError: (id)anError
{
    [self setError: anError];
    [self responseFailed];
}

- (void) connection: (NSURLConnection *)connection didReceiveResponse: (NSURLResponse *)aResponse
{
	[response_ release];
    response_ = [aResponse retain];
    [self responseBegan];
}

- (void) connection: (NSURLConnection *)connection didReceiveData: (NSData *)data
{
    [self responseReceivedData: data];
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
    [self setResult: responseData_];
    [self responseFinished];
}

#pragma mark -
#pragma mark Public API

- (NSString *) responseHeaderValueForKey: (NSString *)key
{
    if ([response_ isKindOfClass: [NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response_;
        return [[r allHeaderFields] objectForKey: key];
    }
    return nil;
}

- (NSInteger) responseStatusCode
{
    NSInteger result = 0;
    if ([response_ isKindOfClass: [NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response_;
        result = [httpResponse statusCode];
    }
    return result;
}

@end
