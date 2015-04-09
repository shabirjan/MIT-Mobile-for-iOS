#import "MITMobiusRootPhoneViewController.h"
#import "MITMobiusResourceDataSource.h"
#import "MITMobiusModel.h"
#import "MITMobiusResourcesTableViewController.h"
#import "MITMobiusDetailContainerViewController.h"
#import "MITSlidingViewController.h"
#import "MITCalloutMapView.h"

#import "MITMobiusMapViewController.h"
#import "MITMobiusRecentSearchController.h"
#import "MITMobiusAdvancedSearchViewController.h"
#import "MITMapPlaceSelector.h"

#import "DDLog.h"
#import "MITAdditions.h"
#import "MITMobiusRoomObject.h"

static NSTimeInterval MITMobiusRootPhoneDefaultAnimationDuration = 0.33;

typedef NS_ENUM(NSInteger, MITMobiusRootViewControllerState) {
    MITMobiusRootViewControllerStateInitial = 0,
    MITMobiusRootViewControllerStateSearch,
    MITMobiusRootViewControllerStateNoResults,
    MITMobiusRootViewControllerStateResults,
};

@interface MITMobiusRootPhoneViewController () <MITMobiusResourcesTableViewControllerDelegate,MITMapPlaceSelectionDelegate,UISearchDisplayDelegate,UISearchBarDelegate,MITMobiusDetailPagingDelegate, MITMobiusRootViewRoomDataSource>

// These are currently strong since, if they are weak,
// they are being released during the various animations and
// wreaking havoc. Guessing it's either in the updateViewConstraints
// or the toggle animation.
// TODO: Figure out exactly where the 'weak' semantics go off the rails
// (bskinner 2015.02.25)
@property(nonatomic,strong) IBOutlet NSLayoutConstraint *mapHeightConstraint;
@property(nonatomic,strong) IBOutlet NSLayoutConstraint *defaultMapHeightConstraint;

@property(nonatomic) MITMobiusRootViewControllerState currentState;
@property(nonatomic,getter=isMapFullScreen) BOOL mapFullScreen;


@property(nonatomic,strong) MITMobiusResourceDataSource *dataSource;

@property(nonatomic,weak) MITMobiusResourcesTableViewController *resourcesTableViewController;
@property(nonatomic,weak) MITMobiusMapViewController *mapViewController;
@property(nonatomic,weak) UITapGestureRecognizer *fullScreenMapGesture;

@property(nonatomic,weak) MITMobiusRecentSearchController *recentSearchViewController;
@property(nonatomic,weak) UIView *searchBarContainer;
@property(nonatomic,weak) UISearchBar *searchBar;
@property(nonatomic,getter=isSearching) BOOL searching;
@property(nonatomic,strong) NSTimer *searchSuggestionsTimer;

@property (nonatomic, copy) NSDictionary *rooms;
@property (nonatomic, readonly, copy) NSArray *allResources;

@end

@implementation MITMobiusRootPhoneViewController {
    CGFloat _mapVerticalOffset;
    CGFloat _standardMapHeight;
    CGAffineTransform _previousMapTransform;
}

