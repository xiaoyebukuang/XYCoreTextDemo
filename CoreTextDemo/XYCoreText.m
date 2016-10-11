//
//  XYCoreText.m
//  CoreTextDemo
//
//  Created by cyp on 16/10/10.
//  Copyright © 2016年 XY. All rights reserved.
//

#import "XYCoreText.h"
#import <CoreText/CoreText.h>
#import "UIView+Frame.h"
#import "UIImageView+WebCache.h"
// 行距
const CGFloat kGlobalLineLeading = 5.0;

// 在15字体下，比值小于这个计算出来的高度会导致emoji显示不全
const CGFloat kPerLineRatio = 1.4;

//识别@人名
//NSString *kAtRegularExpression = @"@[^\\s@]+?\\s{1}";
NSString *kAtRegularExpression = @"@[\u4e00-\u9fa5a-zA-Z0-9_-]{2,30}";
//识别连续的数字
NSString *kNumberRegularExpression = @"\\d+[^\\d]{1}";


@interface XYCoreText()<UIGestureRecognizerDelegate>

@property (nonatomic, assign) CTFrameRef ctFrame;
@property (nonatomic, assign) NSRange pressRange;
@property (nonatomic, assign) CGFloat textHeight;

@property (nonatomic, strong) UIImage *image;

@end

@implementation XYCoreText



- (instancetype)initWithFrame:(CGRect)frame drawType:(XYDrawType)drawType{
    self = [super initWithFrame:frame];
    if (self) {
        self.drawType = drawType;
        self.font = [UIFont systemFontOfSize:15];
        [self configSettings];
    }
    return self;
}
- (void)configSettings{
    if (self.drawType == XYDrawTextWithCheckClick) {
        //添加手势
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        longPressGesture.minimumPressDuration = 0.01;
        longPressGesture.delegate = self;
        [self addGestureRecognizer:longPressGesture];
    }
}

