import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter does not supply platform picker translations for Kinyarwanda.
/// App copy remains rw; platform widgets use English instead of failing to load.
const rwPlatformLocalizationDelegates = <LocalizationsDelegate<dynamic>>[
  _RwMaterialDelegate(),
  _RwCupertinoDelegate(),
  _RwWidgetsDelegate(),
];

class _RwMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _RwMaterialDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_RwMaterialDelegate old) => false;
}

class _RwCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _RwCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_RwCupertinoDelegate old) => false;
}

class _RwWidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RwWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_RwWidgetsDelegate old) => false;
}
