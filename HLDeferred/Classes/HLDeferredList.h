//
//  HLDeferredList.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLDeferred.h"

@interface HLDeferredList : HLDeferred
{
    NSArray *deferreds_;
    NSMutableArray *results_;
    BOOL fireOnFirstResult_;
    BOOL fireOnFirstError_;
    BOOL consumeErrors_;
    NSUInteger finishedCount_;
	BOOL cancelDeferredsWhenCancelled_;
}

- (id) initWithDeferreds: (NSArray *)list
       fireOnFirstResult: (BOOL)flFireOnFirstResult
        fireOnFirstError: (BOOL)flFireOnFirstError
           consumeErrors: (BOOL)flConsumeErrors;

- (id) initWithDeferreds: (NSArray *)list;
- (id) initWithDeferreds: (NSArray *)list fireOnFirstResult: (BOOL)flFireOnFirstResult;
- (id) initWithDeferreds: (NSArray *)list fireOnFirstResult: (BOOL)flFireOnFirstResult consumeErrors: (BOOL)flConsumeErrors;
- (id) initWithDeferreds: (NSArray *)list fireOnFirstError: (BOOL)flFireOnFirstError;
- (id) initWithDeferreds: (NSArray *)list consumeErrors: (BOOL)flConsumeErrors;

- (HLDeferredList *) cancelDeferredsWhenCancelled;

@end
