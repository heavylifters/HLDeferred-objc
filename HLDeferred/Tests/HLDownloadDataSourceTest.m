//
//  HLDownloadDataSourceTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDownloadDataSource.h"

@interface HLDownloadDataSourceTest : GHAsyncTestCase
@end

static NSString *path;

@implementation HLDownloadDataSourceTest

- (void) setUpClass
{
	path = [[NSTemporaryDirectory() stringByAppendingPathComponent: @"test"] retain];
}

- (void) tearDownClass
{
	[path release]; path = nil;
}

- (void) setUp
{
	[[NSFileManager defaultManager] removeItemAtPath: path error: NULL];
}

- (void) testSimple
{
	[self prepare];

	HLDownloadDataSource *ds = [[HLDownloadDataSource alloc] initWithSourceURL: [NSURL URLWithString: @"http://www.google.com/"]
															   destinationPath: path];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertTrue([result isKindOfClass: [NSString class]], @"expected NSData");
		GHAssertEqualStrings(result, path, nil);
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
	
	HLDownloadDataSource *ds = [[HLDownloadDataSource alloc] initWithSourceURL: [NSURL URLWithString: @"random-!-string://foo/bar"]
															   destinationPath: path];
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
	
	HLDownloadDataSource *ds = [[HLDownloadDataSource alloc] initWithSourceURL: [NSURL URLWithString: @"http://google.com/asdfasdfasdf"]
															   destinationPath: path];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	[ds release]; ds = nil;
	
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
}

@end
