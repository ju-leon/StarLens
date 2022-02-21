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

- (instancetype) initWithImage:(UIImage *)image withMask: (nullable UIImage *)mask{
    NSLog (@"OpenCVStacker initWithImage");

    self = [super init];
    if (self) {
        if ([image isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [image rotateToImageOrientation];
            Mat cvImage = [rotatedImage CVMat3];
            
            Mat cvMask;
            if (mask != nil && [mask isKindOfClass:[UIImage class]]) {
                UIImage *rotatedMask = [mask rotateToImageOrientation];
                cvMask = [rotatedMask CVGrayscaleMat];
            }
            
            try {
                merger = make_unique<ImageMerger>(cvImage, cvMask);
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

- (nullable UIImage *)addAndProcess:(UIImage *)image {
    cv::Mat matImage;
    cv::Mat mask;
    if ([image isKindOfClass:[UIImage class]]) {
        UIImage *rotatedImage = [image rotateToImageOrientation];
        matImage = [rotatedImage CVMat3];
    } else {
        return nullptr;
    }

    Mat preview;

    if (merger->mergeImageOnStack(matImage, preview)) {
       std::cout << "Merge successful" << std::endl;
    } else {
        std::cout << "Merge failed" << std::endl;
        return nil;
    }

    return [UIImage imageWithCVMat:preview];
}

- (UIImage *)getProcessedImage {
    Mat preview;
    merger->getProcessed(preview);
    return [UIImage imageWithCVMat:preview];
}

- (UIImage *)getPreviewImage {
    Mat preview;
    merger->getPreview(preview);
    return [UIImage imageWithCVMat:preview];
}

- (void) saveFiles: (NSString *) path {
    merger->saveToDirectory(std::string([path UTF8String]));
}

@end
