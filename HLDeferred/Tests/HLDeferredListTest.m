//
//  HLDeferredListTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredList.h"

@interface HLDeferredListTest : GHTestCase
@end

@interface HLDeferredListTestCanceller : NSObject <HLDeferredCancellable>
{
	BOOL success;
}

- (BOOL) succeeded;

@end

@implementation HLDeferredListTest

- (void) testAllocInitDealloc
{
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray array]];
    GHAssertNotNULL(d, nil);
	[d release];
}

- (void) testFireOnFirstResultEmptyList
{
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray array]
												fireOnFirstResult: YES];
	GHAssertFalse([d isCalled], @"empty HLDeferredList shouldn't immediately resolve if fireOnFirstResult is YES");
	[d release];
}

- (void) testFireOnFirstResultOnCreation
{
	HLDeferred *d1 = [HLDeferred deferredWithResult: @"ok"];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]
												fireOnFirstResult: YES];
	GHAssertTrue([d isCalled], @"HLDeferredList with results should immediately resolve if fireOnFirstResult is YES");
	[d release];
	// d1 is autoreleased
	[d2 release];
}

- (void) testFireOnFirstResultAfterCreation
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]
												fireOnFirstResult: YES];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeResult: @"ok"];
	GHAssertTrue([d isCalled], @"HLDeferredList should resolve with 1 result if fireOnFirstResult is YES");

	__block BOOL success = NO;
	
	[d1 then: ^(id result) {
		GHAssertEqualStrings(result, @"ok", @"first result not received");
		success = YES;
		return result;
	}];
	
	GHAssertTrue(success, @"callback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
	[d2 release];
}

- (void) testEmptyList
{
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray array]];
	GHAssertTrue([d isCalled], @"empty HLDeferredList didn't immediately resolve");
	[d release];
}

- (void) testOneResult
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, nil]];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeResult: @"ok"];
	GHAssertTrue([d isCalled], @"HLDeferredList should be resolved");
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		GHAssertEqualStrings([result objectAtIndex: 0], @"ok", @"expected result not received");
		success = YES;
		return result;
	}];
	
	GHAssertTrue(success, @"callback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
}

- (void) testOneError
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, nil]];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeError: @"ok"];
	GHAssertTrue([d isCalled], @"HLDeferredList should be resolved");
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		GHAssertEquals((int)[result count], 1, @"expected one result");
		GHAssertTrue([[result objectAtIndex: 0] isKindOfClass: [HLFailure class]], @"first result should be HLFailure");
		GHAssertEqualStrings([(HLFailure *)[result objectAtIndex: 0] value], @"ok", @"expected first result value not received");
		success = YES;
		return result;
	}];
	
	GHAssertTrue(success, @"callback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
}

- (void) testOneResultCallbackBeforeResolution
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, nil]];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");

	__block BOOL success = NO;
	
	[d then: ^(id result) {
		GHAssertEqualStrings([result objectAtIndex: 0], @"ok", @"expected result not received");
		success = YES;
		return result;
	}];
	
	[d1 takeResult: @"ok"];
	GHAssertTrue([d isCalled], @"HLDeferredList should be resolved");
	
	GHAssertTrue(success, @"callback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
}

- (void) testTwoResults
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeResult: @"ok1"];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, results incomplete");
	[d2 takeResult: @"ok2"];
	GHAssertTrue([d isCalled], @"HLDeferredList should be resolved");
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		GHAssertTrue([result isKindOfClass: [NSArray class]], @"callback result should be NSArray");
		GHAssertEquals((int)[result count], 2, @"expected two results");
		GHAssertEqualStrings([result objectAtIndex: 0], @"ok1", @"expected first result not received");
		GHAssertEqualStrings([result objectAtIndex: 1], @"ok2", @"expected second result not received");
		success = YES;
		return result;
	}];
	
	GHAssertTrue(success, @"callback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
	[d2 release];
}

- (void) testFireOnFirstErrorEmptyList
{
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray array]
												 fireOnFirstError: YES];
	GHAssertTrue([d isCalled], @"empty HLDeferredList should immediately resolve, even when fireOnFirstError is YES");
	[d release];
}

- (void) testFireOnFirstErrorOnCreation
{
	HLDeferred *d1 = [HLDeferred deferredWithError: @"ok"];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]
												fireOnFirstError: YES];
	GHAssertTrue([d isCalled], @"HLDeferredList with errors should immediately resolve if fireOnFirstError is YES");
	[d release];
	// d1 is autoreleased
	[d2 release];
}

