//
// CCScrollProcessor.m
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

#import "CCScrollProcessor.h"
#import "CCCommonViewPool.h"
#import "_CCUtils.h"

typedef NS_ENUM (NSInteger, CCScrollEvent) {
    kCCScrollEventGetUnReusableComponentView,
    kCCScrollEventGetReusableComponentViewClass,
    kCCScrollEventWillDisplayComponentView,
    kCCScrollEventEndDisplayComponentView,
    kCCScrollEventWillPrepareComponentView,
    kCCScrollEventEndPrepareComponentView,
    kCCScrollEventRelayoutComponentView,
    kCCScrollEventFinishCalculateFrame,
};

static inline SEL _getCCScrollProtocolByEventType(CCScrollEvent event) {
    SEL mapping[] = {
        [kCCScrollEventGetUnReusableComponentView] = @selector(unReusableComponentViewWithModel:),
        [kCCScrollEventGetReusableComponentViewClass] = @selector(reusableComponentViewClassWithModel:),
        [kCCScrollEventWillDisplayComponentView] = @selector(scrollViewWillDisplayComponentView:componentModel:),
        [kCCScrollEventEndDisplayComponentView] = @selector(scrollViewEndDisplayComponentView:componentModel:),
        [kCCScrollEventWillPrepareComponentView] = @selector(scrollViewWillPrepareComponentView:componentModel:),
        [kCCScrollEventEndPrepareComponentView] = @selector(scrollViewEndPrepareComponentView:componentModel:),
        [kCCScrollEventRelayoutComponentView] = @selector(scrollViewRelayoutComponentView:componentModel:),
        [kCCScrollEventFinishCalculateFrame] = @selector(scrollViewFinishCalculateFrameWithComponentView:componentModel:)
    };
    return mapping[event];
}

#define kCCScrollViewContentSize   @"contentSize"
#define kCCScrollViewContentOffset @"contentOffset"

@interface CCScrollProcessor ()

@property (nonatomic, strong, readwrite) __kindof UIScrollView *scrollView;
@property (nonatomic, assign, readwrite) BOOL isLayouting;
@property (nonatomic, assign, readwrite) BOOL isInitCalculate;
@property (nonatomic, assign, readwrite) CGFloat lastComponentTop;

@property (nonatomic, assign, readwrite) CCLayoutType layoutType;
@property (nonatomic, copy, readwrite) CCScrollProcessorDelegateBlock scrollDelegateBlock;

//全部的component models
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCModel *> *allComponentsModels;
//全部可视的component views
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCView *> *visibleComponentViews;
//全部可视的component views
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCView *> *onScrollViewComponentViews;
//内部包含scrollView的component models
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCModel *> *scrollableComponentModels;
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCView *> *scrollableComponentViews;
//自动计算components原始位置
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, NSNumber *> *componentsOriginalTop;

@end

@implementation CCScrollProcessor

- (void)dealloc {
    //回收scrollView上全部component views
    [[CCCommonViewPool sharedInstance] enqueueAllComponentViewsOfSuperView:self.scrollView];

    [self.scrollView safeRemoveObserver:self keyPath:kCCScrollViewContentSize];
    [self.scrollView safeRemoveObserver:self keyPath:kCCScrollViewContentOffset];
 
    _scrollView = nil;
    _scrollDelegateBlock = nil;

    _allComponentsModels = nil;
    _visibleComponentViews = nil;
    _scrollableComponentModels = nil;
    _scrollableComponentViews = nil;
    _componentsOriginalTop = nil;
    _onScrollViewComponentViews = nil;
}