@synthesize resourcesTableViewController = _resourcesTableViewController;
@synthesize mapViewController = _mapViewController;
@synthesize recentSearchViewController = _recentSearchViewController;

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!self.managedObjectContext) {
        self.managedObjectContext = [[MITCoreDataController defaultController] newManagedObjectContextWithConcurrencyType:NSMainQueueConcurrencyType trackChanges:YES];
    }

    self.contentContainerView.hidden = YES;

    _previousMapTransform = CGAffineTransformIdentity;
    self.mapViewContainer.userInteractionEnabled = NO;

    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFullScreenMapGesture:)];
    gestureRecognizer.cancelsTouchesInView = NO;
    [self.contentContainerView addGestureRecognizer:gestureRecognizer];
    self.fullScreenMapGesture = gestureRecognizer;

    UIBarButtonItem *currentLocationBarButton = self.mapViewController.userLocationButton;
    UIImage *image = [UIImage imageNamed:MITImageBarButtonList];
    UIBarButtonItem *dismissMapButton = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(dismissFullScreenMap:)];
    self.toolbarItems = @[currentLocationBarButton, [UIBarButtonItem flexibleSpace], dismissMapButton];
    
    [self.contentContainerView bringSubviewToFront:self.mapViewContainer];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (self.currentState == MITMobiusRootViewControllerStateSearch) {
        UIEdgeInsets contentInset = UIEdgeInsetsMake(CGRectGetMaxY(self.navigationController.navigationBar.frame), 0, 0, 0);
        self.recentSearchViewController.tableView.contentInset = contentInset;
    }

    if (!self.isMapFullScreen) {
        _standardMapHeight = CGRectGetHeight(self.mapViewContainer.frame);
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];

    if ([self isMapFullScreen]) {
        self.mapHeightConstraint.constant = CGRectGetHeight(self.contentContainerView.bounds);

        if ([self.mapHeightConstraint respondsToSelector:@selector(setActive:)]) {
            self.mapHeightConstraint.active = YES;
            self.defaultMapHeightConstraint.active = NO;
        } else {
            self.mapHeightConstraint.priority = UILayoutPriorityDefaultHigh;
            self.defaultMapHeightConstraint.priority = UILayoutPriorityDefaultLow;
        }
    } else {
        self.mapHeightConstraint.constant = 0;
        
        if (_mapVerticalOffset < 0) {
            self.defaultMapHeightConstraint.constant = _mapVerticalOffset * self.defaultMapHeightConstraint.multiplier;
        } else {
            self.defaultMapHeightConstraint.constant = 0;
        }

        if ([self.mapHeightConstraint respondsToSelector:@selector(setActive:)]) {
            self.mapHeightConstraint.active = NO;
            self.defaultMapHeightConstraint.active = YES;
        } else {
            self.mapHeightConstraint.priority = UILayoutPriorityDefaultLow;
            self.defaultMapHeightConstraint.priority = UILayoutPriorityDefaultHigh;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self transitionToState:self.currentState animated:animated completion:nil];
    
    [self setupNavigationBar];

    if (self.isMapFullScreen) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    } else {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadDataSourceForSearch:(NSString*)queryString completion:(void(^)(void))block
{
    if ([queryString length]) {
        __weak MITMobiusRootPhoneViewController *weakSelf = self;
        [self.dataSource resourcesWithQuery:queryString completion:^(MITMobiusResourceDataSource *dataSource, NSError *error) {
            MITMobiusRootPhoneViewController *blockSelf = weakSelf;

            if (!blockSelf) {
                return;
            } else if (error) {
                DDLogWarn(@"Error: %@",error);
                
                if (block) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:block];
                }
            } else {
                [blockSelf.managedObjectContext performBlockAndWait:^{
                    [blockSelf.managedObjectContext reset];
                    blockSelf.rooms = nil;
                    
                    if (block) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:block];
                        [blockSelf.recentSearchViewController addRecentSearchTerm:queryString];
                    }
                }];
            }
        }];
    } else {
        self.contentContainerView.hidden = YES;
        self.helpTextView.hidden = NO;
    }
}

- (MITMobiusResourceDataSource*)dataSource
{
    if (!_dataSource) {
        MITMobiusResourceDataSource *dataSource = [[MITMobiusResourceDataSource alloc] init];
        _dataSource = dataSource;
    }

    return _dataSource;
}

