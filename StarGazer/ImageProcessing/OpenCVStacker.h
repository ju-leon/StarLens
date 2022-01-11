//
//  OpenCVWrapper.h
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.12.21.
//



#import <Foundation/Foundation.h>
//#import "OpenCVWrapper.hpp"
#import <UIKit/UIKit.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
//#import <opencv2/opencv.hpp>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVStacker : NSObject
- (NSString *)openCVVersionString;

- (UIImage *)composeStack;

- (UIImage *)composeTrailing;

- (UIImage *)hdrMerge:(NSArray *)images: (bool)align;

- (void)addSegmentationMask:(UIImage *)mask;

- (void)addImageToStack:(UIImage *)image;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
