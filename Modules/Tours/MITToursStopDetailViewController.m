#import "MITToursStopDetailViewController.h"
#import "MITToursImage.h"
#import "MITToursImageRepresentation.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "MITToursStopCollectionViewManager.h"
#import "MITToursStopCollectionViewPagedLayout.h"
#import "MITToursStopInfiniteScrollCollectionViewManager.h"
#import "MITInfiniteScrollCollectionView.h"
#import "UIFont+MITTours.h"

@interface MITToursStopDetailViewController () <UIScrollViewDelegate, MITToursCollectionViewManagerDelegate>

@property (strong, nonatomic) NSArray *mainLoopStops;
@property (nonatomic) NSUInteger mainLoopIndex;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet MITInfiniteScrollCollectionView *mainLoopCollectionView;
@property (strong, nonatomic) MITToursStopInfiniteScrollCollectionViewManager *mainLoopCollectionViewManager;

@property (weak, nonatomic) IBOutlet UICollectionView *nearHereCollectionView;
@property (strong, nonatomic) MITToursStopCollectionViewManager *nearHereCollectionViewManager;

@property (weak, nonatomic) IBOutlet UIImageView *stopImageView;
@property (weak, nonatomic) IBOutlet UILabel *stopTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *bodyTextLabel;

@property (strong, nonatomic) NSArray *mainLoopCycleButtons;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainLoopLeftMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainLoopRightMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainLoopTopMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainLoopBottomMarginConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nearHereLeftMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nearHereRightMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nearHereTopMarginConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nearHereBottomMarginConstraint;

@property (nonatomic) BOOL isTitleVisible;
@property (nonatomic) CGFloat titleBottom;
@property (nonatomic) CGFloat lastScrollOffset;

@end

@implementation MITToursStopDetailViewController

- (instancetype)initWithTour:(MITToursTour *)tour stop:(MITToursStop *)stop nibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.tour = tour;
        self.stop = stop;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.scrollView.delegate = self;
    
    [self setupCollectionViews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self configureForStop:self.stop];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self setCollectionViewScrollInsets];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Scroll to top
    [self.scrollView setContentOffset:CGPointMake(0, 0) animated:NO];
}

- (void)setupCollectionViews
{
    self.mainLoopCollectionViewManager = [[MITToursStopInfiniteScrollCollectionViewManager alloc] init];
    self.nearHereCollectionViewManager = [[MITToursStopCollectionViewManager alloc] init];
    
    self.mainLoopCollectionViewManager.collectionView = self.mainLoopCollectionView;
    self.nearHereCollectionViewManager.collectionView = self.nearHereCollectionView;
    
    [self.mainLoopCollectionViewManager setup];
    [self.nearHereCollectionViewManager setup];
    
    self.mainLoopCollectionViewManager.delegate = self;
    self.nearHereCollectionViewManager.delegate = self;
    
    self.mainLoopCollectionView.dataSource = self.mainLoopCollectionViewManager;
    self.mainLoopCollectionView.delegate = self.mainLoopCollectionViewManager;
    
    self.nearHereCollectionView.dataSource = self.nearHereCollectionViewManager;
    self.nearHereCollectionView.delegate = self.nearHereCollectionViewManager;
    
    self.mainLoopCollectionView.scrollsToTop = NO;
    self.nearHereCollectionView.scrollsToTop = NO;

}