- (void)setupNavigationBar
{
    if (!_searchBarContainer) {
        UIView *searchBarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 44)];
        searchBarContainer.autoresizingMask = UIViewAutoresizingNone;
        [searchBarContainer addSubview:self.searchBar];

        NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:searchBarContainer
                                                               attribute:NSLayoutAttributeTop
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.searchBar
                                                               attribute:NSLayoutAttributeTop
                                                              multiplier:1.0
                                                                constant:0];
        NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:searchBarContainer
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.searchBar
                                                                attribute:NSLayoutAttributeLeft
                                                               multiplier:1.0
                                                                 constant:0];
        NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:searchBarContainer
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.searchBar
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0
                                                                   constant:0];
        NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:searchBarContainer
                                                                 attribute:NSLayoutAttributeBottom
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.searchBar
                                                                 attribute:NSLayoutAttributeBottom
                                                                multiplier:1.0
                                                                  constant:0];
        [searchBarContainer addConstraints:@[top, left, bottom, right]];
        self.navigationItem.titleView = searchBarContainer;
        self.searchBarContainer = searchBarContainer;
    }

    [self.navigationItem setLeftBarButtonItem:[MIT_MobileAppDelegate applicationDelegate].rootViewController.leftBarButtonItem];
}

#pragma mark Public Properties
- (void)setMapFullScreen:(BOOL)mapFullScreen
{
    [self setMapFullScreen:mapFullScreen animated:NO];
}

- (void)setMapFullScreen:(BOOL)mapFullScreen animated:(BOOL)animated
{
    if (_mapFullScreen != mapFullScreen) {
        _mapFullScreen = mapFullScreen;

        NSTimeInterval duration = (animated ? MITMobiusRootPhoneDefaultAnimationDuration : 0);
        if (_mapFullScreen) {
            [UIView animateWithDuration:duration
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 CGFloat tableContainerTranslation = CGRectGetMaxY(self.contentContainerView.bounds) - CGRectGetMinY(self.tableViewContainer.frame);
                                 self.tableViewContainer.transform = CGAffineTransformMakeTranslation(0, tableContainerTranslation);
                                 self.mapViewContainer.transform = CGAffineTransformIdentity;
                                 
                                 [self.view setNeedsUpdateConstraints];
                                 [self.view layoutIfNeeded];
                             } completion:^(BOOL finished) {
                                 self.fullScreenMapGesture.enabled = NO;
                                 self.mapViewContainer.userInteractionEnabled = YES;
                                 [self.navigationController setToolbarHidden:NO animated:animated];
                             }];
        } else {
            [UIView animateWithDuration:duration
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 self.tableViewContainer.transform = CGAffineTransformIdentity;
                                 self.mapViewContainer.transform = _previousMapTransform;
                                 
                                 [self.view setNeedsUpdateConstraints];
                                 [self.view layoutIfNeeded];
                             } completion:^(BOOL finished) {
                                 self.fullScreenMapGesture.enabled = YES;
                                 self.mapViewContainer.userInteractionEnabled = NO;
                                 
                                 [self.mapViewController recenterOnVisibleResources:animated];
                                 [self.navigationController setToolbarHidden:YES animated:animated];
                                 [self.mapViewController showCalloutForRoom:nil];
                             }];
        }
    }
}

#pragma mark resourcesTableViewController
- (void)loadResourcesTableViewController
{
    MITMobiusResourcesTableViewController *resourcesTableViewController = [[MITMobiusResourcesTableViewController alloc] init];
    resourcesTableViewController.delegate = self;
    resourcesTableViewController.dataSource = self;

    [self addChildViewController:resourcesTableViewController toView:self.tableViewContainer];
    _resourcesTableViewController = resourcesTableViewController;
}

- (MITMobiusResourcesTableViewController*)resourcesTableViewController
{
    if (!_resourcesTableViewController) {
        [self loadResourcesTableViewController];
    }
    
    return _resourcesTableViewController;
}


#pragma mark mapViewController
- (MITMobiusMapViewController*)mapViewController
{
    if (!_mapViewController) {
        [self loadMapViewController];
    }

    return _mapViewController;
}

- (void)loadMapViewController
{
    MITMobiusMapViewController *mapViewController = [[MITMobiusMapViewController alloc] init];
    mapViewController.dataSource = self;
    [self addChildViewController:mapViewController toView:self.mapViewContainer];
    _mapViewController = mapViewController;
}


#pragma mark typeAheadViewController
- (UITableViewController*)recentSearchViewController
{
    if (!_recentSearchViewController) {
        [self loadRecentSearchViewController];
    }

    return _recentSearchViewController;
}

