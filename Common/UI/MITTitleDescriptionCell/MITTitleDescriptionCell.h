#import <UIKit/UIKit.h>

@interface MITTitleDescriptionCell : UITableViewCell

+ (NSString *)titleDescriptionCellNibName;
+ (UINib *)titleDescriptionCellNib;
- (void)setTitle:(NSString *)title withDescription:(NSString *)description;

@end