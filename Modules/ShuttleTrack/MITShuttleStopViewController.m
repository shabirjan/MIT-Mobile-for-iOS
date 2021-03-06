#import "MITShuttleStopViewController.h"
#import "MITShuttleStop.h"
#import "MITShuttleStopAlarmCell.h"
#import "MITShuttlePrediction.h"
#import "MITShuttlePredictionList.h"
#import "MITShuttleRoute.h"
#import "MITShuttleVehicle.h"
#import "MITShuttleController.h"
#import "MITShuttleVehicleList.h"
#import "NSDateFormatter+RelativeString.h"
#import "MITShuttleStopNotificationManager.h"
#import "MITShuttleRouteCell.h"
#import "MITShuttleRouteStopMapContainerViewController.h"
#import "MITShuttlePredictionLoader.h"
#import "MITCoreDataController.h"

NSString * const kMITShuttleStopViewControllerAlarmCellReuseIdentifier = @"kMITShuttleStopViewControllerAlarmCellReuseIdentifier";
NSString * const kMITShuttleStopViewControllerRouteCellReuseIdentifier = @"kMITShuttleStopViewControllerRouteCellReuseIdentifier";
NSString * const kMITShuttleStopViewControllerDefaultCellReuseIdentifier = @"kMITShuttleStopViewControllerDefaultCellReuseIdentifier";

static CGFloat const kMITShuttleStopShortTitleSpacing = 20.0;
static CGFloat const kMITShuttleStopDefaultTitleSpacing = 44.0;

typedef NS_ENUM(NSUInteger, MITShuttleStopViewControllerSectionType) {
    MITShuttleStopViewControllerSectionTypeTitle,
    MITShuttleStopViewControllerSectionTypePredictions,
    MITShuttleStopViewControllerSectionTypeRoutes
};

@interface MITShuttleStopViewController () <MITShuttleStopAlarmCellDelegate, NSFetchedResultsControllerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray *intersectingRoutes;
@property (nonatomic, strong) NSArray *vehicles;
@property (nonatomic, strong) UILabel *helpLabel;
@property (nonatomic, strong) UILabel *statusFooterLabel;

@property (nonatomic, strong) NSArray *sectionTypes;

@property (strong, nonatomic) NSFetchedResultsController *stopsWithSameIdentifierFetchedResultsController;

@property (strong, nonatomic) UIRefreshControl *refreshControl;
@end

@implementation MITShuttleStopViewController

- (instancetype)initWithStyle:(UITableViewStyle)style stop:(MITShuttleStop *)stop route:(MITShuttleRoute *)route
{
    self = [super init];
    if (self) {
        _stop = stop;
        _route = route;
        _shouldHideFooter = NO;
        [self refreshIntersectingRoutes];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [self setupTableView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[MITShuttlePredictionLoader sharedLoader] addPredictionDependencyForStop:self.stop];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(predictionsDidUpdate) name:kMITShuttlePredictionLoaderDidUpdateNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMITShuttlePredictionLoaderDidUpdateNotification object:nil];
    [[MITShuttlePredictionLoader sharedLoader] removePredictionDependencyForStop:self.stop];
}

#pragma mark - FetchedResultsControllers

- (NSFetchedResultsController *)stopsWithSameIdentifierFetchedResultsController
{
    if (!_stopsWithSameIdentifierFetchedResultsController) {
        NSManagedObjectContext *managedObjectContext = [[MITCoreDataController defaultController] mainQueueContext];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:[MITShuttleStop entityName] inManagedObjectContext:managedObjectContext];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier = %@", self.stop.identifier];
        [fetchRequest setPredicate:predicate];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]];
        
        _stopsWithSameIdentifierFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                            managedObjectContext:managedObjectContext
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:nil];
        _stopsWithSameIdentifierFetchedResultsController.delegate = self;
    }
    return _stopsWithSameIdentifierFetchedResultsController;
}

#pragma mark - Refresh Control

- (void)refreshControlActivated:(id)sender
{
    [[MITShuttleController sharedController] getPredictionsForStop:self.stop completion:^(NSArray *predictionLists, NSError *error) {
        [self predictionsDidUpdate];
    }];
}

#pragma mark - Predictions Updates

- (void)predictionsDidUpdate
{
    [self.refreshControl endRefreshing];
    [self configureTableSections];
    [self.tableView reloadData];
}

#pragma mark - Content Height

// Returns an estimated preferred height for the table, or 0 if no such height exists.
- (CGFloat)preferredContentHeight
{
    if (self.viewOption == MITShuttleStopViewOptionAll) {
        return 0;
    }
    [self.tableView reloadData];
    return self.tableView.contentSize.height;

}