- (void)drawRect:(CGRect)rect{
    [super drawRect:rect];
    switch (self.drawType) {
        case XYDrawPureText:
            [self drawRectWithPureText];
            break;
        case XYDrawTextLineByLine:
            [self drawRectWithLineByLine];
            break;
        case XYDrawTextLineByLineAlignment:
            [self drawRectWithLineByLineAlignment];
            break;
        case XYDrawTextWithEllipses:
            [self drawRectWithLineByLineAlignmentAndEllipses];
            break;
        case XYDrawTextWithCheckClick:
            [self drawRectWithCheckClick];
            break;
        case XYDrawTextAndPicture:
            [self drawRectWithPictureAndContent];
            break;
        default:
            break;
    }
}
#pragma mark - 绘制部分
#pragma mark - 纯文本
- (void)drawRectWithPureText{
    // 步骤1：得到当前用于绘制画布的上下文，用于后续将内容绘制在画布上
    // 因为Core Text要配合Core Graphic 配合使用的，如Core Graphic一样，绘图的时候需要获得当前的上下文进行绘制
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 步骤2：翻转当前的坐标系（因为对于底层绘制引擎来说，屏幕左下角为（0，0））
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // 步骤3：创建NSAttributedString
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:self.text];
    [[self class]addGlobalAttributeWithContent:attrString font:self.font];
    
    // 步骤4：根据NSAttributedString创建CTFramesetterRef
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attrString);
    
    // 步骤5：创建绘制区域CGPathRef
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, self.bounds);
    
    // 步骤6：根据CTFramesetterRef和CGPathRef创建CTFrame；
    CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, [attrString length]), path, NULL);
    
    // 步骤7：CTFrameDraw绘制
    CTFrameDraw(frame, context);
    
    // 步骤8.内存管理
    CFRelease(frame);
    CFRelease(path);
    CFRelease(frameSetter);
}
#pragma mark - 一行一行绘制，固定行间距
- (void)drawRectWithLineByLine{
    // 1.创建需要绘制的文字
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:self.text];
    
    // 2.设置行距等样式
    [[self class] addGlobalAttributeWithContent:attributed font:self.font];
    
    
   CGFloat textHeight = [[self class] textHeightWithText:self.text width:CGRectGetWidth(self.bounds) font:self.font type:self.drawType];
    
    // 3.创建绘制区域，path的高度对绘制有直接影响，如果高度不够，则计算出来的CTLine的数量会少一行或者少多行
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, CGRectGetWidth(self.bounds),textHeight));
    
    // 4.根据NSAttributedString生成CTFramesetterRef
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributed);
    
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, NULL);
    
    
    // 1.获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // 2.转换坐标系
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, textHeight); // 此处用计算出来的高度
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    
    // 一行一行绘制
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    
    // 把ctFrame里每一行的初始坐标写到数组里，注意CoreText的坐标是左下角为原点
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    CGFloat frameY = 0;
    for (CFIndex i = 0; i < lineCount; i++){
        // 遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading; // 行距
        // 该函数除了会设置好ascent,descent,leading之外，还会返回这行的宽度
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CGPoint lineOrigin = lineOrigins[i];
        // 微调Y值，需要注意的是CoreText的Y值是在baseLine处，而不是下方的descent。
        // lineDescent为正数，self.font.descender为负数
        if (i > 0){
            // 第二行之后需要计算
            frameY = frameY - kGlobalLineLeading - lineAscent;
            lineOrigin.y = frameY;
        }else{
            // 第一行可直接用
            frameY = lineOrigin.y;
        }
        // 调整坐标
        CGContextSetTextPosition(contextRef, lineOrigin.x, lineOrigin.y);
        CTLineDraw(line, contextRef);
        // 微调
        frameY = frameY - lineDescent;
    }
    CFRelease(path);
    CFRelease(framesetter);
    CFRelease(ctFrame);
}
#pragma mark - 一行一行的绘制纯文本，固定行高
- (void)drawRectWithLineByLineAlignment{
    // 1.创建需要绘制的文字
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:self.text];
    
    // 2.设置行距等样式
    [[self class] addGlobalAttributeWithContent:attributed font:self.font];
    
    
    CGFloat textHeight = [[self class] textHeightWithText:self.text width:CGRectGetWidth(self.bounds) font:self.font type:self.drawType];
    
    // 3.创建绘制区域，path的高度对绘制有直接影响，如果高度不够，则计算出来的CTLine的数量会少一行或者少多行
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, CGRectGetWidth(self.bounds), textHeight*2));
    
    // 4.根据NSAttributedString生成CTFramesetterRef
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributed);
    
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, NULL);
    
    // 获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // 转换坐标系
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, textHeight); // 此处用计算出来的高度
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    
    // 一行一行绘制
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    
    // 把ctFrame里每一行的初始坐标写到数组里，注意CoreText的坐标是左下角为原点
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    CGFloat frameY = 0;
    for (CFIndex i = 0; i < lineCount; i++){
        // 遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);

        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading; // 行距
        // 该函数除了会设置好ascent,descent,leading之外，还会返回这行的宽度
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CGPoint lineOrigin = lineOrigins[i];
        
        // 微调Y值，需要注意的是CoreText的Y值是在baseLine处，而不是下方的descent。
        CGFloat lineHeight = self.font.pointSize * kPerLineRatio;
        frameY = textHeight - (i + 1)*lineHeight - self.font.descender;
        lineOrigin.y = frameY;
        // 调整坐标
        CGContextSetTextPosition(contextRef, lineOrigin.x, lineOrigin.y);
        CTLineDraw(line, contextRef);
    }
    CFRelease(path);
    CFRelease(framesetter);
    CFRelease(ctFrame);
}
#pragma mark - 一行一行的绘制纯文本，高度不够加省略号
- (void)drawRectWithLineByLineAlignmentAndEllipses{
    // 1.创建需要绘制的文字
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:self.text];
    
    // 2.设置行距等样式
    [[self class] addGlobalAttributeWithContent:attributed font:self.font];
    
    CGFloat textHeight = [[self class] textHeightWithText:self.text width:CGRectGetWidth(self.bounds) font:self.font type:self.drawType];
    
    // 3.创建绘制区域，path的高度对绘制有直接影响，如果高度不够，则计算出来的CTLine的数量会少一行或者少多行
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, CGRectGetWidth(self.bounds), textHeight*2));
    
    // 4.根据NSAttributedString生成CTFramesetterRef
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributed);
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, NULL);
    
    // 重置高度
    CGFloat realHeight = textHeight;
    // 绘制全部文本需要的高度大于实际高度则调整，并加上省略号
    if (realHeight > CGRectGetHeight(self.frame)){
        realHeight = CGRectGetHeight(self.frame);
    }
    // 获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // 转换坐标系
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, realHeight); // 这里跟着调整
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    
    // 这里可调整可不调整
    CGPathAddRect(path, NULL, CGRectMake(0, 0, CGRectGetWidth(self.bounds), realHeight));
    
    // 一行一行绘制
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    // 把ctFrame里每一行的初始坐标写到数组里，注意CoreText的坐标是左下角为原点
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    CGFloat frameY = 0;
    for (CFIndex i = 0; i < lineCount; i++){
        // 遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading; // 行距
        // 该函数除了会设置好ascent,descent,leading之外，还会返回这行的宽度
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        //CoreText的origin的Y值是在baseLine处，而不是下方的descent。
        CGPoint lineOrigin = lineOrigins[i];
        //行高
        CGFloat lineHeight = self.font.pointSize * kPerLineRatio;
        //self.font.descender为负值
        frameY = realHeight - (i + 1)*lineHeight - self.font.descender;
        lineOrigin.y = frameY;
        //调整坐标
        CGContextSetTextPosition(contextRef, lineOrigin.x, lineOrigin.y);
        if (frameY + self.font.descender >= lineHeight){
            CTLineDraw(line, contextRef);
        }else{
            // 最后一行，加上省略号
            static NSString* const kEllipsesCharacter = @"\u2026";
            CFRange lastLineRange = CTLineGetStringRange(line);
            // 一个emoji表情占用两个长度单位
            if (lastLineRange.location + lastLineRange.length < (CFIndex)attributed.length){
                // 这一行放不下所有的字符（下一行还有字符），则把此行后面的回车、空格符去掉后，再把最后一个字符替换成省略号
                CTLineTruncationType truncationType = kCTLineTruncationEnd;
                NSUInteger truncationAttributePosition = lastLineRange.location + lastLineRange.length - 1;
                
                // 拿到最后一个字符的属性字典
                NSDictionary *tokenAttributes = [attributed attributesAtIndex:truncationAttributePosition
                                                               effectiveRange:NULL];
                // 给省略号字符设置字体大小、颜色等属性
                NSAttributedString *tokenString = [[NSAttributedString alloc] initWithString:kEllipsesCharacter
                                                                                  attributes:tokenAttributes];
                
                // 用省略号单独创建一个CTLine，下面在截断重新生成CTLine的时候会用到
                CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)tokenString);
                
                // 把这一行的属性字符串复制一份，如果要把省略号放到中间或其他位置，只需指定复制的长度即可
                NSUInteger copyLength = lastLineRange.length;
                
                NSMutableAttributedString *truncationString = [[attributed attributedSubstringFromRange:NSMakeRange(lastLineRange.location, copyLength)] mutableCopy];
                
                if (lastLineRange.length > 0)
                {
                    // Remove any whitespace at the end of the line.
                    unichar lastCharacter = [[truncationString string] characterAtIndex:copyLength - 1];
                    
                    // 如果复制字符串的最后一个字符是换行、空格符，则删掉
                    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:lastCharacter])
                    {
                        [truncationString deleteCharactersInRange:NSMakeRange(copyLength - 1, 1)];
                    }
                }
                
                // 拼接省略号到复制字符串的最后
                [truncationString appendAttributedString:tokenString];
                
                // 把新的字符串创建成CTLine
                CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationString);
                
                // 创建一个截断的CTLine，该方法不能少，具体作用还有待研究
                CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, self.frame.size.width, truncationType, truncationToken);
                
                if (!truncatedLine)
                {
                    // If the line is not as wide as the truncationToken, truncatedLine is NULL
                    truncatedLine = CFRetain(truncationToken);
                }
                
                CFRelease(truncationLine);
                CFRelease(truncationToken);
                
                CTLineDraw(truncatedLine, contextRef);
                CFRelease(truncatedLine);
            } else{
                // 这一行刚好是最后一行，且最后一行的字符可以完全绘制出来
                CTLineDraw(line, contextRef);
            }
            // 跳出循环，避免绘制剩下的多余的CTLine
            break;
        }
    }
    CFRelease(path);
    CFRelease(framesetter);
    CFRelease(ctFrame);
}
#pragma mark - 绘制文本，并识别点击特定字符串
- (void)drawRectWithCheckClick{

    // 1.创建需要绘制的文字
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:self.text];
    
    // 2.1设置行距等样式
    [[self class] addGlobalAttributeWithContent:attributed font:self.font];
    
    // 2.2识别特定字符串并改变其颜色
    [self recognizeSpecialStringWithAttributed:attributed];
    
    //2.3加一个点击改变字符串颜色的效果
    if (self.pressRange.location != 0 && self.pressRange.length != 0){
        [attributed addAttribute:NSForegroundColorAttributeName value:[UIColor yellowColor] range:self.pressRange];
    }
    
    self.textHeight = [[self class] textHeightWithText:self.text width:CGRectGetWidth(self.bounds) font:self.font type:self.drawType];
    
    // 3.创建绘制区域，path的高度对绘制有直接影响，如果高度不够，则计算出来的CTLine的数量会少一行或者少多行
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, CGRectGetWidth(self.bounds), self.textHeight*2));
    
    // 4.根据NSAttributedString生成CTFramesetterRef
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributed);
    
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, NULL);
    self.ctFrame = CFRetain(ctFrame);
    
    // 获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // 转换坐标系
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, self.textHeight); // 此处用计算出来的高度
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    
    // 一行一行绘制
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    
    // 把ctFrame里每一行的初始坐标写到数组里，注意CoreText的坐标是左下角为原点
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    CGFloat frameY = 0;
    for (CFIndex i = 0; i < lineCount; i++){
        // 遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading; // 行距
        // 该函数除了会设置好ascent,descent,leading之外，还会返回这行的宽度
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CGPoint lineOrigin = lineOrigins[i];
        
        // 微调Y值，需要注意的是CoreText的Y值是在baseLine处，而不是下方的descent。
        CGFloat lineHeight = self.font.pointSize * kPerLineRatio;
        frameY = self.textHeight - (i + 1)*lineHeight - self.font.descender;
        lineOrigin.y = frameY;
        // 调整坐标
        CGContextSetTextPosition(contextRef, lineOrigin.x, lineOrigin.y);
        CTLineDraw(line, contextRef);
    }
    CFRelease(path);
    CFRelease(framesetter);
    CFRelease(ctFrame);
}
#pragma mark - 图文混排
- (void)drawRectWithPictureAndContent{
    //步骤1：获取上下文
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    // [a,b,c,d,tx,ty]
    
    //步骤2：翻转坐标系；
    CGContextSetTextMatrix(contextRef, CGAffineTransformIdentity);
    CGContextTranslateCTM(contextRef, 0, self.bounds.size.height);
    CGContextScaleCTM(contextRef, 1.0, -1.0);
    
    //步骤3：创建NSAttributedString
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:self.text];
    //设置字体大小
    [attributed addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(0, 5)];
    //设置字体颜色
    [attributed addAttribute:NSForegroundColorAttributeName value:[UIColor yellowColor] range:NSMakeRange(3, 10)];
    [attributed addAttribute:(id)kCTForegroundColorAttributeName value:(id)[UIColor greenColor].CGColor range:NSMakeRange(0, 2)];
    // 设置行距等样式
    CGFloat lineSpace = 10; // 行距一般取决于这个值
    CGFloat lineSpaceMax = 20;
    CGFloat lineSpaceMin = 2;
    const CFIndex kNumberOfSettings = 3;
    // 结构体数组
    CTParagraphStyleSetting theSettings[kNumberOfSettings] = {
        {kCTParagraphStyleSpecifierLineSpacingAdjustment,sizeof(CGFloat),&lineSpace},
        {kCTParagraphStyleSpecifierMaximumLineSpacing,sizeof(CGFloat),&lineSpaceMax},
        {kCTParagraphStyleSpecifierMinimumLineSpacing,sizeof(CGFloat),&lineSpaceMin}
    };
    CTParagraphStyleRef theParagraphRef = CTParagraphStyleCreate(theSettings, kNumberOfSettings);
    // 将设置的行距应用于整段文字
    [attributed addAttribute:NSParagraphStyleAttributeName value:(__bridge id)(theParagraphRef) range:NSMakeRange(0, attributed.length)];
    CFRelease(theParagraphRef);
    // 插入图片部分
    //为图片设置CTRunDelegate,delegate决定留给图片的空间大小
    NSString *weicaiImageName = @"cloud.jpg";
    CTRunDelegateCallbacks imageCallbacks;
    imageCallbacks.version = kCTRunDelegateVersion1;
    imageCallbacks.dealloc = RunDelegateDeallocCallback;
    imageCallbacks.getAscent = RunDelegateGetAscentCallback;
    imageCallbacks.getDescent = RunDelegateGetDescentCallback;
    imageCallbacks.getWidth = RunDelegateGetWidthCallback;
    // ①该方式适用于图片在本地的情况
    // 设置CTRun的代理
    CTRunDelegateRef runDelegate = CTRunDelegateCreate(&imageCallbacks, (__bridge void *)(weicaiImageName));
    NSMutableAttributedString *imageAttributedString = [[NSMutableAttributedString alloc] initWithString:@" "];//空格用于给图片留位置
    [imageAttributedString addAttribute:(NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:NSMakeRange(0, 1)];
    CFRelease(runDelegate);
    [imageAttributedString addAttribute:@"imageName" value:weicaiImageName range:NSMakeRange(0, 1)];
    // 在index处插入图片，可插入多张
    [attributed insertAttributedString:imageAttributedString atIndex:5];
    //    [attributed insertAttributedString:imageAttributedString atIndex:10];
    
    // ②若图片资源在网络上，则需要使用0xFFFC作为占位符
    // 图片信息字典
    NSString *picURL =@"https://www.baidu.com/img/bd_logo1.png";
    UIImage* pImage = [UIImage imageNamed:@"cloud.jpg"];
    if (self.image) {
        pImage = self.image;
    }
    NSDictionary *imgInfoDic = @{@"width":@(pImage.size.width),@"height":@(pImage.size.height)}; // 宽高跟具体图片有关
    // 设置CTRun的代理
    CTRunDelegateRef delegate = CTRunDelegateCreate(&imageCallbacks, (__bridge void *)imgInfoDic);
    
    // 使用0xFFFC作为空白的占位符
    unichar objectReplacementChar = 0xFFFC;
    NSString *content = [NSString stringWithCharacters:&objectReplacementChar length:1];
    NSMutableAttributedString *space = [[NSMutableAttributedString alloc] initWithString:content];
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)space, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
    CFRelease(delegate);
    
    // 将创建的空白AttributedString插入进当前的attrString中，位置可以随便指定，不能越界
    [attributed insertAttributedString:space atIndex:10];
    
    
    //步骤4：根据NSAttributedString创建CTFramesetterRef
    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributed);
    
    //步骤5：创建绘制区域CGPathRef
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, NULL, self.bounds);
    
    //步骤6：根据CTFramesetterRef和CGPathRef创建CTFrame；
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, [attributed length]), pathRef, NULL);
    
    //步骤7：CTFrameDraw绘制。
    CTFrameDraw(frameRef, contextRef);
    
    // 处理绘制图片的逻辑
    CFArrayRef lines = CTFrameGetLines(frameRef);
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    // 把ctFrame里每一行的初始坐标写到数组里
    CTFrameGetLineOrigins(frameRef, CFRangeMake(0, 0), lineOrigins);
    
    // 遍历CTRun找出图片所在的CTRun并进行绘制
    for (int i = 0; i < CFArrayGetCount(lines); i++)
    {
        // 遍历每一行CTLine
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading; // 行距
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        
        for (int j = 0; j < CFArrayGetCount(runs); j++)
        {
            // 遍历每一个CTRun
            CGFloat runAscent;
            CGFloat runDescent;
            CGPoint lineOrigin = lineOrigins[i]; // 获取该行的初始坐标
            CTRunRef run = CFArrayGetValueAtIndex(runs, j); // 获取当前的CTRun
            NSDictionary* attributes = (NSDictionary*)CTRunGetAttributes(run);
            CGRect runRect;
            runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
            // 这一段可参考Nimbus的NIAttributedLabel
            runRect = CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
            
            NSString *imageName = [attributes objectForKey:@"imageName"];
            if ([imageName isKindOfClass:[NSString class]]){
                // 绘制本地图片
                UIImage *image = [UIImage imageNamed:imageName];
                CGRect imageDrawRect;
                imageDrawRect.size = image.size;
                imageDrawRect.origin.x = runRect.origin.x;// + lineOrigin.x;
                imageDrawRect.origin.y = lineOrigin.y;
                CGContextDrawImage(contextRef, imageDrawRect, image.CGImage);
            } else {
                imageName = nil;
                CTRunDelegateRef delegate = (__bridge CTRunDelegateRef)[attributes objectForKey:(__bridge id)kCTRunDelegateAttributeName];
                if (!delegate){
                    continue; // 如果是非图片的CTRun则跳过
                }
                // 网络图片
                UIImage *image;
                if (!self.image){
                    // 图片未下载完成，使用占位图片
                    image = pImage;
                    // 去下载图片
                    [self downLoadImageWithURL:[NSURL URLWithString:picURL]];
                }else{
                    image = self.image;
                }
                // 绘制网络图片
                CGRect imageDrawRect;
                imageDrawRect.size = image.size;
                imageDrawRect.origin.x = runRect.origin.x;// + lineOrigin.x;
                imageDrawRect.origin.y = lineOrigin.y;
                CGContextDrawImage(contextRef, imageDrawRect, image.CGImage);
            }
        }
    }
    //内存管理
    CFRelease(frameRef);
    CFRelease(pathRef);
    CFRelease(framesetterRef);
}
#pragma mark - 工具方法
#pragma mark 给字符串添加全局属性，比如行距，字体大小，默认颜色
+ (void)addGlobalAttributeWithContent:(NSMutableAttributedString *)attributeString font:(UIFont *)aFont{
    CGFloat lineLeading = kGlobalLineLeading; // 行间距
    //设置部分颜色
    [attributeString addAttribute:(NSString *)kCTForegroundColorAttributeName value:(id)[UIColor greenColor].CGColor range:NSMakeRange(10, 10)];
    //设置文字
    CTFontRef fontRef = CTFontCreateWithName((CFStringRef)@"ArialMT", aFont.pointSize, NULL);
    [attributeString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)fontRef range:NSMakeRange(0, attributeString.length)];
    CFRelease(fontRef);
    // 设置行距等样式
    CGFloat lineSpace = lineLeading; // 行距一般取决于这个值
    CGFloat lineSpaceMax = 20;
    CGFloat lineSpaceMin = 2;
    const CFIndex kNumberOfSettings = 3;
    // 结构体数组
    CTParagraphStyleSetting theSettings[kNumberOfSettings] = {
        {kCTParagraphStyleSpecifierLineSpacingAdjustment,sizeof(CGFloat),&lineSpace},
        {kCTParagraphStyleSpecifierMaximumLineSpacing,sizeof(CGFloat),&lineSpaceMax},
        {kCTParagraphStyleSpecifierMinimumLineSpacing,sizeof(CGFloat),&lineSpaceMin}
    };
    CTParagraphStyleRef theParagraphRef = CTParagraphStyleCreate(theSettings, kNumberOfSettings);
    
    [attributeString addAttribute:(id)kCTParagraphStyleAttributeName value:(__bridge  id)theParagraphRef range:NSMakeRange(0, attributeString.length)];
    
    // 内存管理
    CFRelease(theParagraphRef);
}
#pragma mark -- 下载图片
- (void)downLoadImageWithURL:(NSURL *)url{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SDWebImageOptions options = SDWebImageRetryFailed | SDWebImageHandleCookies | SDWebImageContinueInBackground;
        options = SDWebImageRetryFailed | SDWebImageContinueInBackground;
        [[SDWebImageManager sharedManager] downloadImageWithURL:url options:options progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            weakSelf.image = image;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.image){
                    [weakSelf setNeedsDisplay];
                }
            });
        }];
    });
}
#pragma mark - 图片代理
void RunDelegateDeallocCallback(void *refCon){

}
CGFloat RunDelegateGetAscentCallback(void *refCon){
    NSString *imageName = (__bridge NSString *)refCon;
    if ([imageName isKindOfClass:[NSString class]]){
        // 对应本地图片
        return [UIImage imageNamed:imageName].size.height;
    }
    // 对应网络图片
    NSLog(@"%f",[[(__bridge NSDictionary *)refCon objectForKey:@"height"] floatValue]);
    return [[(__bridge NSDictionary *)refCon objectForKey:@"height"] floatValue];
}
CGFloat RunDelegateGetDescentCallback(void *refCon){
    return 0;
}
CGFloat RunDelegateGetWidthCallback(void *refCon){
    NSString *imageName = (__bridge NSString *)refCon;
    if ([imageName isKindOfClass:[NSString class]]){
        // 本地图片
        return [UIImage imageNamed:imageName].size.width;
    }
    // 对应网络图片
    return [[(__bridge NSDictionary *)refCon objectForKey:@"width"] floatValue];
}