- (instancetype)initWithScrollView:(__kindof UIScrollView *)scrollView
                        layoutType:(CCLayoutType)layoutType
               scrollDelegateBlock:(CCScrollProcessorDelegateBlock)scrollDelegateBlock {
    self = [super init];
    if (self) {
        //scrollView
        _scrollView = scrollView;
        _layoutType = layoutType;
        _scrollDelegateBlock = [scrollDelegateBlock copy];

        _allComponentsModels = [NSMapTable strongToWeakObjectsMapTable];
        _visibleComponentViews = [NSMapTable strongToWeakObjectsMapTable];
        _scrollableComponentModels = [NSMapTable strongToWeakObjectsMapTable];
        _scrollableComponentViews = [NSMapTable strongToWeakObjectsMapTable];
        _componentsOriginalTop = [NSMapTable strongToStrongObjectsMapTable];
        _onScrollViewComponentViews = [NSMapTable strongToWeakObjectsMapTable];

        [self _initNestedScrollingMode];
    }
    return self;
}

#pragma mark - trigger event

- (void)_detailComponentsDidUpdateWithOffsetTop:(CGFloat)offsetTop forceLayout:(BOOL)forceLayout {
    if (_allComponentsModels.count <= 0) {
        return;
    }

    if ((_layoutType == kCCLayoutTypeAutoCalculateFrame) &&
        self.lastComponentTop > 0 &&
        (offsetTop >= self.lastComponentTop + [CCPageManager sharedInstance].componentsPrepareWorkRange)) {
        return;
    }

    _isLayouting = YES;

    CGFloat visibleTopLine = offsetTop;
    CGFloat visibleBottomLine = offsetTop + self.scrollView.frame.size.height;

    CGFloat preparedTopLine = visibleTopLine - [CCPageManager sharedInstance].componentsPrepareWorkRange;
    CGFloat preparedBottomLine = visibleBottomLine + [CCPageManager sharedInstance].componentsPrepareWorkRange;

    //根据新位置进行赋值
    for (CCModel *model in _allComponentsModels.objectEnumerator) {
        CGPoint componentOrigin = [model componentFrame].origin;
        CGSize componentSize = [model componentFrame].size;
        //in prepare
        if (componentOrigin.y + componentSize.height > preparedTopLine && componentOrigin.y < preparedBottomLine) {
            //in visible
            if (componentOrigin.y + componentSize.height > visibleTopLine && componentOrigin.y < visibleBottomLine) {
                model.componentNewState = kCCStateVisible;
            } else {
                model.componentNewState = kCCStatePrepare;
            }
        } else {
            model.componentNewState = kCCStateNone;
        }
    }

    //对比新旧位置，发送通知
    for (CCModel *model in _allComponentsModels.objectEnumerator) {
        NSString *modelIndex = [model componentIndex];

        if (forceLayout) {
            CCView *view = [_onScrollViewComponentViews objectForKey:modelIndex];
            view.frame = [model componentFrame];
        }

        if (model.componentNewState == model.componentOldState) {
            if (forceLayout && model.componentNewState != kCCStateNone) {
                //强制更新
                [self _triggerComponentEvent:kCCScrollEventRelayoutComponentView withModel:model];
            }
            continue;
        }

        if (model.componentNewState == kCCStateVisible && model.componentOldState == kCCStatePrepare) {
            //准备到可见
            [self _triggerComponentEvent:kCCScrollEventWillDisplayComponentView withModel:model];
        } else if (model.componentNewState == kCCStateVisible && model.componentOldState == kCCStateNone) {
            //容错，none到可见
            [self _dequeueViewOfModel:model];
            [self _triggerComponentEvent:kCCScrollEventWillPrepareComponentView withModel:model];
            [self _triggerComponentEvent:kCCScrollEventWillDisplayComponentView withModel:model];
        } else if (model.componentNewState == kCCStatePrepare && model.componentOldState == kCCStateNone) {
            //none到准备
            [self _dequeueViewOfModel:model];
            [self _triggerComponentEvent:kCCScrollEventWillPrepareComponentView withModel:model];
        } else if (model.componentNewState == kCCStatePrepare && model.componentOldState == kCCStateVisible) {
            //可见到准备
            [self _triggerComponentEvent:kCCScrollEventEndDisplayComponentView withModel:model];
        } else if (model.componentNewState == kCCStateNone && model.componentOldState == kCCStatePrepare) {
            //准备到none
            [self _triggerComponentEvent:kCCScrollEventEndPrepareComponentView withModel:model];
            [self _enqueueViewOfModel:model removeUnReusableView:NO];
        } else if (model.componentNewState == kCCStateNone && model.componentOldState == kCCStateVisible) {
            //容错，可见到none
            [self _triggerComponentEvent:kCCScrollEventEndDisplayComponentView withModel:model];
            [self _triggerComponentEvent:kCCScrollEventEndPrepareComponentView withModel:model];
            [self _enqueueViewOfModel:model removeUnReusableView:NO];
        } else {
            //never
        }
        //赋值新状态
        model.componentOldState = model.componentNewState;
    }

    self.isLayouting = NO;
}

