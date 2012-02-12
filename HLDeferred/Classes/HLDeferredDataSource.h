//
//  HLDeferredDataSource.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

// Subclassing note:

// DO NOT OVERRIDE -start OR -main unless you're SURE it's okay.
// HLDeferredDataSource and HLDeferredConcurrentDataSource are
// designed to do the right thing if you override -execute.

@interface HLDeferredDataSource : NSOperation <HLDeferredCancellable>
{
    id error_;
    id result_;
    HLDeferred *deferred_;  
    NSThread *callingThread_;
}

// the deferred will receive its result on this thread
// the thread must be running its run loop
// it will be set to [NSThread currentThread] when
// -requestStartOnQueue: is called, iff it is nil.
@property (strong) NSThread *callingThread;

@property (strong) id result;
@property (strong) id error;

- (NSThread *) actualCallingThread;
- (BOOL) isActualCallingThread;

#pragma mark -
#pragma mark HLDeferred support

// This NSOperation will be added to and retained by the queue, so it is
// safe to release this operation after calling this method.
// Note: the returned HLDeferred is retained by this operation, so you
// are not required to retain the returned HLDeferred to ensure it and its
// callbacks survive until the operation is complete.
//
// Note that this method returns an HLDeferred and the name of the method
// starts with "request". This is a coding convention we suggest you follow:
// "The name of methods returning (HLDeferred *) should start with request"
- (HLDeferred *) requestStartOnQueue: (NSOperationQueue *)queue;

// sends -takeResult: to the HLDeferred, on the main thread using dispatch_async
// the result is from [self result], so call -setResult: before you call this
- (void) asyncCompleteOperationResult;

// sends -takeError: to the HLDeferred, on the main thread using dispatch_async
// the error is from [self error], so call -setError: before you call this
- (void) asyncCompleteOperationError;

#pragma mark -
#pragma mark Template methods for subclasses

// Override this and do what you need to do.
// The default implementation does nothing.
// Your execute method should:
// - call -setResult: then -asyncCompleteOperationResult
// or
// - call -setError: then -asyncCompleteOperationError
// DO NOT CALL THIS YOURSELF
- (void) execute;

// Optionally override this
// Called after the HLDeferred's callback chain has run.
// DO NOT CALL THIS YOURSELF except to call super, which
// you MUST do if you override this
- (void) markOperationCompleted;

@end
