// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Digitale Speisekarte';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get ok => 'OK';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get selectLanguage => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemsprache';

  @override
  String get signOut => 'Abmelden';

  @override
  String get clearAll => 'Alles löschen';

  @override
  String get remove => 'Entfernen';

  @override
  String get dayMonday => 'Montag';

  @override
  String get dayTuesday => 'Dienstag';

  @override
  String get dayWednesday => 'Mittwoch';

  @override
  String get dayThursday => 'Donnerstag';

  @override
  String get dayFriday => 'Freitag';

  @override
  String get daySaturday => 'Samstag';

  @override
  String get daySunday => 'Sonntag';

  @override
  String get signIn => 'Anmelden';

  @override
  String get welcomeTitle => 'Willkommen bei Digital Menu';

  @override
  String get signInSubtitle =>
      'Melde dich an, um Speisekarten hochzuladen und deine Restaurants zu verwalten';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String signInFailed(String message) {
    return 'Anmeldung fehlgeschlagen: $message';
  }

  @override
  String get continueWithoutSignIn => 'Ohne Anmeldung fortfahren';

  @override
  String get signInNoteWeb =>
      'Hinweis: Du wirst auf die Google-Anmeldeseite weitergeleitet. Du kannst Restaurants auch ohne Anmeldung durchsuchen. Melde dich an, um auf Upload- und Verwaltungsfunktionen zuzugreifen.';

  @override
  String get signInNoteMobile =>
      'Hinweis: Du kannst Restaurants ohne Anmeldung durchsuchen. Melde dich an, um auf Upload- und Verwaltungsfunktionen zuzugreifen.';

  @override
  String get selectRestaurant => 'Restaurant auswählen';

  @override
  String get noRestaurantsFound => 'Keine Restaurants gefunden';

  @override
  String get noRestaurantsMatchFilters =>
      'Keine Restaurants entsprechen den Filtern';

  @override
  String get signedInSuccessfully => 'Erfolgreich angemeldet!';

  @override
  String get signedOutSuccessfully => 'Erfolgreich abgemeldet';

  @override
  String get locationServicesDisabled =>
      'Standortdienste sind deaktiviert. Bitte aktiviere sie.';

  @override
  String get locationPermissionDenied => 'Standortberechtigung verweigert';

  @override
  String get locationPermissionRequired => 'Standortberechtigung erforderlich';

  @override
  String get locationPermissionMessage =>
      'Diese App benötigt Standortberechtigung, um nahegelegene Restaurants anzuzeigen. Bitte aktiviere die Standortberechtigung in deinen Geräteeinstellungen.';

  @override
  String get usingCurrentLocation => 'Aktueller Standort wird verwendet';

  @override
  String errorGettingLocation(String message) {
    return 'Fehler beim Abrufen des Standorts: $message';
  }

  @override
  String get pleaseEnterAddress => 'Bitte gib eine Adresse ein';

  @override
  String get locationFilterApplied => 'Standortfilter angewendet';

  @override
  String get addressNotFound =>
      'Adresse nicht gefunden. Versuche stattdessen Koordinaten einzugeben.';

  @override
  String get noAddressesFound =>
      'Keine Adressen gefunden. Versuche Koordinaten wie: 52.520007, 13.404954';

  @override
  String geocodingError(String message) {
    return 'Geocoding-Fehler: $message';
  }

  @override
  String get geocodingFailed => 'Geocoding fehlgeschlagen';

  @override
  String get geocodingInstructions =>
      'Bitte gib Koordinaten im Format ein: Breitengrad, Längengrad';

  @override
  String get geocodingExample => 'Beispiel: 52.520007, 13.404954';

  @override
  String get geocodingMapsHint =>
      'Oder suche deine Adresse auf Google Maps und kopiere die Koordinaten.';

  @override
  String get useCurrentLocation => 'Aktuellen Standort verwenden';

  @override
  String get filterByLocation => 'Nach Standort filtern';

  @override
  String get enterAddressOrCoordinates => 'Adresse oder Koordinaten eingeben';

  @override
  String get radius => 'Radius: ';

  @override
  String get applyLocationFilter => 'Standortfilter anwenden';

  @override
  String get locationFilterActive => 'Standortfilter aktiv';

  @override
  String get deliveryOnly => 'Nur Lieferung';

  @override
  String get cuisineType => 'Küche';

  @override
  String get paymentMethodsFilter => 'Zahlungsmethoden';

  @override
  String get favoritesOnly => 'Nur Favoriten';

  @override
  String get myFavorites => 'Meine Favoriten';

  @override
  String get noFavoritesYet => 'Noch keine Favoriten';

  @override
  String get addToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get signInToFavorite => 'Anmelden, um Favoriten zu speichern';

  @override
  String get shareRestaurant => 'Restaurant teilen';

  @override
  String get linkCopied => 'Link in die Zwischenablage kopiert!';

  @override
  String get generateQrCode => 'QR-Code erstellen';

  @override
  String get qrCodeTitle => 'QR-Code';

  @override
  String get downloadQrCode => 'PNG herunterladen';

  @override
  String get filters => 'Filter';

  @override
  String todayHours(String hours) {
    return 'Heute: $hours';
  }

  @override
  String get deliveryBadge => 'Lieferung';

  @override
  String openingHoursDialog(String restaurantName) {
    return '$restaurantName - Öffnungszeiten';
  }

  @override
  String get selectRestaurantToEdit => 'Restaurant zum Bearbeiten auswählen';

  @override
  String get createMenuManually => 'Speisekarte manuell erstellen';

  @override
  String get createMenuWithAI => 'Speisekarte mit KI erstellen';

  @override
  String get editRestaurant => 'Restaurant bearbeiten';

  @override
  String editRestaurants(int count) {
    return 'Restaurants bearbeiten ($count)';
  }

  @override
  String get manageSubscription => 'Abo verwalten';

  @override
  String get reactivateSubscription => 'Abo reaktivieren';

  @override
  String get upgradeToOwner => 'Zum Restaurant-Inhaber upgraden';

  @override
  String get restaurantOwnerLabel => 'Restaurant-Inhaber';

  @override
  String get ownerInactiveLabel => 'Inhaber (inaktiv)';

  @override
  String get freeCustomerLabel => 'Kostenloser Nutzer';

  @override
  String get subscriptionRequiredTitle =>
      'Restaurant-Inhaber-Plan erforderlich';

  @override
  String get subscriptionRequiredMessage =>
      'Das Erstellen und Verwalten von Speisekarten erfordert ein aktives Restaurant-Inhaber-Abonnement (€4,99/Monat).\n\nTippe auf \"Pläne ansehen\", um dein Konto zu upgraden.';

  @override
  String get viewPlans => 'Pläne ansehen';

  @override
  String errorLoadingMenu(String error) {
    return 'Fehler beim Laden der Speisekarte: $error';
  }

  @override
  String itemCount(int count) {
    return '$count Artikel';
  }

  @override
  String addedToCart(String name) {
    return '$name zum Warenkorb hinzugefügt';
  }

  @override
  String addedToCartWithVariant(String name, String variant) {
    return '$name ($variant) zum Warenkorb hinzugefügt';
  }

  @override
  String get addressLabel => 'Adresse';

  @override
  String get phoneLabel => 'Telefon';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get deliveryAvailable => 'Lieferung verfügbar';

  @override
  String get noDelivery => 'Keine Lieferung';

  @override
  String get openingHoursTitle => 'Öffnungszeiten:';

  @override
  String get paymentMethodsTitle => 'Zahlungsmethoden:';

  @override
  String get closed => 'Geschlossen';

  @override
  String get yourCart => 'Dein Warenkorb';

  @override
  String get cartEmpty => 'Dein Warenkorb ist leer';

  @override
  String get total => 'Gesamt:';

  @override
  String get orderSectionTitle => 'Bereit zum Bestellen?';

  @override
  String get orderSectionSubtitle =>
      'Kontaktiere das Restaurant, um deine Bestellung aufzugeben:';

  @override
  String get callToOrder => 'Anrufen und bestellen';

  @override
  String get emailToOrder => 'Per E-Mail bestellen';

  @override
  String get emailOrderSubject => 'Bestellung';

  @override
  String get noContactAvailable =>
      'Keine Kontaktdaten für dieses Restaurant hinterlegt.';

  @override
  String get compareRestaurants => 'Vergleichen';

  @override
  String get compareTitle => 'Warenkorb-Vergleich';

  @override
  String get compareSubtitle => 'Deine Auswahl aus mehreren Restaurants';

  @override
  String compareItemsCount(int count) {
    return '$count Artikel';
  }

  @override
  String get noMenuItemsFound => 'Keine Menüeinträge gefunden';

  @override
  String get viewDesignedMenu => 'Gestaltete Speisekarte anzeigen';

  @override
  String get myPlan => 'Mein Plan';

  @override
  String get demoActivated => 'Demo-Abonnement für 30 Tage aktiviert!';

  @override
  String get activePlanBadge => 'Aktiv';

  @override
  String get inactivePlanBadge => 'Inaktiv';

  @override
  String get freePlanBadge => 'Kostenlos';

  @override
  String renewsOn(String date) {
    return 'Verlängert sich am $date';
  }

  @override
  String get upgradeDescription =>
      'Wechsle zum Restaurant-Inhaber, um Speisekarten zu erstellen und zu verwalten.';

  @override
  String get restaurantOwnerPlanTitle => 'Restaurant-Inhaber-Plan';

  @override
  String get perMonth => '/Monat';

  @override
  String get cancelAnytime => 'Jederzeit kündbar';

  @override
  String get activateDemoButton => 'Demo aktivieren (30 Tage kostenlos)';

  @override
  String get subscriptionInactiveWarning =>
      'Dein Abonnement ist derzeit inaktiv. Reaktiviere es, um Speisekarten zu erstellen und zu verwalten.';

  @override
  String get subscribeNow => 'Jetzt abonnieren';

  @override
  String get featureCreateManually => 'Speisekarten manuell erstellen';

  @override
  String get featureUploadPdf => 'PDF-Speisekarten per KI hochladen';

  @override
  String get featureEditProfile => 'Restaurant-Profil bearbeiten';

  @override
  String get featureManageItems => 'Menüeinträge & Kategorien verwalten';

  @override
  String get featureAppearInList => 'In der Restaurantliste erscheinen';

  @override
  String get stripePortalNotConfigured =>
      'Stripe-Kundenportal noch nicht konfiguriert. Kontaktiere den Support, um dein Abonnement zu verwalten.';

  @override
  String get freeCustomerAccountTitle => 'Kostenloses Kundenkonto';

  @override
  String get featureBrowseMenus => 'Alle Restaurant-Speisekarten durchsuchen';

  @override
  String get featureSaveFavourites => 'Lieblingsrestaurants speichern';

  @override
  String get featureNoCreditCard => 'Keine Kreditkarte erforderlich';

  @override
  String get paymentMethodCash => 'Bargeld';

  @override
  String get paymentMethodCard => 'Kredit-/Debitkarte';

  @override
  String get paymentMethodEcKarte => 'EC-Karte';

  @override
  String get paymentMethodPayPal => 'PayPal';

  @override
  String get paymentMethodApplePay => 'Apple Pay';

  @override
  String get paymentMethodGooglePay => 'Google Pay';

  @override
  String get paymentMethodInvoice => 'Rechnung';

  @override
  String get supabaseNotConfigured =>
      'Supabase nicht konfiguriert. Bitte .env-Datei prüfen.';

  @override
  String errorLoadingRestaurants(String error) {
    return 'Fehler beim Laden der Restaurants: $error';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get restaurantName => 'Restaurantname';

  @override
  String get restaurantNameAsterisk => 'Restaurantname *';

  @override
  String get restaurantNameRequiredError => 'Restaurantname ist erforderlich';

  @override
  String get addressAsterisk => 'Adresse *';

  @override
  String get addressRequiredError => 'Adresse ist erforderlich';

  @override
  String get cuisineTypeHint => 'z.B. Italienisch, Chinesisch, Mexikanisch';

  @override
  String get offersDelivery => 'Lieferung anbieten';

  @override
  String get openingHoursSection => 'Öffnungszeiten';

  @override
  String get paymentMethodsSection => 'Zahlungsmethoden';

  @override
  String get restaurantPhoto => 'Restaurantfoto';

  @override
  String get restaurantInformation => 'Restaurantinformationen';

  @override
  String get menuCategoriesAndItems => 'Menükategorien & Artikel';

  @override
  String get autoSuggest => 'Automatisch vorschlagen';

  @override
  String get browseUnsplash => 'Unsplash durchsuchen';

  @override
  String get saveRestaurantInfoButton => 'Restaurantinfo speichern';

  @override
  String get createRestaurantTitle => 'Restaurant erstellen';

  @override
  String get addCategoryButton => 'Kategorie hinzufügen';

  @override
  String get addItemButton => 'Artikel hinzufügen';

  @override
  String get goBack => 'Zurück';

  @override
  String get addCategoryDialogTitle => 'Kategorie hinzufügen';

  @override
  String get categoryNameLabel => 'Kategoriename';

  @override
  String get categoryNameHint => 'z.B. Vorspeisen, Hauptgerichte';

  @override
  String addItemToCategoryTitle(String category) {
    return 'Artikel zu $category hinzufügen';
  }

  @override
  String get itemNumberLabel => 'Artikelnummer';

  @override
  String get itemNumberHelperText => 'z.B. 1, 2a, 3b';

  @override
  String get itemNameLabel => 'Artikelname';

  @override
  String get priceLabel => 'Preis';

  @override
  String get descriptionLabel => 'Beschreibung';

  @override
  String get editCategoryDialogTitle => 'Kategorie bearbeiten';

  @override
  String editItemDialogTitle(String name) {
    return 'Bearbeiten: $name';
  }

  @override
  String get deleteCategoryDialogTitle => 'Kategorie löschen';

  @override
  String deleteCategoryConfirm(String name) {
    return 'Möchtest du \"$name\" und alle Artikel wirklich löschen?';
  }

  @override
  String get deleteItemDialogTitle => 'Artikel löschen';

  @override
  String deleteItemConfirm(String name) {
    return 'Möchtest du \"$name\" wirklich löschen?';
  }

  @override
  String get editCategoryNameDialogTitle => 'Kategorienamen bearbeiten';

  @override
  String get editMenuItemDialogTitle => 'Menüartikel bearbeiten';

  @override
  String get restaurantInfoTab => 'Restaurantinfo';

  @override
  String get menuTab => 'Speisekarte';

  @override
  String editRestaurantPageTitle(String name) {
    return 'Bearbeiten: $name';
  }

  @override
  String get categoryAdded => 'Kategorie hinzugefügt!';

  @override
  String get categoryUpdated => 'Kategorie aktualisiert!';

  @override
  String get categoryDeleted => 'Kategorie gelöscht!';

  @override
  String get itemAdded => 'Artikel hinzugefügt!';

  @override
  String get itemUpdated => 'Artikel aktualisiert!';

  @override
  String get itemDeleted => 'Artikel gelöscht!';

  @override
  String get restaurantInfoSavedMessage =>
      'Restaurantinformationen aktualisiert!';

  @override
  String get aiMenuDesignSavedMessage =>
      'KI-Menüdesign gespeichert! Besucher können es jetzt ansehen.';

  @override
  String errorLoadingMenuData(String error) {
    return 'Fehler beim Laden der Menüdaten: $error';
  }

  @override
  String errorSavingData(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String errorCreatingRestaurant(String error) {
    return 'Fehler beim Erstellen des Restaurants: $error';
  }

  @override
  String errorGeneral(String error) {
    return 'Fehler: $error';
  }

  @override
  String get noCategoriesYetMessage =>
      'Noch keine Kategorien. Füge eine hinzu!';

  @override
  String get noItemsInCategory => 'Keine Artikel in dieser Kategorie';

  @override
  String get noCategoriesCardTitle => 'Noch keine Kategorien';

  @override
  String get noCategoriesCardHint =>
      'Füge mindestens eine Kategorie mit Artikeln hinzu';

  @override
  String get accessDeniedTitle => 'Zugriff verweigert';

  @override
  String get accessDeniedMessage =>
      'Du hast keine Berechtigung, dieses Restaurant zu bearbeiten.';

  @override
  String get authRequiredTitle => 'Authentifizierung erforderlich';

  @override
  String get pleaseSignInToCreate =>
      'Bitte melde dich an, um ein Restaurant zu erstellen';

  @override
  String get pleaseAddCategory => 'Bitte mindestens eine Kategorie hinzufügen';

  @override
  String get pleaseAddItem =>
      'Bitte mindestens einen Artikel zu einer Kategorie hinzufügen';

  @override
  String get creatingRestaurant => 'Restaurant wird erstellt...';

  @override
  String restaurantCreatedMessage(String name) {
    return 'Restaurant \"$name\" erfolgreich erstellt!';
  }

  @override
  String get createRestaurantInfoText =>
      'Erstelle dein Restaurant-Menü von Grund auf. Füge Kategorien und Artikel hinzu, um dein vollständiges Menü aufzubauen.';

  @override
  String get noPhotoHint =>
      'Kein Foto – tippe auf \"Automatisch vorschlagen\" oder \"Unsplash durchsuchen\"';

  @override
  String get noPhotoYetHint =>
      'Noch kein Foto – tippe auf \"Automatisch vorschlagen\" oder \"Unsplash durchsuchen\"';

  @override
  String get aiMenuDesignTitle => 'KI-gestaltete Speisekarte';

  @override
  String get aiMenuDesignSavedDescription =>
      'Ein Design ist gespeichert. Erstelle ein neues, um es zu ersetzen.';

  @override
  String get aiMenuDesignDescription =>
      'Lass Claude eine stilvoll gestaltete HTML-Speisekarte erstellen. Vorschau ansehen, dann speichern – Besucher sehen einen \"Gestaltete Speisekarte anzeigen\"-Button.';

  @override
  String get generatingLabel => 'Wird erstellt…';

  @override
  String get regenerateDesign => 'Design neu erstellen';

  @override
  String get generateDesign => 'Design erstellen';

  @override
  String get viewSaved => 'Gespeichertes anzeigen';

  @override
  String get saveAiMenuDialogTitle => 'KI-Menüdesign speichern?';

  @override
  String get saveAiMenuDialogContent =>
      'Das Menü wurde zur Vorschau in einem neuen Tab geöffnet.\n\nDesign speichern, damit alle Besucher es als \"Gestaltete Speisekarte\"-Button sehen?';

  @override
  String get noMenuCategoriesLoaded => 'Noch keine Menükategorien geladen.';

  @override
  String get priceVaries => 'Preis variiert';

  @override
  String get uploadMenuFileTitle => 'Menüdatei hochladen';

  @override
  String menuLastUpdated(String date) {
    return 'Speisekarte aktualisiert: $date';
  }

  @override
  String get dealsTab => 'Angebote';

  @override
  String get addDeal => 'Angebot hinzufügen';

  @override
  String get editDeal => 'Angebot bearbeiten';

  @override
  String get noDealYet => 'Noch keine Angebote';

  @override
  String get dealTitleLabel => 'Bezeichnung';

  @override
  String get dealDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get dealDiscountType => 'Rabattart';

  @override
  String get discountPercentage => 'Prozent (%)';

  @override
  String get discountFixedAmount => 'Fixer Betrag (€)';

  @override
  String get dealDiscountValue => 'Wert';

  @override
  String get dealAppliesTo => 'Gilt für';

  @override
  String get dealAll => 'Alle Artikel';

  @override
  String get dealSelectCategories => 'Bestimmte Kategorien';

  @override
  String get dealSelectItems => 'Bestimmte Artikel';

  @override
  String get dealActiveDays => 'Aktiv an Tagen (keine = jeden Tag)';

  @override
  String get dealEveryDay => 'Jeden Tag';

  @override
  String get dealActive => 'Aktiv';

  @override
  String get dealSaved => 'Angebot gespeichert';

  @override
  String get dealDeleted => 'Angebot gelöscht';

  @override
  String get deleteDealConfirm => 'Dieses Angebot löschen?';
}
