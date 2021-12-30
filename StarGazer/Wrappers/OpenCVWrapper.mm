//
//  OpenCVWrapper.m
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.12.21.
//


#import "OpenCVWrapper.h"
#import "UIImageOpenCV.h"
#import "UIImageRotate.h"
#import "homography.hpp"
#import "foreground.hpp"

using namespace std;
using namespace cv;


@implementation OpenCVWrapper

- (NSString *) openCVVersionString
{
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}


#pragma mark Public
/*
+ (UIImage *)toGray:(UIImage *)source {
    cout << "OpenCV: ";
    return [OpenCVWrapper imageFrom:[OpenCVWrapper _grayFrom:[OpenCVWrapper matFrom:source]]];
}
*/
+ (UIImage *)stackImages:(NSArray *)images onImage:(UIImage *)image{
    if ([images count]==0){
        NSLog (@"imageArray is empty");
        return 0;
    }
    
    cv::Mat combinedImage = [image CVMat3];
    
    
    std::vector<cv::Mat> matImages;
    
    for (id image in images) {
        if ([image isKindOfClass: [UIImage class]]) {
            UIImage* rotatedImage = [image rotateToImageOrientation];
            cv::Mat matImage = [rotatedImage CVMat3];
            matImages.push_back(matImage);
        } else {
            NSLog(@"Unsupported image type");
            return 0;
        }
    }
    
    Mat movement;
    findForeground(movement, matImages);
    
    for (int i = 0; i < matImages.size(); i++) {
        combine(combinedImage, matImages[i], movement);
    }
    

    UIImage* result =  [UIImage imageWithCVMat:combinedImage];
    return result;
}


/*
#pragma mark Private

+ (Mat)matFrom:(UIImage *)source {
    cout << "matFrom ->";
    CGImageRef image = CGImageCreateCopy(source.CGImage);
    CGFloat cols = CGImageGetWidth(image);
    CGFloat rows = CGImageGetHeight(image);
    Mat result(rows, cols, CV_8UC4);
    CGBitmapInfo bitmapFlags = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = result.step[0];
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    CGContextRef context = CGBitmapContextCreate(result.data, cols, rows, bitsPerComponent, bytesPerRow, colorSpace, bitmapFlags);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, cols, rows), image);
    CGContextRelease(context);
    return result;
}
+ (UIImage *)imageFrom:(Mat)source {
    cout << "-> imageFrom\n";
    NSData *data = [NSData dataWithBytes:source.data length:source.elemSize() * source.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGBitmapInfo bitmapFlags = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = source.step[0];
    CGColorSpaceRef colorSpace = (source.elemSize() == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB());
    CGImageRef image = CGImageCreate(source.cols, source.rows, bitsPerComponent, bitsPerComponent * source.elemSize(), bytesPerRow, colorSpace, bitmapFlags, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return result;
}

+ (Mat)_grayFrom:(Mat)source {
    cout << "-> grayFrom ->";
    Mat result;
    cvtColor(source, result, COLOR_BGR2GRAY);
    return result;
}
 */


@end