#pragma mark - auto calculate frame and layout

- (void)_layoutNestScrollingComponent {
    if (_layoutType == kCCLayoutTypeManualCalculateFrame) {
        //已知frame模式下无需计算
        return;
    }

    for (NSString *modelIndex in [_scrollableComponentModels keyEnumerator]) {
        CCModel *model = [self.scrollableComponentModels objectForKey:modelIndex];
        CCView *view = [self.scrollableComponentViews objectForKey:modelIndex];

        CGFloat subScrollViewContentHeight = [self _componentHeight:view];
        CGFloat subScrollViewOriginalTop;
        if ([[_componentsOriginalTop objectForKey:modelIndex] isKindOfClass:[NSNumber class]]) {
            subScrollViewOriginalTop = ((NSNumber *)[_componentsOriginalTop objectForKey:modelIndex]).floatValue;
        } else {
            subScrollViewOriginalTop = 0.f;
        }
        CGFloat subScrollViewTopLine = subScrollViewOriginalTop;
        CGFloat subScrollViewBottomLine = subScrollViewOriginalTop + subScrollViewContentHeight;

        //计算正确的frame
        CGRect viewFrame = view.frame;
        CGFloat scrollOffsetY = self.scrollView.contentOffset.y;
        CGFloat targetTop = scrollOffsetY;
        if (targetTop < subScrollViewTopLine) {
            //小于原始位置的，在原始位置
            targetTop = subScrollViewTopLine;
        } else if (targetTop + viewFrame.size.height > subScrollViewBottomLine) {
            //已经滚动走的，保持在最下方
            targetTop = subScrollViewBottomLine - viewFrame.size.height;
        }

        //调整view的frame
        viewFrame.origin.y = targetTop;
        view.frame = viewFrame;

        //调整model的component frame
        CGRect frame = [model componentFrame];
        [model setComponentFrame:CGRectMake(frame.origin.x, targetTop, frame.size.width, frame.size.height)];

        // contentOffset
        UIScrollView *subScrollView = [view componentInnerScrollView];
        CGFloat targetOffsetY = MIN(MAX(0, scrollOffsetY - subScrollViewOriginalTop), (subScrollViewContentHeight) - view.frame.size.height);
        [subScrollView setContentOffset:CGPointMake(subScrollView.contentOffset.x, targetOffsetY) animated:NO];
    }
}

