//
//  XYCoreText.h
//  CoreTextDemo
//
//  Created by cyp on 16/10/10.
//  Copyright © 2016年 XY. All rights reserved.
//

#import <UIKit/UIKit.h>

// 行距
extern const CGFloat kGlobalLineLeading;

// 在15字体下，比值小于这个则显示emoji不全
extern const CGFloat kPerLineRatio;

typedef NS_ENUM(NSInteger, XYDrawType){
    XYDrawPureText,                // 只绘制纯文本
    XYDrawTextLineByLine,          // 一行一行的绘制纯文本，固定行间距
    XYDrawTextLineByLineAlignment, // 一行一行的绘制纯文本，固定行高
    XYDrawTextWithEllipses,        // 一行一行的绘制纯文本，高度不够加省略号
    XYDrawTextWithCheckClick,      // 识别点击特定字符串
    XYDrawTextAndPicture,          // 图文混排
};
@interface XYCoreText : UIView

@property (nonatomic ,copy) NSString *text;

@property (nonatomic ,strong) UIFont *font;

@property (nonatomic ,assign) XYDrawType drawType;

//初始化
- (instancetype)initWithFrame:(CGRect)frame drawType:(XYDrawType)drawType;

// 计算高度的代码
+ (CGFloat)textHeightWithText:(NSString *)aText width:(CGFloat)aWidth font:(UIFont *)aFont type:(XYDrawType)drawType;

@end