- (void)loadRecentSearchViewController
{
    MITMobiusRecentSearchController *recentSearchViewController = [[MITMobiusRecentSearchController alloc] init];
    recentSearchViewController.delegate = self;
    [self addChildViewController:recentSearchViewController toView:self.view];
    _recentSearchViewController = recentSearchViewController;
}

- (NSArray*)resources
{
    __block NSArray *resourceObjects = nil;
    [self.managedObjectContext performBlockAndWait:^{
        resourceObjects = [self.managedObjectContext transferManagedObjects:self.dataSource.resources];
    }];

    return resourceObjects;
}

#pragma mark - Private
- (IBAction)_didTapShowFilterButton:(UIBarButtonItem*)sender
{
    MITMobiusAdvancedSearchViewController *viewController = [[MITMobiusAdvancedSearchViewController alloc] initWithSearchText:self.searchBar.text];

    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    viewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark State Management
- (BOOL)canTransitionToState:(MITMobiusRootViewControllerState)newState
{
    if (self.currentState == newState) {
        return YES;
    }
    
    switch (self.currentState) {
        case MITMobiusRootViewControllerStateInitial: {
            return (newState == MITMobiusRootViewControllerStateSearch);
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            return ((newState == MITMobiusRootViewControllerStateInitial) ||
                    (newState == MITMobiusRootViewControllerStateNoResults) ||
                    (newState == MITMobiusRootViewControllerStateResults));
        } break;
            
        case MITMobiusRootViewControllerStateNoResults: {
            return (newState == MITMobiusRootViewControllerStateSearch);
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            return (newState == MITMobiusRootViewControllerStateSearch);
        } break;
    }
}

- (void)transitionToState:(MITMobiusRootViewControllerState)newState animated:(BOOL)animate completion:(void(^)(void))block
{
    NSAssert([self canTransitionToState:newState], @"illegal state transition");
    if (self.currentState == newState) {
        return;
    }
    
    MITMobiusRootViewControllerState oldState = self.currentState;
    
    [self willTransitionToState:newState fromState:oldState];
    self.currentState = newState;
    
    [self.view setNeedsUpdateConstraints];
    [self.view setNeedsLayout];
    
    NSTimeInterval animationDuration = (animate ? MITMobiusRootPhoneDefaultAnimationDuration : 0);
    [UIView animateWithDuration:animationDuration
                          delay:0
                        options:0
                     animations:^{
                         [self animateTransitionToState:newState fromState:oldState animated:animate];
                     } completion:^(BOOL finished) {
                         [self didTransitionToState:newState fromState:oldState];
                         [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                             if (block) {
                                 block();
                             }
                         }];
                     }];
}

- (void)willTransitionToState:(MITMobiusRootViewControllerState)newState fromState:(MITMobiusRootViewControllerState)oldState
{
    switch (newState) {
        case MITMobiusRootViewControllerStateNoResults:
        case MITMobiusRootViewControllerStateInitial: {
            self.helpTextView.hidden = NO;
            self.helpTextView.alpha = 0.;
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            self.recentSearchViewController.view.hidden = NO;
            self.recentSearchViewController.view.alpha = 0.;
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            self.contentContainerView.hidden = NO;
            self.contentContainerView.alpha = 0;
            [self.contentContainerView bringSubviewToFront:self.mapViewContainer];
        } break;
    }
    
    switch (oldState) {
        case MITMobiusRootViewControllerStateNoResults:
        case MITMobiusRootViewControllerStateInitial: {
            self.helpTextView.hidden = NO;
            self.helpTextView.alpha = 1;
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            self.recentSearchViewController.view.hidden = NO;
            self.recentSearchViewController.view.alpha = 1.;
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            self.contentContainerView.hidden = NO;
            self.contentContainerView.alpha = 1;
            [self.contentContainerView bringSubviewToFront:self.mapViewContainer];
        } break;
    }
}