- (void)_initAutoCalculateComponentFrame {
    if (_layoutType == kCCLayoutTypeManualCalculateFrame) {
        //已知frame模式下无需计算
        return;
    }
    
    if (_allComponentsModels.count <= 0) {
        return;
    }
    
    _isInitCalculate = YES;

    //根据key排序
    NSArray *sortedKeys = [[[_allComponentsModels keyEnumerator] allObjects] sortedArrayUsingComparator:^NSComparisonResult (id _Nonnull obj1, id _Nonnull obj2) {
        NSString *index1 = [obj1 isKindOfClass:[NSString class]] ? (NSString *)obj1 : @"";
        NSString *index2 = [obj2 isKindOfClass:[NSString class]] ? (NSString *)obj2 : @"";

        if (index1.integerValue < index2.integerValue) {
            return NSOrderedAscending;
        } else if (index1.integerValue > index2.integerValue) {
            return NSOrderedDescending;
        } else {
            CCFatalLog(@"Component Array can not same type");
            return NSOrderedSame;
        }
    }];

    CGFloat componentTop = 0.f;
    CGFloat contentSizeHeight = 0.f;
    //清理之前的缓存
    [_componentsOriginalTop removeAllObjects];
    [_scrollableComponentModels removeAllObjects];
    [_scrollableComponentViews removeAllObjects];

    for (NSString *key in sortedKeys) {
        CCModel *model = [_allComponentsModels objectForKey:key];
        CCView *view = [self _getUnResuableViewWithModel:model];

        CGRect frame = [model componentFrame];
        CGFloat componentHeight = 0.f;
        if (view) {
            // 不需要重用的 计算正确的view height，根据view高度重置model frame
            [self _correctViewHeightWithView:view];
            [model setComponentFrame:CGRectMake(frame.origin.x, componentTop, view.frame.size.width, view.frame.size.height)];
            componentHeight = [self _componentHeight:view];
        } else {
            // 需要重用的 根据model内frame设置
            [model setComponentFrame:CGRectMake(frame.origin.x, componentTop, frame.size.width, frame.size.height)];
            componentHeight = frame.size.height;
        }

        //保存初始位置（滚动前）
        [_componentsOriginalTop setObject:@(componentTop) forKey:key];
        self.lastComponentTop = MAX(self.lastComponentTop, componentTop);
        //滚动类型的保存下
        if ([self _componentInnerScrollView:view]) {
            [_scrollableComponentModels setObject:model forKey:key];
            [_scrollableComponentViews setObject:view forKey:key];
        }

        [self _triggerComponentEvent:kCCScrollEventFinishCalculateFrame withModel:model];
        
        componentTop += componentHeight;
        contentSizeHeight += componentHeight;
    }

    //根据subView的contentSize重新设置contentSize
    if (contentSizeHeight != self.scrollView.contentSize.height) {
        self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width, contentSizeHeight);
    }

    if (self.scrollView.contentOffset.y != 0) {
        //已经滚动的要重新复位下subview中的scrollViews
        [self _layoutNestScrollingComponent];
    }
    
    _isInitCalculate = NO;
}

#pragma mark -  private

- (__kindof UIView *)_dequeueViewOfModel:(CCModel *)model {
    return ({
        CCView *view = [self _getUnResuableViewWithModel:model];
        NSString *componentIndex = [model componentIndex];
        if (view) {
            if (![view isDescendantOfView:_scrollView]) {
                [_scrollView addSubview:view];
                [_onScrollViewComponentViews setObject:view forKey:componentIndex];
            }
        } else {
            //防止刷新直接更换Model有重复view
            view = [_onScrollViewComponentViews objectForKey:componentIndex];
            if (!view) {
                Class viewCls = [self _triggerComponentEvent:kCCScrollEventGetReusableComponentViewClass withModel:model];
                view = [[CCCommonViewPool sharedInstance] dequeueComponentViewWithClass:viewCls];
                [view setComponentViewId:componentIndex];
                [_scrollView addSubview:view];
                [_onScrollViewComponentViews setObject:view forKey:componentIndex];
            } else {
                [[CCCommonViewPool sharedInstance] resetVisibleComponentViewState:view];
            }
        }
        view.frame = [model componentFrame];
        [_visibleComponentViews setObject:view forKey:componentIndex];
        view;
    });
}

