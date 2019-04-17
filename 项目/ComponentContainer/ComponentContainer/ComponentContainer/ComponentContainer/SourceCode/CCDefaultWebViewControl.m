//
// CCDefaultWebViewControl.m
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


#import "CCDefaultWebViewControl.h"
#import "CCPageManager.h"
#import "CCWebViewExtensionDelegate.h"
#import "CCWebViewPool.h"
#import "CCPageHandler.h"
#import "_CCUtils.h"

@interface CCDefaultWebViewModel : NSObject<CCModelProtocol>
@end
@implementation CCDefaultWebViewModel
IMP_CCModelProtocol(@"")
@end

@interface CCDefaultWebViewControl ()

@property (nonatomic, weak, readwrite) CCPageHandler *handler;
@property (nonatomic, assign, readwrite) Class webViewClass;

@property (nonatomic, strong, readwrite) __kindof CCWebView *defaultWebView;
@property (nonatomic, strong, readwrite) CCModel *defaultWebViewModel;

@end

@implementation CCDefaultWebViewControl

- (void)dealloc {
    CCInfoLog(@"CCDefaultWebViewControl dealloc with webview contentSize: %@, invalid: %@", NSStringFromCGSize(self.defaultWebView.scrollView.contentSize), @(self.defaultWebView.invalidForReuse));
    [[CCWebViewPool sharedInstance] enqueueWebView:self.defaultWebView];
}

- (instancetype)initWithDetailHandler:(CCPageHandler *)detailHandler
                  defaultWebViewClass:(Class)webViewClass
                  defaultWebViewIndex:(NSInteger)defaultWebViewIndex {
    self = [super init];
    if (self) {
        self.handler = detailHandler;
        self.webViewClass = webViewClass;

        _defaultWebViewModel = [[CCDefaultWebViewModel alloc] init];
        [_defaultWebViewModel setComponentIndex:@(defaultWebViewIndex).stringValue];

        [self _commonInitWebView];
    }
    return self;
}

- (void)resetWebView {
    //销毁当前的webview及回收池
    [_defaultWebView componentViewWillEnterPool];
    [_defaultWebView removeFromSuperview];
    [[CCWebViewPool sharedInstance] removeReusableWebView:_defaultWebView];
    [[CCWebViewPool sharedInstance] clearAllReusableWebViews];

    [_defaultWebViewModel resetComponentState];
    //重新创建webview
    [self _commonInitWebView];
    CCInfoLog(@"CCDefaultWebViewControl reset webview");
}

#pragma mark - private method
- (void)_commonInitWebView {
    _defaultWebView = nil;
    _defaultWebView = [[CCWebViewPool sharedInstance] dequeueWebViewWithClass:self.webViewClass webViewHolder:self];
    _defaultWebView.frame = CGRectMake(0, 0, self.handler.containerScrollView.frame.size.width, self.handler.containerScrollView.frame.size.height);
    _defaultWebView.scrollView.scrollEnabled = NO;
}

#pragma mark - CCControllerProtocol

- (nullable CCView *)unReusableComponentViewWithModel:(CCModel *)componentModel {
    return _defaultWebView;
}

@end
