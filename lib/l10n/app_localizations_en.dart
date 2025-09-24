// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tourist Safety App';

  @override
  String get appNameShort => 'TripSentry';

  @override
  String get menuRefresh => 'Refresh';

  @override
  String get menuClearData => 'Clear Data';

  @override
  String get menuLogout => 'Logout';

  @override
  String get menuClearDataConfirmTitle => 'Clear Tourist Data';

  @override
  String get menuClearDataConfirmBody =>
      'This will permanently delete your tourist data and all associated information. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get permissionBannerNeedBg =>
      'Allow background location to enable continuous safety alerts.';

  @override
  String get permissionBannerNeedFg =>
      'Allow location access to enable safety tracking and alerts.';

  @override
  String get permissionEnableBg => 'Enable Background';

  @override
  String get permissionEnableFg => 'Enable Location';

  @override
  String get settings => 'Settings';

  @override
  String get snackGrantLocationFirst => 'Grant location permission first.';

  @override
  String get snackEnableBackground =>
      'Enable \"Allow all the time\" for continuous safety tracking.';

  @override
  String get snackBgNeeded => 'Background location needed for alerts.';

  @override
  String get snackFeatureComingSoon => 'This feature is coming soon!';

  @override
  String get snackNoMetadata => 'No metadata found for your Tourist ID.';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get error => 'Error';

  @override
  String get trackingActive => 'Tracking Active (tap to pause)';

  @override
  String get trackingPaused => 'Tracking Paused (tap to resume)';

  @override
  String get touristId => 'Tourist ID';

  @override
  String get tokenId => 'Token ID:';

  @override
  String get validUntil => 'Valid Until:';

  @override
  String get status => 'Status:';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get expired => 'EXPIRED';

  @override
  String get active_caps => 'ACTIVE';

  @override
  String get viewId => 'View ID';

  @override
  String get noTouristIdBody =>
      'You don\'t have an active Tourist ID yet. Create one to enjoy a secure and verified travel experience.';

  @override
  String get createTouristId => 'Create Tourist ID';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get qrCheckIn => 'QR Check-In';

  @override
  String get emergency => 'Emergency';

  @override
  String get checkIn => 'Check-In';

  @override
  String get geoLocation => 'Geo Location';

  @override
  String get deleteExpiredTitle => 'Delete Expired Tourist ID';

  @override
  String get deleteExpiredBody =>
      'This will permanently delete your expired Tourist ID from the blockchain. This action cannot be undone.';

  @override
  String get deletedSuccessfully => 'Tourist ID deleted successfully';

  @override
  String get deleteFailed => 'Failed to delete Tourist ID';

  @override
  String get listening => 'Listening…';

  @override
  String get noEmergencyNumber => 'No emergency contact number found';

  @override
  String get invalidEmergencyNumber => 'Invalid emergency contact number';

  @override
  String get unableToCall => 'Unable to initiate call on this device';

  @override
  String failedToStartCall(Object error) {
    return 'Failed to start call: $error';
  }

  @override
  String get language => 'Language';

  @override
  String get langEnglish => 'English';

  @override
  String get langHindi => 'हिंदी';

  @override
  String get langBengali => 'বাংলা';

  @override
  String get langTamil => 'தமிழ்';

  @override
  String get langTelugu => 'తెలుగు';

  @override
  String get langMalayalam => 'മലയാളം';
}
