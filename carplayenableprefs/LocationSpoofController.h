#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationSpoofController : UIViewController <MKMapViewDelegate, UISearchBarDelegate>

@property (nonatomic, retain) UISwitch *enableSwitch;
@property (nonatomic, retain) UILabel *coordLabel;
@property (nonatomic, retain) MKMapView *mapView;
@property (nonatomic, retain) UISearchBar *searchBar;
@property (nonatomic, retain) MKPointAnnotation *pinAnnotation;

@end