- (void)animateTransitionToState:(MITMobiusRootViewControllerState)newState fromState:(MITMobiusRootViewControllerState)oldState animated:(BOOL)animated
{
    switch (newState) {
        case MITMobiusRootViewControllerStateNoResults:
        case MITMobiusRootViewControllerStateInitial: {
            self.helpTextView.alpha = 1;
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            self.recentSearchViewController.view.alpha = 1;

            UIImage *image = [UIImage imageNamed:MITImageBarButtonFilter];
            UIBarButtonItem *filterBarButton = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(_didTapShowFilterButton:)];
            [self.navigationItem setLeftBarButtonItem:filterBarButton animated:animated];
            [self.searchBar setShowsCancelButton:YES animated:animated];
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            self.contentContainerView.alpha = 1;
            
            if (self.isMapFullScreen) {
                [self.navigationController setToolbarHidden:NO animated:animated];
            } else {
                [self.mapViewController.mapView selectAnnotation:nil animated:animated];
            }
        } break;
    }
    
    switch (oldState) {
        case MITMobiusRootViewControllerStateNoResults:
        case MITMobiusRootViewControllerStateInitial: {
            self.helpTextView.alpha = 0;
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            self.recentSearchViewController.view.alpha = 0;
            [self.searchBar setShowsCancelButton:NO animated:animated];
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            self.contentContainerView.alpha = 0;
            [self.navigationController setToolbarHidden:YES animated:animated];
        } break;
    }
}

- (void)didTransitionToState:(MITMobiusRootViewControllerState)newState fromState:(MITMobiusRootViewControllerState)oldState
{
    switch (oldState) {
        case MITMobiusRootViewControllerStateNoResults:
        case MITMobiusRootViewControllerStateInitial: {
            self.helpTextView.hidden = YES;
        } break;
            
        case MITMobiusRootViewControllerStateSearch: {
            [self.navigationItem setLeftBarButtonItem:[MIT_MobileAppDelegate applicationDelegate].rootViewController.leftBarButtonItem animated:YES];
            self.recentSearchViewController.view.hidden = YES;
        } break;
            
        case MITMobiusRootViewControllerStateResults: {
            self.contentContainerView.hidden = YES;
        } break;
    }
}

- (void)searchSuggestionsTimerFired:(NSTimer*)timer
{
    [self.recentSearchViewController filterResultsUsingString:self.searchBar.text];
}

- (IBAction)dismissFullScreenMap:(UIBarButtonItem*)sender
{
    if (self.currentState != MITMobiusRootViewControllerStateResults) {
        return;
    }
    
    [self setMapFullScreen:NO animated:YES];
}

- (IBAction)handleFullScreenMapGesture:(UITapGestureRecognizer*)gestureRecognizer
{
    if (gestureRecognizer == self.fullScreenMapGesture) {
        if (self.currentState != MITMobiusRootViewControllerStateResults) {
            return;
        }
        
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            CGPoint location = [gestureRecognizer locationInView:self.contentContainerView];

            if (CGRectContainsPoint(self.mapViewContainer.frame, location)) {
                [self setMapFullScreen:YES animated:YES];
            }
        }
    }
}

- (void)addChildViewController:(UIViewController*)viewController toView:(UIView*)superview
{
    NSParameterAssert(viewController);
    NSParameterAssert(superview);
    
    
    [self addChildViewController:viewController];
    [viewController beginAppearanceTransition:YES animated:NO];
    
    viewController.view.frame = superview.bounds;
    viewController.view.translatesAutoresizingMaskIntoConstraints = YES;
    viewController.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    [superview addSubview:viewController.view];
    
    [viewController endAppearanceTransition];
    [viewController didMoveToParentViewController:self];
}

- (void)removeChildViewController:(UIViewController*)viewController
{
    NSParameterAssert(viewController);
    
    [viewController willMoveToParentViewController:nil];
    [viewController beginAppearanceTransition:NO animated:NO];
    [viewController.view removeFromSuperview];
    [viewController endAppearanceTransition];
    [viewController removeFromParentViewController];
}