- (void)_enqueueViewOfModel:(CCModel *)model removeUnReusableView:(BOOL)removeUnReusableView {
    NSString *componentIndex = [model componentIndex];
    if ([self _getUnResuableViewWithModel:model]) {
        //滚动时，重用view不回收
        if (removeUnReusableView) {
            CCView *view = [self _getUnResuableViewWithModel:model];
            [view removeFromSuperview];
            [view setComponentViewId:@""];
            [_onScrollViewComponentViews removeObjectForKey:componentIndex];
        }
    } else {
        CCView *view = [_visibleComponentViews objectForKey:[model componentIndex]];
        [view removeFromSuperview];
        [view setComponentViewId:@""];
        [[CCCommonViewPool sharedInstance] enqueueComponentView:view];
        [_onScrollViewComponentViews removeObjectForKey:componentIndex];
    }
    [_visibleComponentViews removeObjectForKey:componentIndex];
}

- (UIScrollView *)_componentInnerScrollView:(CCView *)componentView {
    if (![componentView respondsToSelector:@selector(componentInnerScrollView)]) {
        return nil;
    }

    if ([[componentView componentInnerScrollView] isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)[componentView componentInnerScrollView];
    } else {
        return nil;
    }
}

- (CGFloat)_componentHeight:(CCView *)componentView{
    if (![componentView respondsToSelector:@selector(componentHeight)]) {
        return componentView.frame.size.height;
    }
    return [componentView componentHeight];
}

- (void)_correctViewHeightWithView:(CCView *)view {
    CGFloat correctHeight = [self _componentHeight:view];

    UIScrollView *contentScrollView = [self _componentInnerScrollView:view];
    if (contentScrollView) {
        contentScrollView.scrollEnabled = NO;
        correctHeight = MIN(correctHeight, _scrollView.frame.size.height);
    }

    if (view.frame.size.height != correctHeight) {
        CGRect frame = view.frame;
        frame.size.height = correctHeight;
        view.frame = frame;
    }
}

- (void)_initNestedScrollingMode {
    
    __weak typeof(self)_self = self;
    [self.scrollView safeAddObserver:self keyPath:kCCScrollViewContentOffset callback:^(NSObject *oldValue, NSObject *newValue) {
        __strong typeof(_self)self = _self;
        if (self.layoutType == kCCLayoutTypeAutoCalculateFrame) {
            //初始化时计算改变contentSize无需滚动处理
            [self _layoutNestScrollingComponent];
        }
        CGPoint oldOffset = [((NSValue *)oldValue) CGPointValue];
        CGPoint newOffset = [((NSValue *)newValue) CGPointValue];
        if (!CGPointEqualToPoint(oldOffset, newOffset)) {
            [self _detailComponentsDidUpdateWithOffsetTop:newOffset.y forceLayout:NO];
        }
    }];
    
    [self.scrollView safeAddObserver:self keyPath:kCCScrollViewContentSize callback:^(NSObject *oldValue, NSObject *newValue) {
        __strong typeof(_self)self = _self;
        if (self.layoutType == kCCLayoutTypeAutoCalculateFrame) {
            //初始化时计算改变contentSize无需滚动处理
            [self _layoutNestScrollingComponent];
        }
    }];
}

- (id)_triggerComponentEvent:(CCScrollEvent)event withModel:(CCModel *)model {
    SEL protocolSelector = _getCCScrollProtocolByEventType(event);
    if (!protocolSelector) {
        CCFatalLog(@"CCSCrollProcessor trigger invalid event:%@", @(event));
        return nil;
    }

    if (!_scrollDelegateBlock) {
        return nil;
    }

    BOOL isGetViewEvent = (event == kCCScrollEventGetUnReusableComponentView || event == kCCScrollEventGetReusableComponentViewClass);

    NSObject<CCControllerProtocol> *scrollDelegate = _scrollDelegateBlock(model, isGetViewEvent);

    if (!scrollDelegate) {
        return nil;
    }

    if (isGetViewEvent) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if ([scrollDelegate respondsToSelector:protocolSelector]) {
            return [scrollDelegate performSelector:protocolSelector withObject:model];
        }
        return nil;
#pragma clang diagnostic pop
    } else {
        CCView *view = [_visibleComponentViews objectForKey:[model componentIndex]];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if ([scrollDelegate respondsToSelector:protocolSelector]) {
            [scrollDelegate performSelector:protocolSelector withObject:view withObject:model];
        }
        return nil;
#pragma clang diagnostic pop
    }
}

