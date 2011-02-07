//
//  HLDeferredDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredDataSource.h"

@implementation HLDeferredDataSource

@synthesize result=result_;
@synthesize error=error_;

- (id) init
{
    self = [super init];
    if (self != nil) {
        error_ = nil;
        result_ = nil;
        deferred_ = [[HLDeferred alloc] initWithCanceller: self];
    }
    return self;
}

- (void) dealloc
{
    [error_ release]; error_ = nil;
    [result_ release]; result_ = nil;
    [deferred_ setCanceller: nil];
    [deferred_ release]; deferred_ = nil;
    [super dealloc];
}

- (HLDeferred *) requestStartOnQueue: (NSOperationQueue *)queue
{
    [queue addOperation: self];
    return [[deferred_ retain] autorelease];
}

// override this method in your subclass to perform work
- (void) execute {}

// DO NOT OVERRIDE THIS METHOD
// DO NOT OVERRIDE -start EITHER
// override -execute instead
- (void) main
{
	@try {
		[self execute];
	} @catch (NSException * e) {
		[self setError: e];
		[self asyncCompleteOperationError];
	}
}

#pragma mark -
#pragma mark HLDeferred support

- (void) deferredWillCancel: (HLDeferred *)d
{
	[self cancel];
}

- (void) markOperationCompleted {}

- (void) asyncCompleteOperationResult
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [deferred_ takeResult: [[result_ retain] autorelease]];
        [self markOperationCompleted];
    });
}

- (void) asyncCompleteOperationError
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [deferred_ takeError: [[error_ retain] autorelease]];
        [self markOperationCompleted];
    });
}

@end