#pragma mark - Private Methods

- (void)setupTableView
{
    [self configureTableSections];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshControlActivated:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
}

- (void)configureTableSections
{
    NSMutableArray *sectionTypes = [[NSMutableArray alloc] init];
    if (self.tableTitle) {
        [sectionTypes addObject:@(MITShuttleStopViewControllerSectionTypeTitle)];
    }
    if (self.viewOption == MITShuttleStopViewOptionAll) {
        [sectionTypes addObject:@(MITShuttleStopViewControllerSectionTypePredictions)];
    }
    [sectionTypes addObject:@(MITShuttleStopViewControllerSectionTypeRoutes)];
    self.sectionTypes = [sectionTypes copy];
}

- (void)refreshIntersectingRoutes
{
    [self.stopsWithSameIdentifierFetchedResultsController performFetch:nil];
    
    if (self.route) {
        NSMutableArray *newIntersectingRoutes = [NSMutableArray array];
        for (MITShuttleStop *stop in self.stopsWithSameIdentifierFetchedResultsController.fetchedObjects) {
            if (![stop.stopAndRouteIdTuple isEqualToString:self.stop.stopAndRouteIdTuple]) {
                [newIntersectingRoutes addObject:stop.route];
            }
        }
        self.intersectingRoutes = [NSArray arrayWithArray:newIntersectingRoutes];
    } else {
        self.intersectingRoutes = [self.stopsWithSameIdentifierFetchedResultsController.fetchedObjects valueForKey:@"route"];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sectionTypes.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:section] integerValue];
    switch (sectionType) {
        case MITShuttleStopViewControllerSectionTypeTitle: {
            return 1;
        }
        case MITShuttleStopViewControllerSectionTypePredictions: {
            NSOrderedSet *predictions = nil;
            if ([self.stop.predictionList.updatedTime timeIntervalSinceNow] >= -60) { // Make sure predictions are 60 seconds old or newer
                predictions = self.stop.predictionList.predictions;
            }
            return predictions.count > 0 ? predictions.count : 1;
        }
        case MITShuttleStopViewControllerSectionTypeRoutes: {
            return self.intersectingRoutes.count > 0 ? self.intersectingRoutes.count : 1;
        }
        default: {
            return 0;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:indexPath.section] integerValue];
    switch (sectionType) {
        case MITShuttleStopViewControllerSectionTypeTitle: {
            return [self tableTitleCellForIndexPath:indexPath];
        }
        case MITShuttleStopViewControllerSectionTypePredictions: {
            return [self predictionCellAtIndexPath:indexPath];
        }
        case MITShuttleStopViewControllerSectionTypeRoutes: {
            return [self intersectingRouteCellAtIndexPath:indexPath];
        }
        default: {
            return [UITableViewCell new];
        }
    }
}

#pragma mark - UITableViewDataSource Helpers

- (UITableViewCell *)tableTitleCellForIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kMITShuttleStopViewControllerDefaultCellReuseIdentifier forIndexPath:indexPath];
    cell.textLabel.text = self.tableTitle;
    return cell;
}

- (UITableViewCell *)predictionCellAtIndexPath:(NSIndexPath *)indexPath
{
    NSOrderedSet *predictions = self.stop.predictionList.predictions;
    MITShuttlePrediction *prediction = nil;
    
    if (predictions.count < 1) {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kMITShuttleStopViewControllerDefaultCellReuseIdentifier forIndexPath:indexPath];
        cell.textLabel.text = @"No current predictions";
        cell.userInteractionEnabled = NO;
        return cell;
    } else {
        MITShuttleStopAlarmCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kMITShuttleStopViewControllerAlarmCellReuseIdentifier forIndexPath:indexPath];
        cell.delegate = self;
        prediction = predictions[indexPath.row];
        [cell updateUIWithPrediction:prediction];
        return cell;
    }
}

