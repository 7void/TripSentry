import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
    Locale('ml'),
    Locale('ta'),
    Locale('te')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tourist Safety App'**
  String get appTitle;

  /// No description provided for @appNameShort.
  ///
  /// In en, this message translates to:
  /// **'TripSentry'**
  String get appNameShort;

  /// No description provided for @menuRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get menuRefresh;

  /// No description provided for @menuClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear Data'**
  String get menuClearData;

  /// No description provided for @menuLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get menuLogout;

  /// No description provided for @menuClearDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Tourist Data'**
  String get menuClearDataConfirmTitle;

  /// No description provided for @menuClearDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your tourist data and all associated information. This action cannot be undone.'**
  String get menuClearDataConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @permissionBannerNeedBg.
  ///
  /// In en, this message translates to:
  /// **'Allow background location to enable continuous safety alerts.'**
  String get permissionBannerNeedBg;

  /// No description provided for @permissionBannerNeedFg.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to enable safety tracking and alerts.'**
  String get permissionBannerNeedFg;

  /// No description provided for @permissionEnableBg.
  ///
  /// In en, this message translates to:
  /// **'Enable Background'**
  String get permissionEnableBg;

  /// No description provided for @permissionEnableFg.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get permissionEnableFg;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @snackGrantLocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Grant location permission first.'**
  String get snackGrantLocationFirst;

  /// No description provided for @snackEnableBackground.
  ///
  /// In en, this message translates to:
  /// **'Enable \"Allow all the time\" for continuous safety tracking.'**
  String get snackEnableBackground;

  /// No description provided for @snackBgNeeded.
  ///
  /// In en, this message translates to:
  /// **'Background location needed for alerts.'**
  String get snackBgNeeded;

  /// No description provided for @snackFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon!'**
  String get snackFeatureComingSoon;

  /// No description provided for @snackNoMetadata.
  ///
  /// In en, this message translates to:
  /// **'No metadata found for your Tourist ID.'**
  String get snackNoMetadata;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @trackingActive.
  ///
  /// In en, this message translates to:
  /// **'Tracking Active (tap to pause)'**
  String get trackingActive;

  /// No description provided for @trackingPaused.
  ///
  /// In en, this message translates to:
  /// **'Tracking Paused (tap to resume)'**
  String get trackingPaused;

  /// No description provided for @touristId.
  ///
  /// In en, this message translates to:
  /// **'Tourist ID'**
  String get touristId;

  /// No description provided for @tokenId.
  ///
  /// In en, this message translates to:
  /// **'Token ID:'**
  String get tokenId;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid Until:'**
  String get validUntil;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get status;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get expired;

  /// No description provided for @active_caps.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active_caps;

  /// No description provided for @viewId.
  ///
  /// In en, this message translates to:
  /// **'View ID'**
  String get viewId;

  /// No description provided for @noTouristIdBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have an active Tourist ID yet. Create one to enjoy a secure and verified travel experience.'**
  String get noTouristIdBody;

  /// No description provided for @createTouristId.
  ///
  /// In en, this message translates to:
  /// **'Create Tourist ID'**
  String get createTouristId;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @qrCheckIn.
  ///
  /// In en, this message translates to:
  /// **'QR Check-In'**
  String get qrCheckIn;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check-In'**
  String get checkIn;

  /// No description provided for @geoLocation.
  ///
  /// In en, this message translates to:
  /// **'Geo Location'**
  String get geoLocation;

  /// No description provided for @deleteExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Expired Tourist ID'**
  String get deleteExpiredTitle;

  /// No description provided for @deleteExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your expired Tourist ID from the blockchain. This action cannot be undone.'**
  String get deleteExpiredBody;

  /// No description provided for @deletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Tourist ID deleted successfully'**
  String get deletedSuccessfully;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete Tourist ID'**
  String get deleteFailed;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @noEmergencyNumber.
  ///
  /// In en, this message translates to:
  /// **'No emergency contact number found'**
  String get noEmergencyNumber;

  /// No description provided for @invalidEmergencyNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid emergency contact number'**
  String get invalidEmergencyNumber;

  /// No description provided for @unableToCall.
  ///
  /// In en, this message translates to:
  /// **'Unable to initiate call on this device'**
  String get unableToCall;

  /// No description provided for @failedToStartCall.
  ///
  /// In en, this message translates to:
  /// **'Failed to start call: {error}'**
  String failedToStartCall(Object error);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get langHindi;

  /// No description provided for @langBengali.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get langBengali;

  /// No description provided for @langTamil.
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get langTamil;

  /// No description provided for @langTelugu.
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get langTelugu;

  /// No description provided for @langMalayalam.
  ///
  /// In en, this message translates to:
  /// **'മലയാളം'**
  String get langMalayalam;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'en',
        'hi',
        'ml',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
