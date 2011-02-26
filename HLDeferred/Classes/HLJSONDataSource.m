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
    NSError *error = nil;
    if ([self responseData]) {
        id result = [[self responseData] objectFromJSONDataWithParseOptions: JKParseOptionStrict error: &error];
        if (!error) {
            [[self responseData] setLength: 0];
            [self setResult: result];
            [self asyncCompleteOperationResult];
            return;
        } else {
            [self setError: error];
            [self asyncCompleteOperationError];
        }
    } else {
        [self setError: @"Not Found"];
        [self asyncCompleteOperationError];
    }
}

@end
