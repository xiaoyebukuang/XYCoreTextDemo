//
//  ViewController.m
//  CoreTextDemo
//
//  Created by cyp on 16/10/10.
//  Copyright © 2016年 XY. All rights reserved.
//

#import "ViewController.h"
#import "XYCoreText.h"
#import "UIView+Frame.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *content = @" 1、有多少放下，就会有多少得到。😳😊😳😊😳，舍得舍得，舍就是得，得就是舍。得到了一些东西，必是舍去了一些东西。舍得就如太极图里的黑白图案，圆是永恒不变的，黑多就会白少，白多就会黑少。10086如若放下，就不会计较黑白，多少，😳😊😳😊😳😊😳，得失。其实黑白，多少，得失，仅仅只是心底的幻觉。10010，2、真正的朋友，需要的不是数量，而是质量！走过一段路，10011，才知道是深是浅；真心的朋友，不离不弃， 比什么都值钱；真心的朋友，信任不疑，比什么都心安；真心的朋友，命里黄金，拿什么都别换。3、手机号：123456789，@王小二，@里大大";
//    NSString *content = @"在现实生活中，我们要不断内外兼修，几十载的人生旅途，看过这边风景，必然错过那边彩虹，有所得，必然有所失。有时，我们只有彻底做到拿得起，放得下，才能拥有一份成熟，才会活得更加充实、坦然、轻松和自由。";

    XYCoreText *coreText = [[XYCoreText alloc]initWithFrame:CGRectMake(0, 20, self.view.width, 400) drawType:XYDrawTextWithCheckClick];
    coreText.font = [UIFont systemFontOfSize:15];
    coreText.text = content;
    coreText.backgroundColor = [UIColor redColor];
    
    CGFloat height = [XYCoreText textHeightWithText:content width:coreText.width font:coreText.font type:coreText.drawType];
    // 在这里控制显示的行数
    CGFloat maxHeight = (coreText.font.pointSize*kPerLineRatio)*6;
    if (height > maxHeight && coreText.drawType == XYDrawTextWithEllipses){
        height = maxHeight;
    }
    coreText.height = height;
    [self.view addSubview:coreText];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
