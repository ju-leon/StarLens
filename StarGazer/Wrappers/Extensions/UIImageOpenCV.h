//
//  UIImageOpenCV.h
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#ifdef __cplusplus
#undef NO
#undef YES
/*
 to use all opencv features, uncomment this line and comment the following two imports.
 */
#import <opencv2/opencv.hpp>

#endif
#import <UIKit/UIKit.h>

@interface UIImage (OpenCV)

    //cv::Mat to UIImage
+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
- (id)initWithCVMat:(const cv::Mat&)cvMat;

    //UIImage to cv::Mat
- (cv::Mat)CVMat;
- (cv::Mat)CVMat3;  // no alpha channel
- (cv::Mat)CVGrayscaleMat;

@end