- (UITableViewCell *)intersectingRouteCellAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.intersectingRoutes.count < 1) {
        UITableViewCell *noIntersectionsCell = [self.tableView dequeueReusableCellWithIdentifier:kMITShuttleStopViewControllerDefaultCellReuseIdentifier forIndexPath:indexPath];
        noIntersectionsCell.textLabel.text = @"No intersecting routes";
        noIntersectionsCell.userInteractionEnabled = NO;
        return noIntersectionsCell;
    }
    
    MITShuttleRouteCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kMITShuttleStopViewControllerRouteCellReuseIdentifier forIndexPath:indexPath];
    MITShuttleRoute *route = self.intersectingRoutes[indexPath.row];
    [cell setRoute:route];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:section] integerValue];
    switch (self.viewOption) {
        case MITShuttleStopViewOptionAll: {
            switch (sectionType) {
                case MITShuttleStopViewControllerSectionTypeTitle:
                case MITShuttleStopViewControllerSectionTypePredictions: {
                    return kMITShuttleStopShortTitleSpacing;
                }
                case MITShuttleStopViewControllerSectionTypeRoutes:
                default: {
                    return kMITShuttleStopDefaultTitleSpacing;
                }
            }
        }
        case MITShuttleStopViewOptionIntersectingOnly:
        default:
            return kMITShuttleStopShortTitleSpacing;
    }
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:section] integerValue];
    switch (self.viewOption) {
        case MITShuttleStopViewOptionAll: {
            switch (sectionType) {
                case MITShuttleStopViewControllerSectionTypeTitle: {
                    return @" ";
                }
                case MITShuttleStopViewControllerSectionTypePredictions: {
                    return @" ";
                }
                case MITShuttleStopViewControllerSectionTypeRoutes: {
                    return @"INTERSECTING ROUTES";
                }
                default: {
                    return nil;
                }
            }
        }
        case MITShuttleStopViewOptionIntersectingOnly: {
            return nil;
        }
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (self.shouldHideFooter) {
        return nil;
    }
    
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:section] integerValue];
    switch (sectionType) {
        case MITShuttleStopViewControllerSectionTypeTitle: {
            return @" ";
        }
        case MITShuttleStopViewControllerSectionTypePredictions: {
            NSOrderedSet *predictions = self.stop.predictionList.predictions;
            if (predictions) {
                return @"Tap bell to be notified 5 minutes before arrival.";
            } else {
                return nil;
            }
        }
        case MITShuttleStopViewControllerSectionTypeRoutes: {
            return @"Other routes stopping at or near this stop.";
        }
        default: {
            return nil;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITShuttleStopViewControllerSectionType sectionType = [[self.sectionTypes objectAtIndex:indexPath.section] integerValue];
    if (sectionType == MITShuttleStopViewControllerSectionTypeRoutes) {
        MITShuttleRoute *route = self.intersectingRoutes[indexPath.row];
        if ([self.delegate respondsToSelector:@selector(shuttleStopViewController:didSelectRoute:withStop:)]) {
            [self.delegate shuttleStopViewController:self didSelectRoute:route withStop:self.stop];
        } else {
            // Default behavior
            MITShuttleRouteStopMapContainerViewController *routeVC = [[MITShuttleRouteStopMapContainerViewController alloc] initWithRoute:route stop:nil];
            [self.navigationController pushViewController:routeVC animated:YES];
        }
    } else if (sectionType == MITShuttleStopViewControllerSectionTypePredictions) {
        MITShuttleStopAlarmCell *alarmCell = (MITShuttleStopAlarmCell *)[tableView cellForRowAtIndexPath:indexPath];
        if ([alarmCell isKindOfClass:[MITShuttleStopAlarmCell class]]) {
            if (!alarmCell.alertButton.hidden) {
                [self stopAlarmCellDidToggleAlarm:alarmCell];
            }
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - MITShuttleStopAlarmCellDelegate

- (void)stopAlarmCellDidToggleAlarm:(MITShuttleStopAlarmCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSOrderedSet *predictions = self.stop.predictionList.predictions;
    MITShuttlePrediction *prediction = predictions[indexPath.row];
    
    NSMutableArray *predictionsGroup = [NSMutableArray array];
    for (NSInteger i = indexPath.row; i < predictions.count && predictionsGroup.count < 3; i++) {
        [predictionsGroup addObject:predictions[i]];
    }
    [[MITShuttleStopNotificationManager sharedManager] toggleNotificationForPredictionGroup:predictionsGroup withRouteTitle:self.route.title];
    
    [cell updateNotificationButtonWithPrediction:prediction];
}

#pragma mark - Getters

- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [self.view addSubview:_tableView];
        
        _tableView.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:_tableView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
        NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:_tableView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
        NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:_tableView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
        NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:_tableView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
        [self.view addConstraints:@[top, left, bottom, right]];
        
        [_tableView registerNib:[UINib nibWithNibName:NSStringFromClass([MITShuttleStopAlarmCell class]) bundle:nil] forCellReuseIdentifier:kMITShuttleStopViewControllerAlarmCellReuseIdentifier];
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kMITShuttleStopViewControllerDefaultCellReuseIdentifier];
        [_tableView registerNib:[UINib nibWithNibName:NSStringFromClass([MITShuttleRouteCell class]) bundle:nil] forCellReuseIdentifier:kMITShuttleStopViewControllerRouteCellReuseIdentifier];
    }
    return _tableView;
}

@end
