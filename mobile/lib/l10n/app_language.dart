import 'package:flutter/material.dart';

final ValueNotifier<String> appLanguage = ValueNotifier<String>('en');

bool get isEnglish => appLanguage.value == 'en';

TextDirection get appTextDirection =>
    isEnglish ? TextDirection.ltr : TextDirection.rtl;

String tr(String arabic, String english) {
  return isEnglish ? english : arabic;
}

void changeAppLanguage(String languageCode) {
  if (languageCode != 'ar' && languageCode != 'en') {
    return;
  }

  appLanguage.value = languageCode;
}