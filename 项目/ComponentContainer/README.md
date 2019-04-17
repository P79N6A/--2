![title_1](./Docs/Images/title.png)

---
**Component Container** 是一个针对资讯类iOS App高性能、易扩展、组件化的Hybrid资讯内容页基础框架。

它可以使开发者**快速**的搭建起`基于WebView展示资讯`、`多种异构NativeView协同滚动`、`面向业务灵活扩展复用`的资讯内容页。

作为腾讯新闻iOS核心基础框架，支撑了App内**日均亿级PV**的内容页浏览；同时面对持续的快速迭代，保持了高性能、高稳定性以及高扩展性。

<br/>

| <img src='/Docs/Images/readme_1.jpeg'>  | <img src='/Docs/Images/readme_2.jpeg'>  | <img src='/Docs/Images/readme_3.jpeg'>  | <img src='/Docs/Images/readme_4.jpeg'>  | <img src='/Docs/Images/readme_5.jpeg'>  | <img src='/Docs/Images/readme_6.jpeg'>  |
|---|---|---|---|---|---|

<br/>

## 目录

- [特性 Features](#features)
- [相关阅读 Related Links](#related-links)
- [安装 Installing](#installing)
- [基本使用 Usage](#usage)
    - [WKWebView扩展与重用](#usage-webview)
    - [NativeView实现WebView特定Dom节点](#usage-native-webview)
    - [普通内容页快速实现](#usage-common-page)
    - [包含WebView复杂内容页快速实现](#usage-hybrid-page)
    - [代码结构](#usage-architecture)
    - [Demo项目架构](#usage-demo-architecture)
- [证书 License](#license)
- [联系我们 Contact](#contact)

<br/>

<a name="features"></a>
## Features
- 多维度支持快速构建资讯内容页，覆盖多数常用业务场景和类型，使用简单、灵活稳定。
- 面向协议提供高性能的滚动视图复用回收和嵌套滚动方案，无需继承易于集成。
- 更加稳定、功能更加全面、回调更加丰富的WKWebview。
- 稳定的WKWebview复用回收机制，提升Webview加载速度。
- 整体面向业务组件化设计，解耦业务逻辑，功能模块高度独立，易于扩展维护。

<br/>

<a name="related-links"></a>
## Related Links

> 强烈建议阅读

- 了解实现Component Container架构的技术选型和优化赋能：[腾讯新闻iOS亿级PV内容页架构与优化](http://km.oa.com/group/35228/articles/show/368249)

<br/>

<a name="installing"></a>
## Installing

> 支持Carthage和CocoaPods两种集成方式

- Carthage

```objc
//通过 Carthage集成 Statically linked framework类型的 ComponentContainer
//In your Cartfile
...
git "http://git.code.oa.com/QQNews_iOS/ComponentContainer.git" "master"
...
```

- CocoaPods

```objc
//通过 ocoaPods集成私有仓库，并支持 Test specs
//In your Podfile
...
pod "ComponentContainer", :git => "http://git.code.oa.com/QQNews_iOS/ComponentContainer.git",:testspecs => ["Tests"]
...
```
<br/>

<a name="usage"></a>
## Usage

> ComponentContainer不仅提供快速搭建复杂资讯内容页的整体解决方案，同时支持多维度细分场景的灵活使用。

<a name="usage-webview"></a>
### 1. WKWebView扩展与重用

CCPageManager & CCWebView 提供基础的WebView复用回收逻辑和WKWebView的扩展功能。
<br/>
##### 1.1 根据WebView的class自动复用回收 

```objc
#import "CCPageManager.h"
...
self.webView = [[CCPageManager sharedInstance] dequeueWebViewWithClass:[CCWebViewSubClass class] webViewHolder:self];
...
```

<br/>
##### 1.2 扩展WKWebView功能

```objc
#import "CCPageManager.h"
...
[WKWebView safeClearAllCacheIncludeiOS8:YES];
...
[self.webView safeAsyncEvaluateJavaScriptString:@"navigator.userAgent"];
...
[self.webView addSecondaryNavigationDelegate:self];
...
```

<br/>

<a name="usage-native-webview"></a>
### 2. NativeView实现WebView特定Dom节点

快速替换HTML标签为Native组件，并实现页面内的滚动复用，支持异步更新等。
<br/>
##### 2.1 生成标签对应Model存储信息，实现协议宏

```objc
@interface VideoModel : NSObject<CCModelProtocol>
...
IMP_CCModelProtocol(@"");
...
```
<br/>
##### 2.2 生成标签对应View，实现协议宏

```objc
@interface VideoView : UIImageView<CCViewProtocol>
...
IMP_CCViewProtocol()
...
```
<br/>
##### 2.3 生成标签对应业务逻辑控制Controller，实现协议接收滚动、controller生命周期等事件
 
```objc
@interface VideoController : NSObject<ComponentControllerProtocol>
...
- (nullable NSArray<Class> *)supportComponentModelClass {
	return @[[VideoModel class]];
}
...
- (nullable Class)reusableComponentViewClassWithModel:(CCModel *)componentModel {
	return [VideoView class];
}
...
- (void)scrollViewWillDisplayComponentView:(CCView *)componentView
                    componentModel:(CCModel *)componentModel {
...
}

- (void)controllerViewDidDisappear {
...
}
```
<br/>
##### 2.4 替换HTML对应DomClass为Native组件

```objc
...
_webComponentHandler = [[CCPageHandler alloc] initWithViewController:self componentsControllers:@[[[VideoController alloc] init]];
...
[_webComponentHandler handleSingleWebView:_webView webComponentDomClass:@"domClass" webComponentIndexKey:@"domAttrIndex"];
...
[_webComponentHandler layoutWithWebComponentModels:@[VideoModel]];
...
```
<br/>

<a name="usage-common-page"></a>
### 3. 普通内容页快速实现

基于业务逻辑划分组件，对应独立的MVC，快速搭建支持异步更新、多ScrollView嵌套滚动、页面内组件滚动复用的内容页。
<br/>
##### 3.1 生成组件Model，存储组件内容

```objc
@interface TitleModel : NSObject<CCModelProtocol>
@interface ContentModel : NSObject<CCModelProtocol>
@interface RelateNewsModel : NSObject<CCModelProtocol>
@interface CommentModel : NSObject<CCModelProtocol>
...
```
<br/>
##### 3.2 生成组件View，支持UIView & UIScrollView全部类型

```objc
@interface TitleView : UIView<CCViewProtocol>
@interface ContentView : UIView <CCViewProtocol>
@interface RelateNewsView : UITableView<CCViewProtocol>
@interface CommentView : UICollectionView<CCViewProtocol>
...
```
<br/>
##### 3.3 生成标签对应业务逻辑控制Controller，实现协议接收滚动、controller生命周期等事件
 
```objc
@interface TitleController : NSObject<ComponentControllerProtocol>
@interface ContentController : NSObject<ComponentControllerProtocol>
@interface RelateNewsController : NSObject<ComponentControllerProtocol>
@interface CommentController : NSObject<ComponentControllerProtocol>
...
```
<br/>
##### 3.4 实现内容页

```objc
...
_componentHandler = [[CCPageHandler alloc] initWithViewController:self componentsControllers:@[[[TitleController alloc] init],[[ContentController alloc] init],[[RelateNewsController alloc] init],[[CommentController alloc] init]];
...
[_componentHandler handleSingleScrollView:[[UIScrollView alloc] initWithFrame:self.view.bounds]];
...
[_componentHandler layoutWithComponentModels:@[TitleModel, ContentModel, RelateNewsModel, CommentModel]];
...
```
<br/>

<a name="usage-hybrid-page"></a>
### 4. 包含WebView复杂内容页快速实现

基于业务逻辑划分组件，对应独立的MVC，快速搭建支持异步更新、多ScrollView嵌套滚动、页面内组件滚动复用的内容页。
同时内置可复用回收的WKWebView,并替换HTML标签为Native组件，并实现页面内的滚动复用
<br/>
##### 4.1 生成组件Model，存储组件内容

```objc
@interface TitleModel : NSObject<CCModelProtocol>
@interface ContentModel : NSObject<CCModelProtocol>
@interface RelateNewsModel : NSObject<CCModelProtocol>
@interface CommentModel : NSObject<CCModelProtocol>
...
@interface WebImgModel : NSObject<CCModelProtocol>
@interface WebVideoModel : NSObject<CCModelProtocol>
...
```
<br/>
##### 4.2 生成组件View，支持UIView & UIScrollView全部类型

```objc
@interface TitleView : UIView<CCViewProtocol>
@interface ContentView : UIView <CCViewProtocol>
@interface RelateNewsView : UITableView<CCViewProtocol>
@interface CommentView : UICollectionView<CCViewProtocol>
...
@interface WebImgView : UIView <CCViewProtocol>
@interface WebVideoView : UIView <CCViewProtocol>
...
```
<br/>
##### 4.3 生成标签对应业务逻辑控制Controller，实现协议接收滚动、controller生命周期等事件
 
```objc
@interface TitleController : NSObject<ComponentControllerProtocol>
@interface ContentController : NSObject<ComponentControllerProtocol>
@interface RelateNewsController : NSObject<ComponentControllerProtocol>
@interface CommentController : NSObject<ComponentControllerProtocol>
...
@interface WebImgController : NSObject<ComponentControllerProtocol>
@interface WebVideoController : NSObject<ComponentControllerProtocol>
...
```
<br/>
##### 4.4 实现内容页

```objc
...
_componentHandler = [[CCPageHandler alloc] initWithViewController:self componentsControllers:@[[[TitleController alloc] init],[[ContentController alloc] init],[[RelateNewsController alloc] init],[[CommentController alloc] init],[[WebImgController alloc] init],[[WebVideoController alloc] init]];
...
[_componentHandler handleHybridPageWithContainerScrollView:[[UIScrollView alloc] initWithFrame:self.view.bounds] defaultWebViewClass:[CCWebViewSubClass class] defaultWebViewIndex:1 webComponentDomClass:@"domClass" webComponentIndexKey:@"domAttrIndex"];
...
[_componentHandler layoutWithWebComponentModels:@[WebImgModel, WebVideoModel]];
...
[_componentHandler layoutWithComponentModels:@[TitleModel, ContentModel, RelateNewsModel, CommentModel]];
...
```
<br/>

<a name="usage-architecture"></a>
### 5. 代码结构

##### `CCViewProtocol.h`
- 组件模块View需要实现的Protocol。
- 提供回收复用前的清理及初始化回调等。

##### `CCModelProtocol.h`
- 组件模块Model需要实现的Protocol。
- 提供自定义设置组件Frame及Index等。

##### `CCControllerProtocol.h`
- 组件模块Controller需要实现的Protocol。
- 提供WebView加载各关键节点的回调。
- 提供ViewController生命周期关键节点的回调。
- 提供组件页面内滚动复用关键节点的回调。

##### `CCPageManager.h`
- 提供基础的框架配置，如Log回调，组件复用最大次数等。
- 提供基础的WebView复用回收接口。
- 提供基础的WebView全局配置（UA、Web Cache等）。

##### `CCPageHandler.h`
- 组件View嵌套滚动、复用回收及布局的设置。
- 提供基于UIScrollView和SubView/SubScrollView的页面布局。
- 提供基于WebView和HTML DOM/SubView的页面布局。
- 提供包含以上两种的复杂内容页综合布局。

##### `CCWebView.h`
- 提供WKWebView功能扩展、复用接口。
- 提供WKWebView Delegate扩展。
<br/>

<a name="usage-demo-architecture"></a>
### 6. Demo项目架构

基于Component Container，我们实现了一个通用的资讯类App内容页展示Demo，方便理解架构的设计和使用。

<div align="center"><img src='/Docs/Images/demo_architecture.png' width='40%'></div>

<br/>

<a name="license"></a>
## License
Component Container is released under the MIT license. See [MIT License](./README_ASSET/LICENSE) for details.

<br/>

<a name="contact"></a>
## Contact

有任何疑问或建议，欢迎联系[shawndeng](http://km.oa.com/user/shawndeng)、[dequanzhu](http://km.oa.com/user/dequanzhu)。
