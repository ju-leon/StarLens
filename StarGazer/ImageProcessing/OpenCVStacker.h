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

- (instancetype) initWithImage:(UIImage *)image withMask: (nullable UIImage *)mask visaliseTrackingPoints: (bool)enabled;

/**
 * Merges a new image onto the current stack.
 * SLOW! ONLY CALL ASYNC!
 * @param image
 */
- (nullable UIImage *)addAndProcess:(UIImage *)image;

/**
 * Return the previously processed image.
 * Can be called at any point to get a preview.
 * @return
 */
- (UIImage *)getProcessedImage;

- (UIImage *)getPreviewImage;

- (void) saveFiles: (NSString *) path;

@end

NS_ASSUME_NONNULL_END
