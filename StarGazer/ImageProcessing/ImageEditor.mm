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

const int LAPLACIAN_THRESHOLD = -25;

Mat combinedImage_;
Mat maxedImage_;
Mat stackedImage_;

Mat filteredImage_;

Mat laplacian_;

Mat tempImage_;

- (instancetype) init:(NSString *)path: (int) numImages {
    self = [super init];

    string pathString = std::string([path UTF8String]);
    
    std::cout << "Searching at path: " << pathString + "/combined.xml" << std::endl;
    
    FileStorage fsCombined(pathString + "/combined.xml", FileStorage::READ);
    fsCombined["combined"] >> combinedImage_;
    fsCombined.release();
    
    combinedImage_.copyTo(filteredImage_);
    filteredImage_ /= numImages;
    filteredImage_.convertTo(filteredImage_, CV_8UC3);
    
    filteredImage_.copyTo(tempImage_);
    
    std::cout << "Combined size: " << combinedImage_.size() << std::endl;
    
    FileStorage fsMaxed(pathString + "/maxed.xml", FileStorage::READ);
    fsMaxed["maxed"] >> maxedImage_;
    fsMaxed.release();

    std::cout << "Maxed size: " << combinedImage_.size() << std::endl;

    FileStorage fsStacked(pathString + "/stacked.xml", FileStorage::READ);
    fsStacked["stacked"] >> stackedImage_;
    fsStacked.release();

    std::cout << "Stacked size: " << combinedImage_.size() << std::endl;

    return self;
}

- (UIImage *) getFilteredImage {
    return [UIImage imageWithCVMat:filteredImage_];
}

- (UIImage *) enhanceStars: (double) factor {
    if (laplacian_.empty()) {
        Mat imGray;
        cvtColor(maxedImage_, imGray, cv::COLOR_BGR2GRAY);
        
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
        cv::threshold(laplacian, threshMat, LAPLACIAN_THRESHOLD, 255, cv::THRESH_BINARY_INV);
        threshMat.convertTo(threshMat, CV_8UC1);
        
        cvtColor(threshMat, laplacian_, COLOR_GRAY2RGB);
    }
    
    addWeighted(filteredImage_, 1, laplacian_, factor, 0, tempImage_);

    return [UIImage imageWithCVMat:tempImage_];
}

- (UIImage *) changeBrightness: (double) factor {
    filteredImage_.convertTo(tempImage_, -1, 1, factor);

    std::cout << "Changed brightness to " << factor << std::endl;
    return [UIImage imageWithCVMat:tempImage_];
}


- (UIImage *) changeContrast: (double) factor {
    filteredImage_.convertTo(tempImage_, -1, factor, 0);

    return [UIImage imageWithCVMat:tempImage_];
}

- (void) finishSingleEdit {
    tempImage_.copyTo(filteredImage_);
}
@end
