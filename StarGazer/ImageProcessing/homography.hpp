//
//  homography.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#ifndef CVOpenTemplate_Header_h
#define CVOpenTemplate_Header_h

#include <opencv2/opencv.hpp>

bool combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &movement, std::size_t numImages, cv::Mat &result);

void createTrackingMask(cv::Mat &segmentation, cv::Mat &mask);

bool alignImages(cv::Mat &im1, cv::Mat &movement, cv::Mat &im2, cv::Mat &im1Reg, cv::Mat &h);

float getThreshold(cv::Mat &img_grayscale);

float getStarCenters(cv::Mat &image, float threshold, std::vector<cv::Point2i> &starCenters);

void matchStars(std::vector<cv::Point2i> &points1, std::vector<cv::Point2i> &points2, std::vector<cv::DMatch> &matches);

#endif /* homography_hpp */
