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


using namespace std;
using namespace cv;


@implementation ImageEditor


const int _laplacianTHRESHOLD = -25;



- (instancetype) initAtPath:(NSString *)path numImages:(int) numImages {
    self = [super init];

    string pathString = std::string([path UTF8String]);
    
    std::cout << "Searching at path: " << pathString + "/combined.xml" << std::endl;
    
    FileStorage fsCombined(pathString + "/combined.xml", FileStorage::READ);
    fsCombined["combined"] >> _combinedImage;
    fsCombined.release();
    
    resize(_combinedImage, _combinedImagePreview, cv::Size(_combinedImage.cols / 3, _combinedImage.rows / 3));
    
    FileStorage fsMaxed(pathString + "/maxed.xml", FileStorage::READ);
    fsMaxed["maxed"] >> _maxedImage;
    fsMaxed.release();
    _maxedImage.convertTo(_maxedImage, CV_64F);

    resize(_maxedImage, _maxedImagePreview, cv::Size(_maxedImage.cols / 3, _maxedImage.rows / 3));
    
    FileStorage fsStacked(pathString + "/stacked.xml", FileStorage::READ);
    fsStacked["stacked"] >> _stackedImage;
    fsStacked.release();
    
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
