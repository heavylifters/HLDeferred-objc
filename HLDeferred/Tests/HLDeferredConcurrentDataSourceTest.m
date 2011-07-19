//
//  HLDeferredConcurrentDataSourceTest.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferredConcurrentDataSource.h"

@interface HLDeferredConcurrentDataSourceTestDataSource : HLDeferredConcurrentDataSource
{
	BOOL success;
}

- (BOOL) succeeded;

@end

@interface HLDeferredConcurrentDataSourceTest : GHAsyncTestCase
@end

@implementation HLDeferredConcurrentDataSourceTest

- (void) testStart
{
	[self prepare];
	
	HLDeferredConcurrentDataSourceTestDataSource *ds = [[HLDeferredConcurrentDataSourceTestDataSource alloc] init];
	HLDeferred *d = [ds requestStartOnQueue: [NSOperationQueue mainQueue]];
	
	__block BOOL success = NO;
	
	[d then: ^(id result) {
		success = YES;
		GHAssertEqualStrings(@"ok", result, @"unexpected result");
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testStart)];
		return result;
	}];
	
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue([ds succeeded], @"concurrent data source wasn't executed");
	GHAssertTrue(success, @"callback didn't run");
    [ds release]; ds = nil;
}

@end

@implementation HLDeferredConcurrentDataSourceTestDataSource

- (id) init
{
	self = [super init];
	return self;
}

- (void) execute
{
	success = YES;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self setResult: @"ok"];
		[self asyncCompleteOperationResult];
	});
}

- (BOOL) succeeded
{
	return success;
}

@end