#pragma mark Search accessory methods
- (UISearchBar*)searchBar
{
    UISearchBar *searchBar = _searchBar;

    if (!searchBar) {
        searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 44)];
        searchBar.searchBarStyle = UISearchBarStyleMinimal;
        searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        searchBar.placeholder = @"Search Mobius";
        searchBar.delegate = self;

        _searchBar = searchBar;
    }

    return searchBar;
}

#pragma mark - Delegation
#pragma mark MITMobiusRecentSearchControllerDelegate
- (void)placeSelectionViewController:(UIViewController<MITMapPlaceSelector>*)viewController didSelectQuery:(NSString*)query
{
    self.searchBar.text = query;
    [self.searchBar resignFirstResponder];
}

#pragma mark MITMobiusResourcesTableViewControllerDelegate
- (void)resourcesTableViewController:(MITMobiusResourcesTableViewController *)tableViewController didSelectResource:(MITMobiusResource *)resource
{
    MITMobiusDetailContainerViewController *detailContainerViewController = [[MITMobiusDetailContainerViewController alloc] initWithResource:resource];
    detailContainerViewController.delegate = self;

    [self.navigationController pushViewController:detailContainerViewController animated:YES];
}

- (BOOL)shouldDisplayPlaceholderCellForResourcesTableViewController:(MITMobiusResourcesTableViewController*)tableViewController
{
    return YES;
}

- (void)resourcesTableViewController:(MITMobiusResourcesTableViewController *)tableViewController didScrollToContentOffset:(CGPoint)contentOffset
{
    if (contentOffset.y > 0) {
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0, -contentOffset.y);
        self.mapViewContainer.transform = transform;
        
        _previousMapTransform = transform;
        _mapVerticalOffset = 0;
    } else {
        _mapVerticalOffset = contentOffset.y;
        _previousMapTransform = CGAffineTransformIdentity;
        self.mapViewContainer.transform = CGAffineTransformIdentity;
    }
    
    [self.view setNeedsUpdateConstraints];
    [self.view updateConstraintsIfNeeded];
}

- (CGFloat)heightOfPlaceholderCellForResourcesTableViewController:(MITMobiusResourcesTableViewController *)tableViewController
{
    return _standardMapHeight;
}

#pragma mark UISearchBarDelegate
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.searching = YES;
    [self transitionToState:MITMobiusRootViewControllerStateSearch animated:YES completion:nil];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    self.searching = NO;
    
    if ([self.searchBar.text length]) {
        NSString *queryString = [[searchBar.text lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([queryString caseInsensitiveCompare:self.dataSource.queryString] != NSOrderedSame) {
            
            [self reloadDataSourceForSearch:queryString completion:^{
                MITMobiusRootViewControllerState newState = MITMobiusRootViewControllerStateNoResults;
                
                if ([self.resources count]) {
                    newState = MITMobiusRootViewControllerStateResults;
                    self.mapFullScreen = NO;
                }
                
                [self transitionToState:newState animated:YES completion:^{
                    self.rooms = nil;
                    [self.resourcesTableViewController.tableView reloadData];
                    [self.mapViewController reloadMapAnimated:YES];
                }];
            }];
        } else {
            MITMobiusRootViewControllerState newState = MITMobiusRootViewControllerStateNoResults;
            if ([self.dataSource.resources count]) {
                newState = MITMobiusRootViewControllerStateResults;
            }
            
            [self transitionToState:newState animated:YES completion:nil];
        }
    } else {
        [self transitionToState:MITMobiusRootViewControllerStateNoResults animated:YES completion:nil];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];

    [self reloadDataSourceForSearch:searchBar.text completion:^{
      
        self.rooms = nil;
        [self.resourcesTableViewController.tableView reloadData];
        [self.mapViewController reloadMapAnimated:YES];
    }];
}

- (NSDictionary*)rooms
{
    if (!_rooms) {
        NSDictionary *resourcesByBuilding = [self.dataSource resourcesGroupedByKey:@"room" withManagedObjectContext:self.managedObjectContext];

        NSMutableDictionary *rooms = [[NSMutableDictionary alloc] init];

        [resourcesByBuilding enumerateKeysAndObjectsUsingBlock:^(NSString *roomName, NSArray *resources, BOOL *stop) {

            MITMobiusRoomObject *mapObject = [[MITMobiusRoomObject alloc] init];
            mapObject.roomName = roomName;
            mapObject.resources = [NSOrderedSet orderedSetWithArray:resources];

            if (!CLLocationCoordinate2DIsValid(mapObject.coordinate)) {
                DDLogWarn(@"Coordinate for room with name %@ is invalid", roomName);
            }

            rooms[roomName] = mapObject;
        }];
        
        _rooms = rooms;
    }

    return _rooms;
}

- (NSArray*)allResources
{
    NSArray *sortedKeys = [self.rooms.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    NSMutableArray *resources = [[NSMutableArray alloc] init];

    [sortedKeys enumerateObjectsUsingBlock:^(id<NSCopying> key, NSUInteger idx, BOOL *stop) {
        MITMobiusRoomObject *room = self.rooms[key];
        [resources addObjectsFromArray:[room.resources array]];
    }];

    return resources;
}

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self.searchSuggestionsTimer invalidate];
    self.searchSuggestionsTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(searchSuggestionsTimerFired:)
                                                                 userInfo:nil
                                                                  repeats:NO];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark MITMobiusDetailPagingDelegate
