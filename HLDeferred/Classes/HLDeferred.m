//
//  HLDeferred.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

NSString * const kHLDeferredCancelled = @"__HLDeferredCancelled__";
NSString * const kHLDeferredNoResult = @"__HLDeferredNoResult__";

@interface HLLink : NSObject
{
    ThenBlock _thenBlock;
    FailBlock _failBlock;
    id _result;
}

@property (nonatomic, copy) ThenBlock thenBlock;
@property (nonatomic, copy) FailBlock failBlock;
@property (nonatomic, retain) id result;

- (id) initWithThenBlock: (ThenBlock)cb_ failBlock: (FailBlock)fb_;

- (id) process: (id)input;

@end

@implementation HLLink

@synthesize thenBlock=_thenBlock;
@synthesize failBlock=_failBlock;
@synthesize result=_result;

- (id) initWithThenBlock: (ThenBlock)thenBlock_ failBlock: (FailBlock)failBlock_
{
    self = [super init];
    if (self) {
        _thenBlock = [thenBlock_ copy];
        _failBlock = [failBlock_ copy];
    }
    return self;
}

- (void) dealloc
{
    [_thenBlock release]; _thenBlock = nil;
    [_failBlock release]; _failBlock = nil;
    [super dealloc];
}

- (id) process: (id)input
{
    id result = input;
    if ([input isKindOfClass: [HLFailure class]]) {
        FailBlock fb = [self failBlock];
        if (fb) {
            result = fb((HLFailure *)input);
        }
    } else {
        ThenBlock tb = [self thenBlock];
        if (tb) {
            result = tb(input);
        }
    }
    return result;
}

@end

@interface HLDeferred ()

@property (nonatomic, retain) id result;
@property (nonatomic, retain) HLDeferred *chainedTo;

- (id) _continue: (id)newResult;
- (void) _runCallbacks;
- (void) _startRunCallbacks: (id)aResult;

@end

@implementation HLDeferred

@synthesize result=result_;
@synthesize canceller=canceller_;
@synthesize called=called_;
@synthesize chainedTo=chainedTo_;

+ (HLDeferred *) deferredWithResult: (id)aResult { return [[[[self alloc] init] autorelease] takeResult: aResult]; }
+ (HLDeferred *) deferredWithError:  (id)anError { return [[[[self alloc] init] autorelease] takeError:  anError]; }

+ (HLDeferred *) deferredObserving: (HLDeferred *)otherDeferred
{
    HLDeferred *result = [[[self alloc] init] autorelease];
    [otherDeferred notify: result];
    return result;
}

- (id) initWithCanceller: (id <HLDeferredCancellable>) theCanceller
{
    self = [super init];
	if (self) {
        called_ = NO;
		suppressAlreadyCalled_ = NO;
        running_ = NO;
        result_ = [kHLDeferredNoResult retain];
        pauseCount_ = 0;
        finalized_ = NO;
        finalizer_ = nil;
        chain_ = [[NSMutableArray alloc] init];
        canceller_ = theCanceller;
	}
    return self;
}

- (id) init
{
	self = [self initWithCanceller: nil];
	return self;
}

- (void) dealloc
{
    canceller_ = nil;
    [result_ release]; result_ = nil;
    [finalizer_ release]; finalizer_ = nil;
    [chain_ release]; chain_ = nil;
    [chainedTo_ release]; chainedTo_ = nil;
    [super dealloc];
}

- (void) pause
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    pauseCount_++;
}

- (void) unpause
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    pauseCount_--;
    if (pauseCount_ > 0) return;
    if (called_) {
        [self _runCallbacks];
    }
}

- (HLDeferred *) thenReturn: (id)aResult {
    return [self then: ^(id _) { return aResult; } fail: nil];
}

- (HLDeferred *) then: (ThenBlock)cb { return [self then: cb fail: nil      ]; }
- (HLDeferred *) fail: (FailBlock)eb  { return [self then: nil       fail: eb ]; }
- (HLDeferred *) both: (ThenBlock)bb { return [self then: bb fail: bb]; }

- (HLDeferred *) then: (ThenBlock)cb fail: (FailBlock)eb
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (finalized_) {
        @throw [NSException exceptionWithName: NSInternalInconsistencyException
                                 reason: @"HLDeferred has been finalized"
                               userInfo: nil];
    } else {
        HLLink *link = [[HLLink alloc] initWithThenBlock: cb failBlock: eb];
        [chain_ addObject: link];
        [link release]; link = nil;
        if (called_) {
            [self _runCallbacks];
        }
    }
    return self;
}

- (HLDeferred *) thenFinally: (ThenBlock)aThenFinalizer { return [self thenFinally: aThenFinalizer failFinally: nil           ]; }
- (HLDeferred *) failFinally: (FailBlock)aFailFinalizer { return [self thenFinally: nil            failFinally: aFailFinalizer]; }
- (HLDeferred *) bothFinally: (ThenBlock)aBothFinalizer { return [self thenFinally: aBothFinalizer failFinally: aBothFinalizer]; }

