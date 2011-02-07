//
//  HLDeferredConcurrentDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredConcurrentDataSource.h"

@implementation HLDeferredConcurrentDataSource

- (id) init
{
    self = [super init];
    if (self != nil) {
        executing_ = NO;
        finished_ = NO;
    }
    return self;
}

// override this method to perform work
- (void) execute
{
	[super execute];
}

#pragma mark -
#pragma mark HLDeferred support

- (void) markOperationCompleted
{
    [self willChangeValueForKey: @"isFinished"];
    [self willChangeValueForKey: @"isExecuting"];
    
    executing_ = NO;
    finished_ = YES;
    
    [self didChangeValueForKey: @"isExecuting"];
    [self didChangeValueForKey: @"isFinished"];
}

#pragma mark -
#pragma mark Concurrent NSOperation support

- (BOOL) isConcurrent { return YES; }
- (BOOL) isExecuting { return executing_; }
- (BOOL) isFinished  { return finished_; }

// DO NOT OVERRIDE THIS METHOD
// override -execute instead
- (void) start
{
    if ([self isCancelled]) {
        [self willChangeValueForKey: @"isFinished"];
        finished_ = YES;
        [self didChangeValueForKey: @"isFinished"];
    } else {
        [self main];
    }
}

// DO NOT OVERRIDE THIS METHOD
// override -execute instead
- (void) main
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self willChangeValueForKey: @"isExecuting"];
		NSException *thrown = nil;
		@try {
			[self execute];
		} @catch (NSException *e) {
			thrown = e;
		}
		executing_ = YES;
        [self didChangeValueForKey: @"isExecuting"];
		// this is down here after didChangeValueForKey because
		// we don't want to call asyncCompleteOperationError
		// before didChangeValueForKey, because
		// asyncCompleteOperationError calls markOperationCompleted
		// which does its own will/didChangeValueForKey for isExecuting
		if (thrown) {
			[self setError: thrown];
			[self asyncCompleteOperationError];
		}
    });
}

- (void) deferredWillCancel: (HLDeferred *)d
{
    [self willChangeValueForKey: @"isFinished"];
    [self willChangeValueForKey: @"isExecuting"];
    
    executing_ = NO;
    finished_ = YES;
    
    [self didChangeValueForKey: @"isExecuting"];
    [self didChangeValueForKey: @"isFinished"];
    [super deferredWillCancel: d];
}

@end
