//
// CCPageHandler.m
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

#import "CCPageHandler.h"
#import "CCScrollProcessor.h"
#import "_CCAspects.h"
#import "_CCUtils.h"
#import "CCDefaultWebViewControl.h"
#import "CCWebViewExtensionDelegate.h"

NSString *const kCCWebViewComponentIndex = @"index";
NSString *const kCCWebViewComponentHeight = @"height";
NSString *const kCCWebViewComponentWidth = @"width";
NSString *const kCCWebViewComponentLeft = @"left";
NSString *const kCCWebViewComponentTop = @"top";

typedef NS_ENUM (NSInteger, CCControllerEvent) {
    //controller
    kCCControllerEventViewWillAppear,
    kCCControllerEventViewDidAppear,
    kCCControllerEventViewWillDisappear,
    kCCControllerEventViewDidDisappear,
    kCCControllerEventReceiveMemoryWarning,
    kCCControllerEventApplicationDidBecomeActive,
    kCCControllerEventApplicationWillResignActive,
};

static inline SEL _getCCControllerProtocolByEventType(CCControllerEvent event) {
    SEL mapping[] = {
        [kCCControllerEventViewWillAppear] = @selector(controllerViewWillAppear),
        [kCCControllerEventViewDidAppear] = @selector(controllerViewDidAppear),
        [kCCControllerEventViewWillDisappear] = @selector(controllerViewWillDisappear),
        [kCCControllerEventViewDidDisappear] = @selector(controllerViewDidDisappear),
        [kCCControllerEventReceiveMemoryWarning] = @selector(controllerReceiveMemoryWarning),
        [kCCControllerEventApplicationDidBecomeActive] = @selector(applicationDidBecomeActive),
        [kCCControllerEventApplicationWillResignActive] = @selector(applicationWillResignActive),
    };
    return mapping[event];
}

@interface CCPageHandler ()

@property (nonatomic, weak, readwrite) __kindof UIViewController *weakController;
@property (nonatomic, weak, readwrite) __kindof UIScrollView *containerScrollView;
@property (nonatomic, weak, readwrite) __kindof WKWebView *webView;

@property (nonatomic, strong, readwrite) CCScrollProcessor *contentViewScrollHandler; //components滚动管理
@property (nonatomic, strong, readwrite) CCScrollProcessor *webViewScrollHandler;     //webComponents滚动管理

@property (nonatomic, strong, readwrite) CCDefaultWebViewControl *defaultWebViewControl;  //默认webview的生成与管理
@property (nonatomic, strong, readwrite) CCWebViewExtensionDelegate *extensionDelegate;   //webview extension delegate

@property (nonatomic, copy, readwrite) NSArray<CCModel *> *componentModels;
@property (nonatomic, copy, readwrite) NSArray<CCModel *> *webComponentModels;

@property (nonatomic, copy, readwrite) NSArray<CCController *> *componentControllers;
@property (nonatomic, strong, readwrite) NSMapTable<NSString *, CCController *> *componentControllerMap;

@property (nonatomic, copy, readwrite) NSString *componentDomClassStr;
@property (nonatomic, copy, readwrite) NSString *componentIndexKeyStr;

@end

@implementation CCPageHandler

#pragma mark - lift cycle

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_handleReceiveMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    self.weakController = nil;
    self.containerScrollView = nil;
    self.webViewScrollHandler = nil;
    self.contentViewScrollHandler = nil;
    self.componentControllerMap = nil;
    self.componentControllers = nil;
    self.extensionDelegate = nil;
    //noti and KVO
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - public method

- (void)configWithViewController:(__kindof UIViewController *)viewController
           componentsControllers:(NSArray<CCController *> *)componentsControllers {
    [self _configViewController:viewController];
    [self _configComponentsControllers:componentsControllers];
}

- (void)handleSingleScrollView:(__kindof UIScrollView *)scrollView {
    if (!scrollView) {
        CCFatalLog(@"CCPageHandler handle scrollview wiht invalid params!");
        return;
    }

    self.containerScrollView = scrollView;
    //components
    __weak typeof(self)_self = self;
    self.contentViewScrollHandler = [[CCScrollProcessor alloc] initWithScrollView:self.containerScrollView
                                                                       layoutType:kCCLayoutTypeAutoCalculateFrame
                                                              scrollDelegateBlock:^NSObject<CCControllerProtocol> *(CCModel *model, BOOL isGetViewEvent) {
        __strong typeof(_self) self = _self;
        //默认的WebView特殊处理下
        if (isGetViewEvent && self.defaultWebViewControl && model == self.defaultWebViewControl.defaultWebViewModel) {
            return self.defaultWebViewControl;
        } else {
            return [self.componentControllerMap objectForKey:NSStringFromClass([model class])];
        }
    }];
}

