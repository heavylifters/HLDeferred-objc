//
//  HLDeferredTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

@interface HLDeferredTest : GHTestCase
@end

@interface HLDeferredTestCanceller : NSObject <HLDeferredCancellable>
{
	BOOL success;
}

- (BOOL) succeeded;

@end

@implementation HLDeferredTest

- (void) testAllocInitDealloc
{
    HLDeferred *d = [[HLDeferred alloc] init];
    GHAssertNotNULL(d, nil);
	[d release];
}

- (void) testOneCallback
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block BOOL success = NO;
    
    [d then: ^(id result) {
        success = YES;
        GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        return result;
    }];
    
    [d takeResult: @"success"];
    GHAssertTrue(success, @"callback did not run");
	[d release];
}

- (void) testMultipleCallbacks
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block int callbackCount = 0;
    int count = 0;
    [d then: ^(id result) {
        callbackCount++;
        GHAssertEqualStrings(result, @"starting", @"unexpected callback result");
        return @"first";
    }];
	count++;
	
	[d then: ^(id result) {
		callbackCount++;		
        GHAssertEqualStrings(result, @"first", @"unexpected callback result");
        return @"second";
	}];
	count++;
	 
	[d then: ^(id result) {
		callbackCount++;		
        GHAssertEqualStrings(result, @"second", @"unexpected callback result");
        return @"blah";
	}];
	count++;
	
    [d takeResult: @"starting"];
    GHAssertEquals(count, callbackCount, @"count doesn't equal callbackCount");
	[d release];
}

- (void) testOneErrback
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block BOOL success = NO;
    
    [d fail: ^(HLFailure *failure) {
        success = YES;
        GHAssertEqualStrings([failure value], @"success", @"unexpected errback result");
        return failure;
    }];
    
    [d takeError: @"success"];
    GHAssertTrue(success, @"errback did not run");
	[d release];
}

- (void) testMultipleErrbacks
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block int errbackCount = 0;
    int count = 0;
    [d fail: ^(HLFailure *failure) {
        errbackCount++;
        GHAssertEqualStrings([failure value], @"starting", @"unexpected callback result");
        return failure;
    }];
	count++;
	
	[d fail: ^(HLFailure *failure) {
		errbackCount++;		
        GHAssertEqualStrings([failure value], @"starting", @"unexpected callback result");
        return failure;
	}];
	count++;
	
	[d fail: ^(HLFailure *failure) {
		errbackCount++;		
        GHAssertEqualStrings([failure value], @"starting", @"unexpected callback result");
        return failure;
	}];
	count++;
	
    [d takeError: @"starting"];
    GHAssertEquals(count, errbackCount, @"count doesn't equal errbackCount");
	[d release];
}

- (void) testSwitchingBetweenCallbacksAndErrbacks
{
    HLDeferred *d = [[HLDeferred alloc] init];
    [d then: ^(id result) {
		return [HLFailure wrap: @"ok"];
    } fail: ^(HLFailure *failure) {
		GHFail(@"errback should not have been called");
		return failure;
	}];
	
    [d then: ^(id result) {
		GHFail(@"callback should not have been called");
		return result;
    } fail: ^(HLFailure *failure) {
		GHAssertEqualStrings(@"ok", [failure value], @"expected ok from previous callback");
		return @"ok";
	}];
	
    [d then: ^(id result) {
		GHAssertEqualStrings(@"ok", result, @"expected ok from previous errback");
		return result;
    } fail: ^(HLFailure *failure) {
		GHFail(@"errback should not have been called");
		return failure;
	}];
	[d release];
}

- (void) testPausing
{
    HLDeferred *d1 = [[HLDeferred alloc] init];
    HLDeferred *d2 = [[HLDeferred alloc] init];
	
	__block int x = 0;
	
	[d2 then: ^(id result) {
		x++;
		return @"ok";
	}];
	
	[d1 then: ^(id result) {
		x++;
		return d2;
	}];
	
	[d1 then: ^(id result) {
		x++;
		GHAssertEqualStrings(@"ok", result, @"expected result ok from d2");
		return result;
	}];
	
	GHAssertEquals(x, 0, @"x is not 0");
	[d1 takeResult: @"starting"];
	GHAssertEquals(x, 1, @"x is not 1");
	[d2 takeResult: @"starting"];
	GHAssertEquals(x, 3, @"x is not 3");
	[d1 release];
	[d2 release];
}

