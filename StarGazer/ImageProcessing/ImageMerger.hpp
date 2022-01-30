//
//  ImageMerger.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.01.22.
//

#ifndef ImageMerger_hpp
#define ImageMerger_hpp

#include <stdio.h>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;

class ImageMerger {
private:
    const int MIN_STARS_PER_IMAGE = 10;
    const int MIN_MATCHED_STARS = 10;

    bool firstImageAdded = false;

    /**
    Current stack all future aligned images will be merged on.
    Images will be added so they can be averaged later.
     */
    Mat currentCombined;

    /**
    Current stack all imges will be merged onto.
    Images are merged onto the stack using a max operation, so the stack contains the max over all images.
     */
    Mat currentMaxed;

    int numImages;
    int numFailed;

    float threshold;

    Mat totalHomography;

    Mat lastImage;

    vector<Point2i> lastStars;


public:
    /**
     * Creates a new image merger and tries to initialize all values.
     * If not enough features are found ion the initial image, an exception is thrown.
     * @param image
     */
    ImageMerger(Mat &image) {
        // Find an initial threshold to be used in future images
        std::cout << "Finding initial threshold..." << std::endl;
        threshold = getThreshold(image);
        std::cout << "Initial threshold: " << threshold << std::endl;
        if (threshold == numeric_limits<float>::infinity()) {
            throw "Could not find a threshold for the first image";
        }

        std::cout << "Finding initial stars..." << std::endl;
        //Find the star centers for the first image
        getStarCenters(image, threshold, lastStars);
        lastImage = image.clone();
        std::cout << "Found " << lastStars.size() << " stars" << std::endl;

        // Init the total homography matrix as identity
        totalHomography = Mat::eye(3, 3, CV_32F);

        if (lastStars.size() < MIN_STARS_PER_IMAGE) {
            throw "Not enough stars found in first image";
        }
    }

    virtual ~ImageMerger() {
        std::cout << "Image merger destructor called" << std::endl;
    }

    /**
     * Calculates a preview of the current stack.
     * @param previewImage
     */
    void getPreview(Mat &previewImage) {
        previewImage = currentMaxed.clone();
        previewImage = previewImage / numImages;

        previewImage.convertTo(previewImage, CV_8UC3);
    }

    /**
     * Tries to merge an image on top of the current stack.
     * Aligns the image if enough stars are found.
     * @param image Image to be merged
     * @param mask Mask segmenting foreground and background
     * @param preview A preview of the current stack will be copied to here.
     * @return True if the operation was successful, false otherwise.
     */
    bool mergeImageOnStack(Mat &image, Mat &mask, Mat &preview) {
        // Compute the stars in the current image
        vector<Point2i> stars;
        threshold = getStarCenters(image, threshold, stars);

        if (stars.size() < MIN_STARS_PER_IMAGE) {
            std::cout << "Not enough stars found" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }

        // Match the stars with the last image
        vector<DMatch> matches;
        matchStars(lastStars, stars, matches);

        // Extract the star centers from the matches
        std::vector<Point2i> matched_points1, matched_points2;
        for (size_t i = 0; i < matches.size(); i++) {
            matched_points1.push_back(lastStars[matches[i].queryIdx]);
            matched_points2.push_back(stars[matches[i].trainIdx]);
        }

        if (matched_points1.size() < MIN_MATCHED_STARS || matched_points2.size() < MIN_MATCHED_STARS) {
            std::cout << "Not enough stars could be matched" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }

        std::cout << "Found " << matched_points1.size() << " points to match" << std::endl;

        // Find homography
        auto h = findHomography(matched_points2, matched_points1, RANSAC);

        // Append to the current total homography
        totalHomography = totalHomography * h;

        // Use homography to warp image
        Mat alignedImage;
        warpPerspective(image, alignedImage, totalHomography, image.size());

        // Add image to the current stacks
        addWeighted(currentCombined, 1, alignedImage, 1, 0.0, currentCombined, CV_32FC3);
        max(currentMaxed, alignedImage, currentMaxed);

        // Update last image and stars
        lastImage = image;
        lastStars = stars;
        numImages++;

        getPreview(preview);
        return true;
    }


};

#endif /* ImageMerger_hpp */
