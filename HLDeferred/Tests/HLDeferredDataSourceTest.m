//
//  HLDeferredDataSourceTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredDataSource.h"

@interface HLDeferredDataSourceTestDataSource : HLDeferredDataSource
{
	BOOL success;
}

- (BOOL) succeeded;

@end

@interface HLDeferredDataSourceTest : GHAsyncTestCase
@end

@implementation HLDeferredDataSourceTest

- (void) testStart
{
	[self prepare];
	
	HLDeferredDataSourceTestDataSource *ds = [[HLDeferredDataSourceTestDataSource alloc] init];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertEqualStrings(@"ok", result, @"unexpected result");
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testStart)];
		return result;
	}];
	
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue([ds succeeded], @"data source wasn't executed");
	GHAssertTrue(success, @"callback didn't run");
    [ds release]; ds = nil;
}

@end

@implementation HLDeferredDataSourceTestDataSource

- (id) init
{
	self = [super init];
	return self;
}

- (void) execute
{
	success = YES;
	[self setResult: @"ok"];
	[self asyncCompleteOperationResult];
}

- (BOOL) succeeded
{
	return success;
}

@end
