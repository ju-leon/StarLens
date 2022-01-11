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


void combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &mask, std::size_t numImages, cv::Mat &result) {
    Mat imReg, h;
    if (alignImages(imageNew, mask, imageBase, imReg, h)) {
        std::cout << "Successfully aligned" << std::endl;

        imReg.convertTo(imReg, CV_32FC3);

        //addWeighted(0.8 * result, 1, imReg, 0.3 * numImages, 0.0, result, CV_32FC3);
        addWeighted(result, 1.0, imReg, 1.0, 0.0, result, CV_32FC3);
        //imageBase = imageBase + imReg;
    } else {

    }
}

void createTrackingMask(cv::Mat &segmentation, cv::Mat &mask) {
    resize(segmentation, mask, cv::Size(segmentation.cols, segmentation.rows), INTER_LINEAR);
    mask.setTo(255, mask == 3);
    mask.setTo(255, mask == 22);
    mask.setTo(255, mask == 27);
    threshold(mask, mask, 254, 255, THRESH_BINARY);

    Mat element = getStructuringElement(MORPH_ELLIPSE, cv::Size(20, 20), cv::Point(10, 10));
    erode(mask, mask, element);

    GaussianBlur(mask, mask, cv::Size(101, 101), 0);

    mask.convertTo(mask, CV_16FC1);
    mask /= 255;
}

bool alignImages(Mat &im1, Mat &mask, Mat &im2, Mat &im1Reg, Mat &h) {
    // Convert images to grayscale
    Mat im1Gray, im2Gray;
    cvtColor(im1, im1Gray, cv::COLOR_BGR2GRAY);
    cvtColor(im2, im2Gray, cv::COLOR_BGR2GRAY);

    //Temporarily convert images to float to allow soft masking
    im1Gray.convertTo(im1Gray, CV_16FC1);
    im2Gray.convertTo(im2Gray, CV_16FC1);

    im1Gray.mul(mask);
    im2Gray.mul(mask);

    im1Gray.convertTo(im1Gray, CV_8UC1);
    im2Gray.convertTo(im2Gray, CV_8UC1);

    // Detect stars in image
    std::vector<KeyPoint> keypoints1, keypoints2;
    Ptr<Feature2D> star = xfeatures2d::StarDetector::create(50, 20, 10, 8, 5);
    star->detect(im1Gray, keypoints1);
    star->detect(im2Gray, keypoints2);

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


    if (points1.size() < 10) {
        std::cout << "Not enough features to track found" << std::endl;
        return false;
    }

    std::cout << "Found " << points1.size() << " features to track" << std::endl;

    // Find homography
    h = findHomography(points1, points2, RANSAC);

    // Use homography to warp image
    warpPerspective(im1, im1Reg, h, im2.size());
    return true;
}
