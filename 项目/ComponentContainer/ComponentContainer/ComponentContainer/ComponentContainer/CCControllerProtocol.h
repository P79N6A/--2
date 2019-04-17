//
// CCControllerProtocol.h
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


#ifndef CCControllerProtocol_h
#define CCControllerProtocol_h

#import <WebKit/WebKit.h>
#import "CCViewProtocol.h"
#import "CCModelProtocol.h"

NS_ASSUME_NONNULL_BEGIN

#define CCController NSObject<CCControllerProtocol>

#define ISCCControl(value) ([value conformsToProtocol:@protocol(CCControllerProtocol)])

/**
 页面包含默认webview时，webview相关回调
 */
@protocol CCDefaultWebViewProtocol

@optional
//webview main delegate实现
- (void)webViewDecidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (void)webViewDecidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler;
- (void)webViewDidReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *_Nullable credential))completionHandler;

//系统webview回调，广播全部component controller
- (void)webViewDidStartProvisionalNavigation:(WKNavigation *)navigation;
- (void)webViewDidReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation;
- (void)webViewDidFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)webViewDidCommitNavigation:(WKNavigation *)navigation;
- (void)webViewDidFinishNavigation:(WKNavigation *)navigation;
- (void)webViewDidFailNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)webViewDidTerminate;

//自定义webview回调，广播全部component controller
- (void)webViewDidInitialized;
- (void)webViewWillShowWithAnimation;
- (void)webViewDidShowWithAnimation;
- (void)webViewContentSizeChangeWithNewSize:(NSValue *)newSizeValue oldSize:(NSValue *)oldSizeValue;
- (void)webViewWillLayoutWebComponent;

@end

//_______________________________________________________________________________________________________________
//_______________________________________________________________________________________________________________

/**
 * 底层页Component组件Controller的protocol
 */
@protocol CCControllerProtocol<CCDefaultWebViewProtocol>

@optional

/**
 返回当前component controller支持的component类型
 非广播类的protocol通过model类型触发对应controller响应protocol
 */
- (nullable NSArray<Class> *)supportComponentModelClass;

/**
 页面内滚动不重用的Component，返回model对应view
 view需要手动管理
 */
- (nullable CCView *)unReusableComponentViewWithModel:(CCModel *)componentModel;

/**
 页面内滚动重用的Component，返回model对应view class ，
 view自动管理
 */
- (nullable Class)reusableComponentViewClassWithModel:(CCModel *)componentModel;

/**
 view controller 生命周期相关回调
 */
- (void)controllerViewWillAppear;
- (void)controllerViewDidAppear;
- (void)controllerViewWillDisappear;
- (void)controllerViewDidDisappear;

/**
 系统通知相关回调
 */
- (void)controllerReceiveMemoryWarning;
- (void)applicationDidBecomeActive;
- (void)applicationWillResignActive;

/**
 滚动过程中状态切换回调
 */
- (void)scrollViewWillDisplayComponentView:(CCView *)componentView
                            componentModel:(CCModel *)componentModel;

- (void)scrollViewEndDisplayComponentView:(CCView *)componentView
                           componentModel:(CCModel *)componentModel;

- (void)scrollViewWillPrepareComponentView:(CCView *)componentView
                            componentModel:(CCModel *)componentModel;

- (void)scrollViewEndPrepareComponentView:(CCView *)componentView
                           componentModel:(CCModel *)componentModel;

- (void)scrollViewRelayoutComponentView:(CCView *)componentView
                         componentModel:(CCModel *)componentModel;

/**
 滚动前原始位置计算结束回调
 */
- (void)scrollViewFinishCalculateFrameWithComponentView:(CCView *)componentView
                                         componentModel:(CCModel *)componentModel;

@end

NS_ASSUME_NONNULL_END

#endif /* CCControllerProtocol_h */
