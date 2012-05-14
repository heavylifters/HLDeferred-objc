//
//  HLDeferredConcurrentDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredConcurrentDataSource.h"

@implementation HLDeferredConcurrentDataSource

@synthesize runLoopThread=runLoopThread_;
@synthesize runLoopModes=runLoopModes_;

- (id) init
{
    self = [super init];
    if (self != nil) {
        executing_ = NO;
        finished_ = NO;
    }
    return self;
}


- (NSThread *) actualRunLoopThread
{
    NSThread *result = [self runLoopThread];
    if (result == nil) result = [NSThread mainThread];
    return result;
}

- (BOOL) isActualRunLoopThread
{
    return [[NSThread currentThread] isEqual: [self actualRunLoopThread]];
}

- (NSSet *) actualRunLoopModes
{
    NSSet * result = [self runLoopModes];
    if ( (result == nil) || ([result count] == 0) ) {
        result = [NSSet setWithObject: NSDefaultRunLoopMode];
    }
    return result;
}

#pragma mark -
#pragma mark HLDeferred support

// called on the callingThread
- (void) markOperationCompleted
{
    assert([self isActualCallingThread]);
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
// called on the queue's thread
- (void) start
{
    if ([self isCancelled]) {
        [self willChangeValueForKey: @"isFinished"];
        finished_ = YES;
        [self didChangeValueForKey: @"isFinished"];
        [self setError: kHLDeferredCancelled];
        [self asyncCompleteOperationError];
    } else {
        [self main];
    }
}

// DO NOT OVERRIDE THIS METHOD
// override -execute instead
// called on the queue's thread
- (void) main
{
    [self willChangeValueForKey: @"isExecuting"];
    executing_ = YES;
    [self didChangeValueForKey: @"isExecuting"];
    
    [self performSelector: @selector(executeOnRunLoopThread)
                 onThread: [self actualRunLoopThread]
               withObject: nil
            waitUntilDone: NO
                    modes: [[self actualRunLoopModes] allObjects]];
}

- (void) executeOnRunLoopThread
{
    assert([self isActualRunLoopThread]);
    NSException *thrown = nil;
    @try {
        [self execute];
    } @catch (NSException *e) {
        thrown = e;
    }
    if (thrown) {
        [self setError: thrown];
        [self asyncCompleteOperationError];
    }
}

// override this method to perform work
// called on the queue's thread
- (void) execute
{
	[super execute];
}

#pragma mark -
#pragma mark HLDeferred support

// NO NOT OVERRIDE THIS
// override cancelOnRunLoopThread instead
- (void) cancel
{
    // THIS IS SYNCHRONOUS
    [self performSelector: @selector(cancelOnRunLoopThread)
                 onThread: [self actualRunLoopThread]
               withObject: nil
            waitUntilDone: YES // <--- SYNCHRONOUS
                    modes: [[self actualRunLoopModes] allObjects]];
}

- (void) cancelOnRunLoopThread
{
    assert([self isActualRunLoopThread]);
    [super cancel];
}

@end
