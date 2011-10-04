#import "MITTabBarController.h"
#import "MITSpringboard.h"

#define MITAppDelegate() ((MIT_MobileAppDelegate *)[[UIApplication sharedApplication] delegate])

@class MITModule;
@class DummyRotatingViewController;

@interface MIT_MobileAppDelegate : NSObject <UIApplicationDelegate, MITSpringboardDelegate> {
    UIWindow *window;
    // have references to both springbard and tabbar, set only one.
    MITNavigationParadigm navParadigm DEPRECATED_ATTRIBUTE;
    MITTabBarController *theTabBarController DEPRECATED_ATTRIBUTE;
    UINavigationController *rootNavigationController;
    DummyRotatingViewController *appModalHolder;
    
    NSArray *modules; // all registered modules as defined in MITModuleList.m
    NSData *devicePushToken; // deviceToken returned by Apple's push servers when we register. Will be nil if not available.
    
    NSInteger networkActivityRefCount; // the number of concurrent network connections the user should know about. If > 0, spinny in status bar is shown
}

- (BOOL)shouldShowOpenHouseContent;

- (BOOL)usesTabBar DEPRECATED_ATTRIBUTE;

- (void)showNetworkActivityIndicator;
- (void)hideNetworkActivityIndicator;

- (void)presentAppModalViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)presentRotatingAppModalViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)dismissAppModalViewControllerAnimated:(BOOL)animated;

@property (nonatomic, retain) DummyRotatingViewController *appModalHolder;
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) MITTabBarController *tabBarController DEPRECATED_ATTRIBUTE;
@property (nonatomic, retain) UINavigationController *rootNavigationController;
@property (nonatomic, retain) NSArray *modules;
@property (nonatomic, retain) NSData *deviceToken;

@end

@interface APNSUIDelegate : NSObject <UIAlertViewDelegate>
{
	NSDictionary *apnsDictionary;
	MIT_MobileAppDelegate *appDelegate;
}

- (id) initWithApnsDictionary: (NSDictionary *)apns appDelegate: (MIT_MobileAppDelegate *)delegate;

@end

