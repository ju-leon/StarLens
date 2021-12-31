//
//  hdrmerge.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#ifndef hdrmerge_hpp
#define hdrmerge_hpp
#include <opencv2/opencv.hpp>

void hdrMerge(std::vector<cv::Mat> &images, cv::Mat &result);

#endif /* hdrmerge_hpp */
