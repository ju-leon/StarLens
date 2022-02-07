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

@property cv::Mat filteredImage;

@property cv::Mat laplacian;

@property cv::Mat tempImage;

#endif

- (instancetype) init:(NSString *)path: (int) numImages;

- (UIImage *) getFilteredImage;

- (UIImage *) enhanceStars: (double) factor;

- (UIImage *) changeBrightness: (double) factor;

- (UIImage *) changeContrast: (double) factor;

- (UIImage *) enhanceSky: (double) factor;

- (void) finishSingleEdit;

@end

NS_ASSUME_NONNULL_END
