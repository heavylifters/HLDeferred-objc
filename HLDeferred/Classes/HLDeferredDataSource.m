//
//  HLDeferredDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredDataSource.h"

@implementation HLDeferredDataSource

@synthesize callingThread=callingThread_;
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
    [deferred_ setCanceller: nil];
     deferred_ = nil;
}

- (NSThread *) actualCallingThread
{
    NSThread *result = [self callingThread];
    if (result == nil) result = [NSThread mainThread];
    return result;
}

- (BOOL) isActualCallingThread
{
    return ([self callingThread] == nil) || [[NSThread currentThread] isEqual: [self actualCallingThread]];
}

- (HLDeferred *) requestStartOnQueue: (NSOperationQueue *)queue
{
    @synchronized (self) {
        // setting callingThread before requestStartOnQueue
        // lets you choose the thread that the result
        // will be delivered on
        if ([self callingThread] == nil) {
            [self setCallingThread: [NSThread currentThread]];
        }
        [queue addOperation: self];
        return deferred_;
    }
}

// DO NOT OVERRIDE THIS METHOD
// DO NOT OVERRIDE -start EITHER
// override -execute instead
// called on the queue's thread
- (void) main
{
	@try {
		[self execute];
	} @catch (NSException * e) {
		[self setError: e];
		[self asyncCompleteOperationError];
	}
}

// override this method in your subclass to perform work
// called on the queue's thread
- (void) execute {}

#pragma mark -
#pragma mark Completing the data source's operation

- (void) cancel
{
	[super cancel];
    if ([self isExecuting]) {
        [self setError: kHLDeferredCancelled];
        [self asyncCompleteOperationError];
    }
}

// overridden by HLDeferredConcurrentDataSource
// called on the callingThread
- (void) markOperationCompleted {}

- (void) asyncCompleteOperationResult
{
    [self performSelector: @selector(asyncCompleteOperationResultOnCallingThread)
                 onThread: [self actualCallingThread]
               withObject: nil
            waitUntilDone: NO];
}

- (void) asyncCompleteOperationResultOnCallingThread
{
    assert([self isActualCallingThread]);
    [deferred_ takeResult: result_];
    [self markOperationCompleted];
}

- (void) asyncCompleteOperationError
{
    [self performSelector: @selector(asyncCompleteOperationErrorOnCallingThread)
                 onThread: [self actualCallingThread]
               withObject: nil
            waitUntilDone: NO];
}

- (void) asyncCompleteOperationErrorOnCallingThread
{
    assert([self isActualCallingThread]);
    [deferred_ takeError: error_];
    [self markOperationCompleted];
}

- (void) deferredWillCancel: (HLDeferred *)d
{
    [self cancel];
}

@end
