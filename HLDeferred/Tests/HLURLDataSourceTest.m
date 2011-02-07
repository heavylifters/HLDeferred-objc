//
//  HLURLDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLURLDataSource.h"

@interface HLURLDataSourceTest : GHAsyncTestCase
@end

@implementation HLURLDataSourceTest : GHAsyncTestCase

- (void) testSimple
{
	[self prepare];
	
	HLURLDataSource *ds = [[HLURLDataSource alloc] initWithURLString: @"http://www.google.com/"];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertTrue([result isKindOfClass: [NSData class]], @"expected NSData");
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testSimple)];
		return result;
	} fail: ^(HLFailure *failure) {
		[self notify: kGHUnitWaitStatusFailure forSelector: @selector(testSimple)];
		return failure;
	}];
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue(success, @"callback didn't run");	
}

- (void) testFail
{
	[self prepare];
	
	HLURLDataSource *ds = [[HLURLDataSource alloc] initWithURLString: @"random-!-string://foo/bar"];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		[self notify: kGHUnitWaitStatusFailure forSelector: @selector(testFail)];
		return result;
	} fail: ^(HLFailure *failure) {
		success = YES;
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testFail)];
		return failure;
	}];
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue(success, @"errback didn't run");	
}

- (void) testNotFound
{
	[self prepare];
	
	HLURLDataSource *ds = [[HLURLDataSource alloc] initWithURLString: @"http://google.com/asdfasdfasdf"];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertNil(result, nil);
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testNotFound)];
		return result;
	} fail: ^(HLFailure *failure) {
		[self notify: kGHUnitWaitStatusFailure forSelector: @selector(testNotFound)];
		return failure;
	}];
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue(success, @"errback didn't run");	
	[ds release]; ds = nil;
}

@end
