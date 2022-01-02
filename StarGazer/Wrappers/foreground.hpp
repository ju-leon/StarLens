//
//  foreground.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#ifndef foreground_hpp
#define foreground_hpp

#include <opencv2/opencv.hpp>

void findForeground(cv::Mat &foreground, std::vector<cv::Mat> &sequence);

#endif /* foreground_hpp */
