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

- (instancetype) init:(NSString *)path: (int) numImages;

- (UIImage *) getFilteredImage;

- (UIImage *) enhanceStars: (double) factor;

- (UIImage *) changeBrightness: (double) factor;

- (UIImage *) changeContrast: (double) factor;

- (void) finishSingleEdit;

@end

NS_ASSUME_NONNULL_END
