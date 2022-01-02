//
//  OpenCVWrapper.h
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.12.21.
//



#import <Foundation/Foundation.h>
//#import "OpenCVWrapper.hpp"
#import <UIKit/UIKit.h>
//#import <opencv2/opencv.hpp>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVStacker : NSObject
- (NSString *)openCVVersionString;

//    +(UIImage *)toGray:(UIImage *)source;
+ (UIImage *)stackImages:(NSArray *)images onImage:(UIImage *)image;

- (UIImage *)composeStack;

- (UIImage *)hdrMerge:(NSArray *)images;
//    +(Mat)matFrom:(UIImage *)source;
//    +(UIImage *)imageFrom:(Mat)source;


@end

NS_ASSUME_NONNULL_END
