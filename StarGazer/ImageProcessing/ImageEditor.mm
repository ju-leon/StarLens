//
//  ImageEditor.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 05.02.22.
//

#import "ImageEditor.h"
#import "UIImageOpenCV.h"
#import "UIImageRotate.h"
#import "homography.hpp"
#import "hdrmerge.hpp"
#import "ImageMerger.hpp"


using namespace std;
using namespace cv;


@implementation ImageEditor

Mat stackedImage_;
Mat maxedImage_;

Mat filteredImage_;

- (instancetype) initWithStackedImage:(UIImage *)stackedImage :(UIImage *) maxedImage {
    self = [super init];
    if (self) {
        if ([stackedImage isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [stackedImage rotateToImageOrientation];
            stackedImage_ = [rotatedImage CVMat3];
        } else {
            NSLog(@"OpenCVStacker unsupportedImageFormat");
            return nil;
        }

        if ([maxedImage isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [stackedImage rotateToImageOrientation];
            maxedImage_ = [rotatedImage CVMat3];
        } else {
            NSLog(@"OpenCVStacker unsupportedImageFormat");
            return nil;
        }
    }
    maxedImage_.copyTo(filteredImage_);
    return self;
}

- (UIImage *) getFilteredImage {
    return [UIImage imageWithCVMat:filteredImage_];
}

- (UIImage *) enhanceStars: (double) factor {
    return [UIImage imageWithCVMat:filteredImage_];
}

@end
