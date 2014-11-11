#import "MITToursCalloutContentView.h"
#import "UIFont+MITTours.h"
#import "UIKit+MITAdditions.h"

#define SMOOTS_PER_MILE 945.671642
#define MILES_PER_METER 0.000621371

static CGFloat const kDistanceLabelTopSpacing = 6;
static CGFloat const kDescriptionLabelTopSpacing = 16;

@interface MITToursCalloutContentView ()

@property (strong, nonatomic) UIView *containerView;

@property (weak, nonatomic) IBOutlet UILabel *stopTypeLabel;
@property (weak, nonatomic) IBOutlet UILabel *stopNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;
@property (weak, nonatomic) IBOutlet UILabel *stopDescriptionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *disclosureImage;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *distanceSpacingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *descriptionSpacingConstraint;

@property (strong, nonatomic) UIGestureRecognizer *tapRecognizer;

@end

@implementation MITToursCalloutContentView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    UIView *view = nil;
    NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"MITToursCalloutContentView" owner:self options:nil];
    for (id object in objects) {
        if ([object isKindOfClass:[UIView class]]) {
            view = object;
            break;
        }
    }
    if (view) {
        self.containerView = view;
        [self addSubview:view];
        
        self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(calloutWasTapped:)];
        [view addGestureRecognizer:self.tapRecognizer];
    }
}

- (void)configureForStop:(MITToursStop *)stop userLocation:(CLLocation *)userLocation showDescription:(BOOL)showDescription
{
    self.stop = stop;
    self.stopType = stop.stopType;
    self.stopName = stop.title;
    if (userLocation) {
        // TODO: DRY this out
        NSArray *stopCoords = stop.coordinates;
        // Convert to location coordinate
        NSNumber *longitude = [stopCoords objectAtIndex:0];
        NSNumber *latitude = [stopCoords objectAtIndex:1];
        CLLocation *stopLocation = [[CLLocation alloc] initWithLatitude:[latitude doubleValue]
                                                              longitude:[longitude doubleValue]];

        self.distanceInMiles = [stopLocation distanceFromLocation:userLocation]  * MILES_PER_METER;
        self.shouldDisplayDistance = YES;
    } else {
        self.shouldDisplayDistance = NO;
    }
    
    // For now we will assume that the provided stopType is a user-facing string,
    // but to be more robust we might consider using an enum value and having the
    // view generate its own text.
    self.stopTypeLabel.text = [self.stopType uppercaseString];
    self.stopTypeLabel.font = [UIFont toursMapCalloutSubtitle];
    self.stopTypeLabel.textColor = [UIColor mit_greyTextColor];
    self.stopTypeLabel.preferredMaxLayoutWidth = [self maxLabelWidth];
    
    self.stopNameLabel.text = self.stopName;
    self.stopNameLabel.font = [UIFont toursMapCalloutTitle];
    self.stopNameLabel.preferredMaxLayoutWidth = [self maxLabelWidth];
    
    if (self.shouldDisplayDistance) {
        CGFloat smoots = self.distanceInMiles * SMOOTS_PER_MILE;
        self.distanceLabel.text = [NSString stringWithFormat:@"%.01f miles (%.f smoots)", self.distanceInMiles, smoots];
        self.distanceSpacingConstraint.constant = kDistanceLabelTopSpacing;
    } else {
        self.distanceLabel.text = @"";
        self.distanceSpacingConstraint.constant = 0;
    }
    self.distanceLabel.font = [UIFont toursMapCalloutSubtitle];
    self.distanceLabel.textColor = [UIColor mit_greyTextColor];
    self.distanceLabel.preferredMaxLayoutWidth = [self maxLabelWidth];
    
    if (showDescription) {
        self.stopDescriptionLabel.attributedText = [self attributedBodyTextForStop:stop];
        self.descriptionSpacingConstraint.constant = kDescriptionLabelTopSpacing;
    } else {
        self.stopDescriptionLabel.attributedText = nil;
        self.descriptionSpacingConstraint.constant = 0;
    }
    
    [self.disclosureImage setImage:[UIImage imageNamed:@"map/map_disclosure_arrow"]];
    
    [self.containerView setNeedsUpdateConstraints];
    [self.containerView setNeedsLayout];
    [self sizeToFit];
}

- (NSAttributedString *)attributedBodyTextForStop:(MITToursStop *)stop
{
    // Mostly copied from MITToursStopDetailViewController
    // TODO: Should move this somewhere shared to keep things DRY
    NSData *bodyTextData = [NSData dataWithBytes:[stop.bodyHTML cStringUsingEncoding:NSUTF8StringEncoding] length:stop.bodyHTML.length];
    NSMutableAttributedString *bodyString = [[NSMutableAttributedString alloc] initWithData:bodyTextData options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType} documentAttributes:NULL error:nil];
    
    [bodyString setAttributes:@{NSFontAttributeName: [UIFont toursMapCalloutSubtitle]}
                        range:NSMakeRange(0, bodyString.length)];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    paragraphStyle.lineHeightMultiple = 1.0;
    [bodyString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, bodyString.length)];
    
    return bodyString;
}

- (void)calloutWasTapped:(UIGestureRecognizer *)sender
{
    if ([self.delegate respondsToSelector:@selector(calloutWasTappedForStop:)]) {
        [self.delegate calloutWasTappedForStop:self.stop];
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return self.intrinsicContentSize;
}

- (CGSize)intrinsicContentSize
{
    return [self.containerView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.containerView.frame = self.bounds;
}

- (CGFloat)maxLabelWidth
{
    return 200;
}

@end
