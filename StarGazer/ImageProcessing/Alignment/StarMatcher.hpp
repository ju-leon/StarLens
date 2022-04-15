//
//  StarMatcher.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 11.03.22.
//

#ifndef StarMatcher_hpp
#define StarMatcher_hpp

#include <stdio.h>
#include <string.h>
#include <opencv2/opencv.hpp>
#include <fstream>
#include <chrono>
#include <algorithm>

using namespace cv;
using namespace std;

/**
 * Max allowed deviation percentage of two triangles to be classified a match
 */
const float MAX_DISTANCE_THRESHOLD = 0.01;

/**
 * Min size a triangle needs to be to be counted as a feature.
 * Prevents to close stars that cannot prvide accurate alignment from being matched.
 */
const float MIN_TRINAGLE_SIZE = 100;

struct Constellation {
    int index;
    Point3f distances;

    Point2i base;
    Point2i left;
    Point2i right;

    Constellation(int index, const Point3f &distances) : index(index), distances(distances), base(0, 0), left(0, 0), right(0, 0) {
    }

    Constellation(int index, const Point3f &distances, const Point2i &base, const Point2i &left, const Point2i &right) :
            index(index), distances(distances), base(base), left(left), right(right) {
    }

    /*
     * Returns the side length of the triangle
     */
    float length() {
        return distances.x + distances.y + distances.z;
    }
};

class StarMatcher {

private:
    vector<Constellation> baseConstellations;
    std::unique_ptr<cv::flann::GenericIndex<cv::flann::L2_Simple<float>>> constellationTree;

    /**
     Generate constellations betweem stars.
     */
    void generateConstellations(vector<Point2i> &stars, vector<Constellation> &constellations, int knn) {
        // Make sure to not query more neighbors than there are stars...
        auto maxTriangles = stars.size() < knn ? stars.size() : knn;
        maxTriangles -= 1;
        
        std::cout << "Max triangles: "  << maxTriangles << std::endl;
        
        /*
         Convert list of stars to features that can be passed to KNN Searcher
         */
        cv::Mat_<float> features(0, 2);
        for (auto &&point: stars) {
            cv::Mat row = (cv::Mat_<float>(1, 2) << point.x, point.y);
            features.push_back(row);
        }

        cv::flann::GenericIndex<cv::flann::L2<float>> starTree(features, cvflann::KDTreeIndexParams(),cv::flann::L2<float>());

        // Reserve space for constellations using Gauss formula
        int numberOfTriangles = (int) (stars.size() * stars.size());
        constellations.reserve(numberOfTriangles);

        /*
         Generate constellations.

         For every star, find the nearest neighbors and calculate the triangles between every pair
         of points and the base point.
         Triangles are always in following order:
          - Short side to base point
          - Long side to base point
          - Connection between outer points
         */
        for (int i = 0; i < stars.size(); i++) {
            std::vector<float> query;
            query.push_back(stars[i].x);
            query.push_back(stars[i].y);
            std::vector<int> indices(maxTriangles);
            std::vector<float> dists(maxTriangles);
            starTree.knnSearch(query, indices, dists, maxTriangles, cvflann::SearchParams());

            // Calculate distances between every pair of points
            // The "closest" point will always be the point we're querying from, so we skip it (start from 1)
            for (int j = 1; j < maxTriangles && j < indices.size(); j++) {
                for (int k = j + 1; k < maxTriangles && k < indices.size(); k++) {
                    // Should never happen...
                    if (indices[j] == indices[k]) {
                        continue;
                    }
                    // Calculate the distance between the two outer points
                    int dist = sqrt(pow(stars[indices[j]].x - stars[indices[k]].x, 2) + pow(stars[indices[j]].y - stars[indices[k]].y, 2));

                    // Make sure the order if the sides is always the same
                    auto shortDistance = dists[j] < dists[k] ? dists[j] : dists[k];
                    auto longDistance = dists[j] < dists[k] ? dists[k] : dists[j];

                    // OpenCV returns squared euclidean distances, so we need to take the square root
                    shortDistance = sqrt(shortDistance);
                    longDistance = sqrt(longDistance);

                    // Add the constellation to the list if the legth requirtent is met
                    if (dist + longDistance + shortDistance > MIN_TRINAGLE_SIZE) {
                        constellations.push_back(Constellation(i, Point3f(shortDistance, longDistance, dist), stars[i], stars[indices[j]], stars[indices[k]]));
                    }
                }
            }
        }

    }

public:
    StarMatcher(vector<Point2i> &stars) {
        generateConstellations(stars, baseConstellations, stars.size());

        cv::Mat_<float> features(0, 3);
        for (auto &constellation: baseConstellations) {
            cv::Mat row = (cv::Mat_<float>(1, 3)
                    << constellation.distances.x, constellation.distances.y, constellation.distances.z);
            features.push_back(row);
        }
        constellationTree = std::make_unique<cv::flann::GenericIndex<cv::flann::L2_Simple<float>>>(features, cvflann::LinearIndexParams());

    }

    void matchStars(vector<Point2i> &stars, vector<DMatch> &matches, Mat &constellationVis) {
        vector<Constellation> constellations;
        std::cout << "Generating consts" << std::endl;
        generateConstellations(stars, constellations, 6);

        for (auto &constellation: constellations) {
            // Query the closest base constellation for every new constellation
            std::vector<float> query;
            query.push_back(constellation.distances.x);
            query.push_back(constellation.distances.y);
            query.push_back(constellation.distances.z);
            std::vector<int> indices(2);
            std::vector<float> dists(2);
            constellationTree->knnSearch(query, indices, dists, 1, cvflann::SearchParams());

            // Add the match to the list if the distance is smaller than the threshold
            if (dists[0] < constellation.length() * MAX_DISTANCE_THRESHOLD) {
                matches.push_back(DMatch(baseConstellations[indices[0]].index, constellation.index, dists[0]));

                // Draw the constellation
                line(constellationVis, constellation.base, constellation.left, Scalar(255, 0, 255), 3);
                line(constellationVis, constellation.base, constellation.right, Scalar(255, 0, 255), 3);
                line(constellationVis, constellation.left, constellation.right, Scalar(255, 0, 255), 3);
            }

        }
    }

};

#endif /* StarMatcher_hpp */
