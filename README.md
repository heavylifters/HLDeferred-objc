HeavyLifters Deferred Library
=============================

HLDeferred makes programming asynchronous processes with callbacks easy in Objective-C. Asynchronous data sources are scheduled on an `NSOperationQueue` and provide an [`HLDeferred`][HLD] object that accept callbacks. Callbacks are simple Objective-C blocks.

An [`HLDeferred`][HLD] object represents a result (or failure) that will become available once its data source retrieves it. This library includes support for creating data sources using concurrent or non-concurrent `NSOperation` objects, but you are not limited to this approach in any way.

HLDeferred is based on `Deferred` classes from [Twisted Python](http://twistedmatrix.com/). The Twisted pattern has been adapted to many languages and environments. HeavyLifters provides and uses implementations in Objective-C, Objective-J, JavaScript, Node.js, and Java.

Why should I use this?
----------------------

Your classes are getting bloated and convoluted because of "delegate hell" (`NSURLConnectionDelegate` and friends). You just want to fetch some data, perhaps JSON using HTTP, act on it once it's available, and know if fetching fails. Tracing your code has become a chore because processes are split across many delegate methods, or you have to maintain complicated state machines to get nested asynchronous processes to work correctly.

You wish there was an easy way do to simple things like this. There is.

Requirements
------------
- Xcode 3.2.5 with iOS 4.2 SDK (or later)
- iOS 4.x devices are supported

Note: This code would probably work on Mac OS X 10.6+, but it hasn't been tested there.

Building HLDeferred
-------------------
- Clone HLDeferred from GitHub: `git clone git://github.com/heavylifters/HLDeferred-objc.git`
- Open HLDeferred-objc/HLDeferred/HLDeferred.xcodeproj in Xcode
- Build

Using HLDeferred in your iOS app project
----------------------------------------
- Drag-and-drop the HLDeferred project icon at the top of HLDeferred's Groups & Files pane into your app project
- In your app target inspector (General tab), make your project dependent on the HLDeferred target in HLDeferred.xcodeproj
- Drag the libHLDeferred.a static library (under HLDeferred.xcodeproj in your app project) inside the "Link Binary with Libraries" section of your app target.
- Drag the "HLDeferred Headers" group from the HLDeferred project into your app project.
- import and use the HLDeferred classes in your app

Running Unit Tests
------------------
- [Download GHUnit for iOS](https://github.com/downloads/gabriel/gh-unit/GHUnitIOS-0.4.28.zip). (or [build it from source](https://github.com/gabriel/gh-unit) if you prefer)
- Copy GHUnitIOS.framework into HLDeferred-objc/HLDeferred/Frameworks.
- Build and run the Tests target in Xcode.

How it works
------------

You can create an [`HLDeferred`][HLD] object directly, but you typically request one from a data source. You get the data source's result by adding **callbacks** and/or **errbacks** to the **callback chain** of the [`HLDeferred`][HLD] object the data source provides. When the data source has the result (or determines failure), the [`HLDeferred`][HLD] object is sent a `-takeResult:` message (or `-takeError:`). At this point, the [`HLDeferred`][HLD] object's callback chain is **fired**, meaning each link in the chain (a callback or errback) is called in turn. The result is the input to the first callback, and its output is the input to the next callback (and so on).

If a callback (or errback) returns an exception, the next errback is called, otherwise the next callback is called.

![Deferred-process](https://github.com/heavylifters/HLDeferred-objc/raw/master/Documentation/images/twisted/deferred-process.png)

The Most Basic Example
----------------------

    - (void) demonstration
    {
        HLDeferred *d = [[HLDeferred alloc] init];
        NSLog(@"created HLDeferred object");
    
        // add a callback
        [d then: ^(id result) {
            NSLog(@"Hello, %@", result);
            return result;
        }];
        NSLog(@"added a callback to the HLDeferred's callback chain");
    
        // resolve the HLDeferred, which fires the callback chain
        [d takeResult: @"World"];
        NSLog(@"In the console, you should see 'Hello, World' in the line above");
    
        // Note: use [d takeError: @"DISASTER!"] to indicate failure
    }

Adding callbacks and errbacks
-----------------------------

Each **link** in a callback chain is a pair of Objective-C blocks, representing a **callback** and an **errback**. Firing the chain executes the callback **OR** errback of **each link, in sequence**. For each link, its callback is executed if its input is a result; the errback is executed if its input is a failure (failures are represented by [`HLFailure`][HLF] objects).

### Adding (just) a callback ###

To append a link with a callback to an [`HLDeferred`][HLD] object, send it the `-then:` message, passing in a `ThenBlock`.  Example:

    [aDeferred then: ^(id result) {
        // do something useful with the result
        return result;
    }];

[`HLDeferred`][HLD] adds a link to its chain with your callback and a "passthrough" errback. The passthrough errback simply returns its exception parameter.

### Adding (just) an errback ###

To append a link with an errback to an [`HLDeferred`][HLD] object, send it the `-fail:` message, passing in a `FailBlock`.  Example:

    [aDeferred fail: ^(HLFailure *failure) {
        // optionally do something useful with [failure value]
        return failure;
    }];

[`HLDeferred`][HLD] adds a link to its chain with your errback and a "passthrough" callback. The passthrough callback simply returns its result parameter.

### Adding a callback and an errback ###

To add a link with a callback *and* errback  to an [`HLDeferred`][HLD] object, send it either the `-then:fail:` message or the `both:` message.

Use `-then:fail:` when you want different behaviour in the case of success or failure:

    [aDeferred then: ^(id result) {
        // do something useful with the result
        return result;
    } fail: ^(HLFailure *failure) {
        // optionally do something useful with [failure value]
        return failure;
    }]

Use `-both:` when you intend to do the same thing in either case:

    [aDeferred both: ^(id result) {
        // in the case of failure, result is an HLFailure
        // do something in either case
        return result;
    }]

HLDeferred in practice
----------------------

By convention, names of methods returning an [`HLDeferred`][HLD] object are prefixed with "request", such as:

    // result is a MyThing object
    - (HLDeferred *) requestDistantInformation;

It might be nice if Objective-C had support for generic types so you could specify the expected type of the result of the [`HLDeferred`][HLD]. Since that isn't the case, you should document that information in your header file or elsewhere.

### Data Sources ###

This library includes several concurrent `NSOperation` classes that act as data sources and provide a [`HLDeferred`][HLD] object.

- [`HLURLDataSource`][HLUDS] fetches the response body of an URL and returns it as `NSData`.
- [`HLDownloadDataSource`][HLDDS] writes the response body of an URL to a file and returns the path.
- [`HLJSONDataSource`][HLJDS] fetches a JSON document from an URL, parses it using [JSONKit][], and returns the represented object.

### Using the included data sources ###

Create a data source operation, then schedule it on an NSOperationQueue by sending it the `-requestStartOnQueue:` message, such as:

    NSOperation *op = [[HLURLDataSource alloc] initWithContext: ctx];
    HLDeferred *d = [op requestStartOnQueue: [NSOperationQueue mainQueue]];

**Note:** You don't have to use `[NSOperationQueue mainQueue]`, you can create your own queue and use that. Be aware that `HLDeferredDataSource` executes its [`HLDeferred`][HLD] object's callback chain on the main thread using GCD's `dispatch_async`.

### Making your own data sources ###

See the comments in [HLDeferredDataSource.h](https://github.com/heavylifters/HLDeferred-objc/raw/master/HLDeferred/Classes/HLDeferredDataSource.h) and [HLDeferredConcurrentDataSource.h](https://github.com/heavylifters/HLDeferred-objc/raw/master/HLDeferred/Classes/HLDeferredConcurrentDataSource.h) for more information.

### Data Source Example ###

    - (HLDeferred *) requestURLFromString: (NSString *)urlString
    {
        // Fetch an URL and do something when it's complete
        NSOperation *op = [[HLURLDataSource alloc] initWithURLString: urlString];
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        HLDeferred *d = [op requestStartOnQueue: queue];
        op = nil;
    
        // the "then" block runs if the operation succeeds
        [d then: ^(id result) {
            // result is NSData
            // download succeeded, do something
            return @"SUCCESS!";
        } fail: ^(HLFailure *failure) { // runs if the operations fails
            // request failed
            return failure;
        }];
        return d;
    }
    
    - (void) main
    {
        HLDeferred *d = [self requestURLFromString: @"http://example.com/"];
        // both means "in the case of success or failure"
        [d both: ^(id result) {
            // run after the callback specified in requestURLFromString
            NSLog(@"result is: %@", [result description]);
            return result;
        }];
        // perhaps return d.
        // The caller could add more callbacks
    }

Composing HLDeferred objects arbitrarily
----------------------------------------

You can return an [`HLDeferred`][HLD] object from the callback or errback of another [`HLDeferred`][HLD] object. If you do, the next link of the callback chain will not be executed until the callback chain of the returned [`HLDeferred`][HLD] is fired. The input to the next link of the original [`HLDeferred`][HLD] object's callback chain will be the output of the returned [`HLDeferred`][HLD] object.

This effectively builds a dependency tree of [`HLDeferred`][HLD] objects. Using this approach makes it easy to compose arbitrary trees of [`HLDeferred`][HLD] objects without having to manage complicated state machines.

### Quick note about memory management ###

The `HLDeferredDataSource` owns the [`HLDeferred`][HLD] object returned by `-requestStartOnQueue:`. Its callback chain will be fired (on the main thread) prior to the operation being marked as complete. When the operation is marked as complete, the queue `release`s it, which in turn `release`s the [`HLDeferred`][HLD] object.

As the NSOperationQueue retains the `HLDeferredDataSource` until it is complete, you can safely `release` the data source object after calling `-requestStartOneQueue:`.

### Assemble a firing squad with HLDeferredList ###

[`HLDeferredList`][HLDL] waits for a list of HLDeferred objects to finish firing before firing its callback chain.

It can optionally fire when the first result is obtained from the list, or when the first error is encountered, or can consume errors.

### Composition example ###

    - (HLDeferred *) requestLogin
    {
        if ([MyApp isLoggedIn]) {
            return [HLDeferred deferredWithResult: @"ok"];
        } else {
            NSDictionary *ctx = ...;
            NSOperation *op = [[HLDeferredURLRequestConcurrentOperation alloc] initWithContext: ctx];
            NSOperationQueue *queue = [NSOperationQueue mainQueue];
            HLDeferred *d = [op requestStartOnQueue: queue];
            op = nil;
    
            [d then: ^(id result) {
                NSLog(@"login succeeded");
                return @"ok";
            }];
    
            return d;
        }
    }
    
    // assume these do network requests of some sort
    - (HLDeferred *) requestStuff1 { ... }
    - (HLDeferred *) requestStuff2 { ... }
    
    // if successful, the result is a dictionary with keys stuff1 and stuff2
    - (HLDeferred *) requestMyStuff
    {
        // call requestLogin and add a callback to its callback chain
        // return that deferred, which the caller can add its own
        // callbacks and/or errbacks to.
        return [[self requestLogin] then: ^(id result) {
            if ([@"ok" isEqualToString: [result description]]) {
                NSArray *stuffs = [NSArray arrayWithObjects:
                    [self requestStuff1],
                    [self requestStuff2],
                    nil];
                HLDeferredList *ds = [[HLDeferredList alloc] initWithDeferreds: stuffs
                                                              fireOnFirstError: YES];
                [ds then: ^(id result) {
                    // result is an NSArray containing 2 objects
                    //  - the result of requestStuff1's HLDeferred
                    //  - the result of requestStuff2's HLDeferred
                    NSDictionary *dict = [[NSDictionary alloc] init];
                    [dict setObject: [result objectAtIndex: 0] forKey: @"stuff1"];
                    [dict setObject: [result objectAtIndex: 1] forKey: @"stuff2"];
                    return dict;
                }];
                return ds;
            } else {
                // returning an exception switches the execution of the
                // callback chain from the "then branch" to the "fail branch"
                return [HLFailure wrap: result];
            }
        }];
    }
    
    - (void) main
    {
        [[self requestMyStuff] then: ^(id result) {
            // at this point, we know requestStuff1 and requestStuff2
            // completed successfully, and result is an NSDictionary
            return result;
        } fail: (HLFailure *failure) {
            // the process failed
            return failure;
        }]
    }

### Handling Failure with composition ###

Unless you require fine-grained handling of failures, specifiy errbacks only in the top-level code that calls the first method returning an [`HLDeferred`][HLD] object. An `IBAction` method is a good example of "top-level code"...

    - (IBAction) signIn: (id)sender
    {
        [[self requestSignInForUser: userid
                       withPassword: password] then: ^(id result) {
            // success!
            return @"ok";
        } fail: (HLFailure *failure) {
            // oh noes!
            [UIAlertView ...];
            return failure;
        }];
    }

If `-requestSignInForUser:withPassword:` displayed a UIAlertView as well, the user would see multiple alerts!

There's more (leftovers we haven't written about yet)
------------

HLDeferred also has support for finalizers (which run after the callback chain is exhausted). Check out `-thenFinally:`, `-failFinally:`, `-thenFinally:failFinally:` and `-bothFinally:` in HLDeferred.m for more information. (Eventually we'll write better docs about this - or you can and send us a pull request :-))

If you use an `HLDeferredOperation`, you can cancel the operation by sending its [`HLDeferred`][HLD] object the `-cancel` message. `HLDeferredOperation` does this by conforming to the `HLDeferredCancellable` protocol and setting itself as the `cancelTarget` of the [`HLDeferred`][HLD] object - thus it is sent the `-cancel` message when you send `-cancel` to the [`HLDeferred`][HLD] object.

Also, timeouts are currently supported, but this will probably be removed soon, as we haven't used this functionality. We implemented it because it was part of the Twisted implementation, but since then the timeout functionality has been removed from Twisted as its use was long discouraged.

Links
-----
- [Docs](https://github.com/heavylifters/HLDeferred-objc/wiki) (forthcoming)
- [Mailing List](http://groups.google.com/group/hldeferred)
- [Issue Tracker](https://github.com/heavylifters/HLDeferred-objc/issues) (please report bugs and feature requests!)

How to contribute
-----------------
- Fork [HLDeferred-objc on GitHub](https://github.com/heavylifters/HLDeferred-objc), send a pull request

Contributors
------------
- [JimRoepcke](https://github.com/JimRoepcke) of [HeavyLifters](https://github.com/heavylifters)
- [samsonjs](https://github.com/samsonjs) of [HeavyLifters](https://github.com/heavylifters)

Alternatives
------------

- [samuraisam's DeferredKit](https://github.com/samuraisam/DeferredKit)

Credits
-------
- Based on [Twisted's Deferred](http://twistedmatrix.com/trac/browser/tags/releases/twisted-10.0.0/twisted/internet/defer.py) classes
- Sponsored by [HeavyLifters Network Ltd.](http://heavylifters.com/)

License
-------

Copyright 2011 [HeavyLifters Network Ltd.](http://heavylifters.com/) Licensed under the terms of the MIT license. See included [LICENSE](https://github.com/heavylifters/HLDeferred-objc/raw/master/LICENSE) file.

[HLD]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLDeferred
[HLF]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLFailure
[HLDL]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLDeferredList
[HLUDS]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLURLDataSource
[HLDDS]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLDownloadDataSource
[HLJDS]: https://github.com/heavylifters/HLDeferred-objc/wiki/HLJSONDataSource
[JSONKit]: https://github.com/johnezang/JSONKit
[GHUnit]: https://github.com/gabriel/gh-unit