- (void) testNotifying
{
    HLDeferred *d1 = [[HLDeferred alloc] init];
    HLDeferred *d2 = [[HLDeferred alloc] init];
	
	[d1 then: ^(id result) {
		GHAssertEqualStrings(@"starting", result, nil);
		return @"d1-result";
	}];
    
    [d1 notify: d2];
	
    [d2 then: ^(id result) {
		GHAssertEqualStrings(@"d1-result", result, nil);
        return @"d2-result-after-d1-notified-d2";
    }];
    
	[d1 then: ^(id result) {
		GHAssertEqualStrings(@"d1-result", result, nil);
		return result;
	}];
    
	[d2 then: ^(id result) {
        GHAssertEqualStrings(@"d2-result-after-d1-notified-d2", result, nil);
        return result;
    }];
    
	[d1 takeResult: @"starting"];
    
    HLDeferred *d3 = [HLDeferred deferredObserving: d2];
    GHAssertNotNil(d3, nil);
    
    [d3 then:^ (id result) {
        GHAssertEqualStrings(@"d2-result-after-d1-notified-d2", result, nil);
        return result;
    }];
    
	[d1 release];
	[d2 release];
}

- (void) testCancel
{
	HLDeferredTestCanceller *c = [[HLDeferredTestCanceller alloc] init];
	HLDeferred *d = [[HLDeferred alloc] initWithCanceller: c];
	GHAssertEquals(c, [d canceller], @"deferred didn't remember canceller");
	GHAssertFalse([c succeeded], @"canceller was called prematurely");
	
	__block BOOL success = NO;
	__block HLFailure *theFailure = nil;

	[d fail: ^(HLFailure *failure) {
        theFailure = [failure retain];
		success = YES;
		return failure;
	}];

	GHAssertFalse(success, @"errback run too soon");
	[d cancel];

	GHAssertTrue(success, @"errback should have run");
    GHAssertEquals([[theFailure autorelease] value], kHLDeferredCancelled, @"errback should have been run with a kHLDeferredCancelled value");
	
	GHAssertTrue([c succeeded], @"canceller was not called");
	[d release];
	[c release];
}

- (void) testFinalizerNoCallbacks
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block BOOL success = NO;

    [d thenFinally: ^(id result) {
        GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        success = YES;
        return result;
    }];

    [d takeResult: @"success"];
    GHAssertTrue(success, @"callback did not run");
	[d release];
}

- (void) testFinalizerOneCallback
{
    HLDeferred *d = [[HLDeferred alloc] init];
    NSMutableString *s = [[NSMutableString alloc] init];

    [d thenFinally: ^(id result) {
        GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        [s appendString: @"f"];
        return result;
    }];
    [d then: ^(id result) {
        GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        [s appendString: @"c"];
        return result;
    }];
    
    [d takeResult: @"success"];
    GHAssertTrue([s length] > 0, @"callback did not run");
    GHAssertEqualStrings(s, @"cf", @"callback should have run, then finalizer");
    [s release];
	[d release];
}

- (void) testTwoFinalizersThrows
{
    HLDeferred *d = [[HLDeferred alloc] init];
    
    [d thenFinally: ^(id result) {
        return result;
    }];
    
    void (^shouldThrow)(void) = ^{
        [d thenFinally: ^(id _) { return _; }];
    };
    
    GHAssertThrows(shouldThrow(), @"should have thrown as there was already a finalizer");
    
    [d takeResult: @""];
	[d release];
}

- (void) testFinalizerAfterRunThrows
{
    HLDeferred *d = [[HLDeferred alloc] init];
    
    [d thenFinally: ^(id result) {
        return result;
    }];

    [d takeResult: @""];
    
    void (^shouldThrow)(void) = ^{
        [d thenFinally: ^(id _) { return _; }];
    };
    
    GHAssertThrows(shouldThrow(), @"should have thrown as the Deferred already ran");
    
	[d release];
}

@end

@implementation HLDeferredTestCanceller

- (id) init
{
	self = [super init];
	if (self) {
		success = NO;
	}
	return self;
}

- (void) deferredWillCancel: (HLDeferred *)d
{
	success = YES;
    [d takeError: kHLDeferredCancelled];
}

- (BOOL) succeeded
{
	return success;
}

@end
