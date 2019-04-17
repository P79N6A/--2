//
// CCModelProtocol.h
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


#ifndef CCModelProtocol_h
#define CCModelProtocol_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef NS_ENUM (NSInteger, CCState) { kCCStateNone, kCCStatePrepare, kCCStateVisible };

NS_ASSUME_NONNULL_BEGIN

#define CCModel NSObject<CCModelProtocol>

#define ISCCModel(value) ([value conformsToProtocol:@protocol(CCModelProtocol)])

#define IMP_CCModelProtocol(INDEX)   \
    - (void)setComponentIndex: (NSString *)componentIndex { objc_setAssociatedObject(self, @selector(setComponentIndex:), componentIndex, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } \
    - (NSString *)componentIndex { NSString *index = objc_getAssociatedObject(self, @selector(setComponentIndex:)); return index ? : INDEX; } \
    - (CGRect)componentFrame {  NSValue *rectValue = objc_getAssociatedObject(self, @selector(setComponentFrame:)); return [rectValue CGRectValue]; } \
    - (void)setComponentFrame:(CGRect)frame { NSValue *rectValue = [NSValue valueWithCGRect:frame]; objc_setAssociatedObject(self, @selector(setComponentFrame:), rectValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } \
    - (CCState)componentNewState { NSNumber *newStateNum = objc_getAssociatedObject(self, @selector(setComponentNewState:)); CCState newState = (CCState)newStateNum.integerValue; return newState; } \
    - (void)setComponentNewState:(CCState)componentNewState { objc_setAssociatedObject(self, @selector(setComponentNewState:), @(componentNewState), OBJC_ASSOCIATION_RETAIN_NONATOMIC); } \
    - (CCState)componentOldState { NSNumber *oldStateNum = objc_getAssociatedObject(self, @selector(setComponentOldState:)); CCState oldState = (CCState)oldStateNum.integerValue; return oldState; } \
    - (void)setComponentOldState:(CCState)componentOldState { objc_setAssociatedObject(self, @selector(setComponentOldState:), @(componentOldState), OBJC_ASSOCIATION_RETAIN_NONATOMIC); } \
    - (void)resetComponentState { [self setComponentNewState:kCCStateNone]; [self setComponentOldState:kCCStateNone]; }

/**
 * 底层页Component组件Model protocol
 * ComponentModel需要实现 `IMP_CCModelProtocol(INDEX)` INDEX为默认component index
 */
@protocol CCModelProtocol

@optional

/**
 @return 返回component model的index
 */
- (NSString *)componentIndex;

/**
 @param componentIndex 设置component model的index
 */
- (void)setComponentIndex:(NSString *)componentIndex;

/**
 @return 返回component在container中的frame
 */
- (CGRect)componentFrame;

/**
 @param frame 设置component在container中的frame
 */
- (void)setComponentFrame:(CGRect)frame;

/**
 清除在container中滚动复用的component状态
 */
- (void)resetComponentState;

/**
 以下使用 `IMP_CCModelProtocol()` 替代
 */
@required
- (CCState)componentNewState;
- (void)setComponentNewState:(CCState)componentNewState;
- (CCState)componentOldState;
- (void)setComponentOldState:(CCState)componentOldState;
@end

NS_ASSUME_NONNULL_END

#endif /* CCModelProtocol_h */
