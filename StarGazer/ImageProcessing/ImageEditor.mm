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


- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages withMask: (UIImage *) mask{
    self = [super init];
    
    string pathString = std::string([path UTF8String]);
    
    std::ifstream ifs(pathString, std::ios::binary);
    readMatBinary(ifs, _combinedImage);
    readMatBinary(ifs, _maxedImage);
    readMatBinary(ifs, _stackedImage);
    readMatBinary(ifs, _mask);
    
    _combinedImage.convertTo(_combinedImage, CV_32F);
    _combinedImage /= numImages;

    _stackedImage.convertTo(_stackedImage, CV_32F);
    _stackedImage /= numImages;
    
    if (_combinedImage.empty() || _maxedImage.empty() || _stackedImage.empty() || ![mask isKindOfClass:[UIImage class]]) {
        return nil;
    }
    
    _maxedImage.convertTo(_maxedImage, CV_32F);
    
    /*
     TODO: Maks is now saved alognside project. No longer needed to pass mask
    UIImage *maskRot = [mask rotateToImageOrientation];
    _mask = [maskRot CVGrayscaleMat];
    
    std::cout << _mask.size << std::endl;
    
    Mat element = getStructuringElement(MORPH_ELLIPSE, cv::Size(MASK_EROSION_RADIUS, MASK_EROSION_RADIUS), cv::Point(-1, -1));
    erode(_mask, _mask, element);
    _mask.convertTo(_mask, CV_32F);
    GaussianBlur( _mask,_mask, cv::Size( MASK_BLUR_RADIUS, MASK_BLUR_RADIUS), 0, 0);
    
    resize(_mask, _mask, _combinedImage.size());
     */
     
    /**
     Resize to speedup previews during editing
     */
    resize(_combinedImage, _combinedImagePreview, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));
    resize(_maxedImage, _maxedImagePreview, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    resize(_stackedImage, _stackedImagePreview, cv::Size(_stackedImage.cols / 3, _stackedImage.rows / 3));
    resize(_mask, _maskPreview, cv::Size(_mask.cols / 3, _mask.rows / 3));

    numImgs = numImages;
    
    return self;
}

- (UIImage *) getFilteredImagePreview {
    Mat result;
    applyFilters(_combinedImagePreview, _maxedImagePreview, _stackedImagePreview, _maskPreview, result);
    return [UIImage imageWithCVMat: result];
}

- (UIImage *) getFilteredImage {
    Mat result;
    applyFilters(_combinedImage, _maxedImage, _stackedImage, _mask, result);
    return [UIImage imageWithCVMat: result];
}

/**
 Set a skyPop value in range [0, 1]
 */
- (void) setStarPop: (double) factor {
    // Convert skyPop value to range [0, 1]
    starPop = factor;
}

/**
 Set a brightness value in range [0, 1]
 */
- (void) setNoiseReduction: (double) factor {
    // Convert brightness value to range [0, 10]
    noiseReductionLevel = factor;
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
    std::cout << "Color:" << color << std::endl;
}

#ifdef __cplusplus

double noiseReductionLevel;
double lightPol;
double starPop;
double skyPop;
double color;
int numImgs;

int maskFeather = 35;

void applyFilters(Mat &imageCombined, Mat &imageMaxed, Mat &foreground, Mat &mask, Mat &result, bool reduceNoise = false) {
    // Apply skyPop
    addWeighted(imageCombined, 1 - starPop, imageMaxed, starPop, 0, result, CV_32F);
    
    increaseStarBrightness(result, result, noiseReductionLevel, color);
    
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
        applyMask(foregroundNormal, 1 - mask, foregroundNormal);
        
        applyMask(result, mask, result);
              
        addWeighted(foregroundNormal, 1, result, 1, 0, result, CV_8U);
        
        
    } else {
        result.convertTo(result, CV_8UC3);
    }
    
    if (reduceNoise) {
        noiseReduction(result, result, 3);
    }

}

#endif

@end
