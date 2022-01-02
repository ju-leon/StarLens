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

- (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}


#pragma mark Public

+ (UIImage *)stackImages:(NSArray *)images onImage:(UIImage *)image {
    /*
    if ([images count]==0){
        NSLog (@"imageArray is empty");
        return 0;
    }
    
    cv::Mat combinedImage = [[image rotateToImageOrientation] CVMat3];
    // Preserve as much data to the end as possible
    combinedImage.convertTo(combinedImage, CV_32FC3);
    
    std::vector<cv::Mat> matImages;
    
    for (id image in images) {
        if ([image isKindOfClass: [UIImage class]]) {
            UIImage* rotatedImage = [image rotateToImageOrientation];
            cv::Mat matImage = [rotatedImage CVMat3];
            matImages.push_back(matImage);
        } else {
            NSLog(@"Unsupported image type");
            return 0;
        }
    } 
    
    Mat movement;
    findForeground(movement, matImages);
    
    for (int i = 0; i < matImages.size(); i++) {
        combine(combinedImage, matImages[i], movement, matImages.size());
    }
    
    NSLog(@"Done combining");
    // UIImage only supports 8bit color depth
    combinedImage *= 255;
    combinedImage.convertTo(combinedImage, CV_8UC3);
    
    NSLog(@"Done converting");
    UIImage* result =  [UIImage imageWithCVMat:combinedImage];
    return result;
     */
    return 0;
}

- (UIImage *)composeStack {
    Mat movement;
    //findForeground(movement, hdrImages);
    cv::Mat baseImage = hdrImages[0];
    cv::Mat combinedImage;
    baseImage.convertTo(combinedImage, CV_32FC3);


    for (int i = 1; i < hdrImages.size(); i++) {
        combine(baseImage, hdrImages[i], movement, hdrImages.size(), combinedImage);
    }
    // UIImage only supports 8bit color depth
    combinedImage.convertTo(combinedImage, CV_8UC3);

    //combinedImage = combinedImage * 255;
    //combinedImage.convertTo(combinedImage, CV_8UC3);
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


@end
