import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Digital Menu'**
  String get appTitle;

  /// Label for cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Label for close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Label for OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Label for open settings button
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Title for the language selection dialog
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get selectLanguage;

  /// Option to use the device system language
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Label for sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Label for clear all button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Label for remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Name of Monday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMonday;

  /// Name of Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTuesday;

  /// Name of Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWednesday;

  /// Name of Thursday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThursday;

  /// Name of Friday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFriday;

  /// Name of Saturday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySaturday;

  /// Name of Sunday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySunday;

  /// Label for sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Welcome screen title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Digital Menu'**
  String get welcomeTitle;

  /// Subtitle on the sign in screen
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload menus and manage your restaurants'**
  String get signInSubtitle;

  /// Label for sign in with Google button
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {message}'**
  String signInFailed(String message);

  /// Label for continue without sign in button
  ///
  /// In en, this message translates to:
  /// **'Continue without signing in'**
  String get continueWithoutSignIn;

  /// Informational note on sign in screen for web platform
  ///
  /// In en, this message translates to:
  /// **'Note: You will be redirected to Google\'s sign-in page. You can browse restaurants without signing in. Sign in to access upload and management features.'**
  String get signInNoteWeb;

  /// Informational note on sign in screen for mobile platform
  ///
  /// In en, this message translates to:
  /// **'Note: You can browse restaurants without signing in. Sign in to access upload and management features.'**
  String get signInNoteMobile;

  /// Label for selecting a restaurant
  ///
  /// In en, this message translates to:
  /// **'Select Restaurant'**
  String get selectRestaurant;

  /// Message shown when no restaurants are found
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get noRestaurantsFound;

  /// Message shown when no restaurants match the active filters
  ///
  /// In en, this message translates to:
  /// **'No restaurants match filters'**
  String get noRestaurantsMatchFilters;

  /// Confirmation message after successful sign in
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully!'**
  String get signedInSuccessfully;

  /// Confirmation message after successful sign out
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully'**
  String get signedOutSuccessfully;

  /// Message shown when location services are disabled
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them.'**
  String get locationServicesDisabled;

  /// Message shown when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// Title of location permission required dialog
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionRequired;

  /// Body message of location permission required dialog
  ///
  /// In en, this message translates to:
  /// **'This app needs location permission to show nearby restaurants. Please enable location permission in your device settings.'**
  String get locationPermissionMessage;

  /// Confirmation that the current location is being used
  ///
  /// In en, this message translates to:
  /// **'Using your current location'**
  String get usingCurrentLocation;

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {message}'**
  String errorGettingLocation(String message);

  /// Validation message asking user to enter an address
  ///
  /// In en, this message translates to:
  /// **'Please enter an address'**
  String get pleaseEnterAddress;

  /// Confirmation that the location filter was applied
  ///
  /// In en, this message translates to:
  /// **'Location filter applied'**
  String get locationFilterApplied;

  /// Message shown when the entered address could not be found
  ///
  /// In en, this message translates to:
  /// **'Address not found. Try entering coordinates instead.'**
  String get addressNotFound;

  /// Message shown when geocoding returns no results
  ///
  /// In en, this message translates to:
  /// **'No addresses found. Try entering coordinates like: 52.520007, 13.404954'**
  String get noAddressesFound;

  /// No description provided for @geocodingError.
  ///
  /// In en, this message translates to:
  /// **'Geocoding error: {message}'**
  String geocodingError(String message);

  /// Message shown when geocoding fails
  ///
  /// In en, this message translates to:
  /// **'Geocoding Failed'**
  String get geocodingFailed;

  /// Instructions for entering coordinates
  ///
  /// In en, this message translates to:
  /// **'Please enter coordinates in format: latitude, longitude'**
  String get geocodingInstructions;

  /// Example of coordinate format
  ///
  /// In en, this message translates to:
  /// **'Example: 52.520007, 13.404954'**
  String get geocodingExample;

  /// Hint to use Google Maps to find coordinates
  ///
  /// In en, this message translates to:
  /// **'Or search for your address on Google Maps and copy the coordinates.'**
  String get geocodingMapsHint;

  /// Label for use current location button
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// Label for filter by location option
  ///
  /// In en, this message translates to:
  /// **'Filter by Location'**
  String get filterByLocation;

  /// Placeholder for address/coordinates input field
  ///
  /// In en, this message translates to:
  /// **'Enter address or coordinates'**
  String get enterAddressOrCoordinates;

  /// Label for radius input field
  ///
  /// In en, this message translates to:
  /// **'Radius: '**
  String get radius;

  /// Label for apply location filter button
  ///
  /// In en, this message translates to:
  /// **'Apply Location Filter'**
  String get applyLocationFilter;

  /// Badge shown when location filter is active
  ///
  /// In en, this message translates to:
  /// **'Location filter active'**
  String get locationFilterActive;

  /// Label for delivery only filter
  ///
  /// In en, this message translates to:
  /// **'Delivery Only'**
  String get deliveryOnly;

  /// Label for cuisine type filter
  ///
  /// In en, this message translates to:
  /// **'Cuisine Type'**
  String get cuisineType;

  /// Label for payment methods filter
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethodsFilter;

  /// Label for favorites only filter
  ///
  /// In en, this message translates to:
  /// **'Favorites Only'**
  String get favoritesOnly;

  /// Menu item to jump to favorites
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

  /// Label shown when no favorites are saved
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// Tooltip for adding to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// Tooltip for removing from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// Snackbar shown when guest tries to favorite
  ///
  /// In en, this message translates to:
  /// **'Sign in to save favorites'**
  String get signInToFavorite;

  /// Tooltip for the share button on a restaurant card
  ///
  /// In en, this message translates to:
  /// **'Share restaurant'**
  String get shareRestaurant;

  /// Snackbar shown after copying the share link
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard!'**
  String get linkCopied;

  /// Menu item label for generating a QR code
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get generateQrCode;

  /// Dialog title for the QR code
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCodeTitle;

  /// Button to download the QR code as PNG
  ///
  /// In en, this message translates to:
  /// **'Download PNG'**
  String get downloadQrCode;

  /// Label for the filters section
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @todayHours.
  ///
  /// In en, this message translates to:
  /// **'Today: {hours}'**
  String todayHours(String hours);

  /// Badge label indicating delivery is available
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryBadge;

  /// No description provided for @openingHoursDialog.
  ///
  /// In en, this message translates to:
  /// **'{restaurantName} - Opening Hours'**
  String openingHoursDialog(String restaurantName);

  /// Label for selecting a restaurant to edit
  ///
  /// In en, this message translates to:
  /// **'Select Restaurant to Edit'**
  String get selectRestaurantToEdit;

  /// Label for create menu manually option
  ///
  /// In en, this message translates to:
  /// **'Create Menu Manually'**
  String get createMenuManually;

  /// Label for create menu with AI option
  ///
  /// In en, this message translates to:
  /// **'Create Menu with AI'**
  String get createMenuWithAI;

  /// Label for edit restaurant button
  ///
  /// In en, this message translates to:
  /// **'Edit Restaurant'**
  String get editRestaurant;

  /// No description provided for @editRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Edit Restaurants ({count})'**
  String editRestaurants(int count);

  /// Label for manage subscription button
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// Label for reactivate subscription button
  ///
  /// In en, this message translates to:
  /// **'Reactivate Subscription'**
  String get reactivateSubscription;

  /// Label for upgrade to restaurant owner button
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Restaurant Owner'**
  String get upgradeToOwner;

  /// Label for restaurant owner role
  ///
  /// In en, this message translates to:
  /// **'Restaurant Owner'**
  String get restaurantOwnerLabel;

  /// Label for inactive restaurant owner role
  ///
  /// In en, this message translates to:
  /// **'Owner (inactive)'**
  String get ownerInactiveLabel;

  /// Label for free customer role
  ///
  /// In en, this message translates to:
  /// **'Free Customer'**
  String get freeCustomerLabel;

  /// Title of dialog shown when subscription is required
  ///
  /// In en, this message translates to:
  /// **'Restaurant Owner Plan Required'**
  String get subscriptionRequiredTitle;

  /// Body of dialog shown when subscription is required
  ///
  /// In en, this message translates to:
  /// **'Creating and managing menus requires an active Restaurant Owner subscription (€4.99/month).\n\nTap \"View Plans\" to upgrade your account.'**
  String get subscriptionRequiredMessage;

  /// Label for view plans button
  ///
  /// In en, this message translates to:
  /// **'View Plans'**
  String get viewPlans;

  /// No description provided for @errorLoadingMenu.
  ///
  /// In en, this message translates to:
  /// **'Error loading menu: {error}'**
  String errorLoadingMenu(String error);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(int count);

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart'**
  String addedToCart(String name);

  /// No description provided for @addedToCartWithVariant.
  ///
  /// In en, this message translates to:
  /// **'{name} ({variant}) added to cart'**
  String addedToCartWithVariant(String name, String variant);

  /// Label for address field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// Label for phone field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Text indicating delivery is available
  ///
  /// In en, this message translates to:
  /// **'Delivery available'**
  String get deliveryAvailable;

  /// Text indicating no delivery is available
  ///
  /// In en, this message translates to:
  /// **'No delivery'**
  String get noDelivery;

  /// Title for opening hours section
  ///
  /// In en, this message translates to:
  /// **'Opening Hours:'**
  String get openingHoursTitle;

  /// Title for payment methods section
  ///
  /// In en, this message translates to:
  /// **'Payment Methods:'**
  String get paymentMethodsTitle;

  /// Label indicating a restaurant is closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Title for the cart screen
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get yourCart;

  /// Message shown when the cart is empty
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// Label for total price in cart
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get total;

  /// Title of the order contact section in cart
  ///
  /// In en, this message translates to:
  /// **'Ready to order?'**
  String get orderSectionTitle;

  /// Subtitle of the order contact section in cart
  ///
  /// In en, this message translates to:
  /// **'Contact the restaurant to place your order:'**
  String get orderSectionSubtitle;

  /// Label for call to order button
  ///
  /// In en, this message translates to:
  /// **'Call to order'**
  String get callToOrder;

  /// Label for order by email button
  ///
  /// In en, this message translates to:
  /// **'Order by email'**
  String get emailToOrder;

  /// Subject line for order email
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get emailOrderSubject;

  /// Message shown when restaurant has no phone or email
  ///
  /// In en, this message translates to:
  /// **'No contact details available for this restaurant.'**
  String get noContactAvailable;

  /// Label for compare restaurants button
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compareRestaurants;

  /// Title of the cart comparison sheet
  ///
  /// In en, this message translates to:
  /// **'Cart Comparison'**
  String get compareTitle;

  /// Subtitle of the cart comparison sheet
  ///
  /// In en, this message translates to:
  /// **'Your selections across multiple restaurants'**
  String get compareSubtitle;

  /// Number of items in a compared cart
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String compareItemsCount(int count);

  /// Message shown when no menu items are found
  ///
  /// In en, this message translates to:
  /// **'No menu items found'**
  String get noMenuItemsFound;

  /// Label for view designed menu button
  ///
  /// In en, this message translates to:
  /// **'View designed menu'**
  String get viewDesignedMenu;

  /// Title for the my plan section
  ///
  /// In en, this message translates to:
  /// **'My Plan'**
  String get myPlan;

  /// Confirmation message when demo subscription is activated
  ///
  /// In en, this message translates to:
  /// **'Demo subscription activated for 30 days!'**
  String get demoActivated;

  /// Badge label for an active plan
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activePlanBadge;

  /// Badge label for an inactive plan
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactivePlanBadge;

  /// Badge label for the free plan
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePlanBadge;

  /// No description provided for @renewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String renewsOn(String date);

  /// Description encouraging user to upgrade to restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Restaurant Owner to create and manage your menus.'**
  String get upgradeDescription;

  /// Title of the restaurant owner subscription plan
  ///
  /// In en, this message translates to:
  /// **'Restaurant Owner Plan'**
  String get restaurantOwnerPlanTitle;

  /// Per month pricing suffix
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// Note that subscription can be cancelled anytime
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get cancelAnytime;

  /// Label for activate demo button
  ///
  /// In en, this message translates to:
  /// **'Activate Demo (30 days free)'**
  String get activateDemoButton;

  /// Warning message shown when subscription is inactive
  ///
  /// In en, this message translates to:
  /// **'Your subscription is currently inactive. Reactivate to create and manage menus.'**
  String get subscriptionInactiveWarning;

  /// Label for subscribe now button
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get subscribeNow;

  /// Feature description for restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Create menus manually'**
  String get featureCreateManually;

  /// Feature description for restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Upload PDF menus parsed by AI'**
  String get featureUploadPdf;

  /// Feature description for restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Edit restaurant profile'**
  String get featureEditProfile;

  /// Feature description for restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Manage menu items & categories'**
  String get featureManageItems;

  /// Feature description for restaurant owner plan
  ///
  /// In en, this message translates to:
  /// **'Appear in the restaurant list'**
  String get featureAppearInList;

  /// Message shown when Stripe customer portal is not configured
  ///
  /// In en, this message translates to:
  /// **'Stripe Customer Portal not configured yet. Contact support to manage your subscription.'**
  String get stripePortalNotConfigured;

  /// Title for the free customer account section
  ///
  /// In en, this message translates to:
  /// **'Free Customer Account'**
  String get freeCustomerAccountTitle;

  /// Feature description for free customer plan
  ///
  /// In en, this message translates to:
  /// **'Browse all restaurant menus'**
  String get featureBrowseMenus;

  /// Feature description for free customer plan
  ///
  /// In en, this message translates to:
  /// **'Save favourite restaurants'**
  String get featureSaveFavourites;

  /// Feature description for free customer plan
  ///
  /// In en, this message translates to:
  /// **'No credit card required'**
  String get featureNoCreditCard;

  /// Payment method: Cash
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// Payment method: Credit/Debit Card
  ///
  /// In en, this message translates to:
  /// **'Credit / Debit Card'**
  String get paymentMethodCard;

  /// Payment method: EC Card
  ///
  /// In en, this message translates to:
  /// **'EC Card'**
  String get paymentMethodEcKarte;

  /// Payment method: PayPal
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get paymentMethodPayPal;

  /// Payment method: Apple Pay
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get paymentMethodApplePay;

  /// Payment method: Google Pay
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get paymentMethodGooglePay;

  /// Payment method: Invoice
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get paymentMethodInvoice;

  /// Error shown when Supabase is not configured
  ///
  /// In en, this message translates to:
  /// **'Supabase not configured. Please check .env file.'**
  String get supabaseNotConfigured;

  /// No description provided for @errorLoadingRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Error loading restaurants: {error}'**
  String errorLoadingRestaurants(String error);

  /// Label for add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Label for save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for discard button
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Validation message for required fields
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Label for restaurant name field
  ///
  /// In en, this message translates to:
  /// **'Restaurant Name'**
  String get restaurantName;

  /// Label for required restaurant name field
  ///
  /// In en, this message translates to:
  /// **'Restaurant Name *'**
  String get restaurantNameAsterisk;

  /// Validation error for restaurant name field
  ///
  /// In en, this message translates to:
  /// **'Restaurant name is required'**
  String get restaurantNameRequiredError;

  /// Label for required address field
  ///
  /// In en, this message translates to:
  /// **'Address *'**
  String get addressAsterisk;

  /// Validation error for address field
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get addressRequiredError;

  /// Hint for cuisine type field
  ///
  /// In en, this message translates to:
  /// **'e.g., Italian, Chinese, Mexican'**
  String get cuisineTypeHint;

  /// Label for offers delivery switch
  ///
  /// In en, this message translates to:
  /// **'Offers Delivery'**
  String get offersDelivery;

  /// Section header for opening hours
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get openingHoursSection;

  /// Section header for payment methods
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethodsSection;

  /// Section header for restaurant photo
  ///
  /// In en, this message translates to:
  /// **'Restaurant Photo'**
  String get restaurantPhoto;

  /// Section header for restaurant information
  ///
  /// In en, this message translates to:
  /// **'Restaurant Information'**
  String get restaurantInformation;

  /// Section header for menu categories and items
  ///
  /// In en, this message translates to:
  /// **'Menu Categories & Items'**
  String get menuCategoriesAndItems;

  /// Label for auto-suggest image button
  ///
  /// In en, this message translates to:
  /// **'Auto-suggest'**
  String get autoSuggest;

  /// Label for browse Unsplash button
  ///
  /// In en, this message translates to:
  /// **'Browse Unsplash'**
  String get browseUnsplash;

  /// Label for save restaurant info button
  ///
  /// In en, this message translates to:
  /// **'Save Restaurant Info'**
  String get saveRestaurantInfoButton;

  /// Title and button label for create restaurant page
  ///
  /// In en, this message translates to:
  /// **'Create Restaurant'**
  String get createRestaurantTitle;

  /// Label for add category button
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategoryButton;

  /// Label for add item button
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItemButton;

  /// Label for go back button
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Title for add category dialog
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategoryDialogTitle;

  /// Label for category name field
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryNameLabel;

  /// Hint for category name field
  ///
  /// In en, this message translates to:
  /// **'e.g., Appetizers, Main Dishes'**
  String get categoryNameHint;

  /// No description provided for @addItemToCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item to {category}'**
  String addItemToCategoryTitle(String category);

  /// Label for item number field
  ///
  /// In en, this message translates to:
  /// **'Item Number'**
  String get itemNumberLabel;

  /// Helper text for item number field
  ///
  /// In en, this message translates to:
  /// **'e.g., 1, 2a, 3b'**
  String get itemNumberHelperText;

  /// Label for item name field
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemNameLabel;

  /// Label for price field
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// Label for description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// Title for edit category dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategoryDialogTitle;

  /// No description provided for @editItemDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit: {name}'**
  String editItemDialogTitle(String name);

  /// Title for delete category dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategoryDialogTitle;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\" and all its items?'**
  String deleteCategoryConfirm(String name);

  /// Title for delete item dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItemDialogTitle;

  /// No description provided for @deleteItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteItemConfirm(String name);

  /// Title for edit category name dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Category Name'**
  String get editCategoryNameDialogTitle;

  /// Title for edit menu item dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Menu Item'**
  String get editMenuItemDialogTitle;

  /// Label for restaurant info tab
  ///
  /// In en, this message translates to:
  /// **'Restaurant Info'**
  String get restaurantInfoTab;

  /// Label for menu tab
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTab;

  /// No description provided for @editRestaurantPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit: {name}'**
  String editRestaurantPageTitle(String name);

  /// Confirmation when category is added
  ///
  /// In en, this message translates to:
  /// **'Category added!'**
  String get categoryAdded;

  /// Confirmation when category is updated
  ///
  /// In en, this message translates to:
  /// **'Category updated!'**
  String get categoryUpdated;

  /// Confirmation when category is deleted
  ///
  /// In en, this message translates to:
  /// **'Category deleted!'**
  String get categoryDeleted;

  /// Confirmation when item is added
  ///
  /// In en, this message translates to:
  /// **'Item added!'**
  String get itemAdded;

  /// Confirmation when item is updated
  ///
  /// In en, this message translates to:
  /// **'Item updated!'**
  String get itemUpdated;

  /// Confirmation when item is deleted
  ///
  /// In en, this message translates to:
  /// **'Item deleted!'**
  String get itemDeleted;

  /// Confirmation when restaurant info is saved
  ///
  /// In en, this message translates to:
  /// **'Restaurant information updated!'**
  String get restaurantInfoSavedMessage;

  /// Confirmation when AI menu design is saved
  ///
  /// In en, this message translates to:
  /// **'AI menu design saved! Visitors can now view it.'**
  String get aiMenuDesignSavedMessage;

  /// No description provided for @errorLoadingMenuData.
  ///
  /// In en, this message translates to:
  /// **'Error loading menu data: {error}'**
  String errorLoadingMenuData(String error);

  /// No description provided for @errorSavingData.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String errorSavingData(String error);

  /// No description provided for @errorCreatingRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Error creating restaurant: {error}'**
  String errorCreatingRestaurant(String error);

  /// No description provided for @errorGeneral.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorGeneral(String error);

  /// Message when no categories exist in edit page
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Add one to get started!'**
  String get noCategoriesYetMessage;

  /// Message when no items exist in a category
  ///
  /// In en, this message translates to:
  /// **'No items in this category'**
  String get noItemsInCategory;

  /// Title on empty categories card
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesCardTitle;

  /// Hint on empty categories card
  ///
  /// In en, this message translates to:
  /// **'Add at least one category with items to create your menu'**
  String get noCategoriesCardHint;

  /// Title of access denied screen
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDeniedTitle;

  /// Message on access denied screen
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to edit this restaurant.'**
  String get accessDeniedMessage;

  /// Title of authentication required screen
  ///
  /// In en, this message translates to:
  /// **'Authentication Required'**
  String get authRequiredTitle;

  /// Message asking user to sign in to create a restaurant
  ///
  /// In en, this message translates to:
  /// **'Please sign in to create a restaurant'**
  String get pleaseSignInToCreate;

  /// Validation error when no category is added
  ///
  /// In en, this message translates to:
  /// **'Please add at least one category'**
  String get pleaseAddCategory;

  /// Validation error when no item is added
  ///
  /// In en, this message translates to:
  /// **'Please add at least one item to a category'**
  String get pleaseAddItem;

  /// Loading label while creating restaurant
  ///
  /// In en, this message translates to:
  /// **'Creating Restaurant...'**
  String get creatingRestaurant;

  /// No description provided for @restaurantCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Restaurant \"{name}\" created successfully!'**
  String restaurantCreatedMessage(String name);

  /// Info card text on create restaurant page
  ///
  /// In en, this message translates to:
  /// **'Create your restaurant menu from scratch. Add categories and items to build your complete menu.'**
  String get createRestaurantInfoText;

  /// Hint when no restaurant photo is selected (edit page)
  ///
  /// In en, this message translates to:
  /// **'No photo — tap \"Auto-suggest\" or \"Browse Unsplash\"'**
  String get noPhotoHint;

  /// Hint when no restaurant photo is selected (create page)
  ///
  /// In en, this message translates to:
  /// **'No photo yet — tap \"Auto-suggest\" or \"Browse Unsplash\"'**
  String get noPhotoYetHint;

  /// Title for AI menu design section
  ///
  /// In en, this message translates to:
  /// **'AI-Designed Menu'**
  String get aiMenuDesignTitle;

  /// Description when AI menu design is already saved
  ///
  /// In en, this message translates to:
  /// **'A design is saved. Generate a new one to replace it.'**
  String get aiMenuDesignSavedDescription;

  /// Description of AI menu design feature
  ///
  /// In en, this message translates to:
  /// **'Let Claude create a beautifully styled HTML menu. Preview it, then save — visitors will see a \"View Designed Menu\" button.'**
  String get aiMenuDesignDescription;

  /// Loading label while AI menu is generating
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generatingLabel;

  /// Label for regenerate design button
  ///
  /// In en, this message translates to:
  /// **'Regenerate Design'**
  String get regenerateDesign;

  /// Label for generate design button
  ///
  /// In en, this message translates to:
  /// **'Generate Design'**
  String get generateDesign;

  /// Label for view saved design button
  ///
  /// In en, this message translates to:
  /// **'View Saved'**
  String get viewSaved;

  /// Title for save AI menu dialog
  ///
  /// In en, this message translates to:
  /// **'Save AI Menu Design?'**
  String get saveAiMenuDialogTitle;

  /// Content of save AI menu dialog
  ///
  /// In en, this message translates to:
  /// **'The menu has opened in a new tab for preview.\n\nSave this design so all visitors see it as the \"Designed Menu\" button?'**
  String get saveAiMenuDialogContent;

  /// Message when no menu categories are loaded for AI generation
  ///
  /// In en, this message translates to:
  /// **'No menu categories loaded yet.'**
  String get noMenuCategoriesLoaded;

  /// Label when item price varies
  ///
  /// In en, this message translates to:
  /// **'Price varies'**
  String get priceVaries;

  /// Title for upload menu file page
  ///
  /// In en, this message translates to:
  /// **'Upload Menu File'**
  String get uploadMenuFileTitle;

  /// Shows when the menu was last updated
  ///
  /// In en, this message translates to:
  /// **'Menu updated: {date}'**
  String menuLastUpdated(String date);

  /// Deals tab label
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get dealsTab;

  /// Button to add a new deal
  ///
  /// In en, this message translates to:
  /// **'Add Deal'**
  String get addDeal;

  /// Dialog title when editing a deal
  ///
  /// In en, this message translates to:
  /// **'Edit Deal'**
  String get editDeal;

  /// Placeholder when no deals exist
  ///
  /// In en, this message translates to:
  /// **'No deals yet'**
  String get noDealYet;

  /// Label for deal title field
  ///
  /// In en, this message translates to:
  /// **'Deal title'**
  String get dealTitleLabel;

  /// Label for deal description field
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get dealDescriptionLabel;

  /// Label for discount type section
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get dealDiscountType;

  /// Percentage discount option
  ///
  /// In en, this message translates to:
  /// **'Percentage (%)'**
  String get discountPercentage;

  /// Fixed amount discount option
  ///
  /// In en, this message translates to:
  /// **'Fixed amount (€)'**
  String get discountFixedAmount;

  /// Label for discount value field
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get dealDiscountValue;

  /// Label for applies-to section
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get dealAppliesTo;

  /// Deal applies to all items
  ///
  /// In en, this message translates to:
  /// **'All items'**
  String get dealAll;

  /// Deal applies to specific categories
  ///
  /// In en, this message translates to:
  /// **'Specific categories'**
  String get dealSelectCategories;

  /// Deal applies to specific items
  ///
  /// In en, this message translates to:
  /// **'Specific items'**
  String get dealSelectItems;

  /// Label for day-of-week selection
  ///
  /// In en, this message translates to:
  /// **'Active on days (none = every day)'**
  String get dealActiveDays;

  /// Deal is active every day
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get dealEveryDay;

  /// Active toggle label for deal
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dealActive;

  /// Snackbar confirmation after saving deal
  ///
  /// In en, this message translates to:
  /// **'Deal saved'**
  String get dealSaved;

  /// Snackbar confirmation after deleting deal
  ///
  /// In en, this message translates to:
  /// **'Deal deleted'**
  String get dealDeleted;

  /// Confirmation dialog title for deal deletion
  ///
  /// In en, this message translates to:
  /// **'Delete this deal?'**
  String get deleteDealConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
