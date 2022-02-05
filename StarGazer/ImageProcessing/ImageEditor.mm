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

Mat stackedImage_;
Mat maxedImage_;

Mat filteredImage_;

Mat laplacian_;


- (instancetype) initWithStackedImage:(UIImage *)stackedImage :(UIImage *) maxedImage {
    self = [super init];
    if (self) {
        if ([stackedImage isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [stackedImage rotateToImageOrientation];
            stackedImage_ = [rotatedImage CVMat3];
        } else {
            NSLog(@"OpenCVStacker unsupportedImageFormat");
            return nil;
        }

        if ([maxedImage isKindOfClass:[UIImage class]]) {
            UIImage *rotatedImage = [maxedImage rotateToImageOrientation];
            maxedImage_ = [rotatedImage CVMat3];
        } else {
            NSLog(@"OpenCVStacker unsupportedImageFormat");
            return nil;
        }
    }
    stackedImage_.copyTo(filteredImage_);
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
    Mat image;

    std::cout << filteredImage_.size() << std::endl;
    std::cout << laplacian_.size() << std::endl;
    
    addWeighted(filteredImage_, 1, laplacian_, factor, 0, image);

    return [UIImage imageWithCVMat:image];
}

@end
