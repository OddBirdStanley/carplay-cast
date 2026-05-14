#import <CoreLocation/CoreLocation.h>

#define PREFERENCES_PLIST_PATH @"/var/mobile/Library/Preferences/com.carplayenable.preferences.plist"

static BOOL spoofEnabled = NO;
static double spoofLat = 0.0;
static double spoofLng = 0.0;

static void loadLocationSpoofPrefs() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFERENCES_PLIST_PATH];
    spoofEnabled = [prefs[@"locationSpoofEnabled"] boolValue];
    spoofLat = [prefs[@"locationSpoofLatitude"] doubleValue];
    spoofLng = [prefs[@"locationSpoofLongitude"] doubleValue];
}

static void onLocationSpoofPrefsChanged(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo) {
    loadLocationSpoofPrefs();
}

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (spoofEnabled && (spoofLat != 0.0 || spoofLng != 0.0)) {
        CLLocationCoordinate2D fakeCoord;
        fakeCoord.latitude = spoofLat;
        fakeCoord.longitude = spoofLng;
        return fakeCoord;
    }
    return %orig;
}

%end

%ctor {
    // Don't spoof location in the Preferences app (so the map picker shows real location)
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.apple.Preferences"]) {
        return;
    }

    loadLocationSpoofPrefs();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        onLocationSpoofPrefsChanged,
        CFSTR("com.carplayenable.locationspoof.changed"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    %init;
}
