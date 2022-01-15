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

- (UIImage *)hdrMerge:(NSArray *)images :(bool)align;

- (void)addSegmentationMask:(UIImage *)mask;

/**
 * Add a new image to the photo stack to be processed later.
 * @param image
 */
- (void)addImageToStack:(UIImage *)image;

/**
 * Merges a new image onto the current stack.
 * SLOW! ONLY CALL ASYNC!
 * @param image
 */
- (nullable UIImage *)addAndProcess:(UIImage *)image :(UIImage *)mask;

/**
 * Return the previously processed image.
 * Can be called at any point to get a preview.
 * @return
 */
- (UIImage *)getProcessedImage;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
