//
// CCPageHandler.h
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


#import "CCControllerProtocol.h"
#import "CCWebView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * CCPageHandler处理component的滚动及事件通信
 */
@interface CCPageHandler : NSObject

@property (nonatomic, weak, readonly) __kindof UIViewController *weakController;              //handler对应的weak controller
@property (nonatomic, weak, readonly) __kindof UIScrollView *containerScrollView;             //handler对应的weak container scrollview
@property (nonatomic, weak, readonly) __kindof WKWebView *webView;                            //handler对应的weak webview

#pragma mark - common init

/**
 初始化CCPageHandler

 @param viewController 当前页面的view controller
 @param componentsControllers 当前页面全部component的controllers
 */
- (void)configWithViewController:(__kindof UIViewController *)viewController
           componentsControllers:(NSArray<CCController *> *)componentsControllers;

#pragma mark - common config

/**
 处理scrollView上多个component的滚动和通信

 @param scrollView container scrollView
 */
- (void)handleSingleScrollView:(__kindof UIScrollView *)scrollView;

/**
 处理webView上多个component的滚动和通信

 @param webComponentDomClass 需要component化的dom class string
 @param webComponentIndexKey 多个同类型component 区分index
 */
- (void)handleSingleWebView:(__kindof WKWebView *)webView
       webComponentDomClass:(NSString *)webComponentDomClass
       webComponentIndexKey:(NSString *)webComponentIndexKey;

/**
 处理scrollView上多个component的滚动和通信，并且component包含webview
 同时处理webView上多个component的滚动和通信

 @param containerScrollView container scrollView
 @param defaultWebViewClass 可重用的webview class，需要继承自CCWebView
 @param defaultWebViewIndex webView作为component在container中的位置
 @param webComponentDomClass 需要component化的dom class string
 @param webComponentIndexKey 多个同类型component 区分index
 */
- (void)handleHybridPageWithContainerScrollView:(__kindof UIScrollView *)containerScrollView
                            defaultWebViewClass:(Class)defaultWebViewClass
                            defaultWebViewIndex:(NSInteger)defaultWebViewIndex
                           webComponentDomClass:(NSString *)webComponentDomClass
                           webComponentIndexKey:(NSString *)webComponentIndexKey;

/**
 使用扩展的navigation delegate，扩展更多的展示期间回调

 @param originalDelegate 原始的delegate，需要实现CCDefaultWebViewProtocol扩展协议
 @return webview新的navigation delegate
 */
- (nullable NSObject<WKNavigationDelegate> *)replaceExtensionDelegateWithOriginalDelegate:(nullable NSObject<CCDefaultWebViewProtocol> *)originalDelegate;

#pragma mark - layout components

/**
 container中/webview中 component size变化时更新
 */
- (void)relayoutWithComponentChange;
- (void)relayoutWithWebComponentChange;

/**
 container中/webview中 根据model重新布局components
 */
- (void)layoutWithComponentModels:(NSArray<CCModel *> *)componentModels;
- (void)layoutWithWebComponentModels:(NSArray<CCModel *> *)componentModels;

/**
 动态增加一个component model 并且重新布局
 webview中的component不可使用此方法
 */
- (void)layoutWithAddComponentModel:(CCModel *)componentModel;

/**
 动态删除一个component model 并且重新布局
 webview中的component不可使用此方法
 */
- (void)layoutWithRemoveComponentModel:(CCModel *)componentModel;

/**
 删除全部组件，用于当前页面切换刷新
 webview中的component不可使用此方法
 */
- (void)removeAllComponents;

/**
 动态改变webviwe中一个component的size，并重新布局

 @param node component对应的componentNode
 @param componentSize 变化后的size
 @param marginLeft 变化后的marginLeft
 */
- (void)reLayoutWebViewComponentsWithNode:(NSObject *)node
                            componentSize:(CGSize)componentSize
                               marginLeft:(CGFloat)marginLeft;

/**
 获得全部Component Models/ Web Component Models
 */
- (NSArray<CCModel *> *)allComponentModels;
- (NSArray<CCModel *> *)allWebComponentModels;

/**
 获得全部可见的Component Models/ Web Component Models
 */
- (NSArray<CCModel *> *)allVisibleComponentModels;
- (NSArray<CCModel *> *)allVisibleWebComponentModels;

/**
 获得全部可见的Component Views/ Web Component Views
 */
- (NSArray<CCView *> *)allVisibleComponentViews;
- (NSArray<CCView *> *)allVisibleWebComponentViews;

/**
 获得全部的component controllers
 */
- (NSArray<CCController *> *)allComponentControllers;

/**
 通过jS获得全部webComponent dom节点的位置
 */
- (void)getAllWebComponentDomFrameWithCompletionBlock:(CCWebViewJSCompletionBlock)completionBlock;

#pragma mark - common method

/**
 单播自定义selector到对应的component controller
 */
- (void)triggerSelector:(SEL)selector toComponentController:(CCController *)toComponentController para1:(nullable NSObject *)para1 para2:(nullable NSObject *)para2;

/**
 广播自定义selector到全部component controllers
 */
- (void)triggerBroadcastSelector:(SEL)selector para1:(nullable NSObject *)para1 para2:(nullable NSObject *)para2;

/**
 *  滚动到页面对应的offset
 */
- (void)scrollToContentOffset:(CGPoint)toContentOffset animated:(BOOL)animated;

/**
 *  滚动到对应的View，以及View相应的offset
 */
- (void)scrollToComponentView:(CCView *)elementView atOffset:(CGFloat)offsetY animated:(BOOL)animated;

/**
 如果使用default webview，从pool中获取新webview，重置当前webview
 */
- (void)resetDefaultWebView;

/**
 自动滚动到上次阅读位置
 */
- (void)setLastReadPositionY:(CGFloat)positionY;

@end

NS_ASSUME_NONNULL_END
