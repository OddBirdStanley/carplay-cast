#import <Preferences/PSListController.h>
#include "CPAppListController.h"
#include "LocationSpoofController.h"

@interface CRERootListController : PSViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, retain) UITableView *rootTable;
@property (nonatomic, retain) CPAppListController *appListController;
@property (nonatomic, retain) LocationSpoofController *locationSpoofController;

@end