- (void)handleSingleWebView:(__kindof WKWebView *)webView
       webComponentDomClass:(NSString *)webComponentDomClass
       webComponentIndexKey:(NSString *)webComponentIndexKey {
    if (!webView) {
        CCFatalLog(@"CCPageHandler handle webview wiht invalid params!");
        return;
    }

    self.webView = webView;
    __weak typeof(self)_self = self;
    self.webViewScrollHandler = [[CCScrollProcessor alloc] initWithScrollView:webView.scrollView
                                                                   layoutType:kCCLayoutTypeManualCalculateFrame
                                                          scrollDelegateBlock:^NSObject<CCControllerProtocol> *(CCModel *model, BOOL isGetViewEvent) {
        __strong typeof(_self) self = _self;
        return [self.componentControllerMap objectForKey:NSStringFromClass([model class])];
    }];

    _componentDomClassStr = webComponentDomClass;
    _componentIndexKeyStr = webComponentIndexKey;
}

- (void)handleHybridPageWithContainerScrollView:(__kindof UIScrollView *)containerScrollView
                            defaultWebViewClass:(Class)defaultWebViewClass
                            defaultWebViewIndex:(NSInteger)defaultWebViewIndex
                           webComponentDomClass:(NSString *)webComponentDomClass
                           webComponentIndexKey:(NSString *)webComponentIndexKey {
    if (!containerScrollView) {
        CCFatalLog(@"CCPageHandler handle hybrid page wiht invalid params!");
        return;
    }

    [self handleSingleScrollView:containerScrollView];

    _defaultWebViewControl = [[CCDefaultWebViewControl alloc] initWithDetailHandler:self defaultWebViewClass:defaultWebViewClass defaultWebViewIndex:defaultWebViewIndex];

    self.webView = _defaultWebViewControl.defaultWebView;
    self.containerScrollView = containerScrollView;

    [self handleSingleWebView:self.webView webComponentDomClass:webComponentDomClass webComponentIndexKey:webComponentIndexKey];
}

- (NSObject<WKNavigationDelegate> *)replaceExtensionDelegateWithOriginalDelegate:(nullable NSObject<CCDefaultWebViewProtocol> *)originalDelegate {
    if (!self.webView) {
        CCFatalLog(@"CCPageHandler should first init webview");
        return nil;
    }

    _extensionDelegate = [[CCWebViewExtensionDelegate alloc] initWithOriginalDelegate:originalDelegate navigationDelegates:[self allComponentControllers]];

    __weak typeof(self)_self = self;
    [_extensionDelegate configWebView:self.webView contentSizeChangeBlock:^(NSValue *newValue, NSValue *oldValue) {
        __strong typeof(_self) self = _self;
        CGSize newSize = [newValue CGSizeValue];
        CGSize oldSize = [oldValue CGSizeValue];
        if (!CGSizeEqualToSize(oldSize, newSize)) {
            [self relayoutWithWebComponentChange];
        }
    }];

    return _extensionDelegate;
}

#pragma mark -

- (void)relayoutWithComponentChange {
    [self.contentViewScrollHandler relayoutWithComponentFrameChange];
}

- (void)relayoutWithWebComponentChange {
    [self layoutWithWebComponentModels:_webComponentModels];
}

- (void)layoutWithComponentModels:(NSArray<CCModel *> *)componentModels {
    if (!componentModels) {
        componentModels = @[];
    }

    if (_defaultWebViewControl && _defaultWebViewControl.defaultWebViewModel) {
        NSMutableArray *componentModelsTmp = componentModels.mutableCopy;
        [componentModelsTmp addObject:_defaultWebViewControl.defaultWebViewModel];
        _componentModels = [componentModelsTmp copy];
        [self.contentViewScrollHandler layoutWithComponentModels:_componentModels];
    } else {
        _componentModels = componentModels;
        [self.contentViewScrollHandler layoutWithComponentModels:_componentModels];
    }
}

- (void)layoutWithAddComponentModel:(CCModel *)componentModel {
    if (!componentModel) {
        return;
    }

    if (!_componentModels) {
        _componentModels = @[];
    }

    NSMutableArray *componentModelsTmp = _componentModels.mutableCopy;
    [componentModelsTmp addObject:componentModel];
    _componentModels = [componentModelsTmp copy];
    [self.contentViewScrollHandler layoutWithComponentModels:_componentModels];
}

