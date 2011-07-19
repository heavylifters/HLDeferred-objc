//
//  HLDeferredDataSourceManager.h
//  HLDeferred
//
//  Created by Jim Roepcke on 11-07-10.
//  Copyright 2011 Jim Roepcke. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

@class HLDeferredDataSource;

@interface HLDeferredDataSourceManager : NSObject
{
    BOOL _networkRunLoopThreadContinue;
    NSThread *_networkRunLoopThread;
    NSOperationQueue *_queueForNetworkTransfers;
    NSUInteger _runningNetworkTransferCount;
}

// observable, always changes on main thread
// you may only access this on the main thread
@property (nonatomic, readonly, assign) BOOL networkInUse;

- (id) initWithRunLoopThreadName: (NSString *)name;

- (HLDeferred *) requestStartNetworkTransferDataSource: (HLDeferredDataSource *)ds;

- (void) stop: (HLVoidBlock)completion;

@end
