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

using namespace std;
using namespace cv;


@implementation ImageEditor


const int _laplacianTHRESHOLD = -25;



- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages {
    self = [super init];

    string pathString = std::string([path UTF8String]);
    
    std::ifstream ifs(pathString + "/checkpoint.stargazer", std::ios::binary);
    readMatBinary(ifs, _combinedImage);
    readMatBinary(ifs, _maxedImage);
    _maxedImage.convertTo(_maxedImage, CV_64F);
    readMatBinary(ifs, _stackedImage);
    
    std::cout << "Combined image type: " << _combinedImage.type() << std::endl;
    std::cout << "Maxed image type: " << _maxedImage.type() << std::endl;
    std::cout << "Stacked image type: " << _stackedImage.type() << std::endl;

    
    resize(_combinedImage, _combinedImagePreview, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));

    resize(_maxedImage, _maxedImagePreview, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    
    //TODO: UNCOMMENT
    //resize(_stackedImage, _stackedImagePreview, cv::Size(_stackedImage.rows / 3, _stackedImage.cols / 3));


    contrast = 1;
    brightness = 0;
    starPop = 1;
    
    return self;
}

- (UIImage *) getFilteredImagePreview {
    Mat result;
    applyFilters(_combinedImagePreview, _maxedImagePreview, _stackedImagePreview, result);
    return [UIImage imageWithCVMat: result];
}

/**
 Seta skyPop value in range [0, 1]
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

void applyFilters(Mat &imageCombined, Mat &imageMaxed, Mat &foreground, Mat &result) {
    // Apply skyPop
    result = imageCombined.mul(imageMaxed / 255 * starPop);
    
    
    // Apply contrast and brightness, convert back to int
    result.convertTo(result, CV_8U, contrast, brightness);
}

#endif

@end
