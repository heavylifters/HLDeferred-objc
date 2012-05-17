//
//  HLDeferred.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLFailure.h"

extern NSString * const kHLDeferredCancelled;
extern NSString * const kHLDeferredNoResult;
extern NSString * const HLDeferredAlreadyCalledException;
extern NSString * const HLDeferredAlreadyFinalizedException;

typedef id (^ThenBlock)(id result);
typedef id (^FailBlock)(HLFailure *failure);
typedef void (^HLVoidBlock)(void);

@class HLDeferred;
@class HLLink;

@protocol HLDeferredCancellable <NSObject>

- (void) deferredWillCancel: (HLDeferred *)d;

@end

@interface HLDeferred : NSObject
{
    BOOL finalized_;
    BOOL called_;
	BOOL suppressAlreadyCalled_;
    BOOL runningCallbacks_;
    id result_;
    NSInteger pauseCount_;
    NSMutableArray *chain_;
    id <HLDeferredCancellable> __weak canceller_;
    HLLink *finalizer_;
    
    HLDeferred *chainedTo_;
}

@property (nonatomic, weak) id <HLDeferredCancellable> canceller;
@property (nonatomic, readonly, assign, getter=isCalled) BOOL called;

// designated initializer
- (id) initWithCanceller: (id <HLDeferredCancellable>) theCanceller;
- (id) init; // calls initWithCanceller: nil

+ (HLDeferred *) deferredWithResult: (id)result;
+ (HLDeferred *) deferredWithError:  (id)error;
+ (HLDeferred *) deferredObserving: (HLDeferred *)otherDeferred;

- (HLDeferred *) then: (ThenBlock)cb;
- (HLDeferred *) fail: (FailBlock)eb;
- (HLDeferred *) both: (ThenBlock)bb;

- (HLDeferred *) then: (ThenBlock)cb fail: (FailBlock)eb;

- (HLDeferred *) thenReturn: (id)aResult;

- (HLDeferred *) thenFinally: (ThenBlock)aThenFinalizer;
- (HLDeferred *) failFinally: (FailBlock)aFailFinalizer;
- (HLDeferred *) bothFinally: (ThenBlock)aBothFinalizer;

- (HLDeferred *) thenFinally: (ThenBlock)atThenFinalizer failFinally: (FailBlock)aFailFinalizer;

- (HLDeferred *) takeResult: (id)aResult;
- (HLDeferred *) takeError: (id)anError;
- (HLDeferred *) notify: (HLDeferred *)otherDeferred;
- (void) cancel;

@end
