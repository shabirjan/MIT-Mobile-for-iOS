#import "MITMobiusResourcesTableViewController.h"
#import "MITMobiusModel.h"
#import "MITMobiusResourceTableViewCell.h"
#import "UITableView+DynamicSizing.h"
#import "MITMobiusResourceView.h"
#import "MITMobiusRootPhoneViewController.h"

NSString* const MITMobiusResourcesTableViewPlaceholderCellIdentifier = @"PlaceholderCell";

@interface MITMobiusResourcesTableViewController () <UITableViewDataSourceDynamicSizing>
@property(nonatomic,readonly,strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation MITMobiusResourcesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _managedObjectContext = [[MITCoreDataController defaultController] newManagedObjectContextWithConcurrencyType:NSMainQueueConcurrencyType trackChanges:NO];
    
    UINib *resourceTableViewCellNib = [UINib nibWithNibName:@"MITMobiusResourceTableViewCell" bundle:nil];
    [self.tableView registerNib:resourceTableViewCellNib forDynamicCellReuseIdentifier:NSStringFromClass([MITMobiusResourceTableViewCell class])];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITMobiusResourcesTableViewPlaceholderCellIdentifier];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (MITMobiusResource*)selectedResource
{
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    NSInteger section = indexPath.section;

    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        return nil;
    } else if ([self shouldDisplayPlaceholderCell]) {
        --section;
    }

    NSManagedObjectID *resourceObjectID = [[self.dataSource viewController:self resourceAtIndex:indexPath.row inRoomAtIndex:section] objectID];
    MITMobiusResource *resource = (MITMobiusResource*)[[[MITCoreDataController defaultController] mainQueueContext] objectWithID:resourceObjectID];
    return resource;
}



- (MITMobiusResource*)_representedObjectForIndexPath:(NSIndexPath*)indexPath
{
    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        return nil;
    } else {
        NSInteger section = indexPath.section;
        if ([self shouldDisplayPlaceholderCell]) {
            --section;
        }
        
        return [self.dataSource viewController:self resourceAtIndex:indexPath.row inRoomAtIndex:section];
    }
}

#pragma mark Delegate Passthroughs
- (NSIndexPath*)_indexPathForPlaceholderCell
{
    if ([self shouldDisplayPlaceholderCell]) {
        return nil;
    } else {
        return [NSIndexPath indexPathForRow:0 inSection:0];
    }
}

- (BOOL)_isPlaceholderCellAtIndexPath:(NSIndexPath*)indexPath
{
    if ([self shouldDisplayPlaceholderCell]) {
        return (indexPath.section == 0 && indexPath.row == 0);
    } else {
        return NO;
    }
}

- (BOOL)shouldDisplayPlaceholderCell
{
    if ([self.delegate respondsToSelector:@selector(shouldDisplayPlaceholderCellForResourcesTableViewController:)]) {
        return [self.delegate shouldDisplayPlaceholderCellForResourcesTableViewController:self];
    } else {
        return NO;
    }
}

- (CGFloat)heightOfPlaceholderCell
{
    if ([self.delegate respondsToSelector:@selector(heightOfPlaceholderCellForResourcesTableViewController:)]) {
        return [self.delegate heightOfPlaceholderCellForResourcesTableViewController:self];
    } else {
        return 0;
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    __block NSInteger numberOfSections = 0;
    numberOfSections = [self.dataSource numberOfRoomsForViewController:self];

    if ([self shouldDisplayPlaceholderCell]) {
        ++numberOfSections;
    }

    return numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self shouldDisplayPlaceholderCell] && section == 0) {
        return 1;
    } else {
        if ([self shouldDisplayPlaceholderCell]) {
            --section;
        }
        NSInteger room = [self.dataSource viewController:self numberOfResourcesInRoomAtIndex:section];
        return room;
    }
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([self shouldDisplayPlaceholderCell] && (section == 0)) {
        return nil;
    } else if ([self shouldDisplayPlaceholderCell]) {
        --section;
    }

    MITMobiusRoomObject *room = [self.dataSource viewController:self roomAtIndex:section];
    return [NSString stringWithFormat:@"Room %@", room.roomName];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = nil;

    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        cellIdentifier = MITMobiusResourcesTableViewPlaceholderCellIdentifier;
    } else {
        cellIdentifier = NSStringFromClass([MITMobiusResourceTableViewCell class]);
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];

    [self tableView:tableView configureCell:cell forRowAtIndexPath:indexPath];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        return [self heightOfPlaceholderCell];
    } else {
        return [tableView minimumHeightForCellWithReuseIdentifier:NSStringFromClass([MITMobiusResourceTableViewCell class]) atIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView*)tableView configureCell:(UITableViewCell*)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.textLabel.text = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        NSAssert([cell isKindOfClass:[MITMobiusResourceTableViewCell class]], @"cell for [%@,%@] is kind of %@, expected %@",cell.reuseIdentifier,indexPath,NSStringFromClass([cell class]),NSStringFromClass([MITMobiusResourceTableViewCell class]));
        
        MITMobiusResourceTableViewCell *resourceCell = (MITMobiusResourceTableViewCell*)cell;
        MITMobiusResource *resource = [self _representedObjectForIndexPath:indexPath];

        resourceCell.resourceView.index = NSNotFound;
        resourceCell.resourceView.machineName = resource.name;
        resourceCell.resourceView.location = resource.room;
        [resourceCell.resourceView setStatus:MITMobiusResourceStatusOnline withText:resource.status];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        cell.separatorInset = UIEdgeInsetsMake(0, CGRectGetWidth(cell.bounds), 0, 0);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self _isPlaceholderCellAtIndexPath:indexPath]) {
        if ([self.delegate respondsToSelector:@selector(resourcesTableViewControllerDidSelectPlaceholderCell:)]) {
            [self.delegate resourcesTableViewControllerDidSelectPlaceholderCell:self];
        }
    } else if ([self.delegate respondsToSelector:@selector(resourcesTableViewController:didSelectResource:)]) {
        MITMobiusResource *resource = [self _representedObjectForIndexPath:indexPath];
        [self.delegate resourcesTableViewController:self didSelectResource:resource];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.tableView) {
        if ([self.delegate respondsToSelector:@selector(resourcesTableViewController:didScrollToContentOffset:)]) {
            [self.delegate resourcesTableViewController:self didScrollToContentOffset:scrollView.contentOffset];
        }
    }
}

@end