- (CCView *)_getUnResuableViewWithModel:(CCModel *)model {
    CCView *view = [self _triggerComponentEvent:kCCScrollEventGetUnReusableComponentView withModel:model];
    [view setComponentViewId:[model componentIndex]];
    return view;
}

- (void)_scrollToComponentIndex:(NSString *)componentIndex atOffset:(CGFloat)offsetY animated:(BOOL)animated {
    if ([[_componentsOriginalTop objectForKey:componentIndex] isKindOfClass:[NSNumber class]]) {
        CGFloat originalTop = ((NSNumber *)[_componentsOriginalTop objectForKey:componentIndex]).floatValue;
        [self _scrollToContentOffset:CGPointMake(0, originalTop + offsetY) animated:animated];
    }
}

- (void)_scrollToContentOffset:(CGPoint)toContentOffset animated:(BOOL)animated {
    CGFloat y = MAX(0, toContentOffset.y);
    y = MIN(y, _scrollView.contentSize.height - _scrollView.frame.size.height);
    [_scrollView setContentOffset:CGPointMake(toContentOffset.x, y) animated:animated];
    CCInfoLog(@"CCScrollProcessor has scrollto offsety:%@",@(y));
}

#pragma mark -
#pragma mark -
#pragma mark - public

- (void)relayoutWithComponentFrameChange {
    
    if (_isInitCalculate) {
        return;
    }
    
    if (_isLayouting) {
        __weak typeof(self)_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(_self)self = _self;
            //在布局期间发生更新，下一个runloop进行更新
            [self relayoutWithComponentFrameChange];
        });
    } else {
        [self _initAutoCalculateComponentFrame];
        [self _detailComponentsDidUpdateWithOffsetTop:MAX(_scrollView.contentOffset.y, 0.f) forceLayout:YES];
    }
}

- (void)addComponentModelAndRelayout:(CCModel *)componentModel {
    if (_isInitCalculate || !componentModel) {
        return;
    }
    if (_isLayouting) {
        __weak typeof(self)_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(_self)self = _self;
            //在布局期间发生更新，下一个runloop进行更新
            [self addComponentModelAndRelayout:componentModel];
        });
    } else {
        [_allComponentsModels setObject:componentModel forKey:[componentModel componentIndex]];
        [self _initAutoCalculateComponentFrame];
        [self _detailComponentsDidUpdateWithOffsetTop:MAX(_scrollView.contentOffset.y, 0.f) forceLayout:YES];
    }
}

- (void)removeComponentModelAndRelayout:(CCModel *)componentModel {
    if (_isInitCalculate || !componentModel) {
        return;
    }

    if (_isLayouting) {
        __weak typeof(self)_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(_self)self = _self;
            //在布局期间发生更新，下一个runloop进行更新
            [self removeComponentModelAndRelayout:componentModel];
        });
    } else {
        //remove的时候处理下遗留view
        [self _enqueueViewOfModel:componentModel removeUnReusableView:YES];
        [_allComponentsModels removeObjectForKey:[componentModel componentIndex]];
        [componentModel resetComponentState];
        [self _initAutoCalculateComponentFrame];
        [self _detailComponentsDidUpdateWithOffsetTop:MAX(_scrollView.contentOffset.y, 0.f) forceLayout:YES];
    }
}

