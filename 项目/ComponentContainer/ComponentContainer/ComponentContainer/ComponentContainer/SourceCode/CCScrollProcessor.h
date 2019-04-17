//
// CCScrollProcessor.h
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
#import "CCViewProtocol.h"
#import "CCModelProtocol.h"
#import "CCControllerProtocol.h"

typedef NSObject<CCControllerProtocol>* (^CCScrollProcessorDelegateBlock)(CCModel *model , BOOL isGetViewEvent);

typedef NS_ENUM (NSInteger, CCLayoutType) {
    kCCLayoutTypeAutoCalculateFrame,     //根据ComponentIndex及相应的protocol自动计算
    kCCLayoutTypeManualCalculateFrame,   //根据ComponentModel中的Frame布局
};
/**
 * 底层页components滚动管理
 */
@interface CCScrollProcessor : NSObject

#pragma mark -

- (instancetype)initWithScrollView:(__kindof UIScrollView *)scrollView
                        layoutType:(CCLayoutType)layoutType
               scrollDelegateBlock:(CCScrollProcessorDelegateBlock)scrollDelegateBlock;

#pragma mark - layout

- (void)relayoutWithComponentFrameChange;
- (void)addComponentModelAndRelayout:(CCModel *)componentModel;
- (void)removeComponentModelAndRelayout:(CCModel *)componentModel;
- (void)layoutWithComponentModels:(NSArray <CCModel *> *)componentModels;
- (void)removeAllComponents;

#pragma mark - scroll

- (void)scrollToContentOffset:(CGPoint)toContentOffset animated:(BOOL)animated;
- (void)scrollToComponentView:(CCView *)componentView atOffset:(CGFloat)offsetY animated:(BOOL)animated;
- (void)scrollToComponentModel:(CCModel *)componentModel atOffset:(CGFloat)offsetY animated:(BOOL)animated;

#pragma mark - get View or Model

- (NSArray <CCModel *> *)getAllComponentModels;
- (NSArray <CCModel *> *)getVisibleComponentModels;
- (NSArray <CCView *> *)getVisibleComponentViews;

//get model
- (CCModel *)getComponentModelByComponentView:(CCView *)componentView;
- (CCModel *)getComponentModelByIndex:(NSString *)componentIndex;

//get view
- (CCView *)getComponentViewByComponentModel:(CCModel *)componentModel;
- (CCView *)getComponentViewByIndex:(NSString *)componentIndex;

@end