- (HLDeferred *) thenFinally: (ThenBlock)aThenFinalizer failFinally: (FailBlock)aFailFinalizer
{
    if (finalized_) {
        @throw [NSException exceptionWithName: NSInternalInconsistencyException
                                       reason: @"HLDeferred has been finalized"
                                     userInfo: nil];
    } else if (finalizer_) {
        @throw [NSException exceptionWithName: NSInternalInconsistencyException
                                       reason: @"HLDeferred already has a finalizer"
                                     userInfo: nil];
    } else {
        finalizer_ = [[HLLink alloc] initWithThenBlock: aThenFinalizer failBlock: aFailFinalizer];
        if (called_) {
            [self _runCallbacks];
        }
    }
    return self;
}

- (HLDeferred *) takeResult: (id)aResult
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    [self _startRunCallbacks: aResult];
    return self;
}

- (HLDeferred *) takeError: (id)anError
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    id err = anError;
    if (![err isKindOfClass: [HLFailure class]]) {
		err = [[[HLFailure alloc] initWithValue: anError] autorelease];
    }
    [self _startRunCallbacks: err];
    return self;
}

// this is different than chaining. The result from the other
// HLDeferred's callback chain will not affect this HLDeferred's result.
// this is useful if you cache a HLDeferred and don't want its result
// mutated by its clients. Instead, return a new HLDeferred that is
// notified by the cached HLDeferred.
// Also, check out the convenience method: +deferredObserving:
//
// return [HLDeferred deferredObserving: _cachedDeferred];
//
- (HLDeferred *) notify: (HLDeferred *)otherDeferred
{
	// NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
	return [self then: ^(id result) { [otherDeferred takeResult: result]; return result; }
                 fail: ^(HLFailure *failure) { [otherDeferred takeError: failure]; return failure; }];
}

- (void) cancel
{
	if (! called_) {
		if (canceller_) {
			[canceller_ deferredWillCancel: self];
		} else {
			suppressAlreadyCalled_ = YES;
		}
		if ( (! called_) && (canceller_ == nil) ) {
            // if there is a canceller, the canceller
            // must call [d takeError: kHLDeferredCancelled]
			[self takeError: kHLDeferredCancelled];
		}
	} else if ([result_ isKindOfClass: [HLDeferred class]]) {
		[result_ cancel];
	}
}

/*
 #pragma mark -
 #pragma mark Private API: processing machinery
 */

- (void) _startRunCallbacks: (id)aResult
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (finalized_) {
		@throw [NSException exceptionWithName: @"HLDeferredAlreadyCalledException"
									   reason: @"cannot run an HLDeferred object more than once"
									 userInfo: [NSDictionary dictionaryWithObject: self
																		   forKey: @"HLDeferred"]];
    }
    if (called_) {
		if (suppressAlreadyCalled_) {
			suppressAlreadyCalled_ = NO;
			return;
		}
		@throw [NSException exceptionWithName: @"HLDeferredAlreadyCalledException"
									   reason: @"cannot run an HLDeferred object more than once"
									 userInfo: [NSDictionary dictionaryWithObject: self
																		   forKey: @"HLDeferred"]];
    }
    called_ = YES;
    [self setResult: aResult];
    [self _runCallbacks];
}

- (void) _runCallbacks
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (running_) return;
    if (pauseCount_ == 0) {
        // NSLog(@"%@ in %@, not paused", self, NSStringFromSelector(_cmd));
        HLLink *link = nil;
        while ([chain_ count] > 0) {
            // NSLog(@"%@ in %@, running callback", self, NSStringFromSelector(_cmd));
            @try {
                link = [[chain_ objectAtIndex: 0] retain];
                [chain_ removeObjectAtIndex: 0];
                running_ = YES;
                @try {
                    [self setResult: [link process: result_]];
                } @finally {
                    running_ = NO;
                }
                if ([result_ isKindOfClass: [HLDeferred class]]) {
                    // NSLog(@"%@ in %@, result is HLDeferred, pausing", self, NSStringFromSelector(_cmd));
                    [self pause];
                    [result_ then: ^(id result) { [self _continue: result]; return result; }
                             fail: ^(HLFailure *failure) { [self _continue: failure]; return failure; }];
                    break;
                }
            } @catch (NSException *e) {
                // NSLog(@"%@ in %@, caught exception: %@", self, NSStringFromSelector(_cmd), e);
				[self setResult: [HLFailure wrap: e]];
            } @finally {
                [link release]; link = nil;
            }
        }
        if (finalizer_ && (pauseCount_ == 0)) {
            [chain_ addObject: finalizer_];
            [finalizer_ release]; finalizer_ = nil;
            finalized_ = YES;
            [self _runCallbacks];
        }
    }
    // NSLog(@"%@ in %@, done", self, NSStringFromSelector(_cmd));
}

- (id) _continue: (id)newResult
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    [self setResult: newResult];
    [self unpause];
    return result_;
}

@end
