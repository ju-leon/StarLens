//
//  homography.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//
#include "homography.hpp"
#include <iostream>
#include <fstream>

using namespace std;
using namespace cv;

const int MAX_FEATURES = 500;
const float GOOD_MATCH_PERCENT = 0.15f;


void combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &movement, std::size_t numImages, cv::Mat &result) {
    Mat imReg, h;
    alignImages(imageNew, movement, imageBase, imReg, h);
    std::cout << "Finished alignment" << std::endl;
    
    imReg.convertTo(imReg, CV_32FC3);
    
    std::cout << "Base type: " << imageBase.type() << std::endl;
    std::cout << "Reg type:  " << imageBase.type() << std::endl;
    
    addWeighted(result, 1, imReg, 1 / numImages, 0.0, result, CV_32FC3);
    //imageBase = imageBase + imReg;
    
    std::cout << "Added" << std::endl;
}

void alignImages(Mat &im1, Mat &movement, Mat &im2, Mat &im1Reg, Mat &h)
{
  // Convert images to grayscale
  Mat im1Gray, im2Gray;
  cvtColor(im1, im1Gray, cv::COLOR_BGR2GRAY);
  cvtColor(im2, im2Gray, cv::COLOR_BGR2GRAY);

    //im1Gray *= 255;
  //im1Gray.convertTo(im1Gray, CV_8UC1);
   // im2Gray *= 255;
  //im2Gray.convertTo(im2Gray, CV_8UC1);
    
    std::cout << "Converted" << std::endl;
  // Only compare moving parts of the orginal image
  //bitwise_and(im2Gray, movement, im2Gray);

  // Variables to store keypoints and descriptors
  std::vector<KeyPoint> keypoints1, keypoints2;
  Mat descriptors1, descriptors2;

  // Detect ORB features and compute descriptors.
  Ptr<Feature2D> orb = ORB::create(MAX_FEATURES);
  orb->detectAndCompute(im1Gray, Mat(), keypoints1, descriptors1);
  orb->detectAndCompute(im2Gray, Mat(), keypoints2, descriptors2);
    
    std::cout << "Detected orbs" << std::endl;
  // Match features.
  std::vector<DMatch> matches;
  Ptr<DescriptorMatcher> matcher = DescriptorMatcher::create("BruteForce-Hamming");
  matcher->match(descriptors1, descriptors2, matches, Mat());

    std::cout << "matched" << std::endl;
  // Sort matches by score
  std::sort(matches.begin(), matches.end());

  // Remove not so good matches
  const int numGoodMatches = matches.size() * GOOD_MATCH_PERCENT;
  matches.erase(matches.begin()+numGoodMatches, matches.end());

  // Draw top matches
  //Mat imMatches;
  //drawMatches(im1, keypoints1, im2, keypoints2, matches, imMatches);
  //imwrite("matches.jpg", imMatches);
    std::cout << "draw" << std::endl;
  // Extract location of good matches
  std::vector<Point2f> points1, points2;

  for( size_t i = 0; i < matches.size(); i++ )
  {
    points1.push_back( keypoints1[ matches[i].queryIdx ].pt );
    points2.push_back( keypoints2[ matches[i].trainIdx ].pt );
  }

  // Find homography
  h = findHomography( points1, points2, RANSAC );
    std::cout << "homo" << std::endl;
  // Use homography to warp image
  warpPerspective(im1, im1Reg, h, im2.size());
}