#pragma mark - 计算高度
+ (CGFloat)textHeightWithText:(NSString *)aText width:(CGFloat)aWidth font:(UIFont *)aFont type:(XYDrawType)drawType{
    switch (drawType) {
        case XYDrawPureText:
            return 400;
            break;
        case XYDrawTextLineByLine:
            return [self textHeightWithText2:aText width:aWidth font:aFont];
            break;
        case XYDrawTextLineByLineAlignment:
            return [self textHeightWithText3:aText width:aWidth font:aFont];
            break;
        case XYDrawTextWithEllipses:
            // 跟上方保持一致
            return [self textHeightWithText3:aText width:aWidth font:aFont];
            break;
        case XYDrawTextWithCheckClick:
            return [self textHeightWithText3:aText width:aWidth font:aFont];
            break;
        case XYDrawTextAndPicture:
            return 400*3;
            break;
        default:
            break;
    }
    return 0;
}
/**
 *  固定行间距
 *  高度 = 每行的asent + 每行的descent + 行数*行间距
 *  行间距为指定的数值
 */
+ (CGFloat)textHeightWithText2:(NSString *)aText width:(CGFloat)aWidth font:(UIFont *)aFont
{
    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] initWithString:aText];
    // 设置全局样式
    [self addGlobalAttributeWithContent:content font:aFont];
    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)content);
    //粗略的计算高度
    CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetterRef, CFRangeMake(0, aText.length), NULL, CGSizeMake(aWidth, MAXFLOAT), NULL);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, aWidth, suggestSize.height*10)); // 10这个数值是随便给的，主要是为了确保高度足够
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, aText.length), path, NULL);
    CFArrayRef lines = CTFrameGetLines(frameRef);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGFloat ascent = 0;
    CGFloat descent = 0;
    CGFloat leading = 0;
    CGFloat totalHeight = 0;
    for (CFIndex i = 0; i < lineCount; i++){
        CTLineRef lineRef = CFArrayGetValueAtIndex(lines, i);
        CTLineGetTypographicBounds(lineRef, &ascent, &descent, &leading);
        totalHeight += ascent + descent + kGlobalLineLeading;//行间距
    }
    return totalHeight;
}
/**
 *  固定行高
 *  高度 = 每行的固定高度 * 行数
 */
