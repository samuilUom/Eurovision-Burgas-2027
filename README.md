# Eurovision Burgas 2027

A Eurovision-themed iPhone city guide for Burgas. Discover useful places nearby, find a walking route, save favourites, and share reviews and photos with other visitors.

The app has a Bulgarian interface and combines an interactive city map with community contributions.

## Explore Burgas

| Category | What you can find |
| --- | --- |
| Toilets | Nearby facilities, prices, opening hours, accessibility and essential amenities |
| Restaurants | Places to eat, shared reviews and photos, and Google reviews |
| ATMs | Nearby cash machines and directions |
| Supermarkets and shops | Everyday shopping, including nonstop shops |
| Health | Hospitals and pharmacies, with 24/7 badges for known round-the-clock locations |
| Petrol stations | Fuel stops, place information and directions |
| EV charging | Charging locations and links to their operators |
| Transport | Stops, walking directions and access to Burgasbus information |

## Features

- **Interactive map:** browse by category, search for places, and explore the area after moving the map.
- **In-app directions:** follow a walking route with an updating location marker.
- **Community reviews:** star ratings, comments, photos and toilet amenity observations.
- **Profiles:** profile pictures, public contributions and links to reviewers' profiles.
- **Favourites:** save places across the app's categories and revisit them from your profile or the favourites tab.
- **Shared contributions:** registered users can add places, while administrators manage listings and moderate contributions.
- **Place details:** opening hours, addresses, websites and available contact information.
- **Event experience:** a themed welcome page, launch animation and preparation checklist.

Google reviews appear through Google's official Places UI Kit component inside the app. Google ratings and community ratings are displayed separately.

Transport supports a Burgasbus feed integration; live bus positions require provider access and a configured feed server.

## Technology

- **SwiftUI** for the native iPhone interface.
- **MapKit and Core Location** for maps, place discovery, location and routes.
- **Supabase** for shared accounts, profiles, places, reviews and favourites.
- **SQLite** for the on-device demonstration database.
- **WKWebView and Google Places UI Kit** for the Google reviews component.

The app targets **iOS 17 or later** and uses no third-party Swift packages.

## Run the app

1. Clone this repository and open [FindMyToilet.xcodeproj](FindMyToilet.xcodeproj) in Xcode with an iOS 17 or later SDK.
2. Select the **FindMyToilet** scheme and an iPhone simulator or connected iPhone.
3. For a physical iPhone, select your development team under **Signing & Capabilities**.
4. Press **Run** or **⌘R**.

The Xcode project and scheme retain the original **FindMyToilet** name; the app is displayed as **Eurovision Burgas 2027**.

Shared features use a configured Supabase backend. Connection instructions and database permissions are documented in [Backend setup](Backend/SETUP.md). Feature-specific database scripts and guides are in [Backend](Backend).

## Project structure

| Folder | Contents |
| --- | --- |
| [FindMyToilet](FindMyToilet) | Swift source, app assets and configuration |
| [FindMyToilet.xcodeproj](FindMyToilet.xcodeproj) | Xcode project and shared scheme |
| [FindMyToiletTests](FindMyToiletTests) | App regression tests |
| [Backend](Backend) | Supabase setup, feature migrations, source catalogues and transport integration |
| [Database](Database) | Local database schema |
| [GoogleReviewsWidget](GoogleReviewsWidget) | Hosted Google reviews component and its setup guide |
| [Design](Design) | App artwork generators |

See [Testing](TESTING.md) for verification notes and [the project plan](PLAN_BG.md) for the original diploma scope.
