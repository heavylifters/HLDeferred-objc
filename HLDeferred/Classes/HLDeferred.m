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
NSString * const HLDeferredAlreadyCalledException = @"HLDeferredAlreadyCalledException";
NSString * const HLDeferredAlreadyFinalizedException = @"HLDeferredAlreadyFinalizedException";

@interface HLLink : NSObject
{
    ThenBlock _thenBlock;
    FailBlock _failBlock;
    id _result;
}

@property (nonatomic, copy) ThenBlock thenBlock;
@property (nonatomic, copy) FailBlock failBlock;
@property (nonatomic, strong) id result;

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
     _thenBlock = nil;
     _failBlock = nil;
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

@interface HLContinuationLink : HLLink
{
    HLDeferred *deferred_;
}

@property (nonatomic, readonly, strong) HLDeferred *deferred;

- (id) initWithDeferred: (HLDeferred *)d;

@end

@implementation HLContinuationLink

@synthesize deferred=deferred_;

- (id) initWithDeferred: (HLDeferred *)deferred
{
    self = [super initWithThenBlock: nil failBlock: nil];
    if (self) {
        deferred_ = deferred;
    }
    return self;
}

- (id) process: (id)input
{
    return input;
}

@end

@interface HLDeferred ()

@property (nonatomic, readwrite, assign, getter=isCalled) BOOL called;
@property (nonatomic, strong) id result;
@property (nonatomic, strong) HLDeferred *chainedTo;

- (void) _runCallbacks;
- (void) _startRunCallbacks: (id)aResult;

- (NSException *) _alreadyCalledException;
- (NSException *) _alreadyChainedException;
- (NSException *) _alreadyFinalizedException;
- (NSException *) _alreadyHasAFinalizerException;

@end

@implementation HLDeferred

@synthesize result=result_;
@synthesize canceller=canceller_;
@synthesize called=called_;
@synthesize chainedTo=chainedTo_;

+ (HLDeferred *) deferredWithResult: (id)aResult { return [[[self alloc] init] takeResult: aResult]; }
+ (HLDeferred *) deferredWithError:  (id)anError { return [[[self alloc] init] takeError:  anError]; }

+ (HLDeferred *) deferredObserving: (HLDeferred *)otherDeferred
{
    HLDeferred *result = [[self alloc] init];
    [otherDeferred notify: result];
    return result;
}

