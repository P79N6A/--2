//
// CCWebViewDelegateTests.m
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

#import <XCTest/XCTest.h>
#import "CCWebView.h"

typedef WKNavigationActionPolicy (^CCWebViewDelegateDecidePolicyBlock)(void);
typedef void (^CCWebViewDelegateFinishNavigationBlock)(WKNavigation *navigation);
typedef void (^CCWebViewDelegateFailNavigationBlock)(NSError *error);

@interface CCWebViewDelegate : NSObject<WKNavigationDelegate>
@property (nonatomic, copy, readwrite) CCWebViewDelegateDecidePolicyBlock decidePolicyBlock;
@property (nonatomic, copy, readwrite) CCWebViewDelegateFinishNavigationBlock finishNavigationBlock;
@property (nonatomic, copy, readwrite) CCWebViewDelegateFailNavigationBlock failNavigationBlock;
@end
@implementation CCWebViewDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (_decidePolicyBlock) {
        decisionHandler(_decidePolicyBlock());
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    if (_finishNavigationBlock) {
        _finishNavigationBlock(navigation);
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if (_failNavigationBlock) {
        _failNavigationBlock(error);
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if (_failNavigationBlock) {
        _failNavigationBlock(error);
    }
}

@end

@interface CCWebViewDelegateTests : XCTestCase

@property (nonatomic, strong, readwrite) CCWebView *webView;
@property (nonatomic, strong, readwrite) CCWebViewDelegate *mainDelegate;
@property (nonatomic, strong, readwrite) CCWebViewDelegate *secondaryDelegate;
@end

@implementation CCWebViewDelegateTests

- (void)setUp {
    _webView = [[CCWebView alloc]initWithFrame:CGRectZero];
    _mainDelegate = [[CCWebViewDelegate alloc] init];
    _secondaryDelegate = [[CCWebViewDelegate alloc] init];
}

- (void)tearDown {
}

- (void)testWebViewDelegate {
    [_webView useExternalNavigationDelegateAndWithDefaultUIDelegate:YES];
    [_webView setMainNavigationDelegate:_mainDelegate];
    XCTAssertNotEqualObjects(_mainDelegate, _webView.navigationDelegate);
    [_webView addSecondaryNavigationDelegate:_secondaryDelegate];
    XCTAssertNotEqualObjects(_secondaryDelegate, _webView.navigationDelegate);

    XCTestExpectation *expectation = [self expectationWithDescription:@(__LINE__).stringValue];
    [_mainDelegate setDecidePolicyBlock:^WKNavigationActionPolicy {
        return WKNavigationActionPolicyAllow;
    }];
    [_secondaryDelegate setDecidePolicyBlock:^WKNavigationActionPolicy {
        return WKNavigationActionPolicyCancel;
    }];
    [_secondaryDelegate setFinishNavigationBlock:^(WKNavigation *navigation) {
        [expectation fulfill];
    }];

    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://httpbin.org/"]]];
    [self waitForExpectationsWithTimeout:10 * 60 handler:nil];
}

@end
