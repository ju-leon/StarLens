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

@property cv::Mat combinedImagePreview;
@property cv::Mat maxedImagePreview;
@property cv::Mat stackedImagePreview;

#endif

- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages;


- (void) setStarPop: (double) factor;
- (void) setBrightness: (double) factor;
- (void) setContrast: (double) factor;

- (UIImage *) getFilteredImagePreview;

@end

NS_ASSUME_NONNULL_END
