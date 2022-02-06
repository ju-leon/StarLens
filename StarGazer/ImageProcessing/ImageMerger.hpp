//
//  ImageMerger.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.01.22.
//

#ifndef ImageMerger_hpp
#define ImageMerger_hpp

#include <stdio.h>
#include <string.h>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;

struct MergingException : public exception {
    const char *info;

    MergingException(const char *info) : info(info) {
    }

    const char *what() const throw() {
        return info;
    }
};

class ImageMerger {
private:
    const int MIN_STARS_PER_IMAGE = 5;
    const int MIN_MATCHED_STARS = 5;

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
    
    /**
    Current stack all imges will be merged onto.
    Images are merged onto the stack without being aligned. Used to spereate foreground and background.
     */
    Mat currentStacked;

    int numImages;
    int numFailed;

    float threshold;

    Mat totalHomography;

    Mat lastImage;

    vector<Point2i> lastStars;
    
    bool maskEnabled;

public:
    /**
     * Creates a new image merger and tries to initialize all values.
     * If not enough features are found ion the initial image, an exception is thrown.
     * @param image
     */
    ImageMerger(Mat &image, bool maskEnabled) : maskEnabled(maskEnabled) {
        // Find an initial threshold to be used in future images
        std::cout << "Finding initial threshold..." << std::endl;
        threshold = getThreshold(image);
        std::cout << "Initial threshold: " << threshold << std::endl;
        if (threshold == numeric_limits<float>::infinity()) {
            throw MergingException("Could not find initial threshold");
        }

        std::cout << "Finding initial stars..." << std::endl;
        //Find the star centers for the first image
        getStarCenters(image, threshold, lastStars);
        std::cout << "Found " << lastStars.size() << " stars" << std::endl;

        if (lastStars.size() < MIN_STARS_PER_IMAGE) {
            throw MergingException("Not enough stars found in initial image");
        }
        
        // Initialize the current stacks
        image.copyTo(lastImage);
        lastImage.convertTo(currentCombined, CV_64F);
        lastImage.convertTo(currentStacked, CV_64F);

        currentMaxed = image.clone();

        // Init the total homography matrix as identity
        totalHomography = Mat::eye(3, 3, CV_64FC1);

        numImages = 0;
        numFailed = 0;
    }

    virtual ~ImageMerger() {
        std::cout << "Image merger destructor called" << std::endl;
    }

    /**
     * Calculates a preview of the current stack.
     * @param previewImage
     */
    void getPreview(Mat &previewImage) {
        //previewImage = currentMaxed;
        previewImage = currentMaxed.clone();
    }


    /**
     * Returns the processed image.
     */
    void getProcessed(Mat &image) {
        currentCombined.copyTo(image);
        // Convert to 8 bit
        image = image / numImages;
        image.convertTo(image, CV_8U);
    }

    /**
     * Tries to merge an image on top of the current stack.
     * Aligns the image if enough stars are found.
     * @param image Image to be merged
     * @param mask Mask segmenting foreground and background
     * @param preview A preview of the current stack will be copied to here.
     * @return True if the operation was successful, false otherwise.
     */
    bool mergeImageOnStack(Mat &image, Mat &segmentation, Mat &preview) {
        
        Mat imageMasked;
        if (maskEnabled) {
            // Convert mask to binary image
            Mat mask;
            createTrackingMask(segmentation, mask);
            resize(mask, mask, image.size(), 0, 0, INTER_LINEAR);
            cvtColor(mask, mask, COLOR_GRAY2RGB);

            // Apply mask to image. Temporarily convert to float to allow soft masking.
            image.convertTo(imageMasked, CV_32FC1);
            multiply(imageMasked, mask, imageMasked);
            imageMasked.convertTo(imageMasked, CV_8UC3);
            
        } else {
            imageMasked = image.clone();
        }
        
        // Compute the stars in the current image
        vector<Point2i> stars;
        threshold = getStarCenters(imageMasked, threshold, stars);

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
        warpPerspective(imageMasked, alignedImage, totalHomography, imageMasked.size());

        max(currentMaxed, alignedImage, currentMaxed);

        // Add image to the current stacks
        alignedImage.convertTo(alignedImage, CV_64F);
        addWeighted(currentCombined, 1, alignedImage, 1, 0.0, currentCombined, CV_64F);

        // Add image without alignment
        Mat doubleImage;
        image.convertTo(doubleImage, CV_64F);
        addWeighted(currentStacked, 1, doubleImage, 1, 0.0, currentStacked, CV_64F);
        
        
        // Update last image and stars
        lastImage = image;
        lastStars = stars;
        numImages++;

        getPreview(preview);

        return true;
    }

    
    void saveToDirectory(string dir) {
        // Save combined
        FileStorage fsCombined(dir + "/combined.xml", FileStorage::WRITE);
        fsCombined << "combined" << currentCombined;
        fsCombined.release();
        
        // Save maxed
        FileStorage fsMaxed(dir + "/maxed.xml", FileStorage::WRITE);
        fsMaxed << "maxed" << currentMaxed;
        fsMaxed.release();
        
        // Save stacked
        FileStorage fsStacked(dir + "/stacked.xml", FileStorage::WRITE);
        fsStacked << "maxed" << currentMaxed;
        fsStacked.release();
    }

};

#endif /* ImageMerger_hpp */
