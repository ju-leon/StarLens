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
//#import <opencv2/opencv.hpp>

NS_ASSUME_NONNULL_BEGIN

@interface ImageEditor : NSObject

- (instancetype) initWithStackedImage:(UIImage *)stackedImage :(UIImage *) maxedImage;

- (UIImage *) getFilteredImage;

- (UIImage *) enhanceStars: (double) factor;

@end

NS_ASSUME_NONNULL_END
