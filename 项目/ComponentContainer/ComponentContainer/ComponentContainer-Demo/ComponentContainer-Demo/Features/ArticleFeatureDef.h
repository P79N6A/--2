//
// ArticleFeatureDef.h
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

#import "TitleView.h"
#import "TitleModel.h"
#import "TitleController.h"

#import "BlockNewsView.h"
#import "BlockNewsModel.h"
#import "BlockNewsController.h"

#import "RelateNewsView.h"
#import "RelateNewsModel.h"
#import "RelateNewsController.h"

#import "HotCommentView.h"
#import "HotCommentModel.h"
#import "HotCommentController.h"

#import "MediaView.h"
#import "MediaModel.h"
#import "MediaController.h"

#import "AdView.h"
#import "AdModel.h"
#import "AdController.h"

#import "VideoView.h"
#import "VideoModel.h"
#import "VideoController.h"

#import "GifView.h"
#import "GifModel.h"
#import "GifController.h"

#import "ImageView.h"
#import "ImageModel.h"
#import "ImageController.h"

typedef NS_ENUM(NSInteger, CCDemoComponentIndex){
    kCCDemoComponentIndexTitle,
    kCCDemoComponentIndexWebView,
    kCCDemoComponentIndexBlockNews,
    kCCDemoComponentIndexAd,
    kCCDemoComponentIndexRelate,
    kCCDemoComponentIndexMedia,
    kCCDemoComponentIndexComment,
};
