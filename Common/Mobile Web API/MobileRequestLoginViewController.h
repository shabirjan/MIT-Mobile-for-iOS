#import <UIKit/UIKit.h>

@class MobileRequestLoginViewController;

@protocol MobileRequestLoginViewDelegate 
@required
- (void)loginRequest:(MobileRequestLoginViewController*)view
  didEndWithUsername:(NSString*)username
            password:(NSString*)password
     shouldSaveLogin:(BOOL)saveLogin;
- (void)cancelWasPressedForLoginRequest:(MobileRequestLoginViewController*)view;
@end

@interface MobileRequestLoginViewController : UIViewController <UITextFieldDelegate> {

}

@property (nonatomic,assign) id<MobileRequestLoginViewDelegate> delegate;

- (id)initWithIdentifier:(NSString*)identifier;
- (id)initWithUsername:(NSString*)user password:(NSString*)password;

- (void)showError:(NSString*)error;
- (void)showActivityView;
- (void)hideActivityView;
@end
