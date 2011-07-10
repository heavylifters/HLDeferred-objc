//
//  HLDeferred.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

NSString * const kHLDeferredCancelled = @"__HLDeferredCancelled__";

@interface HLDeferred ()

@property (nonatomic, retain) id result;

- (id) _continue: (id)newResult;
- (void) _run;
- (void) _startRun: (id)aResult;

@end

@implementation HLDeferred

@synthesize result=result_;
@synthesize canceller=canceller_;
@synthesize called=called_;

+ (HLDeferred *) deferredWithResult: (id)aResult { return [[[[self alloc] init] autorelease] takeResult: aResult]; }
+ (HLDeferred *) deferredWithError:  (id)anError { return [[[[self alloc] init] autorelease] takeError:  anError]; }

- (id) initWithCanceller: (id <HLDeferredCancellable>) theCanceller
{
    self = [super init];
	if (self) {
        called_ = NO;
		suppressAlreadyCalled_ = NO;
        running_ = NO;
        result_ = nil;
        pauseCount_ = 0;
        finalized_ = NO;
        finalizer_ = nil;
        callbacks_ = [[NSMutableArray alloc] init];
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
    [finalizer_ release];
    [callbacks_ release]; callbacks_ = nil;
    
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
        [self _run];
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
        NSMutableDictionary *link = [[NSMutableDictionary alloc] initWithCapacity: 2];
        cb = [cb copy];
        eb = [eb copy];
        if (cb) [link setObject: cb forKey: @"t"];
        if (eb) [link setObject: eb forKey: @"f"];
        [callbacks_ addObject: link];
        [cb release];
        [eb release];
        [link release];
        if (called_) {
            [self _run];
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
        NSMutableDictionary *finalizer = [[NSMutableDictionary alloc] initWithCapacity: 2];
        if (aThenFinalizer) {
            aThenFinalizer = [aThenFinalizer copy];
            [finalizer setObject: aThenFinalizer forKey: @"t"];
            [aThenFinalizer release];
        }
        if (aFailFinalizer) {
            aFailFinalizer = [aFailFinalizer copy];
            [finalizer setObject: aFailFinalizer forKey: @"f"];
            [aFailFinalizer release];
        }
        finalizer_ = [[NSDictionary alloc] initWithDictionary: finalizer];
        [finalizer release];
        if (called_) {
            [self _run];
        }
    }
    return self;
}

- (HLDeferred *) takeResult: (id)aResult
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    [self _startRun: aResult];
    return self;
}

- (HLDeferred *) takeError: (id)anError
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    id err = anError;
    if (![err isKindOfClass: [HLFailure class]]) {
		err = [[[HLFailure alloc] initWithValue: anError] autorelease];
    }
    [self _startRun: err];
    return self;
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

- (void) _startRun: (id)aResult
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
    [self _run];
}

- (void) _run
{
    // NSLog(@"%@ in %@", self, NSStringFromSelector(_cmd));
    if (running_) return;
    if (pauseCount_ == 0) {
        // NSLog(@"%@ in %@, not paused", self, NSStringFromSelector(_cmd));
        NSDictionary *link;
        while ([callbacks_ count] > 0) {
            // NSLog(@"%@ in %@, running callback", self, NSStringFromSelector(_cmd));
            @try {
                link = [[callbacks_ objectAtIndex: 0] retain];
                [callbacks_ removeObjectAtIndex: 0];
                running_ = YES;
                @try {
                    if ([result_ isKindOfClass: [HLFailure class]]) {
                        FailBlock failBlock = [link objectForKey: @"f"];
                        // NSLog(@"%@ in %@, calling failBlock", self, NSStringFromSelector(_cmd));
                        // NSLog(@"HLDeferred: calling errback, result: '%@'", result_);
                        [self setResult: failBlock ? failBlock((HLFailure *)result_) : result_];
                    } else {
                        ThenBlock thenBlock = [link objectForKey: @"t"];
                        // NSLog(@"%@ in %@, calling thenBlock", self, NSStringFromSelector(_cmd));
                        [self setResult: thenBlock ? thenBlock(result_) : result_];
                    }
                } @finally {
                    // NSLog(@"%@ in %@, running=NO", self, NSStringFromSelector(_cmd));
                    running_ = NO;
                }
                if ([result_ isKindOfClass: [HLDeferred class]]) {
                    // NSLog(@"%@ in %@, result is HLDeferred, pausing", self, NSStringFromSelector(_cmd));
                    // CPLog("callback result is another HLDeferred, pausing: " + self);
                    [self pause];
                    [result_ then: ^(id result) { return [self _continue: result]; }
                             fail: ^(HLFailure *failure) { return [self _continue: failure]; }];
                    break;
                }
            } @catch (NSException *e) {
                // NSLog(@"%@ in %@, caught exception: %@", self, NSStringFromSelector(_cmd), e);
				[self setResult: [HLFailure wrap: e]];
            } @finally {
                [link release];
            }
        }
        if (finalizer_ && (pauseCount_ == 0)) {
            [callbacks_ addObject: finalizer_];
            [finalizer_ release]; finalizer_ = nil;
            finalized_ = YES;
            [self _run];
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