- (void) testFireOnFirstErrorAfterCreation
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]
												fireOnFirstError: YES];
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeError: @"ok"];
	GHAssertTrue([d isCalled], @"HLDeferredList should resolve with 1 error if fireOnFirstError is YES");
	
	__block BOOL success = NO;
	
	[d1 fail: ^(HLFailure *failure) {
		GHAssertEqualStrings([failure value], @"ok", @"error not received");
		success = YES;
		return failure;
	}];
	
	GHAssertTrue(success, @"errback wasn't called on resolved HLDeferred");
	
	success = NO;
	
	[d fail: ^(HLFailure *failure) {
		GHAssertEqualStrings([failure value], @"ok", @"first error not received");
		success = YES;
		return failure;
	}];
	
	GHAssertTrue(success, @"errback wasn't called on resolved HLDeferredList");
	
	[d release];
	[d1 release];
	[d2 release];
}

- (void) testConsumeErrors
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	
    HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, nil]
													consumeErrors: YES];

	[d1 then: ^(id result) {
		GHAssertNil(result, @"callback result should be nil (consumed by HLDeferredList)");
		return result;
	} fail: ^(HLFailure *failure) {
		GHFail(@"errback was called but the error should have been consumed by the HLDeferredList");
		return failure;
	}];
	
	GHAssertFalse([d isCalled], @"HLDeferredList shouldn't immediately resolve, no results yet");
	[d1 takeError: @"ok"];
	GHAssertTrue([d1 isCalled], @"Deferred with error should resolve");
	GHAssertTrue([d isCalled], @"HLDeferredList should resolve with 1 error if fireOnFirstError is YES");

	[d then: ^(id result) {
		GHAssertTrue([result isKindOfClass: [NSArray class]], @"callback result should be NSArray");
		GHAssertEquals((int)[result count], 1, @"expected one result");
		GHAssertTrue([[result objectAtIndex: 0] isKindOfClass: [HLFailure class]], @"callback result first element should be HLFailure");
		GHAssertEqualStrings([(HLFailure *)[result objectAtIndex: 0] value], @"ok", @"expected error not received");
		return result;
	}];
	
	[d release];
	[d1 release];
}

- (void) testCancel
{
	HLDeferred *d1 = [[HLDeferred alloc] init];
	HLDeferred *d2 = [[HLDeferred alloc] init];
	HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: [NSArray arrayWithObjects: d1, d2, nil]];
	__block BOOL success = NO;
	
	[d fail: ^(HLFailure *failure) {
		success = YES;
		GHAssertEquals([failure value], kHLDeferredCancelled, @"errback should have been run with a kHLDeferredCancelled value");
		return failure;
	}];
	
	GHAssertFalse(success, @"errback run too soon");
	[d cancel];
	GHAssertTrue(success, @"errback should have run");
	
	[d release];
	[d2 release];
	[d1 release];
}

- (void) testCancelDeferredsWhenCancelled
{
	HLDeferredListTestCanceller *c1 = [[HLDeferredListTestCanceller alloc] init];
	HLDeferredListTestCanceller *c2 = [[HLDeferredListTestCanceller alloc] init];
	HLDeferred *d1 = [[HLDeferred alloc] initWithCanceller: c1];
	HLDeferred *d2 = [[HLDeferred alloc] initWithCanceller: c2];
	NSArray *list = [[NSArray alloc] initWithObjects: d1, d2, nil];
	HLDeferredList *d = [[HLDeferredList alloc] initWithDeferreds: list];
    [d cancelDeferredsWhenCancelled];
	GHAssertFalse([c1 succeeded], @"canceller 1 was called prematurely");
	GHAssertFalse([c2 succeeded], @"canceller 2 was called prematurely");

	__block BOOL success = NO;
	
	[d fail: ^(HLFailure *failure) {
		success = YES;
		GHAssertEquals([failure value], kHLDeferredCancelled, @"errback should have been run with a kHLDeferredCancelled value");
		return failure;
	}];
	
	GHAssertFalse(success, @"errback run too soon");
	[d cancel];
	GHAssertTrue(success, @"errback should have run");
	
	GHAssertTrue([c1 succeeded], @"canceller 1 was not called");
	GHAssertTrue([c2 succeeded], @"canceller 2 was not called");
	[d release];
	[d2 release];
	[d1 release];
	[c2 release];
	[c1 release];
	[list release];
}

@end

@implementation HLDeferredListTestCanceller

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
