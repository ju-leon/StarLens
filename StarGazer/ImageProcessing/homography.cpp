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

/**
 Minimum roundnes required to be counted as a star.
 */
const float ROUNDNESS_THRESHOLD = 0.8;

/**
 Minimum area required to be counted as a star.
 */
const int AREA_THRESHOLD = 39;

/**
 Maxmium distance allowed to match 2 stars.
 */
const int DISTANCE_THRESHOLD = 50;

bool combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &mask, std::size_t numImages, cv::Mat &result) {
    Mat imReg, h;
    if (alignImages(imageNew, mask, imageBase, imReg, h)) {
        std::cout << "Successfully aligned" << std::endl;

        imReg.convertTo(imReg, CV_32FC3);

        double weight = 1.0 / numImages;
        
        addWeighted(imageBase, 1, imReg, 1, 0.0, result, CV_32FC3);
        //cv::max(imageBase, imReg, result);
        return true;
        
    } else {
        return false;
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

void pointsToMat(std::vector<cv::Point2i> &points, cv::Mat &mat) {
    cv::Mat_<float> features(0, 2);
    for (auto &&point: points) {
        //Fill matrix
        cv::Mat row = (cv::Mat_<float>(1, 2) << point.x, point.y);
        features.push_back(row);
    }
    mat = features;
}

void extractStars(cv::Mat &image,
                  std::vector<KeyPoint> &keypoints,
                  std::vector<cv::Point2i> &starCenters) {
    
    cv::Mat1b contourMat(image.size());
    
    for (auto keypoint: keypoints) {
        cv::circle(contourMat, keypoint.pt, keypoint.size / 2, 255, -1);
    }
    
    vector<vector<Point> > contours;
    vector<Vec4i> hierarchy;
    cv::findContours(contourMat, contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE);
    
    for (vector<Point> contour : contours) {
        if (contour.size() < 1) {
            continue;
        }
        
        auto area = cv::contourArea(contour);
        std::vector<Point> convexHull;
        cv::convexHull(contour, convexHull);
        auto convexHullArea = cv::contourArea(convexHull);
        
        if (convexHullArea == 0) {
            continue;
        }
        
        auto ratio = area / convexHullArea;
        
        if (ratio >= ROUNDNESS_THRESHOLD && area > AREA_THRESHOLD) {
            Moments moment = cv::moments(contour);
            int cX = moment.m10 / moment.m00;
            int cY = moment.m01 / moment.m00;

            starCenters.emplace_back(Point2i(cX, cY));
        }
    }
}

void matchStars(std::vector<cv::Point2i> &points1,
        std::vector<cv::Point2i> &points2,
        std::vector<cv::DMatch> &matches,
        int max_distance = DISTANCE_THRESHOLD) {
    std::cout << "Matching stars" << std::endl;

    cv::Mat features1, features2;
    pointsToMat(points1, features1);
    pointsToMat(points2, features2);

    cv::flann::GenericIndex<cvflann::L2<float>> kdTree1(features1, cvflann::KDTreeIndexParams());
    cv::flann::GenericIndex<cvflann::L2<float>> kdTree2(features2, cvflann::KDTreeIndexParams());

    for (int index1 = 0; index1 < points1.size(); index1++) {
        auto query_point1 = points1[index1];

        // Find the closest point in the second image
        std::vector<float> query2;
        query2.push_back(query_point1.x);
        query2.push_back(query_point1.y);
        vector<int> indices2;
        indices2.resize(2);
        vector<float> distances2;
        distances2.resize(2);
        kdTree2.knnSearch(query2, indices2, distances2, 2, cvflann::SearchParams());
        // Index of the closest star in the second image
        auto index2 = indices2[0];
        auto query_point2 = points2[index2];

        // Find the closest point to the just discovered point in the first image
        std::vector<float> query1;
        query1.push_back(query_point2.x);
        query1.push_back(query_point2.y);
        vector<int> indices1;
        indices1.resize(2);
        vector<float> distances1;
        distances1.resize(2);
        kdTree1.knnSearch(query1, indices1, distances1, 2, cvflann::SearchParams());

        // If the point in backwards directions equals the point in the first image,
        // then the two points are a match.
        if (index1 == indices1[0]) {
            if (distances1[0] < max_distance) {
                matches.push_back(DMatch(index1, index2, distances1[0]));
            }
            matches.push_back(DMatch(index1, index2, distances1[0]));
        }
    }
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
    Ptr<Feature2D> star = xfeatures2d::StarDetector::create(20, 16, 10, 8, 3);
    star->detect(im1Gray, keypoints1);
    star->detect(im2Gray, keypoints2);

    std::cout << "Found " << keypoints1.size() << " keypoints to track" << std::endl;

    if (keypoints1.size() < 5 || keypoints2.size() < 5) {
        std::cout << "Not enough keypoints to track" << std::endl;
        return false;
    }
    
    std::vector<Point2i> points1, points2;
    extractStars(im1Gray, keypoints1, points1);
    extractStars(im2Gray, keypoints2, points2);
    
    std::cout << "Extracted " << points1.size() << " stars from keypoints1" << std::endl;
    std::cout << "Extracted " << points2.size() << " stars from keypoints2" << std::endl;

    if (points1.size() < 5 || points2.size() < 5) {
        std::cout << "Not enough stars to track" << std::endl;
        return false;
    }

    std::vector<DMatch> matches;
    matchStars(points1, points2, matches);

    //OPTIONAL: REMOVE BAD MATCHES. SEE HOW IT GOES FIRST
    /*
    // Sort matches by score
    std::sort(matches.begin(), matches.end());

    // Remove not so good matches
    const int numGoodMatches = matches.size() * GOOD_MATCH_PERCENT;
    matches.erase(matches.begin() + numGoodMatches, matches.end());
    */

    std::vector<Point2i> matched_points1, matched_points2;
    for (size_t i = 0; i < matches.size(); i++) {
        matched_points1.push_back(points1[matches[i].queryIdx]);
        matched_points2.push_back(points2[matches[i].trainIdx]);
    }


    if (matched_points1.size() < 10) {
        std::cout << "Not enough features to match found" << std::endl;
        return false;
    }

    std::cout << "Found " << matched_points1.size() << " points to match" << std::endl;

    // Find homography
    h = findHomography(matched_points2, matched_points1, RANSAC);

    // Use homography to warp image
    warpPerspective(im1, im1Reg, h, im2.size());
    return true;
}