- (void)setCollectionViewScrollInsets
{
    // Set up content insets and page alignment for "Main Loop" collection view
    CGFloat leftInset = self.mainLoopLeftMarginConstraint.constant;
    CGFloat rightInset = self.mainLoopRightMarginConstraint.constant;
    CGFloat topInset = self.mainLoopTopMarginConstraint.constant;
    CGFloat bottomInset = self.mainLoopBottomMarginConstraint.constant;
    CGFloat contentHeight = CGRectGetHeight(self.mainLoopCollectionView.bounds) - topInset - bottomInset;
    CGFloat pageCenterY = topInset + contentHeight * 0.5;

    MITToursStopCollectionViewPagedLayout *mainLoopLayout = (MITToursStopCollectionViewPagedLayout *)self.mainLoopCollectionView.collectionViewLayout;
    mainLoopLayout.pagePosition = CGPointMake(leftInset, pageCenterY);
    mainLoopLayout.pageCellScrollPosition = UICollectionViewScrollPositionLeft | UICollectionViewScrollPositionCenteredVertically;

    self.mainLoopCollectionView.contentInset = UIEdgeInsetsMake(topInset, leftInset, bottomInset, rightInset);

    // Set up content insets and page alignment for "Near Here" collection view
    leftInset = self.nearHereLeftMarginConstraint.constant;
    rightInset = self.nearHereRightMarginConstraint.constant;
    topInset = self.nearHereTopMarginConstraint.constant;
    bottomInset = self.nearHereBottomMarginConstraint.constant;
    contentHeight = CGRectGetHeight(self.nearHereCollectionView.bounds) - topInset - bottomInset;
    pageCenterY = topInset + contentHeight * 0.5;
    
    MITToursStopCollectionViewPagedLayout *nearHereLayout = (MITToursStopCollectionViewPagedLayout *)self.nearHereCollectionView.collectionViewLayout;
    nearHereLayout.pagePosition = CGPointMake(leftInset, pageCenterY);
    nearHereLayout.pageCellScrollPosition = UICollectionViewScrollPositionLeft | UICollectionViewScrollPositionCenteredVertically;
    
    // Adjust rightInset based on how many items will fit
    // Note that we are making an assumption of uniform cell width, which currently holds true for the "Near Here" collection.
    CGFloat contentWidth = CGRectGetWidth(self.view.bounds) - leftInset - rightInset;
    CGFloat maxCellSize = nearHereLayout.itemSize.width + nearHereLayout.minimumInteritemSpacing;
    NSInteger numberOfItemsThatWillFit = (contentWidth + nearHereLayout.minimumInteritemSpacing) / maxCellSize;
    if (numberOfItemsThatWillFit > 0) {
        CGFloat widthOfItems = numberOfItemsThatWillFit * maxCellSize - nearHereLayout.minimumInteritemSpacing;
        rightInset += contentWidth - widthOfItems;
    }
    
    self.nearHereCollectionView.contentInset = UIEdgeInsetsMake(topInset, leftInset, bottomInset, rightInset);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.titleBottom = CGRectGetMaxY(self.stopTitleLabel.frame);
    [self updateTitleVisibility];
}

- (void)setTour:(MITToursTour *)tour
{
    _tour = tour;
    self.mainLoopStops = [[tour mainLoopStops] copy];
}

- (void)setStop:(MITToursStop *)stop
{
    if (_stop != stop) {
        _stop = stop;
        self.mainLoopIndex = [self.mainLoopStops indexOfObject:stop];
        [self configureForStop:stop];
    }
}

