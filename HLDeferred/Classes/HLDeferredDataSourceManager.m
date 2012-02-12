//
//  HLDeferredDataSourceManager.m
//  HLDeferred
//
//  Created by Jim Roepcke on 11-07-10.
//  Copyright 2011 Jim Roepcke. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

// This code is based on NetworkManager from MVCNetworking sample

#import "HLDeferredDataSourceManager.h"
#import "HLDeferredDataSource.h"
#import "HLDeferredConcurrentDataSource.h"

@interface HLDeferredDataSourceManager ()

// private properties

@property (nonatomic, readonly, strong ) NSThread *networkRunLoopThread;
@property (nonatomic, readonly, strong ) NSOperationQueue *queueForNetworkTransfers;

@end

@implementation HLDeferredDataSourceManager

@synthesize networkRunLoopThread=_networkRunLoopThread;
@synthesize queueForNetworkTransfers=_queueForNetworkTransfers;

- (id) initWithRunLoopThreadName: (NSString *)name
{
    self = [super init];
    if (self) {

        // Create the network transfer queue.  We will run up to 4 simultaneous network requests.

        _queueForNetworkTransfers = [[NSOperationQueue alloc] init];
        assert(_queueForNetworkTransfers != nil);

        [_queueForNetworkTransfers setMaxConcurrentOperationCount: 4];
        assert(_queueForNetworkTransfers != nil);

        // We run all of our network callbacks on a secondary thread to ensure that they don't 
        // contribute to main thread latency.  Create and configure that thread.

        // this retains self, so now we have a retain loop. fantastic
        _networkRunLoopThreadContinue = YES;
        _networkRunLoopThread = [[NSThread alloc] initWithTarget: self
                                                        selector: @selector(networkRunLoopThreadEntry)
                                                          object: nil];
        assert(_networkRunLoopThread != nil);

        [_networkRunLoopThread setName: name];
        if ( [_networkRunLoopThread respondsToSelector: @selector(setThreadPriority)] ) {
            [_networkRunLoopThread setThreadPriority: 0.3];
        }

        [_networkRunLoopThread start];
    }
    return self;
}

- (void) dealloc
{
    // this cannot run until the _networkRunLoopThread is terminated
    // because it retains self
    [_queueForNetworkTransfers cancelAllOperations];
}

- (void) stop: (HLVoidBlock)completion
{
    HLVoidBlock completionBlock = (HLVoidBlock)[completion copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_queueForNetworkTransfers cancelAllOperations];
        [_queueForNetworkTransfers waitUntilAllOperationsAreFinished];
        [self performSelector: @selector(networkRunLoopThreadStopper)
                     onThread: _networkRunLoopThread
                   withObject: nil
                waitUntilDone: YES];
        completionBlock();
    });
}

// this gets the run loop to run so that the _networkRunLoopThread's
// -[[NSRunLoop currentRunLoop] runMode:beforeDate:]  finishes
// and the thread can exit
- (void) networkRunLoopThreadStopper {
    _networkRunLoopThreadContinue = NO;
}

- (void) networkRunLoopThreadEntry
{
    assert( ! [NSThread isMainThread] );
    while (_networkRunLoopThreadContinue) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
        }
    }
}

- (BOOL) networkInUse
{
    assert([NSThread isMainThread]);
    return _runningNetworkTransferCount != 0;
}

- (void) incrementRunningNetworkTransferCount
{
    assert([NSThread isMainThread]);

    BOOL movingToInUse = (_runningNetworkTransferCount == 0);

    if (movingToInUse) [self willChangeValueForKey: @"networkInUse"];
    _runningNetworkTransferCount += 1;
    if (movingToInUse) [self  didChangeValueForKey: @"networkInUse"];
}

- (void) decrementRunningNetworkTransferCount
{
    assert([NSThread isMainThread]);

    assert(_runningNetworkTransferCount != 0);
    BOOL movingToNotInUse = (_runningNetworkTransferCount == 1);
    if (movingToNotInUse) [self willChangeValueForKey: @"networkInUse"];
    _runningNetworkTransferCount -= 1;
    if (movingToNotInUse) [self  didChangeValueForKey: @"networkInUse"];
}

- (HLDeferred *) requestStartNetworkTransferDataSource: (HLDeferredDataSource *)ds
{
    if ([ds respondsToSelector: @selector(setRunLoopThread:)]) {
        // this is a concurrent data source, give it a runLoopThread
        // this keeps network processing off the main thread which
        // improves UI responsiveness
        [(id)ds setRunLoopThread: [self networkRunLoopThread]];
    }
    HLDeferred *result = [ds requestStartOnQueue: [self queueForNetworkTransfers]];
    [self performSelectorOnMainThread: @selector(incrementRunningNetworkTransferCount)
                           withObject: nil
                        waitUntilDone: NO];
    __unsafe_unretained HLDeferredDataSourceManager *blockSelf = self;
    result = [result both: ^(id result) {
        [blockSelf performSelectorOnMainThread: @selector(decrementRunningNetworkTransferCount)
                                    withObject: nil
                                 waitUntilDone: NO];
        return result;
    }];
    return result;
}

@end
