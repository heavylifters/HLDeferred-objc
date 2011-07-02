//
//  HLJSONDataSource.m
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

#import "HLJSONDataSource.h"
#import "JSONKit.h"

@implementation HLJSONDataSource

- (void) responseFinished
{
    if ([self responseData]) {
        NSError *error = nil;
        id result = [[self responseData] objectFromJSONDataWithParseOptions: JKParseOptionStrict error: &error];
        if (result) {
            [self setResponseData: nil];
            [self setResult: result];
            [self asyncCompleteOperationResult];
        } else {
            [self setError: error];
            [self asyncCompleteOperationError];
        }
    } else {
        [super responseFinished];
    }
}

@end
