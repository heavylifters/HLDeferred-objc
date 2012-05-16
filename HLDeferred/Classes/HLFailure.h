//
//  HLFailure.h
//  HLDeferred
//
//  Copyright 2011 HeavyLifters Network Ltd.. All rights reserved.
//  See included LICENSE file (MIT) for licensing information.
//

@interface HLFailure : NSObject
{
	id value_;
}

+ (HLFailure *) wrap: (id)v;

- (id) initWithValue: (id)v;
- (id) value;
- (NSError *) valueAsError;

@end
