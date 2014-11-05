
#import "MITLibrariesFormSheetViewController.h"
#import "MITLibrariesFormSheetCellOptions.h"
#import "MITLibrariesFormSheetCellSingleLineTextEntry.h"
#import "MITLibrariesFormSheetCellMultiLineTextEntry.h"
#import "MITLibrariesFormSheetCellWebLink.h"
#import "UIKit+MITAdditions.h"

static NSString * const MITLibrariesFormSheetCellIdentifierOptions = @"MITLibrariesFormSheetCellIdentifierOptions";
static NSString * const MITLibrariesFormSheetCellIdentifierSingleLineTextEntry = @"MITLibrariesFormSheetCellIdentifierSingleLineTextEntry";
static NSString * const MITLibrariesFormSheetCellIdentifierMultiLineTextEntry = @"MITLibrariesFormSheetCellIdentifierMultiLineTextEntry";
static NSString * const MITLibrariesFormSheetCellIdentifierWebLink = @"MITLibrariesFormSheetCellIdentifierWebLink";

@interface MITLibrariesFormSheetViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@end

@implementation MITLibrariesFormSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

#pragma mark - Setup

- (void)setup
{
    [self setupActivityIndicator];
    [self setupTableView];
    [self setupNavigationBar];
}

- (void)setupActivityIndicator
{
    self.activityIndicator.color = [UIColor mit_tintColor];
}

- (void)setupTableView
{
    [self registerTableViewCells];
}

- (void)registerTableViewCells
{
    UINib *optionsCellNib = [UINib nibWithNibName:MITLibrariesFormSheetCellOptionsNibName bundle:nil];
    [self.tableView registerNib:optionsCellNib forCellReuseIdentifier:MITLibrariesFormSheetCellIdentifierOptions];
    
    UINib *singleLineEntryCellNib = [UINib nibWithNibName:MITLibrariesFormSheetCellSingleLineTextEntryNibName bundle:nil];
    [self.tableView registerNib:singleLineEntryCellNib forCellReuseIdentifier:MITLibrariesFormSheetCellIdentifierSingleLineTextEntry];
    
    UINib *multiLineEntryCellNib = [UINib nibWithNibName:MITLibrariesFormSheetCellMultiLineTextEntryNibName bundle:nil];
    [self.tableView registerNib:multiLineEntryCellNib forCellReuseIdentifier:MITLibrariesFormSheetCellIdentifierMultiLineTextEntry];
    
    UINib *webLinkCellNib = [UINib nibWithNibName:MITLibrariesFormSheetCellWebLinkNibName bundle:nil];
    [self.tableView registerNib:webLinkCellNib forCellReuseIdentifier:MITLibrariesFormSheetCellIdentifierWebLink];
}

- (void)setupNavigationBar
{
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Submit"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(submitButtonPressed:)];
}

#pragma mark - Activity Indicator

- (void)showActivityIndicator
{
    [self.activityIndicator startAnimating];
}

- (void)hideActivityIndicator
{
    [self.activityIndicator stopAnimating];
}

#pragma mark - Button Presses

- (void)submitButtonPressed:(UIBarButtonItem *)sender
{
    // TODO: Submit form
}

#pragma mark - Form Submission

- (void)submitForm
{
    
}

#pragma mark - TableView Reload

- (void)reloadTableView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.formSheetGroups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    MITLibrariesFormSheetGroup *groupForSection = self.formSheetGroups[section];
    return groupForSection.elements.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITLibrariesFormSheetGroup *groupForSection = self.formSheetGroups[indexPath.section];
    MITLibrariesFormSheetElement *elementForRow = groupForSection.elements[indexPath.row];
    
    UITableViewCell<MITLibrariesFormSheetCellProtocol> *cell;
    switch (elementForRow.type) {
        case MITLibrariesFormSheetElementTypeOptions:
            cell = [tableView dequeueReusableCellWithIdentifier:MITLibrariesFormSheetCellIdentifierOptions forIndexPath:indexPath];
            break;
        case MITLibrariesFormSheetElementTypeSingleLineTextEntry:
            cell = [tableView dequeueReusableCellWithIdentifier:MITLibrariesFormSheetCellIdentifierSingleLineTextEntry forIndexPath:indexPath];
            break;
        case MITLibrariesFormSheetElementTypeMultiLineTextEntry:
            cell = [tableView dequeueReusableCellWithIdentifier:MITLibrariesFormSheetCellIdentifierMultiLineTextEntry forIndexPath:indexPath];
            break;
        case MITLibrariesFormSheetElementTypeWebLink:
            cell = [tableView dequeueReusableCellWithIdentifier:MITLibrariesFormSheetCellIdentifierWebLink forIndexPath:indexPath];
            break;
    }
    
    [cell configureCellForFormSheetElement:elementForRow];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    MITLibrariesFormSheetGroup *groupForSection = self.formSheetGroups[section];
    return groupForSection.headerTitle;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    MITLibrariesFormSheetGroup *groupForSection = self.formSheetGroups[section];
    return groupForSection.footerTitle;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITLibrariesFormSheetGroup *groupForSection = self.formSheetGroups[indexPath.section];
    MITLibrariesFormSheetElement *elementForRow = groupForSection.elements[indexPath.row];
    
    CGFloat height;
    switch (elementForRow.type) {
        case MITLibrariesFormSheetElementTypeOptions:
            height = [MITLibrariesFormSheetCellOptions heightForCell];
            break;
        case MITLibrariesFormSheetElementTypeSingleLineTextEntry:
            height = [MITLibrariesFormSheetCellSingleLineTextEntry heightForCell];
            break;
        case MITLibrariesFormSheetElementTypeMultiLineTextEntry:
            height = [MITLibrariesFormSheetCellMultiLineTextEntry heightForCell];
            break;
        case MITLibrariesFormSheetElementTypeWebLink:
            height = [MITLibrariesFormSheetCellWebLink heightForCell];
            break;
    }
    return height;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
