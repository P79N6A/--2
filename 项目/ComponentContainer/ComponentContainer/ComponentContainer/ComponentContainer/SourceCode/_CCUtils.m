//
// _CCUtils.m
//
// Copyright (c) 2019 dequanzhu
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import "_CCUtils.h"

@interface _CCKVODispatcher : NSObject
@property (nonatomic, unsafe_unretained, readwrite) id unsafeObservedObject;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSMapTable<NSObject *, CCKVOCallback> *> *bindings;

@end

@implementation _CCKVODispatcher

static void *_CCKVODispatcherContext = &_CCKVODispatcherContext;

- (instancetype)initWithObservedObject:(NSObject *)observedObject {
    self = [super init];
    if (self) {
        self.unsafeObservedObject = observedObject;
        self.bindings = @{}.mutableCopy;
    }
    return self;
}

- (void)dealloc {
    @autoreleasepool {
        [[self.bindings allKeys] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            @try {
                [self.unsafeObservedObject removeObserver:self forKeyPath:key];
            } @catch (NSException *exception) {
                CCErrorLog(@"failed to remove KVO observer on webview exception: %@, %@, %@", exception.name, exception.reason, exception.userInfo);
            }
        }];
    }
}

#pragma mark -

- (void)_addObserver:(id)observer keyPath:(NSString *)keyPath callback:(CCKVOCallback)callback {
    if (!observer || keyPath.length <= 0 || !callback) {
        CCFatalLog(@"add observer with invalid parameters:observer %@, keyPath %@, callback %@", observer, keyPath, callback);
        return;
    }

    NSMapTable<NSObject *, CCKVOCallback> *tables = self.bindings[keyPath];

    if (!tables) {
        tables = [[NSMapTable alloc]
                  initWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
                        valueOptions:NSPointerFunctionsCopyIn
                            capacity:2];
        [_bindings setObject:tables forKey:keyPath];
        @try {
            [self.unsafeObservedObject addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:_CCKVODispatcherContext];
        } @catch (NSException *exception) {
            CCErrorLog(@"failed to add KVO observer on webview exception: %@, %@, %@", exception.name, exception.reason, exception.userInfo);
        }
    }

    if ([tables objectForKey:observer]) {
        CCFatalLog(@"Operation NOT allowed! Rebinding with the same observer: %@, keyPath: %@", observer, keyPath);
    }

    [tables setObject:[callback copy] forKey:observer];
}

- (void)_removeObserver:(id)observer keyPath:(NSString *)keyPath {
    NSMapTable<NSObject *, CCKVOCallback> *tables = _bindings[keyPath];
    if (tables.count > 0) {
        [tables removeObjectForKey:observer];
        if (tables.count == 0) {
            [self _unobserve:keyPath];
        }
    }
}

- (void)_unobserve:(NSString *)keyPath {
    if (keyPath.length <= 0) {
        return;
    }
    @autoreleasepool {
        [_bindings removeObjectForKey:keyPath];
        @try {
            [self.unsafeObservedObject removeObserver:self forKeyPath:keyPath context:_CCKVODispatcherContext];
        } @catch (NSException *exception) {
            CCErrorLog(@"failed to remove KVO observer on webview exception: %@, %@, %@", exception.name, exception.reason, exception.userInfo);
        }
    }
}

- (void)_removeAllCustomObserver{
    NSArray *allKeyPath = [[self.bindings allKeys] copy];
    [allKeyPath enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        [self _unobserve:key];
    }];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context == _CCKVODispatcherContext) {
        NSMapTable<NSObject *, CCKVOCallback> *tables = _bindings[keyPath];

        NSArray<CCKVOCallback> *infos = [[tables objectEnumerator] allObjects];

        if (infos) {
            if (infos.count == 0) {
                [self _unobserve:keyPath];
            } else {
                [infos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    CCKVOCallback callBack = (CCKVOCallback)obj;
                    if (callBack) {
                        callBack(change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
                    }
                }];
            }
        }
    }
}

@end

@implementation NSObject (CCKVO)

- (_CCKVODispatcher *)_CCKVODispatcher {
    _CCKVODispatcher *dispatcher = objc_getAssociatedObject(self, @selector(_CCKVODispatcher));

    if (!dispatcher) {
        dispatcher = [[_CCKVODispatcher alloc] initWithObservedObject:self];
        objc_setAssociatedObject(self, @selector(_CCKVODispatcher), dispatcher, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return dispatcher;
}

- (void)safeAddObserver:(id)observer keyPath:(NSString *)keyPath callback:(CCKVOCallback)callback {
    if (!observer || keyPath.length <= 0 || !callback) {
        CCFatalLog(@"add observer with invalid parameters:observer %@, keyPath %@, callback %@", observer, keyPath, callback);
        return;
    }

    @autoreleasepool {
        return [[self _CCKVODispatcher] _addObserver:observer keyPath:keyPath callback:callback];
    }
}

- (void)safeRemoveObserver:(id)observer keyPath:(NSString *)keyPath {
    if (keyPath.length <= 0) {
        return;
    }

    @autoreleasepool {
        [[self _CCKVODispatcher] _removeObserver:observer keyPath:keyPath];
    }
}

- (void)safeRemoveAllObserver{
    [[self _CCKVODispatcher] _removeAllCustomObserver];
}

@end

@implementation CCPageManager (_utils)
- (void)logWithErrorLevel:(CCLogLevel)errorLevel logFormat:(NSString *)logFormat, ... NS_FORMAT_FUNCTION(2, 3) {
    if (self.logCallBack) {
        NSString *logStr;
        va_list argList;
        va_start(argList, logFormat);
        logStr = [[NSString alloc] initWithFormat:logFormat arguments:argList];
        va_end(argList);
        self.logCallBack(logStr, errorLevel);
    }
}
@end
