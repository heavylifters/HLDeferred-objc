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

- (void) testCancel
{
	HLDeferredTestCanceller *c = [[HLDeferredTestCanceller alloc] init];
	HLDeferred *d = [[HLDeferred alloc] initWithCanceller: c];
	GHAssertEquals(c, [d canceller], @"deferred didn't remember canceller");
	GHAssertFalse([c succeeded], @"canceller was called prematurely");
	
	__block BOOL success = NO;
	
	[d fail: ^(HLFailure *failure) {
		success = YES;
		GHAssertEquals([failure value], kHLDeferredCancelled, @"errback should have been run with a kHLDeferredCancelled value");
		return failure;
	}];
	
	GHAssertFalse(success, @"errback run too soon");
	[d cancel];
	GHAssertTrue(success, @"errback should have run");
	
	GHAssertTrue([c succeeded], @"canceller was not called");
	[d release];
	[c release];
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
}

- (BOOL) succeeded
{
	return success;
}

@end
