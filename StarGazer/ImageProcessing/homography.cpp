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
const int MIN_AREA_THRESHOLD = 5;

/**
 Maximum area to be counted as a star.
 Prevent clouds from being counted as stars.
 */
const int MAX_AREA_THRESHOLD = 1000;

/**
 Maxmium distance allowed to match 2 stars.
 */
const int DISTANCE_THRESHOLD = 50;

/**
 Minimum number of contours required to start a star detection.
 */
const int MIN_NUM_CONTOURS = 2000;

/**
 Minimum number of contours allowed  to start a star detection.
 */
const int MAX_NUM_CONTOURS = 20000;



void createTrackingMask(cv::Mat &segmentation, cv::Mat &mask) {
    mask = Mat::zeros(segmentation.size(), CV_32FC1);
    mask.setTo(1.0, segmentation == 3);
    mask.setTo(1.0, segmentation == 22);
    mask.setTo(1.0, segmentation == 27);

    Mat element = getStructuringElement(MORPH_ELLIPSE, cv::Size(4, 4), cv::Point(2, 2));
    erode(mask, mask, element);

    GaussianBlur(mask, mask, cv::Size(25, 25), 0);
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

void matchStars(std::vector<cv::Point2i> &points1,
        std::vector<cv::Point2i> &points2,
        std::vector<cv::DMatch> &matches) {

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
            if (distances1[0] < DISTANCE_THRESHOLD) {
                matches.push_back(DMatch(index1, index2, distances1[0]));
            }
            //matches.push_back(DMatch(index1, index2, distances1[0]));
        }
    }
}

/**
 Returns the threshold in the Laplacian of an image under which points are used in the contour detector.
 Aims to get a number of contours(that will later be used as starts) between MIN_NUM_CONTOURS and MAX_NUM_CONTOURS
 
 Returns infinity if no threshold could be found
 */
float getThreshold(Mat &img) {
    Mat imgGrayscale;
    cvtColor(img, imgGrayscale, cv::COLOR_BGR2GRAY);


    GaussianBlur( imgGrayscale, imgGrayscale, Size(3, 3), 0, 0, BORDER_DEFAULT );

    int kernel_size = 3;
    int scale = 1;
    int delta = 0;
    Mat laplacian;
    Laplacian( imgGrayscale, laplacian, CV_16S, kernel_size, scale, delta, BORDER_DEFAULT );


    /**
     * Only give 100 tries, abort if no threshold could be found
     */
    float threshold = -200;
    int i = 0;
    while (i++ < 100) {
        Mat threshMat;
        cv::threshold(laplacian, threshMat, threshold, 255, cv::THRESH_BINARY_INV);
        threshMat.convertTo(threshMat, CV_8UC1);

        vector<vector<Point> > contours;
        vector<Vec4i> hierarchy;
        cv::findContours(threshMat, contours, hierarchy, RETR_LIST, CHAIN_APPROX_SIMPLE);
        
        std::cout << "Num Contours: " << contours.size() << std::endl;
        
        if (contours.size() > MAX_NUM_CONTOURS) {
            // To many contours, lower threshold
            // All values we're interested in are negative -> *1.5 gives a lower value
            threshold = threshold * 1.5;
        } else if (contours.size() < MIN_NUM_CONTOURS) {
            // To little contours, increase threshold
            threshold = threshold * 0.8;
        } else {
            return threshold;
        }
        
        
        // Check if the threshold is still within an allowed range. If not, no star recognition is possible.
        if (threshold >= 0 || threshold < -2000) {
            return std::numeric_limits<float>::infinity();
        }

        std::cout << "Threshold: " << threshold << std::endl;
        
    }
    return numeric_limits<float>::infinity();
}

/**
Extracts star centers under a athreshold using a lplacian transformation.
After a Laplacian is applied, the iamge is thesholded and stars are detected using a contour descriptor.

Returns a suggestion for a new threshold value. This helps to adapt to changing ligting conditions.
 */
float getStarCenters(Mat &image, float threshold, vector<Point2i> &starCenters) {
    Mat imGray;
    cvtColor(image, imGray, cv::COLOR_BGR2GRAY);
    
    // Blur the image first to be less sensitive to noise
    GaussianBlur( imGray, imGray, Size(7, 7), 0, 0, BORDER_DEFAULT );

    // Detect the stars using a Laplacian
    Mat laplacian;
    int kernel_size = 3;
    int scale = 1;
    int delta = 0;
    Laplacian( imGray, laplacian, CV_16S, kernel_size, scale, delta, BORDER_DEFAULT );

    // Only count stars that fall under the determined threshold
    Mat threshMat;
    cv::threshold(laplacian, threshMat, threshold, 255, cv::THRESH_BINARY_INV);
    threshMat.convertTo(threshMat, CV_8UC1);

    // Detect contour in the filtered features
    vector<vector<Point> > contours;
    vector<Vec4i> hierarchy;
    cv::findContours(threshMat, contours, hierarchy, RETR_LIST, CHAIN_APPROX_SIMPLE);
    
    // Continously adapt threshold to account for changes in lighting if neccesary.
    if (contours.size() > MAX_NUM_CONTOURS) {
        // To many contours, lower threshold
        // All values we're interested in are negative -> *1.1 gives a lower value
        threshold = threshold * 1.1;
        std::cout << "Threshold too high, lowering to " << threshold << std::endl;
    } else if (contours.size() < MIN_NUM_CONTOURS) {
        // To little contours, increase threshold
        threshold = threshold * 0.95;
        std::cout << "Threshold too low, raising to " << threshold << std::endl;
    }
    
    // Find the center point in every contour
    for (vector<Point> contour : contours) {
        if (contour.size() < 2) {
            continue;
        }

        // Find the convex hull of the contour to determin contours that are invalid
        auto area = cv::contourArea(contour);
        std::vector<Point> convexHull;
        cv::convexHull(contour, convexHull);
        auto convexHullArea = cv::contourArea(convexHull);
        
        if (convexHullArea == 0) {
            continue;
        }
        
        // Only select stars over a certain size
        if (area > MIN_AREA_THRESHOLD && area < MAX_AREA_THRESHOLD) {
            Moments moment = cv::moments(contour);
            
            if (moment.m00 != 0) {
                int cX = moment.m10 / moment.m00;
                int cY = moment.m01 / moment.m00;
                starCenters.emplace_back(Point2i(cX, cY));
            }
        }
    }    
    
    return threshold;
    
}
