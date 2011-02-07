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
}

#pragma mark -
#pragma mark Template methods for subclasses

// -main will run on the main thread via dispatch_async
- (void) execute;

@end
