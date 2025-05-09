library app_utils;

import 'package:flutter/material.dart';

export 'src/network_service_handler.dart';
export 'src/snapshot_handler.dart';
export 'src/app_text_field.dart';

export 'src/core/network_service_config.dart';
export 'src/core/user_session.dart';



class AppUtils{

  AppUtils._internal();

  static final AppUtils _instance = AppUtils._internal();

  static AppUtils get  instance => _instance;

  BuildContext? get context => navigatorKey.currentContext;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

}