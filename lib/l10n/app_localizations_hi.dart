// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'पर्यटक सुरक्षा ऐप';

  @override
  String get appNameShort => 'ट्रिपसेंट्री';

  @override
  String get menuRefresh => 'रीफ़्रेश';

  @override
  String get menuClearData => 'डेटा हटाएँ';

  @override
  String get menuLogout => 'लॉग आउट';

  @override
  String get menuClearDataConfirmTitle => 'पर्यटक डेटा साफ़ करें';

  @override
  String get menuClearDataConfirmBody =>
      'यह आपके पर्यटक डेटा और सभी संबंधित जानकारी को स्थायी रूप से हटा देगा। इसे वापस नहीं किया जा सकता।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get permissionBannerNeedBg =>
      'लगातार सुरक्षा अलर्ट के लिए बैकग्राउंड लोकेशन की अनुमति दें।';

  @override
  String get permissionBannerNeedFg =>
      'सुरक्षा ट्रैकिंग और अलर्ट सक्षम करने के लिए लोकेशन एक्सेस की अनुमति दें।';

  @override
  String get permissionEnableBg => 'बैकग्राउंड सक्षम करें';

  @override
  String get permissionEnableFg => 'लोकेशन सक्षम करें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get snackGrantLocationFirst => 'पहले लोकेशन अनुमति दें।';

  @override
  String get snackEnableBackground =>
      'निरंतर सुरक्षा ट्रैकिंग के लिए \'हमेशा अनुमति दें\' सक्षम करें।';

  @override
  String get snackBgNeeded => 'अलर्ट के लिए बैकग्राउंड लोकेशन आवश्यक है।';

  @override
  String get snackFeatureComingSoon => 'यह सुविधा जल्द आ रही है!';

  @override
  String get snackNoMetadata =>
      'आपके Tourist ID के लिए कोई मेटाडेटा नहीं मिला।';

  @override
  String get dismiss => 'खारिज करें';

  @override
  String get error => 'त्रुटि';

  @override
  String get trackingActive => 'ट्रैकिंग चालू (रोकने हेतु टैप करें)';

  @override
  String get trackingPaused => 'ट्रैकिंग रुकी (दोबारा शुरू हेतु टैप करें)';

  @override
  String get touristId => 'टूरिस्ट आईडी';

  @override
  String get tokenId => 'टोकन आईडी:';

  @override
  String get validUntil => 'मान्य तिथि:';

  @override
  String get status => 'स्थिति:';

  @override
  String get active => 'सक्रिय';

  @override
  String get inactive => 'निष्क्रिय';

  @override
  String get expired => 'समाप्त';

  @override
  String get active_caps => 'सक्रिय';

  @override
  String get viewId => 'आईडी देखें';

  @override
  String get noTouristIdBody =>
      'आपके पास अभी कोई सक्रिय Tourist ID नहीं है। सुरक्षित और सत्यापित यात्रा अनुभव के लिए एक बनाएं।';

  @override
  String get createTouristId => 'टूरिस्ट आईडी बनाएं';

  @override
  String get quickActions => 'त्वरित क्रियाएँ';

  @override
  String get qrCheckIn => 'क्यूआर चेक-इन';

  @override
  String get emergency => 'आपातकाल';

  @override
  String get checkIn => 'चेक-इन';

  @override
  String get geoLocation => 'जियो लोकेशन';

  @override
  String get deleteExpiredTitle => 'समाप्त टूरिस्ट आईडी हटाएँ';

  @override
  String get deleteExpiredBody =>
      'यह आपके समाप्त टूरिस्ट आईडी को ब्लॉकचेन से स्थायी रूप से हटा देगा। इसे वापस नहीं किया जा सकता।';

  @override
  String get deletedSuccessfully => 'टूरिस्ट आईडी सफलतापूर्वक हटाई गई';

  @override
  String get deleteFailed => 'टूरिस्ट आईडी हटाने में विफल';

  @override
  String get listening => 'सुन रहा है…';

  @override
  String get noEmergencyNumber => 'कोई आपातकालीन संपर्क नंबर नहीं मिला';

  @override
  String get invalidEmergencyNumber => 'अमान्य आपातकालीन संपर्क नंबर';

  @override
  String get unableToCall => 'इस डिवाइस पर कॉल शुरू नहीं की जा सकी';

  @override
  String failedToStartCall(Object error) {
    return 'कॉल शुरू करने में विफल: $error';
  }

  @override
  String get language => 'भाषा';

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
