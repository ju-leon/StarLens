//
//  OpenCVWrapper.m
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.12.21.
//


#import "OpenCVStacker.h"
#import "UIImageOpenCV.h"
#import "UIImageRotate.h"
#import "homography.hpp"
#import "hdrmerge.hpp"
#import "ImageMerger.hpp"

using namespace std;
using namespace cv;


@implementation OpenCVStacker

unique_ptr<ImageMerger> merger;

#pragma mark Public

- (instancetype) initWithImage:(UIImage *)image :(bool) maskEnabled {
    NSLog (@"OpenCVStacker initWithImage");

    self = [super init];
    if (self) {
        if ([image isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [image rotateToImageOrientation];
            Mat cvImage = [rotatedImage CVMat3];

            try {
                merger = make_unique<ImageMerger>(cvImage, maskEnabled);
            } catch (const MergingException& e) {
                NSLog(@"OpenCVStacker initWithImage: %s", e.what());
                return nil;
            }

        } else {
            NSLog(@"OpenCVStacker unsupportedImageFormat");
            return nil;
        }
    }
    return self;
}

- (nullable UIImage *)addAndProcess:(UIImage *)image :(UIImage *)maskImage {
    cv::Mat matImage;
    cv::Mat mask;
    if ([image isKindOfClass:[UIImage class]] && [maskImage isKindOfClass:[UIImage class]]) {
        UIImage *rotatedImage = [image rotateToImageOrientation];
        matImage = [rotatedImage CVMat3];

        mask = [maskImage CVGrayscaleMat];
    } else {
        return nullptr;
    }

    Mat preview;

    if (merger->mergeImageOnStack(matImage, mask, preview)) {
       std::cout << "Merge successful" << std::endl;
    } else {
        std::cout << "Merge failed" << std::endl;
        return nil;
    }

    return [UIImage imageWithCVMat:preview];
}

- (UIImage *)getProcessedImage {
    Mat preview;
    merger->getPreview(preview);
    return [UIImage imageWithCVMat:preview];
}

@end
