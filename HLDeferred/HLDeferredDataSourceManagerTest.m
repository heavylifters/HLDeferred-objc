//
//  HLDeferredDataSourceManagerTest.m
//  HLDeferred
//
//  Created by Jim Roepcke on 11-07-19.
//  Copyright 2011 Jim Roepcke. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLURLDataSource.h"
#import "HLDeferredDataSourceManager.h"

@interface HLDeferredDataSourceManagerTest : GHAsyncTestCase
@end

@implementation HLDeferredDataSourceManagerTest

- (void) testRequestStartNetworkTransferDataSource
{
    [self prepare];

    HLDeferredDataSourceManager *mgr = [[HLDeferredDataSourceManager alloc]
                                        initWithRunLoopThreadName:
                                        @"testRequestStartNetworkTransferDataSource"];
    GHAssertNotNil(mgr, nil);

    HLURLDataSource *ds = [[HLURLDataSource alloc] initWithURLString: @"http://www.google.com/"];
    [ds setCallingThread: [NSThread mainThread]];
    GHAssertNotNil(ds, nil);

    HLDeferred *d = [mgr requestStartNetworkTransferDataSource: ds];
    GHAssertNotNil(d, nil);

	__block BOOL success = NO;
	__block id theResult = nil;
    __block NSThread *theThread = nil;
	[d then: ^(id result) {
		success = YES;
        theThread = [[NSThread currentThread] retain];
        theResult = [result retain];
		[self notify: kGHUnitWaitStatusSuccess forSelector: @selector(testRequestStartNetworkTransferDataSource)];
		return result;
	}];

	[self waitForStatus: kGHUnitWaitStatusSuccess timeout: 10.0];
	GHAssertTrue(success, @"callback didn't run");
    GHAssertEquals(theThread, [NSThread mainThread], nil);
    GHAssertNotNil(theResult, nil);
    [theResult release]; theResult = nil;
    [theThread release]; theThread = nil;
    d = nil;

    [self prepare];
    [mgr stop: ^{
        [self notify: kGHUnitWaitStatusSuccess
         forSelector: @selector(testRequestStartNetworkTransferDataSource)];
    }];
    [self waitForStatus: kGHUnitWaitStatusSuccess timeout: 10.0];
    [ds release]; ds = nil;
    [mgr release]; mgr = nil;
}

- (void) testStop
{
    [self prepare];
    
    HLDeferredDataSourceManager *mgr = [[HLDeferredDataSourceManager alloc]
                                        initWithRunLoopThreadName:
                                        @"testStop"];
    GHAssertNotNil(mgr, nil);
    
    [mgr stop: ^{
        [self notify: kGHUnitWaitStatusSuccess
         forSelector: @selector(testStop)];
    }];
    [self waitForStatus: kGHUnitWaitStatusSuccess timeout: 10.0];
    [mgr release]; mgr = nil;
}

@end
