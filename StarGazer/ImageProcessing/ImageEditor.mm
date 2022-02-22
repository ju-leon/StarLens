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

using namespace std;
using namespace cv;


@implementation ImageEditor


const int _laplacianTHRESHOLD = -25;



- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages withMask: (UIImage *) mask{
    self = [super init];
    
    string pathString = std::string([path UTF8String]);
    
    std::ifstream ifs(pathString, std::ios::binary);
    readMatBinary(ifs, _combinedImage);
    readMatBinary(ifs, _maxedImage);
    readMatBinary(ifs, _stackedImage);
    
    _combinedImage /= numImages;
    _stackedImage /= numImages;
    
    if (_combinedImage.empty() || _maxedImage.empty() || _stackedImage.empty() || ![mask isKindOfClass:[UIImage class]]) {
        return nil;
    }
    
    _maxedImage.convertTo(_maxedImage, CV_32F);
    
    UIImage *maskRot = [mask rotateToImageOrientation];
    _mask = [maskRot CVGrayscaleMat];
    
    
    Mat element = getStructuringElement(MORPH_ELLIPSE, cv::Size(4, 4), cv::Point(2, 2));
    erode(_mask, _mask, element);
    _mask.convertTo(_mask, CV_32F);
    GaussianBlur( _mask,_mask, cv::Size( 19, 19), 0, 0);
    
    resize(_mask, _mask, _combinedImage.size());
    cvtColor(_mask, _mask, COLOR_GRAY2RGB);

    /**
     Resize to speedup previews during editing
     */
    resize(_combinedImage, _combinedImagePreview, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));
    resize(_maxedImage, _maxedImagePreview, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    resize(_stackedImage, _stackedImagePreview, cv::Size(_stackedImage.cols / 3, _stackedImage.rows / 3));
    resize(_mask, _maskPreview, cv::Size(_mask.cols / 3, _mask.rows / 3));


    contrast = 1;
    brightness = 0;
    starPop = 1;
    numImgs = numImages;
    
    return self;
}

- (UIImage *) getFilteredImagePreview {
    Mat result;
    applyFilters(_combinedImagePreview, _maxedImagePreview, _stackedImagePreview, _maskPreview, result);
    return [UIImage imageWithCVMat: result];
}

/**
 Set a skyPop value in range [0, 1]
 */
- (void) setStarPop: (double) factor {
    // Convert skyPop value to range [0, 2]
    starPop = (factor * 1) + 0.5;
}

/**
 Set a brightness value in range [0, 1]
 */
- (void) setBrightness: (double) factor {
    // Convert brightness value to range [-127, 127]
    brightness = (factor * 400) - 127;
}


/**
 Set a contrast level in range [0, 1]
 */
- (void) setContrast: (double) factor {
    //Convert contrast value to range [0, 1.5]
    contrast = factor * 3;
}

#ifdef __cplusplus

double contrast;
double brightness;
double starPop;
double skyPop;
int numImgs;

int maskFeather = 35;

void applyFilters(Mat &imageCombined, Mat &imageMaxed, Mat &foreground, Mat &mask, Mat &result) {
    // Apply skyPop
    result = ((imageCombined) + (imageMaxed * starPop)) / (1 + starPop);
    result = result.mul(imageMaxed / 255 * starPop);
    
    // Apply contrast and brightness
    result.convertTo(result, CV_32F, contrast, brightness);

    Mat foregroundNormal = foreground;
    
    // Apply mask
    if (!mask.empty()) {
        //Mat floatMask;
        //cvtColor(mask, floatMask, COLOR_GRAY2BGR);
        //floatMask.convertTo(floatMask, CV_32FC3);
        blendMasked(result, foregroundNormal, mask, result);
    } else {
        result.convertTo(result, CV_8UC3);
    }
    
}

#endif

@end
