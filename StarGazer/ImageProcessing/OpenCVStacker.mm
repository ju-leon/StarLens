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

- (instancetype) initWithImage:(UIImage *)image withMask: (nullable UIImage *)mask visaliseTrackingPoints: (bool)enabled{
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
                merger = make_unique<ImageMerger>(cvImage, cvMask, enabled);
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

- (instancetype) initFromCheckpoint: (NSString *)path processed: (int)numImages visualiseTrackingPoints: (bool)enabled {
    auto pathString = std::string([path UTF8String]);
    
    merger = make_unique<ImageMerger>(pathString, numImages, enabled);
    
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

/**
 Returns the processed image from all the currently added images.
 If the init operation of the merger has failed, returns nil
 */
- (nullable UIImage *)getProcessedImage {
    if (merger == nullptr) {
        return nil;
    }
    
    Mat preview;
    merger->getProcessed(preview);
    return [UIImage imageWithCVMat:preview];
}

/**
 Returns the processed images from all the currently added iamges.
 If the init operation of the merger has failed, returns nil
 */
- (nullable UIImage *)getPreviewImage {
    if (merger == nullptr) {
        return nil;
    }
    
    Mat preview;
    merger->getPreview(preview);
    return [UIImage imageWithCVMat:preview];
}

- (void) saveFiles: (NSString *) path {
    merger->saveToDirectory(std::string([path UTF8String]));
}

- (void) deallocMerger {
    merger.reset();
}
@end
