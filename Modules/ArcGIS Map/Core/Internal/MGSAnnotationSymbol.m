#import "MGSAnnotationSymbol.h"
#import "MGSLayerAnnotation.h"

@interface MGSAnnotationSymbol ()
@property (nonatomic,strong) id<MGSAnnotation> annotation;
@property (nonatomic,strong) UIImage *cachedImage;
@end

@implementation MGSAnnotationSymbol
- (id)initWithAnnotation:(id<MGSAnnotation>)annotation
{
    return [self initWithAnnotation:annotation
                   defaultImageName:@"map/map_pin_complete"];
}

- (id)initWithAnnotation:(id<MGSAnnotation>)layerAnnotation defaultImageName:(NSString *)imageName
{
    self = [super initWithImageNamed:imageName];
    
    if (self)
    {
        self.annotation = layerAnnotation;
    }
    
    return self;
}

- (UIImage*)image
{
    UIView *annotationView = self.annotation.annotationView;
    
    if (annotationView)
    {
        [annotationView sizeToFit];
        [annotationView layoutIfNeeded];
        
        CALayer *annotationLayer = annotationView.layer;
        annotationLayer.backgroundColor = [[UIColor blackColor] CGColor];
        
        if ((self.cachedImage == nil) || annotationLayer.needsDisplay)
        {
            
            CGRect originalFrame = annotationView.frame;
            CGRect newFrame = annotationView.frame;
            newFrame.origin = CGPointZero;
            annotationView.frame = newFrame;
            
            
            self.xoffset = -CGRectGetMinX(originalFrame);
            self.yoffset = -CGRectGetMinY(originalFrame);
            CGSize size = CGSizeMake(CGRectGetWidth(originalFrame),
                                     CGRectGetHeight(originalFrame));
            UIGraphicsBeginImageContextWithOptions(size, NO, [[UIScreen mainScreen] scale]);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            [annotationLayer renderInContext:context];
            self.cachedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            annotationView.frame = originalFrame;
        }
        
        return self.cachedImage;
    }
    
    UIImage *image = [super image];
    return image;
}

- (void)setAnnotation:(id<MGSAnnotation>)annotation
{
    if ([annotation isEqual:_annotation] == NO)
    {
        _annotation = annotation;
        self.cachedImage = nil;
    }
}

- (BOOL)shouldCacheSymbol
{
    return NO;
}
@end