+ (CGFloat)textHeightWithText3:(NSString *)aText width:(CGFloat)aWidth font:(UIFont *)aFont{
    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] initWithString:aText];
    // 给字符串设置字体行距等样式
    [self addGlobalAttributeWithContent:content font:aFont];
    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)content);
    // 粗略的高度，该高度不准，仅供参考
    CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetterRef, CFRangeMake(0, content.length), NULL, CGSizeMake(aWidth, MAXFLOAT), NULL);
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPathAddRect(pathRef, NULL, CGRectMake(0, 0, aWidth, suggestSize.height));
    
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, content.length), pathRef, NULL);
    
    CFArrayRef lines = CTFrameGetLines(frameRef);
    CFIndex lineCount = CFArrayGetCount(lines);
    
    // 总高度 = 行数*每行的高度，其中每行的高度为指定的值，不同字体大小不一样
    CGFloat accurateHeight = lineCount * (aFont.pointSize * kPerLineRatio);
    CGFloat height = accurateHeight;
    
    CFRelease(pathRef);
    CFRelease(frameRef);
    
    return height;
}
#pragma mark - 识别特定字符串并改其颜色，返回识别到的字符串所在的range
- (NSMutableArray *)recognizeSpecialStringWithAttributed:(NSMutableAttributedString *)attributed{
    NSMutableArray *rangeArray = [NSMutableArray array];
    
    // 识别@人名
    NSRegularExpression *atRegular = [NSRegularExpression regularExpressionWithPattern:kAtRegularExpression options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray *atResults = [atRegular matchesInString:self.text options:NSMatchingWithTransparentBounds range:NSMakeRange(0, self.text.length)];
    for (NSTextCheckingResult *checkResult in atResults){
        if (attributed){
            [attributed addAttribute:NSForegroundColorAttributeName value:[UIColor purpleColor] range:checkResult.range];
        }
        [rangeArray addObject:[NSValue valueWithRange:checkResult.range]];
    }
    // 识别连续的数字
    NSRegularExpression *numberRegular = [NSRegularExpression regularExpressionWithPattern:kNumberRegularExpression options:NSRegularExpressionCaseInsensitive|NSRegularExpressionUseUnixLineSeparators error:nil];
    NSArray *numberResults = [numberRegular matchesInString:self.text options:NSMatchingWithTransparentBounds range:NSMakeRange(0, self.text.length)];
    for (NSTextCheckingResult *checkResult in numberResults){
        if (attributed){
            [attributed addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(checkResult.range.location, checkResult.range.length-1)];
        }
        [rangeArray addObject:[NSValue valueWithRange:NSMakeRange(checkResult.range.location, checkResult.range.length-1)]];
    }
    return rangeArray;
}
#pragma mark - 手势识别相关
- (void)longPress:(UIGestureRecognizer *)gesture{
    // 改变字符串的颜色并进行重绘
    if (gesture.state == UIGestureRecognizerStateBegan){
        if (self.pressRange.length != 0||self.pressRange.location != 0) {
            [self setNeedsDisplay];
        }
    }else if(gesture.state == UIGestureRecognizerStateEnded){
        if (self.pressRange.location != 0 && self.pressRange.length != 0){
            NSString *clickStr = [self.text substringWithRange:self.pressRange];
            NSLog(@"点击了 %@",clickStr);
            self.pressRange = NSMakeRange(0, 0);
            [self setNeedsDisplay];
        }
    }
}
#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    // 点击处在特定字符串内才进行识别
    BOOL gestureShouldBegin = NO;
    CGPoint location = [gestureRecognizer locationInView:self];
    //单行高度
    CGFloat lineHeight = self.font.pointSize * kPerLineRatio;
    //点击行数
    int lineIndex = location.y/lineHeight;
    // 把点击的坐标转换为CoreText坐标系下
    CGPoint clickPoint = CGPointMake(location.x, self.height - location.y);

    CFArrayRef lines = CTFrameGetLines(self.ctFrame);
    if (lineIndex < CFArrayGetCount(lines)){
        CTLineRef clickLine = CFArrayGetValueAtIndex(lines, lineIndex);
        // 点击处的字符位于总字符串的index
        CFIndex strIndex = CTLineGetStringIndexForPosition(clickLine, clickPoint);
        NSMutableAttributedString *mutableAttributed = [[NSMutableAttributedString alloc] initWithString:self.text];
        NSArray *checkResults = [self recognizeSpecialStringWithAttributed:mutableAttributed];
        for (NSValue *value in checkResults){
            NSRange range = [value rangeValue];
            if (strIndex >= range.location && strIndex <= range.location + range.length){
                self.pressRange = range;
                gestureShouldBegin = YES;
            }
        }
    }
    return gestureShouldBegin;
}
// 该方法可实现也可不实现，取决于应用场景
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]])
    {
        return YES; // 避免应用在UITableViewCell上时，挡住拖动tableView的手势
    }
    
    return NO;
}
@end
