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

using namespace std;
using namespace cv;


@implementation OpenCVStacker

vector<Mat> hdrImages;
vector<Mat> segmentationMasks;
Mat foregroundMask;

- (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}


#pragma mark Public

- (UIImage *)composeStack {
    //findForeground(movement, hdrImages);
    cv::Mat baseImage = hdrImages[0];
    cv::Mat combinedImage;

    resize(segmentationMasks[0], foregroundMask, baseImage.size(), INTER_AREA);
    createTrackingMask(foregroundMask, foregroundMask);

    baseImage.convertTo(combinedImage, CV_32FC3);
    for (int i = 1; i < hdrImages.size(); i++) {
        combine(baseImage, hdrImages[i], foregroundMask, hdrImages.size(), combinedImage);
    }

    combinedImage.convertTo(combinedImage, CV_8UC3);

    UIImage *result = [UIImage imageWithCVMat:combinedImage];
    return result;
}


- (UIImage *)hdrMerge:(NSArray *)images {
    if ([images count] == 0) {
        NSLog(@"imageArray is empty");
        return 0;
    }

    if ([images count] == 1) {
        NSLog(@"Only one left. cannot merge");
        //hdrImages.emplace_back(images[0]);
        return images[0];
    }

    std::vector<cv::Mat> matImages;
    for (id image in images) {
        if ([image isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [image rotateToImageOrientation];
            cv::Mat matImage = [rotatedImage CVMat3];
            matImages.push_back(matImage);
        } else {
            return 0;
        }
    }

    cv::Mat merged;
    hdrMerge(matImages, merged);

    merged = merged * 255;
    merged.convertTo(merged, CV_8UC3);

    hdrImages.emplace_back(merged);
    UIImage *result = [UIImage imageWithCVMat:merged];
    return result;
}

- (void)addSegmentationMask:(UIImage *)mask {
    cv::Mat matMask = [mask CVGrayscaleMat];
    segmentationMasks.emplace_back(matMask);
}

- (void)reset {
    hdrImages = vector<Mat>();
    segmentationMasks = vector<Mat>();
}

@end