- (NSUInteger)numberOfResourcesInDetailViewController:(MITMobiusDetailContainerViewController*)viewController
{
    // TODO: This approach needs some work, we should be keeping track of what chunk of data is being displayed,
    // not requiring the view controller to do it for us.
    return self.allResources.count;
}

- (MITMobiusResource*)detailViewController:(MITMobiusDetailContainerViewController*)viewController resourceAtIndex:(NSUInteger)index
{
    return self.allResources[index];
}

- (NSUInteger)detailViewController:(MITMobiusDetailContainerViewController*)viewController indexForResourceWithIdentifier:(NSString*)resourceIdentifier
{
    __block NSUInteger index = NSNotFound;
    [self.allResources enumerateObjectsUsingBlock:^(MITMobiusResource *resource, NSUInteger idx, BOOL *stop) {
        if ([resource.identifier isEqualToString:resourceIdentifier]) {
            index = idx;
            (*stop) = YES;
        }
    }];

    return index;
}

- (NSUInteger)detailViewController:(MITMobiusDetailContainerViewController*)viewController indexAfterIndex:(NSUInteger)index
{
    return (index + 1) % self.allResources.count;
}

- (NSUInteger)detailViewController:(MITMobiusDetailContainerViewController*)viewController indexBeforeIndex:(NSUInteger)index
{
    NSArray *allResources = self.allResources;
    return ((index + allResources.count) - 1) % allResources.count;
}

#pragma mark MITMobiusRoomDataSource
- (NSInteger)numberOfRoomsForViewController:(UIViewController*)viewController
{
    return self.rooms.allKeys.count;
}

- (MITMobiusRoomObject*)viewController:(UIViewController*)viewController roomAtIndex:(NSInteger)roomIndex
{
    NSArray *buildingsArray = [self.rooms.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSString *key = buildingsArray[roomIndex];
    return self.rooms[key];
}

- (NSInteger)viewController:(UIViewController*)viewController numberOfResourcesInRoomAtIndex:(NSInteger)roomIndex
{
    NSArray *buildingsArray = [self.rooms.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSString *key = buildingsArray[roomIndex];
    MITMobiusRoomObject *room = self.rooms[key];
    return room.resources.count;
}

- (MITMobiusResource*)viewController:(UIViewController*)viewController resourceAtIndex:(NSInteger)resourceIndex inRoomAtIndex:(NSInteger)roomIndex
{
    NSArray *buildingsArray = [self.rooms.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSString *key = buildingsArray[roomIndex];
    MITMobiusRoomObject *room = self.rooms[key];
    return room.resources[resourceIndex];
}

@end