// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'சுற்றுலா பாதுகாப்பு செயலி';

  @override
  String get appNameShort => 'ட்ரிப் சென்ட்ரி';

  @override
  String get menuRefresh => 'புதுப்பிக்க';

  @override
  String get menuClearData => 'தரவு அழிக்க';

  @override
  String get menuLogout => 'வெளியேறு';

  @override
  String get menuClearDataConfirmTitle => 'சுற்றுலா தரவை அழிக்கவும்';

  @override
  String get menuClearDataConfirmBody =>
      'இது உங்கள் சுற்றுலா தரவையும் தொடர்புடைய அனைத்து தகவல்களையும் நிரந்தரமாக அழித்துவிடும். இந்த செயலை வாபஸ் பெற முடியாது.';

  @override
  String get cancel => 'ரத்து';

  @override
  String get delete => 'அழிக்க';

  @override
  String get permissionBannerNeedBg =>
      'தொடர்ச்சியான பாதுகாப்பு எச்சரிக்கைகளுக்கு பின்னணி இடத்தை அனுமதிக்கவும்.';

  @override
  String get permissionBannerNeedFg =>
      'பாதுகாப்பு கண்காணிப்பு மற்றும் எச்சரிக்கைகளை இயக்க இடம் அணுகலை அனுமதிக்கவும்.';

  @override
  String get permissionEnableBg => 'பின்னணி இயக்கவும்';

  @override
  String get permissionEnableFg => 'இடத்தை இயக்கவும்';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get snackGrantLocationFirst => 'முதலில் இடம் அனுமதியை வழங்குங்கள்.';

  @override
  String get snackEnableBackground =>
      'தொடர்ச்சியான பாதுகாப்பு கண்காணிப்புக்காக \'எப்போதும் அனுமதி\' ஐ இயக்கவும்.';

  @override
  String get snackBgNeeded => 'எச்சரிக்கைகளுக்கு பின்னணி இடம் தேவை.';

  @override
  String get snackFeatureComingSoon => 'இந்த அம்சம் விரைவில் வருகிறது!';

  @override
  String get snackNoMetadata =>
      'உங்கள் Tourist ID க்கு எந்த மெட்டாடேட்டாவும் கிடைக்கவில்லை.';

  @override
  String get dismiss => 'மூடு';

  @override
  String get error => 'பிழை';

  @override
  String get trackingActive => 'கண்காணிப்பு செயலில் (இடைநிறுத்த தட்டவும்)';

  @override
  String get trackingPaused =>
      'கண்காணிப்பு நிறுத்தப்பட்டுள்ளது (மீண்டும் தொடங்க தட்டவும்)';

  @override
  String get touristId => 'சுற்றுலா ஐடி';

  @override
  String get tokenId => 'டோக்கன் ஐடி:';

  @override
  String get validUntil => 'செல்லுபடியாகும் நாள்:';

  @override
  String get status => 'நிலை:';

  @override
  String get active => 'செயலில்';

  @override
  String get inactive => 'செயலிழந்தது';

  @override
  String get expired => 'காலாவதியானது';

  @override
  String get active_caps => 'செயலில்';

  @override
  String get viewId => 'ஐடி பார்க்க';

  @override
  String get noTouristIdBody =>
      'உங்களுக்கு இன்னும் செயல்பாட்டில் உள்ள Tourist ID இல்லை. பாதுகாப்பான மற்றும் சரிபார்க்கப்பட்ட பயண அனுபவத்திற்காக ஒன்றை உருவாக்குங்கள்.';

  @override
  String get createTouristId => 'சுற்றுலா ஐடி உருவாக்கவும்';

  @override
  String get quickActions => 'விரைவு செயல்கள்';

  @override
  String get qrCheckIn => 'QR செக்-இன்';

  @override
  String get emergency => 'அவசரம்';

  @override
  String get checkIn => 'செக்-இன்';

  @override
  String get geoLocation => 'புவிஇடம்';

  @override
  String get deleteExpiredTitle => 'காலாவதியான சுற்றுலா ஐடி அழிக்க';

  @override
  String get deleteExpiredBody =>
      'இது உங்கள் காலாவதியான சுற்றுலா ஐடியை ப்ளாக்செயினிலிருந்து நிரந்தரமாக அகற்றும். இதை மீட்டெடுக்க முடியாது.';

  @override
  String get deletedSuccessfully => 'சுற்றுலா ஐடி வெற்றிகரமாக அகற்றப்பட்டது';

  @override
  String get deleteFailed => 'சுற்றுலா ஐடி அகற்றம் தோல்வியடைந்தது';

  @override
  String get listening => 'கேட்கிறது…';

  @override
  String get noEmergencyNumber => 'அவசர தொடர்பு எண் எதுவும் கிடைக்கவில்லை';

  @override
  String get invalidEmergencyNumber => 'தவறான அவசர தொடர்பு எண்';

  @override
  String get unableToCall => 'இந்த சாதனத்தில் அழைப்பை தொடங்க முடியவில்லை';

  @override
  String failedToStartCall(Object error) {
    return 'அழைப்பைத் தொடங்க இயலவில்லை: $error';
  }

  @override
  String get language => 'மொழி';

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
