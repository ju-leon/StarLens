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
#import "SaveBinaryCV.hpp"
#import "blend.hpp"
#include "enhance.hpp"

using namespace std;
using namespace cv;


@implementation ImageEditor

const int MASK_EROSION_RADIUS = 1;
const int MASK_BLUR_RADIUS = 15;

/**
 Itialises previews of every image.
 All images are resized to save memory and speed up computations.
 */
- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages withMask: (UIImage *) mask{
    self = [super init];
    
    pathString = std::string([path UTF8String]);
    
    std::ifstream ifs(pathString, std::ios::binary);
    readMatBinary(ifs, _combinedImage);
    resize(_combinedImage, _combinedImage, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));
    _combinedImage.convertTo(_combinedImage, CV_32F);
    _combinedImage /= numImages;
    
    readMatBinary(ifs, _maxedImage);
    resize(_maxedImage, _maxedImage, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    _maxedImage.convertTo(_maxedImage, CV_32F);
    
    readMatBinary(ifs, _stackedImage);
    resize(_stackedImage, _stackedImage, cv::Size(_stackedImage.cols / 3, _stackedImage.rows / 3));
    _stackedImage.convertTo(_stackedImage, CV_32F);
    _stackedImage /= numImages;
    
    readMatBinary(ifs, _mask);
    if (_mask.empty()) {
        _mask = Mat::ones(_stackedImage.rows, _stackedImage.cols, CV_32F);
    } else {
        resize(_mask, _mask, cv::Size(_mask.cols / 3, _mask.rows / 3));
    }
    /*
    if (_combinedImage.empty() || _maxedImage.empty() || _stackedImage.empty() || ![mask isKindOfClass:[UIImage class]]) {
        return nil;
    }*/

    numImgs = numImages;
    
    return self;
}

- (UIImage *) getFilteredImagePreview {
    Mat result;
    applyFilters(_combinedImage, _maxedImage, _stackedImage, _mask, result);
    return [UIImage imageWithCVMat: result];
}


- (UIImage *) getFilteredImage {
    Mat result;
    createFilteredImage(result);
    return [UIImage imageWithCVMat: result];
}

- (void) exportRawImage: (NSString *) path {
    Mat result;
    createFilteredImage(result);
    
    cv::cvtColor(result, result, COLOR_BGR2RGB);
    
    result.convertTo(result, CV_16U);
    result = result * 256;
    
    std::cout << [path UTF8String] << std::endl;

    std::vector<Mat> imgs;
    split(result, imgs);
    imwrite([path UTF8String], result);
    
}

/**
 Set a skyPop value in range [0, 1]
 */
- (void) setStarPop: (double) factor {
    // Convert skyPop value to range [0, 1]
    starPop = factor;
}

/**
 Set a contrast level in range [0, 1]
 */
- (void) setLightPolReduction: (double) factor {
    //Convert contrast value to range [1, 256]
    lightPol = factor;
}

/**
 Set a color correction level in range [0.75, 1.25]
 */
- (void) setColor: (double) factor {
    color = (factor * 0.5) + 0.75;
}

/**
 Set a saturation level in range [0.5, 1.5]
 */
- (void) setSaturation: (double) factor {
    saturation = factor + 0.5;
}

/**
 Set a brightness value in range [0, 2]
 */
- (void) setBrightness: (double) factor {
    // Convert brightness value to range [0, 10]
    brightness = (factor * 2);
}

#ifdef __cplusplus


double lightPol;
double starPop;
double skyPop;
double color;
double saturation;
double brightness;

int numImgs;
string pathString;

int maskFeather = 35;

void applyFilters(Mat &imageCombined, Mat &imageMaxed, Mat &foreground, Mat &mask, Mat &result, bool reduceNoise = false) {
    // Apply skyPop
    addWeighted(imageCombined, 1 - starPop, imageMaxed, starPop, 0, result, CV_32F);
    
    adaptStarColor(result, result, color, saturation, brightness);
    
    result *= 256;
    result.convertTo(result, CV_16U);
    
    equalizeIntensity(result, result);
    
    reduceLightPollution(result, result, lightPol);
    
    result /= 256;
    result.convertTo(result, CV_8U);

    Mat foregroundNormal;
    foreground.convertTo(foregroundNormal, CV_8U);

    // Apply mask
    if (!mask.empty()) {
        //Mat floatMask;
        //cvtColor(mask, floatMask, COLOR_GRAY2BGR);
        //floatMask.convertTo(floatMask, CV_32FC3);
        
        applyMask(result, mask, result);
        applyMask(foregroundNormal, 1 - mask, foregroundNormal);
        
        addWeighted(foregroundNormal, 1, result, 1, 0, result, CV_8U);
        
        
    } else {
        result.convertTo(result, CV_8UC3);
    }
    
    if (reduceNoise) {
        noiseReduction(result, result, 3);
    }

}

void createFilteredImage(Mat &result) {
    std::ifstream ifs(pathString, std::ios::binary);
    
    Mat combinedImage, maxedImage, stackedImage, mask;
    readMatBinary(ifs, combinedImage);
    combinedImage.convertTo(combinedImage, CV_32F);
    combinedImage /= numImgs;
    
    readMatBinary(ifs, maxedImage);
    maxedImage.convertTo(maxedImage, CV_32F);
    
    readMatBinary(ifs, stackedImage);
    stackedImage.convertTo(stackedImage, CV_32F);
    stackedImage /= numImgs;
    
    readMatBinary(ifs, mask);
    if (mask.empty()) {
        mask = Mat::ones(stackedImage.rows, stackedImage.cols, CV_32F);
    }
    
    applyFilters(combinedImage, maxedImage, stackedImage, mask, result);
}


#endif

@end
