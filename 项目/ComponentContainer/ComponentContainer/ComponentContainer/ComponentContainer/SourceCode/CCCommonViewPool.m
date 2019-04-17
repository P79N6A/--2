//
// CCCommonViewPool.m
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


#import "CCCommonViewPool.h"
#import "CCPageManager.h"
#import "_CCUtils.h"

@interface CCCommonViewPool ()
@property(nonatomic,strong,readwrite)dispatch_semaphore_t lock;
@property(nonatomic,strong,readwrite)NSMutableDictionary<NSString *,NSMutableSet< CCView *> *> *dequeueViews;
@property(nonatomic,strong,readwrite)NSMutableDictionary<NSString *,NSMutableSet< CCView *> *> *enqueueViews;
@end

@implementation CCCommonViewPool

+ (CCCommonViewPool *)sharedInstance {
    static dispatch_once_t once;
    static CCCommonViewPool *singleton;
    dispatch_once(&once,
                  ^{
                      singleton = [[CCCommonViewPool alloc] init];
                  });
    return singleton;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _dequeueViews = @{}.mutableCopy;
        _enqueueViews = @{}.mutableCopy;
        _lock = dispatch_semaphore_create(1);
        //memory warning 时清理全部
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearAllReusableComponentViews)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.dequeueViews removeAllObjects];
    [self.enqueueViews removeAllObjects];
    self.dequeueViews = nil;
    self.enqueueViews = nil;
}

#pragma mark - public method

- (CCView *)dequeueComponentViewWithClass:(Class)viewClass{
    if(!ISCCView(viewClass)){
        CCFatalLog(@"CCCommonViewPool dequeue invalid class:%@" ,viewClass);
        return nil;
    }
    CCView *dequeueView = [self _getViewOfClass:viewClass];
    return dequeueView;
}

- (void)enqueueComponentView:(CCView *)componentView{
    
    if(!componentView || !ISCCView(componentView)){
        CCErrorLog(@"CCViewPool enqueue with invalid view:%@", componentView);
        return;
    }
    [componentView removeFromSuperview];
    [componentView setComponentViewId:@""];
    [self _recycleView:componentView];
}

- (void)enqueueAllComponentViewsOfSuperView:(__kindof UIView *)superView{
    [self _tryCompactWeakSuperView:superView];
}

- (void)clearAllReusableComponentViews{
    
    //auto recycle
    [self _tryCompactWeakSuperView:nil];
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [_enqueueViews removeAllObjects];
    dispatch_semaphore_signal(_lock);
}

- (void)resetVisibleComponentViewState:(CCView *)componentView{

    if(![[_dequeueViews objectForKey:NSStringFromClass([componentView class])] containsObject:componentView]){
        return;
    }
    
    //进入回收池前清理
    if([componentView respondsToSelector:@selector(componentViewWillEnterPool)]){
        [componentView componentViewWillEnterPool];
    }
    
    //出回收池前初始化
    if([componentView respondsToSelector:@selector(componentViewWillLeavePool)]){
        [componentView componentViewWillLeavePool];
    }
}

#pragma mark - private method

- (void)_tryCompactWeakSuperView:(__kindof UIView *)superView {
    NSDictionary *dequeueViewsTmp = _dequeueViews.copy;
    if(dequeueViewsTmp && dequeueViewsTmp.count > 0){
        for (NSMutableSet *viewSet in dequeueViewsTmp.allValues) {
            NSSet *viewSetTmp = viewSet.copy;
            for (CCView *view in viewSetTmp) {
                if(view.superview == superView || !view.superview){
                    [view setFrame:CGRectZero];
                    [view setComponentViewId:@""];
                    [view removeFromSuperview];
                    [self _recycleView:view];
                }
            }
        }
    }
}

-(void)_recycleView:(CCView *)view{
    
    if (!ISCCView(view)) {
        return;
    }
    
    //进入回收池前清理
    if([view respondsToSelector:@selector(componentViewWillEnterPool)]){
        [view componentViewWillEnterPool];
    }
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSString *classStr = NSStringFromClass(view.class);
    if([[_dequeueViews allKeys] containsObject:classStr]){
        NSMutableSet *viewSet =  [_dequeueViews objectForKey:classStr];
        [viewSet removeObject:view];
    }else{
        dispatch_semaphore_signal(_lock);
        CCFatalLog(@"CCCommonViewPool recycle invalid view");
    }
    
    if([[_enqueueViews allKeys] containsObject:classStr]){
        NSMutableSet *viewSet =  [_enqueueViews objectForKey:classStr];
        if(viewSet.count < [CCPageManager sharedInstance].componentsMaxReuseCount){
            [viewSet addObject:view];
        }else{
        }
    }else{
        NSMutableSet *viewSet = [[NSSet set] mutableCopy];
        [viewSet addObject:view];
        [_enqueueViews setValue:viewSet forKey:classStr];
    }
    
    dispatch_semaphore_signal(_lock);
}

-(CCView *)_getViewOfClass:(Class)viewClass{
    
    if (!ISCCView(viewClass)) {
        return nil;
    }
    
    CCView * view;
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    NSString *classStr = NSStringFromClass(viewClass);
    if([[_enqueueViews allKeys] containsObject:classStr]){
        NSMutableSet *viewSet =  [_enqueueViews objectForKey:classStr];
        if (viewSet && viewSet.count > 0) {
            view = [viewSet anyObject];
            [viewSet removeObject:view];
        }
    }
    
    if(!view){
        view = [[viewClass alloc] initWithFrame:CGRectZero];
    }
    
    if([[_dequeueViews allKeys] containsObject:classStr]){
        NSMutableSet *viewSet =  [_dequeueViews objectForKey:classStr];
        [viewSet addObject:view];
    }else{
        NSMutableSet *viewSet = [[NSSet set] mutableCopy];
        [viewSet addObject:view];
        [_dequeueViews setValue:viewSet forKey:classStr];
    }
    dispatch_semaphore_signal(_lock);
    
    //出回收池前初始化
    if([view respondsToSelector:@selector(componentViewWillLeavePool)]){
        [view componentViewWillLeavePool];
    }
    return view;
}
@end

