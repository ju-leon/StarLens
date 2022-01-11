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

/**
Align images by tracking the positions of the stars.
All images with enough features are stacked.
 */
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

    combinedImage /= hdrImages.size();

    combinedImage.convertTo(combinedImage, CV_8UC3);

    std::cout << "Stacked Size: " << combinedImage.size() << std::endl;

    UIImage *result = [UIImage imageWithCVMat:combinedImage];

    return result;
}

/**
 Stack all images without aligning to create star trailing images.
 */
- (UIImage *)composeTrailing {
    cv::Mat baseImage = hdrImages[0];

    // HDR will crop the images slightly differently
    // Find the smallest sizes to combine the images
    int min_cols = baseImage.cols;
    int min_rows = baseImage.rows;
    for (int i = 1; i < hdrImages.size(); i++) {
        if (hdrImages[i].cols < min_cols) {
            min_cols = hdrImages[i].cols;
        }
        if (hdrImages[i].rows < min_rows) {
            min_rows = hdrImages[i].rows;
        }
    }

    cv::Mat combinedImage;
    baseImage.convertTo(combinedImage, CV_32FC3);
    combinedImage = combinedImage(cv::Rect(0, 0, min_cols, min_rows));
    for (int i = 1; i < hdrImages.size(); i++) {
        cv::Mat imReg;
        hdrImages[i].convertTo(imReg, CV_32FC3);
        imReg = imReg(cv::Rect(0, 0, min_cols, min_rows));
        addWeighted(combinedImage, 1.0, imReg, 1.0, 0.0, combinedImage, CV_32FC3);
    }
    combinedImage /= hdrImages.size();
    combinedImage.convertTo(combinedImage, CV_8UC3);

    std::cout << "Trailing Size: " << combinedImage.size() << std::endl;

    UIImage *result = [UIImage imageWithCVMat:combinedImage];
    return result;
}

- (UIImage *)hdrMerge:(NSArray *)images :(bool)align {
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
    hdrMerge(matImages, merged, align);

    merged = merged * 255;
    merged.convertTo(merged, CV_8UC3);

    hdrImages.emplace_back(merged);
    UIImage *result = [UIImage imageWithCVMat:merged];
    return result;
}

- (void)addImageToStack:(UIImage *)image {
    if ([image isKindOfClass:[UIImage class]]) {
        UIImage *rotatedImage = [image rotateToImageOrientation];
        cv::Mat matImage = [rotatedImage CVMat3];
        hdrImages.push_back(matImage);
    } else {
        return;
    }
}

- (void)addSegmentationMask:(UIImage *)mask {
    cv::Mat matMask = [mask CVGrayscaleMat];
    segmentationMasks.emplace_back(matMask);
}

- (void)reset {
    NSLog(@"Reset");
    hdrImages = vector<Mat>();
    segmentationMasks = vector<Mat>();
}

@end
