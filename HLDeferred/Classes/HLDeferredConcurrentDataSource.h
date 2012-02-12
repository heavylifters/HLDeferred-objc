//
//  HLDeferredConcurrentDataSource.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredDataSource.h"

@interface HLDeferredConcurrentDataSource : HLDeferredDataSource <HLDeferredCancellable>
{
    BOOL executing_;
    BOOL finished_;

    NSThread *runLoopThread_;
    NSSet *runLoopModes_;
}

@property (strong) NSThread *runLoopThread; // default is nil, implying main thread
@property (copy)   NSSet *runLoopModes; // default is nil, implying set containing NSDefaultRunLoopMode

#pragma mark -
#pragma mark Template methods for subclasses

// called on the runLoopThread
- (void) execute;

// if you override this, you MUST call super
// called on the runLoopThread
- (void) cancelOnRunLoopThread;

@end
