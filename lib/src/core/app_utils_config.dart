import 'package:flutter/cupertino.dart';

class AppUtilsConfig{

  AppUtilsConfig._internal();

  static final AppUtilsConfig _instance = AppUtilsConfig._internal();

  static AppUtilsConfig get  instance => _instance;

  BuildContext? get context => navigatorKey.currentContext;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

}