- (void)configureForStop:(MITToursStop *)stop
{
    self.stopTitleLabel.text = stop.title;
    [self configureBodyTextForStop:stop];
    [self configureImageForStop:stop];
    
    // Set up "Main Loop" stops
    NSInteger index = [self.mainLoopStops indexOfObject:stop];
    if (index == NSNotFound) {
        index = 0;
    }
    // We want the current stop to be the first stop in display order
    NSMutableArray *sortedMainLoopStops = [[NSMutableArray alloc] init];
    for (NSInteger i = index; i < self.mainLoopStops.count; i++) {
        [sortedMainLoopStops addObject:[self.mainLoopStops objectAtIndex:i]];
    }
    for (NSInteger i = 0; i < index; i++) {
        [sortedMainLoopStops addObject:[self.mainLoopStops objectAtIndex:i]];
    }
    self.mainLoopCollectionViewManager.stops = self.mainLoopStops;
    self.mainLoopCollectionViewManager.stopsInDisplayOrder = sortedMainLoopStops;
    self.mainLoopCollectionViewManager.selectedStop = stop;
    [self.mainLoopCollectionView reloadData];
    
    // Set up "Near Here" stops
    // Exclude the current stop from the "near here" list
    NSMutableArray *otherStops = [self.tour.stops mutableCopy];
    [otherStops removeObject:stop];
    
    // Order the stops by distance from the current stop
    CLLocation *currentStopLocation = [stop locationForStop];
    NSArray *sortedStops = [otherStops sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        CLLocationDistance distance1 = [[((MITToursStop *)obj1) locationForStop] distanceFromLocation:currentStopLocation];
        CLLocationDistance distance2 = [[((MITToursStop *)obj2) locationForStop] distanceFromLocation:currentStopLocation];
        if (distance1 < distance2) {
            return NSOrderedAscending;
        } else if (distance1 > distance2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    self.nearHereCollectionViewManager.stops = [self.tour.stops copy];
    self.nearHereCollectionViewManager.stopsInDisplayOrder = [sortedStops copy];
    self.nearHereCollectionViewManager.selectedStop = stop;
    [self.nearHereCollectionView reloadData];
    
    [self.view setNeedsLayout];
}

- (void)configureBodyTextForStop:(MITToursStop *)stop
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Bit of a hack here: For some reason the UILabel is not being correctly sized to fit
        // the last line of text, so we append a line break to account for this.
        NSMutableString *htmlString = [stop.bodyHTML mutableCopy];
        [htmlString appendString:@"<br/>"];
        NSData *bodyTextData = [NSData dataWithBytes:[htmlString cStringUsingEncoding:NSUTF8StringEncoding] length:htmlString.length];
        
        // Ideally, we'd be able to do everything but setting the label on a background thread,
        // but creating an attributed string with HTML uses a webview internally to do this, and
        // crashes if you try it on a background thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSMutableAttributedString *bodyString = [[NSMutableAttributedString alloc] initWithData:bodyTextData options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType} documentAttributes:NULL error:nil];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            paragraphStyle.lineHeightMultiple = 1.2;
            paragraphStyle.paragraphSpacing = 12.0;
            
            NSDictionary *attributes = @{ NSParagraphStyleAttributeName: paragraphStyle,
                                          NSFontAttributeName: [UIFont toursStopDetailBody] };
            [bodyString addAttributes:attributes range:NSMakeRange(0, bodyString.length)];
            
            [self.bodyTextLabel setAttributedText:bodyString]; });
    });
}

- (void)configureImageForStop:(MITToursStop *)stop
{
    if (stop.images.count) {
        NSString *stopImageURLString = [self.stop fullImageURL];
        if (stopImageURLString) {
            [self.stopImageView sd_setImageWithURL:[NSURL URLWithString:stopImageURLString] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                [self.view setNeedsLayout];
            }];
        }
    }
}

#pragma mark - Title Visibility

- (void)updateTitleVisibility
{
    BOOL wasAboveTitle = self.lastScrollOffset < self.titleBottom;
    BOOL isAboveTitle = self.scrollView.contentOffset.y < self.titleBottom;
    
    self.lastScrollOffset = self.scrollView.contentOffset.y;
    
    if (wasAboveTitle && !isAboveTitle && [self.delegate respondsToSelector:@selector(stopDetailViewControllerTitleDidScrollBelowTitle:)]) {
        [self.delegate stopDetailViewControllerTitleDidScrollBelowTitle:self];
    } else if (!wasAboveTitle && isAboveTitle && [self.delegate respondsToSelector:@selector(stopDetailViewControllerTitleDidScrollAboveTitle:)]) {
        [self.delegate stopDetailViewControllerTitleDidScrollAboveTitle:self];
    }
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateTitleVisibility];
}

#pragma mark - MITToursCollectionViewManagerDelegate Methods

- (void)collectionView:(UICollectionView *)collectionView didSelectItemForStop:(MITToursStop *)stop
{
    if ([self.delegate respondsToSelector:@selector(stopDetailViewController:didSelectStop:)]) {
        [self.delegate stopDetailViewController:self didSelectStop:stop];
    }
}

@end
