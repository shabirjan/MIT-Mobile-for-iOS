#import "MITLibrariesAskUsFormSheetViewController.h"
#import "MITLibrariesWebservices.h"
#import "MITLibrariesAskUsModel.h"
#import "MITLibrariesFormSheetElementStatus.h"
#import "MITLibrariesFormSheetGroupTechnicalHelp.h"

@implementation MITLibrariesAskUsFormSheetViewController

#pragma mark - Setup

- (void)setup
{
    [super setup];
    self.title = @"Ask Us!";
    [self setupFormSheetGroups];
}

- (void)setupFormSheetGroups
{
    [self showActivityIndicator];
    [self buildTopFormSheetGroupInBackgroundWithCompletion:^(MITLibrariesFormSheetGroup *formSheetGroup, NSError *error) {
        [self hideActivityIndicator];
        if (!error) {
            [self hideActivityIndicator];
            NSMutableArray *formSheetGroups = [NSMutableArray array];
            [formSheetGroups addObject:formSheetGroup];
            [formSheetGroups addObject:[self bottomFormSheetGroup]];
            self.formSheetGroups = formSheetGroups;
            [self reloadTableView];
        } else {
            NSLog(@"Error building top form sheet group: %@", error);
            [self notifyOfTopicsFetchFailure];
        }
    }];
}

#pragma mark - Form Submission

- (void)submitFormForParameters:(NSDictionary *)parameters
{
    NSMutableDictionary *paramsToSubmit = [parameters mutableCopy];
    paramsToSubmit[@"ask_type"] = @"ask_us";
    [self showActivityIndicator];
    [MITLibrariesWebservices postAskUsFormForParameters:paramsToSubmit withCompletion:^(id responseObject, NSError *error) {
        [self hideActivityIndicator];
        if (!error) {
            [self notifyFormSubmissionSuccessWithResponseObject:responseObject];
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self notifyFormSubmissionError];
        }
    }];
}

#pragma mark - Data Assembly

- (void)buildTopFormSheetGroupInBackgroundWithCompletion:(void(^)(MITLibrariesFormSheetGroup *formSheetGroup, NSError *error))completion
{
    [MITLibrariesWebservices getAskUsTopicsWithCompletion:^(MITLibrariesAskUsModel *askUs, NSError *error) {
        if (!error) {
            MITLibrariesFormSheetElement *topic = [MITLibrariesFormSheetElement new];
            topic.type = MITLibrariesFormSheetElementTypeOptions;
            topic.title = @"Topic";
            topic.htmlParameterKey = @"topic";
            topic.availableOptions = askUs.topics;
            
            MITLibrariesFormSheetElement *subject = [MITLibrariesFormSheetElement new];
            subject.type = MITLibrariesFormSheetElementTypeSingleLineTextEntry;
            subject.title = @"Subject";
            subject.htmlParameterKey = @"subject";
            
            MITLibrariesFormSheetElement *detailedQuestion = [MITLibrariesFormSheetElement new];
            detailedQuestion.type = MITLibrariesFormSheetElementTypeMultiLineTextEntry;
            detailedQuestion.title = @"Detailed question";
            detailedQuestion.htmlParameterKey = @"question";
            
            MITLibrariesFormSheetGroup *topGroup = [MITLibrariesFormSheetGroup new];
            topGroup.headerTitle = nil;
            topGroup.footerTitle = nil;
            topGroup.elements = @[topic, subject, detailedQuestion];
            
            completion(topGroup, nil);
        } else {
            completion(nil, error);
        }
    }];
}

- (MITLibrariesFormSheetGroup *)bottomFormSheetGroup
{
    MITLibrariesFormSheetElementStatus *status = [MITLibrariesFormSheetElementStatus new];
    
    MITLibrariesFormSheetElement *department = [MITLibrariesFormSheetElement new];
    department.type = MITLibrariesFormSheetElementTypeSingleLineTextEntry;
    department.title = @"Department, Lab, or Center";
    department.htmlParameterKey = @"department";
    
    MITLibrariesFormSheetElement *phoneNumber = [MITLibrariesFormSheetElement new];
    phoneNumber.type = MITLibrariesFormSheetElementTypeSingleLineTextEntry;
    phoneNumber.title = @"Phone";
    phoneNumber.htmlParameterKey = @"phone";
    phoneNumber.optional = YES;
    
    MITLibrariesFormSheetGroup *bottomGroup = [MITLibrariesFormSheetGroup new];
    bottomGroup.headerTitle = @"PERSONAL INFO";
    bottomGroup.footerTitle = nil;
    bottomGroup.elements = @[status, department, phoneNumber];
    
    return bottomGroup;
}

#pragma mark - MITLibrariesFormSheetOptionsSelectionViewControllerDelegate

- (void)formSheetOptionsSelectionViewController:(MITLibrariesFormSheetOptionsSelectionViewController *)optionsSelectionViewController didFinishUpdatingElement:(MITLibrariesFormSheetElement *)element
{
    [super formSheetOptionsSelectionViewController:optionsSelectionViewController didFinishUpdatingElement:element];
    if ([element.title isEqualToString:@"Topic"]) {
        if ([element.value isEqualToString:@"Technical Help"]) {
            [self showTechnicalFormGroup];
        } else {
            [self hideTechnicalFormGroup];
        }
    }
}

- (void)showTechnicalFormGroup
{
    MITLibrariesFormSheetGroup *technicalHelpGroup = [self activeTechnicalHelpGroup];
    if (!technicalHelpGroup) {
        NSMutableArray *formSheetGroups = [self.formSheetGroups mutableCopy];
        if (1 < formSheetGroups.count) {
            [formSheetGroups insertObject:[MITLibrariesFormSheetGroupTechnicalHelp new] atIndex:1];
        } else {
            [formSheetGroups addObject:[MITLibrariesFormSheetGroupTechnicalHelp new]];
        }
        self.formSheetGroups = formSheetGroups;
        [self reloadTableView];
    }
}

- (void)hideTechnicalFormGroup
{
    MITLibrariesFormSheetGroup *technicalHelpGroup = [self activeTechnicalHelpGroup];
    if (technicalHelpGroup) {
        NSMutableArray *formSheetGroups = [self.formSheetGroups mutableCopy];
        [formSheetGroups removeObject:technicalHelpGroup];
        self.formSheetGroups = formSheetGroups;
        [self reloadTableView];
    }
}

- (MITLibrariesFormSheetGroup *)activeTechnicalHelpGroup
{
    MITLibrariesFormSheetGroup *technicalHelpGroup;
    for (MITLibrariesFormSheetGroup *group in self.formSheetGroups) {
        if ([group.headerTitle.lowercaseString isEqualToString:@"technical help"]) {
            technicalHelpGroup = group;
            break;
        }
    }
    return technicalHelpGroup;
}

#pragma mark - Failure Alerts

- (void)notifyOfTopicsFetchFailure
{
    NSString *title = @"Unable To Fetch Options";
    NSString *message = @"We were unable to receive some of the options necessary for submiting a request.  Please check your internet connection and try again.";
    NSString *confirmation = @"Ok";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:confirmation, nil];
    [alert show];
}

@end
