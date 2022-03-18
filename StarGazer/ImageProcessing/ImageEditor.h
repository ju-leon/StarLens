//
//  ImageEditor.h
//  StarGazer
//
//  Created by Leon Jungemeyer on 05.02.22.
//

#import <Foundation/Foundation.h>
//#import "OpenCVWrapper.hpp"
#import <UIKit/UIKit.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>

#ifdef __cplusplus

#import <opencv2/opencv.hpp>

#endif

NS_ASSUME_NONNULL_BEGIN

@interface ImageEditor : NSObject

#ifdef __cplusplus

@property cv::Mat combinedImage;
@property cv::Mat maxedImage;
@property cv::Mat stackedImage;
@property cv::Mat mask;

@property cv::Mat combinedImagePreview;
@property cv::Mat maxedImagePreview;
@property cv::Mat stackedImagePreview;
@property cv::Mat maskPreview;

#endif

- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages withMask: (UIImage *) mask;


- (void) setStarPop: (double) factor;
- (void) setNoiseReduction: (double) factor;
- (void) setLightPolReduction: (double) factor;

- (UIImage *) getFilteredImagePreview;

- (UIImage *) getFilteredImage;

@end

NS_ASSUME_NONNULL_END
