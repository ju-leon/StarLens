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



- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages {
    self = [super init];

    string pathString = std::string([path UTF8String]);
    
    std::ifstream ifs(pathString, std::ios::binary);
    readMatBinary(ifs, _combinedImage);
    readMatBinary(ifs, _maxedImage);
    readMatBinary(ifs, _stackedImage);
    readMatBinary(ifs, _mask);
    
    if (_combinedImage.empty() || _maxedImage.empty() || _stackedImage.empty()) {
        return nil;
    }
    
    _maxedImage.convertTo(_maxedImage, CV_64F);
    
    resize(_combinedImage, _combinedImagePreview, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));

    resize(_maxedImage, _maxedImagePreview, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    
    resize(_stackedImage, _stackedImagePreview, cv::Size(_stackedImage.rows / 3, _stackedImage.cols / 3));
    
    resize(_mask, _maskPreview, cv::Size(_mask.rows / 3, _mask.cols / 3));


    contrast = 1;
    brightness = 0;
    starPop = 1;
    
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
    // Convert skyPop value to range [0.8, 1.2]
    starPop = (factor * 0.4) + 0.8;
}

/**
 Set a brightness value in range [0, 1]
 */
- (void) setBrightness: (double) factor {
    // Convert brightness value to range [-127, 127]
    brightness = (factor * 255) - 127;
}


/**
 Set a contrast level in range [0, 1]
 */
- (void) setContrast: (double) factor {
    //Convert contrast value to range [0, 1.5]
    contrast = factor * 1.5;
}

#ifdef __cplusplus

double contrast;
double brightness;
double starPop;
double skyPop;

void applyFilters(Mat &imageCombined, Mat &imageMaxed, Mat &foreground, Mat &mask, Mat &result) {
    // Apply skyPop
    result = imageCombined.mul(imageMaxed / 255 * starPop);
    
    
    // Apply contrast and brightness, convert back to int
    result.convertTo(result, CV_8U, contrast, brightness);

    // Apply mask
    blendMasked(result, foreground, mask, result);
}

#endif

@end
