//
// CCPageManager.m
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


#import "CCPageManager.h"
#import "CCWebViewPool.h"
#import "WKWebView + CCExtension.h"

@implementation CCPageManager

+ (CCPageManager *)sharedInstance {
    static dispatch_once_t once;
    static CCPageManager *singleton;
    dispatch_once(&once,
                  ^{
        singleton = [[CCPageManager alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.showWebViewWithAnimation = YES;
        self.componentsPrepareWorkRange = [UIScreen mainScreen].bounds.size.height / 2;
        self.componentsMaxReuseCount = 10;
        self.webViewShowMaxRetryTimes = 50;
        self.webViewMaxReuseTimes = NSIntegerMax;
        self.webViewReuseLoadUrlStr = @"";
    }
    return self;
}

#pragma mark - CCReusableWebView

- (__kindof CCWebView *)dequeueWebViewWithClass:(Class)webViewClass webViewHolder:(NSObject *)webViewHolder {
    return [[CCWebViewPool sharedInstance] dequeueWebViewWithClass:webViewClass webViewHolder:webViewHolder];
}

- (void)enqueueWebView:(__kindof CCWebView *)webView {
    [[CCWebViewPool sharedInstance] enqueueWebView:webView];
}

- (void)removeReusableWebView:(__kindof CCWebView *)webView {
    [[CCWebViewPool sharedInstance] removeReusableWebView:webView];
}

- (void)clearAllReusableWebViews {
    [[CCWebViewPool sharedInstance] clearAllReusableWebViews];
}

- (void)clearAllReusableWebViewsWithClass:(Class)webViewClass {
    [[CCWebViewPool sharedInstance] clearAllReusableWebViewsWithClass:webViewClass];
}

- (void)reloadAllReusableWebViews {
    [[CCWebViewPool sharedInstance] reloadAllReusableWebViews];
}

#pragma mark - CCWebView

+ (void)configCustomUAWithType:(CCWebViewUAConfigType)type
                      UAString:(NSString *)customString {
    [WKWebView configCustomUAWithType:((type == kCCWebViewUAConfigTypeReplace) ? kConfigUATypeReplace : kConfigUATypeAppend)
                             UAString:customString];
}

+ (void)safeClearAllCacheIncludeiOS8:(BOOL)includeiOS8 {
    [WKWebView safeClearAllCacheIncludeiOS8:includeiOS8];
}

+ (void)fixWKWebViewMenuItems {
    [WKWebView fixWKWebViewMenuItems];
}

@end
