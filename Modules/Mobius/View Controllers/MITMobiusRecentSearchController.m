#import "MITMobiusRecentSearchController.h"
#import "MITMobiusResourceDataSource.h"
#import "MITMobiusRecentSearchQuery.h"
#import "UIKit+MITAdditions.h"
#import "MITCoreData.h"

@interface MITMobiusRecentSearchController () <UIActionSheetDelegate>
@property (nonatomic,weak) UIActionSheet *confirmSheet;
@property (nonatomic,copy) NSString *filterString;
@property (nonatomic,weak) UIBarButtonItem *clearButtonItem;

@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation MITMobiusRecentSearchController
#pragma mark - View lifecycle
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *clearButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearRecentsButtonClicked:)];
    
    self.navigationItem.title = @"Recents";
    self.navigationItem.leftBarButtonItem = clearButtonItem;
    self.clearButtonItem = clearButtonItem;
    
    self.navigationController.navigationBar.tintColor = [UIColor mit_tintColor];
    self.view.tintColor = [UIColor mit_tintColor];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    managedObjectContext.parentContext = [MITCoreDataController defaultController].mainQueueContext;
    self.managedObjectContext = managedObjectContext;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusRecentSearchQuery entityName]];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                               managedObjectContext:managedObjectContext
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:nil];
    self.fetchedResultsController = fetchedResultsController;

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.fetchedResultsController.fetchedObjects == nil) {
        [self.fetchedResultsController performFetch:nil];
    }
    
    if (self.fetchedResultsController.fetchedObjects.count == 0) {
        self.clearButtonItem.enabled = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.confirmSheet dismissWithClickedButtonIndex:self.confirmSheet.cancelButtonIndex animated:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Recent Add/Remove methods
- (IBAction)clearRecentsButtonClicked:(id)sender
{
    UIActionSheet *actionSheet =  [[UIActionSheet alloc] initWithTitle:nil
                                                              delegate:self
                                                     cancelButtonTitle:@"Cancel"
                                                destructiveButtonTitle:@"Clear All Recents"
                                                     otherButtonTitles:nil];
    [actionSheet showInView:self.view];
    self.confirmSheet = actionSheet;
}

- (void)filterResultsUsingString:(NSString *)filterString
{
    if (![self.filterString isEqualToString:filterString]) {
        self.filterString = filterString;
        
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusRecentSearchQuery entityName]];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
        
        if (filterString) {
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text BEGINSWITH[c] %@",filterString];
        }
        
        NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                                   managedObjectContext:self.managedObjectContext
                                                                                                     sectionNameKeyPath:nil
                                                                                                              cacheName:nil];
        self.fetchedResultsController = fetchedResultsController;
        [self.fetchedResultsController performFetch:nil];
        
        if (self.fetchedResultsController.fetchedObjects.count > 0) {
            self.clearButtonItem.enabled = YES;
        } else {
            self.clearButtonItem.enabled = NO;
        }
        
        [self.tableView reloadData];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [self clearRecents];
    }
    
    self.confirmSheet = nil;
}

- (void)clearRecents
{
    [[MITCoreDataController defaultController] performBackgroundUpdateAndWait:^BOOL(NSManagedObjectContext *context, NSError *__autoreleasing *error) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusRecentSearchQuery entityName]];
        NSArray *objects = [context executeFetchRequest:fetchRequest error:error];
        
        if (!objects) {
            return NO;
        }
        
        [objects enumerateObjectsUsingBlock:^(NSManagedObject *obj, NSUInteger idx, BOOL *stop) {
            [context deleteObject:obj];
        }];
        
        return YES;
    } error:nil];
    
    [self.managedObjectContext reset];
    [self.fetchedResultsController performFetch:nil];
    [self.tableView reloadData];
    self.clearButtonItem.enabled = NO;
}

#pragma mark - Table View methods
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    
    MITMobiusRecentSearchQuery *query = self.fetchedResultsController.fetchedObjects[indexPath.row];
    cell.textLabel.text = query.text;
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.fetchedResultsController.fetchedObjects.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MITMobiusRecentSearchQuery *query = self.fetchedResultsController.fetchedObjects[indexPath.row];
    
    if ([self.delegate respondsToSelector:@selector(placeSelectionViewController:didSelectQuery:)]) {
        [self.delegate placeSelectionViewController:self didSelectQuery:query.text];
    }
    
    [self filterResultsUsingString:query.text];
}

@end
