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


void combine(cv::Mat &imageBase, cv::Mat &imageNew, cv::Mat &movement) {
    Mat imReg, h;
    
    alignImages(imageNew, movement, imageBase, imReg, h);
    std::cout << "Finished alignment" << std::endl;
    
    addWeighted(imageBase, 0.5, imReg, 0.5, 0.0, imageBase);
}

void alignImages(Mat &im1, Mat &movement, Mat &im2, Mat &im1Reg, Mat &h)
{
  // Convert images to grayscale
  Mat im1Gray, im2Gray;
  cvtColor(im1, im1Gray, cv::COLOR_BGR2GRAY);
  cvtColor(im2, im2Gray, cv::COLOR_BGR2GRAY);
    
  // Only compare moving parts of the orginal image
  //bitwise_and(im2Gray, movement, im2Gray);

  // Variables to store keypoints and descriptors
  std::vector<KeyPoint> keypoints1, keypoints2;
  Mat descriptors1, descriptors2;

  // Detect ORB features and compute descriptors.
  Ptr<Feature2D> orb = ORB::create(MAX_FEATURES);
  orb->detectAndCompute(im1Gray, Mat(), keypoints1, descriptors1);
  orb->detectAndCompute(im2Gray, Mat(), keypoints2, descriptors2);

  // Match features.
  std::vector<DMatch> matches;
  Ptr<DescriptorMatcher> matcher = DescriptorMatcher::create("BruteForce-Hamming");
  matcher->match(descriptors1, descriptors2, matches, Mat());

  // Sort matches by score
  std::sort(matches.begin(), matches.end());

  // Remove not so good matches
  const int numGoodMatches = matches.size() * GOOD_MATCH_PERCENT;
  matches.erase(matches.begin()+numGoodMatches, matches.end());

  // Draw top matches
  Mat imMatches;
  drawMatches(im1, keypoints1, im2, keypoints2, matches, imMatches);
  //imwrite("matches.jpg", imMatches);

  // Extract location of good matches
  std::vector<Point2f> points1, points2;

  for( size_t i = 0; i < matches.size(); i++ )
  {
    points1.push_back( keypoints1[ matches[i].queryIdx ].pt );
    points2.push_back( keypoints2[ matches[i].trainIdx ].pt );
  }

  // Find homography
  h = findHomography( points1, points2, RANSAC );

  // Use homography to warp image
  warpPerspective(im1, im1Reg, h, im2.size());
}
