//
//  homography.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//
#include "homography.hpp"

#include <fstream>

using namespace std;
using namespace cv;

const int MAX_FEATURES = 500;
const float GOOD_MATCH_PERCENT = 0.15f;


void combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &movement, std::size_t numImages, cv::Mat &result) {
    Mat imReg, h;
    alignImages(imageNew, movement, imageBase, imReg, h);

    imReg.convertTo(imReg, CV_32FC3);

    addWeighted(0.8 * result, 1, imReg, 0.3 * numImages, 0.0, result, CV_32FC3);
    //imageBase = imageBase + imReg;

}

void alignImages(Mat &im1, Mat &movement, Mat &im2, Mat &im1Reg, Mat &h) {
    // Convert images to grayscale
    Mat im1Gray, im2Gray;
    cvtColor(im1, im1Gray, cv::COLOR_BGR2GRAY);
    cvtColor(im2, im2Gray, cv::COLOR_BGR2GRAY);

    // Detect stars in image
    std::vector<KeyPoint> keypoints1, keypoints2;
    Ptr<Feature2D> star = xfeatures2d::StarDetector::create(100,10,10,8,2);
    star->detect(im1Gray, keypoints1);
    star->detect(im2Gray, keypoints2);

    std::cout << "Num Keypoints 1: " << keypoints1.size() << std::endl;
    std::cout << "Num Keypoints 2: " << keypoints2.size() << std::endl;

    // Find descriptors for stars
    Mat descriptors1, descriptors2;
    Ptr<Feature2D> brief = xfeatures2d::BriefDescriptorExtractor::create();
    brief->compute(im1Gray, keypoints1, descriptors1);
    brief->compute(im2Gray, keypoints2, descriptors2);

    // Match features.
    std::vector<DMatch> matches;
    Ptr<DescriptorMatcher> matcher = DescriptorMatcher::create("BruteForce-Hamming");
    matcher->match(descriptors1, descriptors2, matches, Mat());

    // Sort matches by score
    std::sort(matches.begin(), matches.end());

    // Remove not so good matches
    const int numGoodMatches = matches.size() * GOOD_MATCH_PERCENT;
    matches.erase(matches.begin() + numGoodMatches, matches.end());

    // Extract location of good matches
    std::vector<Point2f> points1, points2;

    for (size_t i = 0; i < matches.size(); i++) {
        points1.push_back(keypoints1[matches[i].queryIdx].pt);
        points2.push_back(keypoints2[matches[i].trainIdx].pt);
    }

    std::cout << "Num Points 1: " << points1.size() << std::endl;
    std::cout << "Num Points 2: " << points2.size() << std::endl;
    
    // Find homography
    h = findHomography(points1, points2, RANSAC);

    // Use homography to warp image
    warpPerspective(im1, im1Reg, h, im2.size());
}
