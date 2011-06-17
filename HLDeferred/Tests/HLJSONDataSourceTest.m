//
//  HLJSONDataSourceTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLJSONDataSource.h"
#import "JSONKit.h"

@interface HLJSONDataSourceTest : GHAsyncTestCase
@end

@implementation HLJSONDataSourceTest

- (void) testEmptyStringToJSONKit
{
    NSError *error = nil;
    id result = [@"" objectFromJSONStringWithParseOptions: JKParseOptionStrict error: &error];
    GHAssertNil(result, @"expected nil back when parsing empty string");
    GHAssertNotNil(error, @"expected error when parsing empty string: %@", error);
    error = nil;
    result = [@"null" objectFromJSONStringWithParseOptions: JKParseOptionStrict error: &error];
    GHAssertNil(result, @"expected nil back when parsing \"null\"");
    // i don't really want this error, but it's not working, so i want to know if this
    // behaviour changes in the future.
    GHAssertNotNil(error, @"expected error when parsing \"null\" string: %@", error);
}

- (void) testSimple
{
	[self prepare];
	
	HLJSONDataSource *ds = [[HLJSONDataSource alloc] initWithURLString: @"http://api.twitter.com/1/statuses/public_timeline.json"];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertTrue([result isKindOfClass: [NSArray class]], @"expected NSArray");
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
	
	HLJSONDataSource *ds = [[HLJSONDataSource alloc] initWithURLString: @"http://www.google.com/"];
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
	
	HLJSONDataSource *ds = [[HLJSONDataSource alloc] initWithURLString: @"http://www.google.com/asdfasdfasdf"];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
	__block BOOL success = NO;
	__block id theResult = nil;
    
	[d then: ^(id result) {
		success = YES;
        theResult = [result retain];
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testNotFound)];
		return result;
	} fail: ^(HLFailure *failure) {
		[self notify: kGHUnitWaitStatusFailure forSelector: @selector(testNotFound)];
		return failure;
	}];
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue(success, @"callback didn't run");	
    GHAssertNil(theResult, nil);
    [theResult release]; theResult = nil;
}

@end
