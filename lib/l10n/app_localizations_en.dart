// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Digital Menu';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get selectLanguage => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get signOut => 'Sign Out';

  @override
  String get clearAll => 'Clear All';

  @override
  String get remove => 'Remove';

  @override
  String get dayMonday => 'Monday';

  @override
  String get dayTuesday => 'Tuesday';

  @override
  String get dayWednesday => 'Wednesday';

  @override
  String get dayThursday => 'Thursday';

  @override
  String get dayFriday => 'Friday';

  @override
  String get daySaturday => 'Saturday';

  @override
  String get daySunday => 'Sunday';

  @override
  String get signIn => 'Sign In';

  @override
  String get welcomeTitle => 'Welcome to Digital Menu';

  @override
  String get signInSubtitle =>
      'Sign in to upload menus and manage your restaurants';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String signInFailed(String message) {
    return 'Sign-in failed: $message';
  }

  @override
  String get continueWithoutSignIn => 'Continue without signing in';

  @override
  String get signInNoteWeb =>
      'Note: You will be redirected to Google\'s sign-in page. You can browse restaurants without signing in. Sign in to access upload and management features.';

  @override
  String get signInNoteMobile =>
      'Note: You can browse restaurants without signing in. Sign in to access upload and management features.';

  @override
  String get selectRestaurant => 'Select Restaurant';

  @override
  String get noRestaurantsFound => 'No restaurants found';

  @override
  String get noRestaurantsMatchFilters => 'No restaurants match filters';

  @override
  String get signedInSuccessfully => 'Signed in successfully!';

  @override
  String get signedOutSuccessfully => 'Signed out successfully';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. Please enable them.';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionRequired => 'Location Permission Required';

  @override
  String get locationPermissionMessage =>
      'This app needs location permission to show nearby restaurants. Please enable location permission in your device settings.';

  @override
  String get usingCurrentLocation => 'Using your current location';

  @override
  String errorGettingLocation(String message) {
    return 'Error getting location: $message';
  }

  @override
  String get pleaseEnterAddress => 'Please enter an address';

  @override
  String get locationFilterApplied => 'Location filter applied';

  @override
  String get addressNotFound =>
      'Address not found. Try entering coordinates instead.';

  @override
  String get noAddressesFound =>
      'No addresses found. Try entering coordinates like: 52.520007, 13.404954';

  @override
  String geocodingError(String message) {
    return 'Geocoding error: $message';
  }

  @override
  String get geocodingFailed => 'Geocoding Failed';

  @override
  String get geocodingInstructions =>
      'Please enter coordinates in format: latitude, longitude';

  @override
  String get geocodingExample => 'Example: 52.520007, 13.404954';

  @override
  String get geocodingMapsHint =>
      'Or search for your address on Google Maps and copy the coordinates.';

  @override
  String get useCurrentLocation => 'Use current location';

  @override
  String get filterByLocation => 'Filter by Location';

  @override
  String get enterAddressOrCoordinates => 'Enter address or coordinates';

  @override
  String get radius => 'Radius: ';

  @override
  String get applyLocationFilter => 'Apply Location Filter';

  @override
  String get locationFilterActive => 'Location filter active';

  @override
  String get deliveryOnly => 'Delivery Only';

  @override
  String get cuisineType => 'Cuisine Type';

  @override
  String get paymentMethodsFilter => 'Payment Methods';

  @override
  String get favoritesOnly => 'Favorites Only';

  @override
  String get myFavorites => 'My Favorites';

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get signInToFavorite => 'Sign in to save favorites';

  @override
  String get shareRestaurant => 'Share restaurant';

  @override
  String get linkCopied => 'Link copied to clipboard!';

  @override
  String get generateQrCode => 'Generate QR Code';

  @override
  String get qrCodeTitle => 'QR Code';

  @override
  String get downloadQrCode => 'Download PNG';

  @override
  String get filters => 'Filters';

  @override
  String todayHours(String hours) {
    return 'Today: $hours';
  }

  @override
  String get deliveryBadge => 'Delivery';

  @override
  String openingHoursDialog(String restaurantName) {
    return '$restaurantName - Opening Hours';
  }

  @override
  String get selectRestaurantToEdit => 'Select Restaurant to Edit';

  @override
  String get createMenuManually => 'Create Menu Manually';

  @override
  String get createMenuWithAI => 'Create Menu with AI';

  @override
  String get editRestaurant => 'Edit Restaurant';

  @override
  String editRestaurants(int count) {
    return 'Edit Restaurants ($count)';
  }

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get reactivateSubscription => 'Reactivate Subscription';

  @override
  String get upgradeToOwner => 'Upgrade to Restaurant Owner';

  @override
  String get restaurantOwnerLabel => 'Restaurant Owner';

  @override
  String get ownerInactiveLabel => 'Owner (inactive)';

  @override
  String get freeCustomerLabel => 'Free Customer';

  @override
  String get subscriptionRequiredTitle => 'Restaurant Owner Plan Required';

  @override
  String get subscriptionRequiredMessage =>
      'Creating and managing menus requires an active Restaurant Owner subscription (€4.99/month).\n\nTap \"View Plans\" to upgrade your account.';

  @override
  String get viewPlans => 'View Plans';

  @override
  String errorLoadingMenu(String error) {
    return 'Error loading menu: $error';
  }

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String addedToCart(String name) {
    return '$name added to cart';
  }

  @override
  String addedToCartWithVariant(String name, String variant) {
    return '$name ($variant) added to cart';
  }

  @override
  String get addressLabel => 'Address';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get emailLabel => 'Email';

  @override
  String get deliveryAvailable => 'Delivery available';

  @override
  String get noDelivery => 'No delivery';

  @override
  String get openingHoursTitle => 'Opening Hours:';

  @override
  String get paymentMethodsTitle => 'Payment Methods:';

  @override
  String get closed => 'Closed';

  @override
  String get yourCart => 'Your Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get total => 'Total:';

  @override
  String get orderSectionTitle => 'Ready to order?';

  @override
  String get orderSectionSubtitle =>
      'Contact the restaurant to place your order:';

  @override
  String get callToOrder => 'Call to order';

  @override
  String get emailToOrder => 'Order by email';

  @override
  String get emailOrderSubject => 'Order';

  @override
  String get noContactAvailable =>
      'No contact details available for this restaurant.';

  @override
  String get compareRestaurants => 'Compare';

  @override
  String get compareTitle => 'Cart Comparison';

  @override
  String get compareSubtitle => 'Your selections across multiple restaurants';

  @override
  String compareItemsCount(int count) {
    return '$count items';
  }

  @override
  String get noMenuItemsFound => 'No menu items found';

  @override
  String get viewDesignedMenu => 'View designed menu';

  @override
  String get myPlan => 'My Plan';

  @override
  String get demoActivated => 'Demo subscription activated for 30 days!';

  @override
  String get activePlanBadge => 'Active';

  @override
  String get inactivePlanBadge => 'Inactive';

  @override
  String get freePlanBadge => 'Free';

  @override
  String renewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String get upgradeDescription =>
      'Upgrade to Restaurant Owner to create and manage your menus.';

  @override
  String get restaurantOwnerPlanTitle => 'Restaurant Owner Plan';

  @override
  String get perMonth => '/month';

  @override
  String get cancelAnytime => 'Cancel anytime';

  @override
  String get activateDemoButton => 'Activate Demo (30 days free)';

  @override
  String get subscriptionInactiveWarning =>
      'Your subscription is currently inactive. Reactivate to create and manage menus.';

  @override
  String get subscribeNow => 'Subscribe Now';

  @override
  String get featureCreateManually => 'Create menus manually';

  @override
  String get featureUploadPdf => 'Upload PDF menus parsed by AI';

  @override
  String get featureEditProfile => 'Edit restaurant profile';

  @override
  String get featureManageItems => 'Manage menu items & categories';

  @override
  String get featureAppearInList => 'Appear in the restaurant list';

  @override
  String get stripePortalNotConfigured =>
      'Stripe Customer Portal not configured yet. Contact support to manage your subscription.';

  @override
  String get freeCustomerAccountTitle => 'Free Customer Account';

  @override
  String get featureBrowseMenus => 'Browse all restaurant menus';

  @override
  String get featureSaveFavourites => 'Save favourite restaurants';

  @override
  String get featureNoCreditCard => 'No credit card required';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCard => 'Credit / Debit Card';

  @override
  String get paymentMethodEcKarte => 'EC Card';

  @override
  String get paymentMethodPayPal => 'PayPal';

  @override
  String get paymentMethodApplePay => 'Apple Pay';

  @override
  String get paymentMethodGooglePay => 'Google Pay';

  @override
  String get paymentMethodInvoice => 'Invoice';

  @override
  String get supabaseNotConfigured =>
      'Supabase not configured. Please check .env file.';

  @override
  String errorLoadingRestaurants(String error) {
    return 'Error loading restaurants: $error';
  }

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get discard => 'Discard';

  @override
  String get required => 'Required';

  @override
  String get restaurantName => 'Restaurant Name';

  @override
  String get restaurantNameAsterisk => 'Restaurant Name *';

  @override
  String get restaurantNameRequiredError => 'Restaurant name is required';

  @override
  String get addressAsterisk => 'Address *';

  @override
  String get addressRequiredError => 'Address is required';

  @override
  String get cuisineTypeHint => 'e.g., Italian, Chinese, Mexican';

  @override
  String get offersDelivery => 'Offers Delivery';

  @override
  String get openingHoursSection => 'Opening Hours';

  @override
  String get paymentMethodsSection => 'Payment Methods';

  @override
  String get restaurantPhoto => 'Restaurant Photo';

  @override
  String get restaurantInformation => 'Restaurant Information';

  @override
  String get menuCategoriesAndItems => 'Menu Categories & Items';

  @override
  String get autoSuggest => 'Auto-suggest';

  @override
  String get browseUnsplash => 'Browse Unsplash';

  @override
  String get saveRestaurantInfoButton => 'Save Restaurant Info';

  @override
  String get createRestaurantTitle => 'Create Restaurant';

  @override
  String get addCategoryButton => 'Add Category';

  @override
  String get addItemButton => 'Add Item';

  @override
  String get goBack => 'Go Back';

  @override
  String get addCategoryDialogTitle => 'Add Category';

  @override
  String get categoryNameLabel => 'Category Name';

  @override
  String get categoryNameHint => 'e.g., Appetizers, Main Dishes';

  @override
  String addItemToCategoryTitle(String category) {
    return 'Add Item to $category';
  }

  @override
  String get itemNumberLabel => 'Item Number';

  @override
  String get itemNumberHelperText => 'e.g., 1, 2a, 3b';

  @override
  String get itemNameLabel => 'Item Name';

  @override
  String get priceLabel => 'Price';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get editCategoryDialogTitle => 'Edit Category';

  @override
  String editItemDialogTitle(String name) {
    return 'Edit: $name';
  }

  @override
  String get deleteCategoryDialogTitle => 'Delete Category';

  @override
  String deleteCategoryConfirm(String name) {
    return 'Are you sure you want to delete \"$name\" and all its items?';
  }

  @override
  String get deleteItemDialogTitle => 'Delete Item';

  @override
  String deleteItemConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get editCategoryNameDialogTitle => 'Edit Category Name';

  @override
  String get editMenuItemDialogTitle => 'Edit Menu Item';

  @override
  String get restaurantInfoTab => 'Restaurant Info';

  @override
  String get menuTab => 'Menu';

  @override
  String editRestaurantPageTitle(String name) {
    return 'Edit: $name';
  }

  @override
  String get categoryAdded => 'Category added!';

  @override
  String get categoryUpdated => 'Category updated!';

  @override
  String get categoryDeleted => 'Category deleted!';

  @override
  String get itemAdded => 'Item added!';

  @override
  String get itemUpdated => 'Item updated!';

  @override
  String get itemDeleted => 'Item deleted!';

  @override
  String get restaurantInfoSavedMessage => 'Restaurant information updated!';

  @override
  String get aiMenuDesignSavedMessage =>
      'AI menu design saved! Visitors can now view it.';

  @override
  String errorLoadingMenuData(String error) {
    return 'Error loading menu data: $error';
  }

  @override
  String errorSavingData(String error) {
    return 'Error saving: $error';
  }

  @override
  String errorCreatingRestaurant(String error) {
    return 'Error creating restaurant: $error';
  }

  @override
  String errorGeneral(String error) {
    return 'Error: $error';
  }

  @override
  String get noCategoriesYetMessage =>
      'No categories yet. Add one to get started!';

  @override
  String get noItemsInCategory => 'No items in this category';

  @override
  String get noCategoriesCardTitle => 'No categories yet';

  @override
  String get noCategoriesCardHint =>
      'Add at least one category with items to create your menu';

  @override
  String get accessDeniedTitle => 'Access Denied';

  @override
  String get accessDeniedMessage =>
      'You do not have permission to edit this restaurant.';

  @override
  String get authRequiredTitle => 'Authentication Required';

  @override
  String get pleaseSignInToCreate => 'Please sign in to create a restaurant';

  @override
  String get pleaseAddCategory => 'Please add at least one category';

  @override
  String get pleaseAddItem => 'Please add at least one item to a category';

  @override
  String get creatingRestaurant => 'Creating Restaurant...';

  @override
  String restaurantCreatedMessage(String name) {
    return 'Restaurant \"$name\" created successfully!';
  }

  @override
  String get createRestaurantInfoText =>
      'Create your restaurant menu from scratch. Add categories and items to build your complete menu.';

  @override
  String get noPhotoHint =>
      'No photo — tap \"Auto-suggest\" or \"Browse Unsplash\"';

  @override
  String get noPhotoYetHint =>
      'No photo yet — tap \"Auto-suggest\" or \"Browse Unsplash\"';

  @override
  String get aiMenuDesignTitle => 'AI-Designed Menu';

  @override
  String get aiMenuDesignSavedDescription =>
      'A design is saved. Generate a new one to replace it.';

  @override
  String get aiMenuDesignDescription =>
      'Let Claude create a beautifully styled HTML menu. Preview it, then save — visitors will see a \"View Designed Menu\" button.';

  @override
  String get generatingLabel => 'Generating…';

  @override
  String get regenerateDesign => 'Regenerate Design';

  @override
  String get generateDesign => 'Generate Design';

  @override
  String get viewSaved => 'View Saved';

  @override
  String get saveAiMenuDialogTitle => 'Save AI Menu Design?';

  @override
  String get saveAiMenuDialogContent =>
      'The menu has opened in a new tab for preview.\n\nSave this design so all visitors see it as the \"Designed Menu\" button?';

  @override
  String get noMenuCategoriesLoaded => 'No menu categories loaded yet.';

  @override
  String get priceVaries => 'Price varies';

  @override
  String get uploadMenuFileTitle => 'Upload Menu File';

  @override
  String menuLastUpdated(String date) {
    return 'Menu updated: $date';
  }

  @override
  String get dealsTab => 'Deals';

  @override
  String get addDeal => 'Add Deal';

  @override
  String get editDeal => 'Edit Deal';

  @override
  String get noDealYet => 'No deals yet';

  @override
  String get dealTitleLabel => 'Deal title';

  @override
  String get dealDescriptionLabel => 'Description (optional)';

  @override
  String get dealDiscountType => 'Discount type';

  @override
  String get discountPercentage => 'Percentage (%)';

  @override
  String get discountFixedAmount => 'Fixed amount (€)';

  @override
  String get dealDiscountValue => 'Value';

  @override
  String get dealAppliesTo => 'Applies to';

  @override
  String get dealAll => 'All items';

  @override
  String get dealSelectCategories => 'Specific categories';

  @override
  String get dealSelectItems => 'Specific items';

  @override
  String get dealActiveDays => 'Active on days (none = every day)';

  @override
  String get dealEveryDay => 'Every day';

  @override
  String get dealActive => 'Active';

  @override
  String get dealSaved => 'Deal saved';

  @override
  String get dealDeleted => 'Deal deleted';

  @override
  String get deleteDealConfirm => 'Delete this deal?';
}
