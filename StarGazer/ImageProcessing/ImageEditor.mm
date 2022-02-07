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



- (instancetype) init:(NSString *)path: (int) numImages {
    self = [super init];

    string pathString = std::string([path UTF8String]);
    
    std::cout << "Searching at path: " << pathString + "/combined.xml" << std::endl;
    
    FileStorage fsCombined(pathString + "/combined.xml", FileStorage::READ);
    fsCombined["combined"] >> _combinedImage;
    fsCombined.release();
    
    _combinedImage.copyTo(_filteredImage);
    _filteredImage /= numImages;
    _filteredImage.convertTo(_filteredImage, CV_8UC3);
    
    _filteredImage.copyTo(_tempImage);
    
    std::cout << "Combined size: " << _combinedImage.size() << std::endl;
    
    FileStorage fsMaxed(pathString + "/maxed.xml", FileStorage::READ);
    fsMaxed["maxed"] >> _maxedImage;
    fsMaxed.release();

    std::cout << "Maxed size: " << _combinedImage.size() << std::endl;

    FileStorage fsStacked(pathString + "/stacked.xml", FileStorage::READ);
    fsStacked["stacked"] >> _stackedImage;
    fsStacked.release();

    std::cout << "Stacked size: " << _combinedImage.size() << std::endl;

    return self;
}

- (UIImage *) getFilteredImage {
    return [UIImage imageWithCVMat:_filteredImage];
}

- (UIImage *) enhanceStars: (double) factor {
    if (_laplacian.empty()) {
        Mat imGray;
        cvtColor(_maxedImage, imGray, cv::COLOR_BGR2GRAY);
        
        // Blur the image first to be less sensitive to noise
        GaussianBlur( imGray, imGray, cv::Size(9, 9), 0, 0, BORDER_DEFAULT );

        // Detect the stars using a Laplacian
        Mat laplacian;
        int kernel_size = 3;
        int scale = 1;
        int delta = 0;
        Laplacian( imGray, laplacian, CV_16S, kernel_size, scale, delta, BORDER_DEFAULT );

        // Only count stars that fall under the determined threshold
        Mat threshMat;
        cv::threshold(laplacian, threshMat, _laplacianTHRESHOLD, 255, cv::THRESH_BINARY_INV);
        threshMat.convertTo(threshMat, CV_8UC1);
        
        cvtColor(threshMat, _laplacian, COLOR_GRAY2RGB);
    }
    
    addWeighted(_filteredImage, 1, _laplacian, factor, 0, _tempImage);

    return [UIImage imageWithCVMat:_tempImage];
}

- (UIImage *) enhanceSky: (double) factor {
    Mat multiplyMat;
    
    _maxedImage.convertTo(multiplyMat, CV_64F);
    multiplyMat /= factor;
    
    cv::multiply(_filteredImage, multiplyMat, _tempImage, 1, CV_8UC3);
    
    return [UIImage imageWithCVMat:_tempImage];
}

- (UIImage *) changeBrightness: (double) factor {
    _filteredImage.convertTo(_tempImage, -1, 1, factor);

    return [UIImage imageWithCVMat:_tempImage];
}


- (UIImage *) changeContrast: (double) factor {
    _filteredImage.convertTo(_tempImage, -1, factor, 0);

    return [UIImage imageWithCVMat:_tempImage];
}

- (void) finishSingleEdit {
    _tempImage.copyTo(_filteredImage);
}
@end
