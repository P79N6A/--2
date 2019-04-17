//
// CCWebViewReuseTests.m
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
#import "CCPageManager.h"
#import "WKWebView + CCReusable.h"

@interface TestWebView : CCWebView
@end
@implementation TestWebView
@end

@interface CCWebViewReuseTests : XCTestCase

@property (nonatomic, weak, readwrite) CCWebView *webView1;
@property (nonatomic, weak, readwrite) CCWebView *webView2;
@property (nonatomic, weak, readwrite) CCWebView *webView3;

@end

@implementation CCWebViewReuseTests

- (void)testReusableWebView {
    //常规取
    _webView1 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:self];
    XCTAssertNotNil(_webView1);
    XCTAssertTrue([_webView1 isMemberOfClass:[TestWebView class]]);

    _webView2 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[CCWebView class] webViewHolder:self];
    XCTAssertNotNil(_webView2);
    XCTAssertTrue([_webView2 isMemberOfClass:[CCWebView class]]);
    XCTAssertNotEqualObjects(_webView1, _webView2);

    //回收
    [[CCPageManager sharedInstance] enqueueWebView:_webView1];
    _webView3 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:self];
    XCTAssertEqual(_webView3.reusedTimes, 2);
    XCTAssertEqualObjects(_webView1, _webView3);

    //回收
    [[CCPageManager sharedInstance] enqueueWebView:_webView1];
    _webView3 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[CCWebView class] webViewHolder:self];
    XCTAssertNotEqualObjects(_webView1, _webView3);

    //删除
    [[CCPageManager sharedInstance] removeReusableWebView:_webView1];
    _webView3 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:self];
    XCTAssertNotEqualObjects(_webView1, _webView3);
    
    //invalid
    _webView3.invalid = YES;
    [[CCPageManager sharedInstance] enqueueWebView:_webView3];
    _webView1 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:self];
    XCTAssertNotEqualObjects(_webView1, _webView3);
    
    //auto recyle
    NSObject *temHolder = [[NSObject alloc] init];
    _webView1 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:temHolder];
    temHolder = nil;
    _webView2 = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[TestWebView class] webViewHolder:self];
    XCTAssertEqualObjects(_webView1, _webView2);
}

@end
