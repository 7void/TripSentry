// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'পর্যটক সুরক্ষা অ্যাপ';

  @override
  String get appNameShort => 'ট্রিপসেন্ট্রি';

  @override
  String get menuRefresh => 'রিফ্রেশ';

  @override
  String get menuClearData => 'ডেটা মুছুন';

  @override
  String get menuLogout => 'লগ আউট';

  @override
  String get menuClearDataConfirmTitle => 'পর্যটক ডেটা মুছুন';

  @override
  String get menuClearDataConfirmBody =>
      'এটি আপনার পর্যটক ডেটা এবং সংশ্লিষ্ট সব তথ্য স্থায়ীভাবে মুছে দেবে। এই কাজটি ফেরত নেওয়া যাবে না।';

  @override
  String get cancel => 'বাতিল';

  @override
  String get delete => 'মুছুন';

  @override
  String get permissionBannerNeedBg =>
      'ধারাবাহিক নিরাপত্তা সতর্কতার জন্য ব্যাকগ্রাউন্ড লোকেশন অনুমতি দিন।';

  @override
  String get permissionBannerNeedFg =>
      'সুরক্ষা ট্র্যাকিং এবং সতর্কতা সক্ষম করতে লোকেশন অ্যাক্সেস অনুমতি দিন।';

  @override
  String get permissionEnableBg => 'ব্যাকগ্রাউন্ড চালু করুন';

  @override
  String get permissionEnableFg => 'লোকেশন চালু করুন';

  @override
  String get settings => 'সেটিংস';

  @override
  String get snackGrantLocationFirst => 'প্রথমে লোকেশন অনুমতি দিন।';

  @override
  String get snackEnableBackground =>
      'ধারাবাহিক সুরক্ষা ট্র্যাকিংয়ের জন্য \'সবসময় অনুমতি দিন\' চালু করুন।';

  @override
  String get snackBgNeeded => 'সতর্কতার জন্য ব্যাকগ্রাউন্ড লোকেশন প্রয়োজন।';

  @override
  String get snackFeatureComingSoon => 'ফিচারটি শীঘ্রই আসছে!';

  @override
  String get snackNoMetadata =>
      'আপনার Tourist ID-এর জন্য কোনো মেটাডেটা পাওয়া যায়নি।';

  @override
  String get dismiss => 'বন্ধ করুন';

  @override
  String get error => 'ত্রুটি';

  @override
  String get trackingActive => 'ট্র্যাকিং চলছে (স্থগিত করতে ট্যাপ করুন)';

  @override
  String get trackingPaused => 'ট্র্যাকিং বন্ধ (আবার শুরু করতে ট্যাপ করুন)';

  @override
  String get touristId => 'ট্যুরিস্ট আইডি';

  @override
  String get tokenId => 'টোকেন আইডি:';

  @override
  String get validUntil => 'যতদিন বৈধ:';

  @override
  String get status => 'অবস্থা:';

  @override
  String get active => 'সক্রিয়';

  @override
  String get inactive => 'নিষ্ক্রিয়';

  @override
  String get expired => 'মেয়াদোত্তীর্ণ';

  @override
  String get active_caps => 'সক্রিয়';

  @override
  String get viewId => 'আইডি দেখুন';

  @override
  String get noTouristIdBody =>
      'আপনার কোনো সক্রিয় Tourist ID নেই। নিরাপদ এবং যাচাইকৃত ভ্রমণের অভিজ্ঞতার জন্য একটি তৈরি করুন।';

  @override
  String get createTouristId => 'ট্যুরিস্ট আইডি তৈরি করুন';

  @override
  String get quickActions => 'দ্রুত কার্যাবলী';

  @override
  String get qrCheckIn => 'কিউআর চেক-ইন';

  @override
  String get emergency => 'জরুরি';

  @override
  String get checkIn => 'চেক-ইন';

  @override
  String get geoLocation => 'জিও লোকেশন';

  @override
  String get deleteExpiredTitle => 'মেয়াদোত্তীর্ণ ট্যুরিস্ট আইডি মুছুন';

  @override
  String get deleteExpiredBody =>
      'এটি আপনার মেয়াদোত্তীর্ণ ট্যুরিস্ট আইডি ব্লকচেইন থেকে স্থায়ীভাবে মুছে দেবে। এটি ফেরত নেওয়া যাবে না।';

  @override
  String get deletedSuccessfully => 'ট্যুরিস্ট আইডি সফলভাবে মুছে ফেলা হয়েছে';

  @override
  String get deleteFailed => 'ট্যুরিস্ট আইডি মুছতে ব্যর্থ';

  @override
  String get listening => 'শুনছে…';

  @override
  String get noEmergencyNumber => 'কোনো জরুরি যোগাযোগ নম্বর পাওয়া যায়নি';

  @override
  String get invalidEmergencyNumber => 'অবৈধ জরুরি যোগাযোগ নম্বর';

  @override
  String get unableToCall => 'এই ডিভাইসে কল শুরু করা যাচ্ছে না';

  @override
  String failedToStartCall(Object error) {
    return 'কল শুরু করতে ব্যর্থ: $error';
  }

  @override
  String get language => 'ভাষা';

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
