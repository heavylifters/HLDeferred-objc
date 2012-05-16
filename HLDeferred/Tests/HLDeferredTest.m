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
    __block id blockResult = nil;
    
    [d then: ^(id result) {
        success = YES;
        blockResult = [result retain];
        return result;
    }];
    
    [d takeResult: @"success"];
    GHAssertTrue(success, @"callback did not run");
    GHAssertEqualStrings(blockResult, @"success", @"unexpected callback result");
    [blockResult release];
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
    
    __block HLFailure *failed = nil;
    [d fail: ^id(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);
    
	[d release];
}

- (void) testOneErrback
{
    HLDeferred *d = [[HLDeferred alloc] init];
    __block BOOL success = NO;
    __block NSException *blockException = nil;
    
    [d fail: ^(HLFailure *failure) {
        @try {
            success = YES;
            GHAssertEqualStrings([failure value], @"success", @"unexpected errback result");
        } @catch (NSException *exception) {
            blockException = [exception retain];
        } @finally {
            return failure;
        }
    }];
    
    [d takeError: @"success"];
    GHAssertTrue(success, @"errback did not run");
    GHAssertNil([blockException autorelease], @"%@", blockException);
    
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
    
    __block id blockResult = nil;
    [d then: ^id(id result) {
        blockResult = [result retain];
        return result;
    }];
    GHAssertNil([blockResult autorelease], @"%@", blockResult);
	
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
    
    __block HLFailure *failed = nil;
    [d fail: ^id(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);

	[d release];
}

- (void) testRaisingExceptionsInCallbacks
{
    HLDeferred *d = [[HLDeferred alloc] init];
    
    __block BOOL success = NO;
    
    [d then: ^id(id result) {
        [NSException raise: @"TestException" format: @""];
        return result;
    }];
    
    [d fail: ^id(HLFailure *failure) {
        success = YES;
        return failure;
    }];
    
    [d takeResult: @"starting"];
    
    GHAssertTrue(success, @"errback should have bene called");
    
    __block id blockResult = nil;
    [d then: ^id(id result) {
        blockResult = [result retain];
        return result;
    }];
    GHAssertNil([blockResult autorelease], @"%@", blockResult);
    
    [d release];
}

- (void) testPausing
{
    HLDeferred *d1 = [[HLDeferred alloc] init];
    HLDeferred *d2 = [[HLDeferred alloc] init];
	
	__block int x = 0;
	
	[d1 then: ^id(id result) {
        GHTestLog(@"x=%d: d1 then (first) %@", x, result);
        GHAssertEquals(0, x, nil);
        x++;
        return d2;
	}];
	
	[d2 then: ^id(id result) {
        GHTestLog(@"x=%d: d2 then (first) %@", x, result);
        GHAssertEquals(1, x, nil);
        x++;
        return @"ok";
	}];
	
    [d2 then: ^id(id result) {
        GHTestLog(@"x=%d: d2 then (second) %@", x, result);
        GHAssertEquals(2, x, nil);
        GHAssertEqualStrings(@"ok", result, nil);
        x++;
        return @"d2-second";
    }];
	
    // this should not run until d2 receives takeResult:
	[d1 then: ^id(id result) {
        GHTestLog(@"x=%d: d1 then (second) %@", x, result);
        GHAssertEquals(3, x, nil);
        GHAssertEqualStrings(@"d2-second", result, nil);
        x++;
        return @"d1-second";
	}];
    
	GHAssertEquals(x, 0, nil);
	[d1 takeResult: @"starting"];
	[d2 takeResult: @"starting"];
    
    [d1 then: ^id(id result) {
        GHTestLog(@"x=%d: d1 then (third) %@", x, result);
        GHAssertEquals(4, x, nil);
        GHAssertEqualStrings(@"d1-second", result, nil);
        x++;
        return @"d1-third";
    }];
    
    [d2 then: ^id(id result) {
        GHTestLog(@"x=%d: d2 then (third) %@", x, result);
        GHAssertEquals(5, x, nil);
        GHAssertEqualStrings(@"d2-second", result, nil);
        x++;
        return @"d2-third";
    }];
    
    __block HLFailure *failed = nil;
    [d1 fail: ^(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);
    failed = nil;
    
    [d2 fail: ^(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);
    failed = nil;
    
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
    
    __block HLFailure *failed = nil;
    [d1 fail: ^id(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);
    failed = nil;

    [d2 fail: ^id(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);
    failed = nil;

    [d3 fail: ^id(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    GHAssertNil([failed autorelease], @"%@", [failed value]);

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
		success = YES;
        theFailure = [failure retain];
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
    __block NSException *blockException = nil;
    
    [d thenFinally: ^(id result) {
        @try {
            success = YES;
            GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        } @catch (NSException *exception) {
            blockException = [exception retain];
        } @finally {
            return result;
        }
    }];

    [d takeResult: @"success"];
    GHAssertTrue(success, @"callback did not run");
    GHAssertNil([blockException autorelease], @"%@", blockException);
	[d release];
}

- (void) testFinalizerOneCallback
{
    HLDeferred *d = [[HLDeferred alloc] init];
    NSMutableString *s = [[NSMutableString alloc] init];
    __block NSException *blockException = nil;
    
    [d thenFinally: ^(id result) {
        @try {
            GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        } @catch (NSException *exception) {
            blockException = [exception retain];
        } @finally {
            [s appendString: @"f"];
            return result;
        }
    }];
    [d then: ^(id result) {
        GHAssertEqualStrings(result, @"success", @"unexpected callback result");
        [s appendString: @"c"];
        return result;
    }];
    
    __block HLFailure *failed = nil;
    [d fail: ^(HLFailure *failure) {
        failed = [failure retain];
        return failure;
    }];
    
    [d takeResult: @"success"];
    GHAssertNil([blockException autorelease], @"%@", blockException);
    GHAssertTrue([s length] > 0, @"callback did not run");
    GHAssertEqualStrings(s, @"cf", @"callback should have run, then finalizer");
    GHAssertNil([failed autorelease], @"%@", [failed value]);
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
