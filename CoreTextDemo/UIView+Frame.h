//
//  UIView+Frame.h
//  xpkc
//
//  Created by TopSageOSX on 15/1/7.
//  Copyright (c) 2015年 TopSage. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 *  UIView 
 *  直接设定位置的拓展
 *  @param size     大小
 *  @param left     左距
 *  @param right    右距
 *  @param top      上距
 *  @param bottom   下距
 *  @param centerX  中心X
 *  @param centerY  中心Y
 *  @param width    宽度
 *  @param height   高度
 */
@interface UIView (Frame)
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGFloat left;
@property (nonatomic, assign) CGFloat right;
@property (nonatomic, assign) CGFloat top;
@property (nonatomic, assign) CGFloat bottom;
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@end