- (id) initWithCanceller: (id <HLDeferredCancellable>) theCanceller
{
    self = [super init];
	if (self) {
        called_ = NO;
		suppressAlreadyCalled_ = NO;
        runningCallbacks_ = NO;
        result_ = kHLDeferredNoResult;
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
     finalizer_ = nil;
     chain_ = nil;
}

- (NSString *)debugDescription
{
    NSString *superDescription = [super debugDescription];
    NSString *result = superDescription;
    NSString *extra = nil;
    if (chainedTo_) {
        extra = [NSString stringWithFormat: @" (waiting on %@ at %p)>",
                 NSStringFromClass([chainedTo_ class]), chainedTo_];
    } else if (result_ == kHLDeferredNoResult) {
        extra = @">";
    } else {
        extra = [NSString stringWithFormat: @" (result: %@)>", result_];
    }
    result = [result stringByReplacingOccurrencesOfString: @">" withString: extra];
    return result;
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
        @throw [self _alreadyFinalizedException];
    } else {
        HLLink *link = [[HLLink alloc] initWithThenBlock: cb failBlock: eb];
        [chain_ addObject: link];
        link = nil;
        if ([self isCalled]) {
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
        @throw [self _alreadyFinalizedException];
    } else if (finalizer_) {
        @throw [self _alreadyHasAFinalizerException];
    } else {
        finalizer_ = [[HLLink alloc] initWithThenBlock: aThenFinalizer failBlock: aFailFinalizer];
        if ([self isCalled]) {
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
		err = [[HLFailure alloc] initWithValue: anError];
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
    if (finalized_) {
        @throw [self _alreadyFinalizedException];
    } else {
        if ([otherDeferred isCalled]) {
            @throw [self _alreadyCalledException];
        } else if ([otherDeferred chainedTo]) {
            @throw [self _alreadyChainedException];
        } else {
            otherDeferred->pauseCount_++;
            [otherDeferred setChainedTo: self];
            HLLink *link = [[HLContinuationLink alloc] initWithDeferred: otherDeferred];
            [chain_ addObject: link];
            link = nil;
            if ([self isCalled]) {
                [self _runCallbacks];
            }
        }
    }
    return self;
}

- (void) cancel
{
	if (! [self isCalled]) {
		if (canceller_) {
			[canceller_ deferredWillCancel: self];
		} else {
			suppressAlreadyCalled_ = YES;
		}
		if ( (! [self isCalled]) && (canceller_ == nil) ) {
            // if there is a canceller, the canceller
            // must call [d takeError: kHLDeferredCancelled]
			[self takeError: kHLDeferredCancelled];
		}
	} else if ([result_ isKindOfClass: [HLDeferred class]]) {
		[result_ cancel];
	}
}

#pragma mark -
#pragma mark Private API: Exceptions

- (NSException *) _alreadyCalledException
{
    return [NSException exceptionWithName: HLDeferredAlreadyCalledException
                                   reason: @"this HLDeferred has already been called"
                                 userInfo: [NSDictionary dictionaryWithObject: self
                                                                       forKey: @"HLDeferred"]];
}

- (NSException *) _alreadyFinalizedException
{
    return [NSException exceptionWithName: HLDeferredAlreadyFinalizedException
                                   reason: @"this HLDeferred has already been finalized"
                                 userInfo: [NSDictionary dictionaryWithObject: self
                                                                       forKey: @"HLDeferred"]];
}

- (NSException *) _alreadyChainedException
{
    return [NSException exceptionWithName: NSInvalidArgumentException
                                   reason: @"this HLDeferred is already chained to another HLDeferred"
                                 userInfo: [NSDictionary dictionaryWithObject: self
                                                                       forKey: @"HLDeferred"]];
}
- (NSException *) _alreadyHasAFinalizerException
{
    return [NSException exceptionWithName: NSInternalInconsistencyException
                                   reason: @"this HLDeferred already has a finalizer"
                                 userInfo: [NSDictionary dictionaryWithObject: self
                                                                       forKey: @"HLDeferred"]];
}


#pragma mark -
#pragma mark Private API: processing machinery

- (void) _startRunCallbacks: (id)aResult
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (finalized_) {
        @throw [self _alreadyFinalizedException];
    }
    if ([self isCalled]) {
		if (suppressAlreadyCalled_) {
			suppressAlreadyCalled_ = NO;
			return;
		}
		@throw [self _alreadyCalledException];
    }
    [self setCalled: YES];
    [self setResult: aResult];
    [self _runCallbacks];
}

- (void) _runCallbacks
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (runningCallbacks_) return; // Don't recursively run callbacks
    
    // Keep track of all the HLDeferreds encountered while propagating results
    // up a chain.  The way a HLDeferred gets onto this stack is by having
    // added its _continuation() to the callbacks list of a second HLDeferred
    // and then that second HLDeferred being fired.  ie, if ever had _chainedTo
    // set to something other than nil, you might end up on this stack.
    NSMutableArray *chain = [NSMutableArray arrayWithObject: self];

    while ([chain count]) {
        HLDeferred *current = [chain lastObject];
        
        if (current->pauseCount_) {
            // This HLDeferred isn't going to produce a result at all.  All the
            // HLDeferreds up the chain waiting on it will just have to...
            // wait.
            return;
        }
        
        BOOL finished = YES;
        [current setCalled: YES];
        [current setChainedTo: nil];
        while ([current->chain_ count]) {
            HLLink *item = [current->chain_ objectAtIndex: 0];
            [current->chain_ removeObjectAtIndex: 0];
            
            if ([item isKindOfClass: [HLContinuationLink class]]) {
                // Give the waiting HLDeferred our current result and then
                // forget about that result ourselves.
                HLDeferred *chainee = [(HLContinuationLink *)item deferred];
                [chainee setResult: [current result]];
                // [current setResult: nil]; // Twisted does this, HLDeferred does NOT
                chainee->pauseCount_--;
                [chain addObject: chainee];
                // Delay popping this HLDeferred from the chain
                // until after we've dealt with chainee.
                finished = NO;
                item = nil;
                break;
            }
            
            @try {
                current->runningCallbacks_ = YES;
                @try {
                    [current setResult: [item process: [current result]]];
                } @finally {
                    current->runningCallbacks_ = NO;
                }
                if ([[current result] isKindOfClass: [HLDeferred class]]) {
                    HLDeferred *currentResult = (HLDeferred *)[current result];
                    // The result is another HLDeferred.  If it has a result,
                    // we can take it and keep going.
                    id resultResult = [currentResult result];
                    if ((resultResult == kHLDeferredNoResult) || [resultResult isKindOfClass: [HLDeferred class]] || currentResult->pauseCount_) {
                        // Nope, it didn't. Pause and chain.
                        current->pauseCount_++;
                        [current setChainedTo: currentResult];
                        // Note: currentResult has no result, so it's not
                        // running its chain_ right now.  Therefore we can
                        // append to the chain_ list directly instead of
                        // using then:fail:.
                        [currentResult->chain_ addObject: [[HLContinuationLink alloc] initWithDeferred: current]];
                        break;
                    } else {
                        // Yep, it did. Steal it.
                        [current setResult: resultResult];
                        // [currentResult setResult: nil]; // Twisted does this, HLDeferred does NOT
                    }
                }
            } @catch (NSException *exception) {
                [current setResult: [HLFailure wrap: exception]];
            } @finally {
                item = nil;
            }
        }
        if (finished) {
            if (current->finalizer_ && (current->pauseCount_ == 0)) {
                [current->chain_ addObject: current->finalizer_];
                current->finalizer_ = nil;
                current->finalized_ = YES;
                [current _runCallbacks];
            }
            [chain removeLastObject];
        }
    }
    // NSLog(@"%@ in %@, done", self, NSStringFromSelector(_cmd));
}

@end
