//
//  homography.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#ifndef CVOpenTemplate_Header_h
#define CVOpenTemplate_Header_h
#include <opencv2/opencv.hpp>

void combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &movement);

void alignImages(cv::Mat &im1, cv::Mat &movement, cv::Mat &im2, cv::Mat &im1Reg, cv::Mat &h);
#endif /* homography_hpp */
