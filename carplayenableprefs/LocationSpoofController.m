#import "LocationSpoofController.h"

#define PREFERENCES_PLIST_PATH @"/var/mobile/Library/Preferences/com.carplayenable.preferences.plist"

@implementation LocationSpoofController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Location Spoofer"];
    [[self view] setBackgroundColor:[UIColor systemBackgroundColor]];

    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFERENCES_PLIST_PATH];
    BOOL enabled = [prefs[@"locationSpoofEnabled"] boolValue];
    double lat = [prefs[@"locationSpoofLatitude"] doubleValue];
    double lng = [prefs[@"locationSpoofLongitude"] doubleValue];

    CGFloat width = self.view.bounds.size.width;
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *))
    {
        safeTop = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
    }

    CGFloat y = safeTop + 8;

    // Enable switch row
    UIView *switchRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 50)];
    [switchRow setBackgroundColor:[UIColor secondarySystemGroupedBackgroundColor]];

    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 200, 50)];
    [switchLabel setText:@"Enable Spoofing"];
    [switchLabel setFont:[UIFont systemFontOfSize:17]];
    [switchRow addSubview:switchLabel];

    _enableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 67, 10, 51, 31)];
    [_enableSwitch setOn:enabled];
    [_enableSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [switchRow addSubview:_enableSwitch];
    [[self view] addSubview:switchRow];
    y += 54;

    // Coordinate label
    _coordLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, width - 32, 24)];
    [_coordLabel setFont:[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular]];
    [_coordLabel setTextColor:[UIColor secondaryLabelColor]];
    [_coordLabel setTextAlignment:NSTextAlignmentCenter];
    if (lat != 0.0 || lng != 0.0)
    {
        [self updateCoordLabelWithLat:lat lng:lng];
    }
    else
    {
        [_coordLabel setText:@"Long press on map to set location"];
    }
    [[self view] addSubview:_coordLabel];
    y += 30;

    // Search bar
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, y, width, 44)];
    [_searchBar setPlaceholder:@"Search for a place..."];
    [_searchBar setDelegate:self];
    [_searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [[self view] addSubview:_searchBar];
    y += 48;

    // Map view
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, y, width, self.view.bounds.size.height - y)];
    [_mapView setDelegate:self];
    [_mapView setShowsUserLocation:YES];
    [_mapView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
    [[self view] addSubview:_mapView];

    // Long press to drop pin
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
    [longPress setMinimumPressDuration:0.5];
    [_mapView addGestureRecognizer:longPress];

    // Show existing pin if saved
    if (lat != 0.0 || lng != 0.0)
    {
        CLLocationCoordinate2D savedCoord = CLLocationCoordinate2DMake(lat, lng);
        [self placePinAtCoordinate:savedCoord animated:NO];
    }
}

- (void)updateCoordLabelWithLat:(double)lat lng:(double)lng
{
    [_coordLabel setText:[NSString stringWithFormat:@"%.6f, %.6f", lat, lng]];
}

- (void)placePinAtCoordinate:(CLLocationCoordinate2D)coord animated:(BOOL)animated
{
    if (_pinAnnotation)
    {
        [_mapView removeAnnotation:_pinAnnotation];
    }

    _pinAnnotation = [[MKPointAnnotation alloc] init];
    [_pinAnnotation setCoordinate:coord];
    [_pinAnnotation setTitle:@"Spoofed Location"];
    [_mapView addAnnotation:_pinAnnotation];

    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 1000, 1000);
    [_mapView setRegion:region animated:animated];

    [self updateCoordLabelWithLat:coord.latitude lng:coord.longitude];
    [self saveCoordinate:coord];
}

- (void)saveCoordinate:(CLLocationCoordinate2D)coord
{
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREFERENCES_PLIST_PATH];
    if (!prefs)
    {
        prefs = [NSMutableDictionary dictionary];
    }
    prefs[@"locationSpoofLatitude"] = @(coord.latitude);
    prefs[@"locationSpoofLongitude"] = @(coord.longitude);
    [prefs writeToFile:PREFERENCES_PLIST_PATH atomically:YES];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.carplayenable.locationspoof.changed"),
        NULL, NULL, YES
    );
}

- (void)toggleChanged:(UISwitch *)sender
{
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREFERENCES_PLIST_PATH];
    if (!prefs)
    {
        prefs = [NSMutableDictionary dictionary];
    }
    prefs[@"locationSpoofEnabled"] = @(sender.isOn);
    [prefs writeToFile:PREFERENCES_PLIST_PATH atomically:YES];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.carplayenable.locationspoof.changed"),
        NULL, NULL, YES
    );
}

#pragma mark - Map gesture

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture
{
    if ([gesture state] != UIGestureRecognizerStateBegan)
    {
        return;
    }

    CGPoint touchPoint = [gesture locationInView:_mapView];
    CLLocationCoordinate2D coord = [_mapView convertPoint:touchPoint toCoordinateFromView:_mapView];
    [self placePinAtCoordinate:coord animated:YES];
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    NSString *query = [searchBar text];
    if (!query || [query length] == 0)
    {
        return;
    }

    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder geocodeAddressString:query completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (error || [placemarks count] == 0)
        {
            return;
        }

        CLPlacemark *placemark = [placemarks firstObject];
        CLLocationCoordinate2D coord = placemark.location.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self placePinAtCoordinate:coord animated:YES];
            [_pinAnnotation setTitle:placemark.name ?: query];
        });
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

@end