- (void)layoutWithRemoveComponentModel:(CCModel *)componentModel{
    if (!componentModel) {
        return;
    }
    
    if (!_componentModels || ![_componentModels containsObject:componentModel]) {
        return;
    }
    
    NSMutableArray *componentModelsTmp = _componentModels.mutableCopy;
    [componentModelsTmp removeObject:componentModel];
    _componentModels = [componentModelsTmp copy];
    [_contentViewScrollHandler removeComponentModelAndRelayout:componentModel];
}

- (void)removeAllComponents{
    
    if (!_componentModels || _componentModels.count == 0) {
        return;
    }
    
    [_contentViewScrollHandler removeAllComponents];
}

- (void)layoutWithWebComponentModels:(NSArray<CCModel *> *)componentModels {
    if (!componentModels || componentModels.count <= 0) {
        if (_extensionDelegate) {
            //如果使用delegate扩展，广播方法
            [_extensionDelegate triggerRelayoutWebComponentEvent];
        }
        return;
    }

    self.webComponentModels = componentModels;

    NSString *jsStr = [self _detectComponentsFrameJS];

    if (!jsStr || jsStr.length <= 0) {
        return;
    }

    [self.webView safeAsyncEvaluateJavaScriptString:jsStr completionBlock:^(NSObject *result) {
        __unused __attribute__((objc_ownership(strong))) __typeof__(self) self_retain_ = self;

        if (![result isKindOfClass:[NSArray class]]) {
            return;
        }

        NSArray *componentsFrameArray = (NSArray *)result;

        for (NSObject *frameInfoObj in componentsFrameArray) {
            if (![frameInfoObj isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *frameInfo = (NSDictionary *)frameInfoObj;
            NSString *componentId = [[frameInfo objectForKey:kCCWebViewComponentIndex] isKindOfClass:[NSString class]] ? (NSString *)[frameInfo objectForKey:kCCWebViewComponentIndex] : @"";
            CGRect componentRect = CGRectMake([frameInfo[kCCWebViewComponentLeft] isKindOfClass:[NSNumber class]] ?
                                              ((NSNumber *)frameInfo[kCCWebViewComponentLeft]).floatValue : 0.f,
                                              [frameInfo[kCCWebViewComponentTop] isKindOfClass:[NSNumber class]] ?
                                              ((NSNumber *)frameInfo[kCCWebViewComponentTop]).floatValue : 0.f,
                                              [frameInfo[kCCWebViewComponentWidth] isKindOfClass:[NSNumber class]] ?
                                              ((NSNumber *)frameInfo[kCCWebViewComponentWidth]).floatValue : 0.f,
                                              [frameInfo[kCCWebViewComponentHeight] isKindOfClass:[NSNumber class]] ?
                                              ((NSNumber *)frameInfo[kCCWebViewComponentHeight]).floatValue : 0.f);

            [self.webComponentModels enumerateObjectsUsingBlock:^(NSObject<CCModelProtocol> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                CCModel *model = obj;
                if (componentId && [[model componentIndex] isEqualToString:componentId]) {
                    [model setComponentFrame:componentRect];
                    *stop = YES;
                }
            }];
        }
        [self.webViewScrollHandler layoutWithComponentModels:self.webComponentModels];
    }];

    if (_extensionDelegate) {
        //如果使用delegate扩展，广播方法
        [_extensionDelegate triggerRelayoutWebComponentEvent];
    }
}

- (void)reLayoutWebViewComponentsWithNode:(NSObject *)node
                            componentSize:(CGSize)componentSize
                               marginLeft:(CGFloat)marginLeft {
    if (ISCCModel(node)) {
        if (!CGSizeEqualToSize([((CCModel *)node) componentFrame].size, componentSize)) {
            NSString *jsStr = [self _setComponentJSWithWithIndex:((CCModel *)node).componentIndex componentSize:componentSize left:marginLeft];

            if (!jsStr || jsStr.length <= 0) {
                return;
            }

            [self.webView safeAsyncEvaluateJavaScriptString:jsStr
                                            completionBlock:^(NSObject *result) {
                __unused __attribute__((objc_ownership(strong))) __typeof__(self) self_retain_ = self;
                [self relayoutWithWebComponentChange];
            }];
        }
    }
}

- (NSArray<CCModel *> *)allComponentModels{
    return [self.contentViewScrollHandler getAllComponentModels] ? : @[];
}

- (NSArray<CCModel *> *)allWebComponentModels{
    return [self.webViewScrollHandler getAllComponentModels] ? : @[];
}

- (NSArray<CCModel *> *)allVisibleComponentModels {
    return [self.contentViewScrollHandler getVisibleComponentModels] ? : @[];
}

- (NSArray<CCModel *> *)allVisibleWebComponentModels {
    return [self.webViewScrollHandler getVisibleComponentModels] ? : @[];
}

- (NSArray<CCView *> *)allVisibleComponentViews {
    return [self.contentViewScrollHandler getVisibleComponentViews] ? : @[];
}

- (NSArray<CCView *> *)allVisibleWebComponentViews {
    return [self.webViewScrollHandler getVisibleComponentViews] ? : @[];
}

- (NSArray<CCController *> *)allComponentControllers {
    return _componentControllers;
}

- (void)getAllWebComponentDomFrameWithCompletionBlock:(CCWebViewJSCompletionBlock)completionBlock{
    NSString *jsStr = [self _detectComponentsFrameJS];
    if (!jsStr || jsStr.length <= 0) {
        CCFatalLog(@"CCPageHandler get all web component failed %@, %@",_componentDomClassStr ,_componentIndexKeyStr);
        return;
    }
    [self.webView safeAsyncEvaluateJavaScriptString:jsStr completionBlock:completionBlock];
}

#pragma mark -

- (void)triggerEvent:(CCControllerEvent)event {
    SEL protocolSelector = _getCCControllerProtocolByEventType(event);
    if (!protocolSelector) {
        CCFatalLog(@"CCPageHandler trigger invalid event:%@", @(event));
        return;
    }

    for (__kindof NSObject<CCControllerProtocol> *component in _componentControllers) {
        [self _componentController:component performSelector:protocolSelector withObject:nil withObject:nil];
    }
}

- (void)triggerSelector:(SEL)selector toComponentController:(CCController *)toComponentController para1:(NSObject *)para1 para2:(NSObject *)para2 {
    if (!selector || !toComponentController) {
        return;
    }
    [self _componentController:toComponentController performSelector:selector withObject:para1 withObject:para2];
}

- (void)triggerBroadcastSelector:(SEL)selector para1:(NSObject *)para1 para2:(NSObject *)para2 {
    if (!selector) {
        return;
    }

    for (__kindof NSObject<CCControllerProtocol> *component in _componentControllers) {
        [self _componentController:component performSelector:selector withObject:para1 withObject:para2];
    }
}

- (void)scrollToContentOffset:(CGPoint)toContentOffset animated:(BOOL)animated {
    [self.contentViewScrollHandler scrollToContentOffset:toContentOffset animated:animated];
}

- (void)scrollToComponentView:(CCView *)elementView
                     atOffset:(CGFloat)offsetY
                     animated:(BOOL)animated {
    [self.contentViewScrollHandler scrollToComponentView:elementView atOffset:offsetY animated:animated];
}

- (void)resetDefaultWebView {
    CCInfoLog(@"CCPageHandler begin reset default webview");
    [_contentViewScrollHandler removeComponentModelAndRelayout:_defaultWebViewControl.defaultWebViewModel];
    [_defaultWebViewControl resetWebView];
    [_contentViewScrollHandler addComponentModelAndRelayout:_defaultWebViewControl.defaultWebViewModel];
    self.webView = _defaultWebViewControl.defaultWebView;
    __weak typeof(self)_self = self;
    self.webViewScrollHandler = [[CCScrollProcessor alloc] initWithScrollView:self.webView.scrollView
                                                                   layoutType:kCCLayoutTypeManualCalculateFrame
                                                          scrollDelegateBlock:^NSObject<CCControllerProtocol> *(CCModel *model, BOOL isGetViewEvent) {
                                                              __strong typeof(_self) self = _self;
                                                              return [self.componentControllerMap objectForKey:NSStringFromClass([model class])];
                                                          }];
}

- (void)setLastReadPositionY:(CGFloat)positionY {
    __weak typeof(self)_self = self;
    [_extensionDelegate configWebViewLastReadPositionY:positionY scrollBlock:^(CGPoint offset) {
        __strong typeof(_self) self = _self;
        CGPoint scrollToOffset = CGPointMake(offset.x, MIN(offset.y, self.containerScrollView.contentSize.height - self.containerScrollView.frame.size.height));
        [self scrollToContentOffset:scrollToOffset animated:NO];
    }];
}

#pragma mark - private method

- (void)_configViewController:(__kindof UIViewController *)viewController {
    self.weakController = viewController;

    __weak typeof(self)_self = self;
    [self.weakController CC_aspect_hookSelector:@selector(viewWillAppear:)
                                    withOptions:AspectPositionAfter
                                     usingBlock:^(id<CC_AspectInfo> info, BOOL animated) {
        __strong typeof(_self) self = _self;
        [self triggerEvent:kCCControllerEventViewWillAppear];
    } error:nil];
    [self.weakController CC_aspect_hookSelector:@selector(viewDidAppear:)
                                    withOptions:AspectPositionAfter
                                     usingBlock:^(id<CC_AspectInfo> info, BOOL animated) {
        __strong typeof(_self) self = _self;
        [self triggerEvent:kCCControllerEventViewDidAppear];
    } error:nil];
    [self.weakController CC_aspect_hookSelector:@selector(viewWillDisappear:)
                                    withOptions:AspectPositionAfter
                                     usingBlock:^(id<CC_AspectInfo> info, BOOL animated) {
        __strong typeof(_self) self = _self;
        [self triggerEvent:kCCControllerEventViewWillDisappear];
    } error:nil];
    [self.weakController CC_aspect_hookSelector:@selector(viewDidDisappear:)
                                    withOptions:AspectPositionAfter
                                     usingBlock:^(id<CC_AspectInfo> info, BOOL animated) {
        __strong typeof(_self) self = _self;
        [self triggerEvent:kCCControllerEventViewDidDisappear];
    } error:nil];
}

- (void)_configComponentsControllers:(NSArray<CCController *> *)componentsControllers {
    if (!componentsControllers || componentsControllers.count <= 0) {
        CCFatalLog(@"CCPageHandler config wiht invalid params!");
        return;
    }

    _componentControllers = [componentsControllers copy];
    _componentControllerMap = [NSMapTable strongToWeakObjectsMapTable];

    for (NSObject *control in componentsControllers) {
        //数据校验
        if (!ISCCControl(control)) {
            CCFatalLog(@"CCPageHandler has invalid components controls ");
            continue;
        }

        CCController *componentControl;
        if ([control isKindOfClass:[CCController class]]) {
            componentControl = (CCController *)control;
        }

        if ([componentControl respondsToSelector:@selector(supportComponentModelClass)]) {
            NSArray<Class> *modelClass = [componentControl supportComponentModelClass];
            for (Class cls in modelClass) {
                NSString *classString = NSStringFromClass(cls);
                if ([[[_componentControllerMap keyEnumerator] allObjects] containsObject:classString]) {
                    CCFatalLog(@"CCHandler invalid support model class");
                }
                [_componentControllerMap setObject:componentControl forKey:classString];
            }
        }
    }
}

- (void)_componentController:(CCController *)componentController
             performSelector:(SEL)aSelector
                  withObject:(NSObject *)object1
                  withObject:(NSObject *)object2 {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([componentController respondsToSelector:aSelector]) {
        [componentController performSelector:aSelector withObject:object1 withObject:object2];
    }
#pragma clang diagnostic pop
}

- (void)_handleReceiveMemoryWarning {
    [self triggerEvent:kCCControllerEventReceiveMemoryWarning];
}

- (void)_handleBecomeActive {
    [self triggerEvent:kCCControllerEventApplicationDidBecomeActive];
}

- (void)_handleResignActive {
    [self triggerEvent:kCCControllerEventApplicationWillResignActive];
}

- (NSString *)_detectComponentsFrameJS {
    if (!_componentDomClassStr || !_componentIndexKeyStr) {
        return nil;
    }
    //通过className和attribute取frame
    return [NSString stringWithFormat:@"(function(){var componentFrameDic=[];var list= document.getElementsByClassName('%@');for(var i=0;i<list.length;i++){var dom = list[i];componentFrameDic.push({'%@':dom.getAttribute('%@'),'%@':dom.offsetTop,'%@':dom.offsetLeft,'%@':dom.clientWidth,'%@':dom.clientHeight});}return componentFrameDic;}())", _componentDomClassStr, kCCWebViewComponentIndex, _componentIndexKeyStr, kCCWebViewComponentTop, kCCWebViewComponentLeft, kCCWebViewComponentWidth, kCCWebViewComponentHeight];
}

- (NSString *)_setComponentJSWithWithIndex:(NSString *)index componentSize:(CGSize)componentSize left:(CGFloat)left {
    if (!_componentDomClassStr || !_componentIndexKeyStr || index.length <= 0) {
        return nil;
    }
    //通过className和attribute设置frame
    return [NSString stringWithFormat:@"[].forEach.call(document.getElementsByClassName('%@'), function (dom) {if(dom.getAttribute('%@') == '%@'){dom.style.width='%@px';dom.style.height='%@px';%@}});", _componentDomClassStr, _componentIndexKeyStr, index, @(componentSize.width), @(componentSize.height), ((left != 0.f) ? [NSString stringWithFormat:@"dom.style.marginLeft='%@px';", @(left)] : @"")];
}

@end
