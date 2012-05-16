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
	__block NSException *blockException = nil;
    
	[d then: ^(id result) {
        @try {
            success = YES;
            GHAssertEqualStrings(@"ok", result, @"unexpected result");
            [self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testStart)];
        } @catch (NSException *exception) {
            blockException = [exception retain];
        } @finally {
            return result;
        }
	}];
	
	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 5.0];
	GHAssertTrue([ds succeeded], @"data source wasn't executed");
	GHAssertTrue(success, @"callback didn't run");
    GHAssertNil([blockException autorelease], @"%@", blockException);
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