- (void)removeAllComponents{
    if (_isInitCalculate) {
        return;
    }
    
    if (_isLayouting) {
        __weak typeof(self)_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(_self)self = _self;
            //在布局期间发生更新，下一个runloop进行更新
            [self removeAllComponents];
        });
    } else {
        for (CCModel *model in _allComponentsModels.objectEnumerator) {
            [model resetComponentState];
            [self _enqueueViewOfModel:model removeUnReusableView:YES];
        }
        [_allComponentsModels removeAllObjects];
        [self _initAutoCalculateComponentFrame];
        [self _detailComponentsDidUpdateWithOffsetTop:0.f forceLayout:YES];
    }
}

- (void)layoutWithComponentModels:(NSArray <CCModel *> *)componentModels {
    if (_isInitCalculate || !componentModels || componentModels.count <= 0) {
        return;
    }

    if (_isLayouting) {
        __weak typeof(self)_self = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(_self)self = _self;
            //在布局期间发生更新，下一个runloop进行更新
            [self layoutWithComponentModels:componentModels];
        });
    } else {
        [_allComponentsModels removeAllObjects];
        for (CCModel *model in componentModels) {
            [_allComponentsModels setObject:model forKey:[model componentIndex]];
        }
        //需要计算contentSize的，以及位置布局
        [self _initAutoCalculateComponentFrame];
        //更新组件信息后，强制更新所有
        [self _detailComponentsDidUpdateWithOffsetTop:MAX(_scrollView.contentOffset.y, 0.f) forceLayout:YES];
    }
}

#pragma mark - scroll

- (void)scrollToComponentView:(CCView *)componentView atOffset:(CGFloat)offsetY animated:(BOOL)animated {
    NSString *componentIndex = [componentView componentViewId];
    if (!componentIndex || componentIndex.length <= 0) {
        return;
    }
    [self _scrollToComponentIndex:componentIndex atOffset:offsetY animated:animated];
}

- (void)scrollToComponentModel:(CCModel *)componentModel atOffset:(CGFloat)offsetY animated:(BOOL)animated {
    NSString *componentIndex = [componentModel componentIndex];
    if (!componentIndex || componentIndex.length <= 0) {
        return;
    }
    [self _scrollToComponentIndex:componentIndex atOffset:offsetY animated:animated];
}

- (void)scrollToContentOffset:(CGPoint)toContentOffset animated:(BOOL)animated {
    [self _scrollToContentOffset:toContentOffset animated:animated];
}

#pragma mark - get View or Model

- (NSArray <CCModel *> *)getAllComponentModels {
    return [[_allComponentsModels objectEnumerator] allObjects];
}

//get visible
- (NSArray <CCView *> *)getVisibleComponentViews {
    return [[_visibleComponentViews objectEnumerator] allObjects];
}

- (NSArray <CCModel *> *)getVisibleComponentModels {
    NSMutableArray *visibleComponents = @[].mutableCopy;
    for (CCModel *model in [_allComponentsModels objectEnumerator]) {
        if (model.componentNewState == kCCStateVisible) {
            [visibleComponents addObject:model];
        }
    }
    return visibleComponents.copy;
}

//get model
- (CCModel *)getComponentModelByComponentView:(CCView *)componentView {
    return [self getComponentModelByIndex:[componentView componentViewId]];
}

- (CCModel *)getComponentModelByIndex:(NSString *)componentIndex {
    if (!componentIndex || componentIndex.length <= 0) {
        return nil;
    }
    return [_allComponentsModels objectForKey:componentIndex];
}

//get view
- (CCView *)getComponentViewByComponentModel:(CCModel *)componentModel {
    return [self getComponentViewByIndex:[componentModel componentIndex]];
}

- (CCView *)getComponentViewByIndex:(NSString *)componentIndex {
    if (!componentIndex || componentIndex.length <= 0) {
        return nil;
    }
    return [_visibleComponentViews objectForKey:componentIndex];
}

@end
