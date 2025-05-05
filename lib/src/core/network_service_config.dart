import 'dart:async';

import 'package:flutter/material.dart';

typedef SnackBarCallback = SnackBar Function(String message);
typedef UnAuthenticationCallback = FutureOr<void> Function(BuildContext context);

class NetworkServiceConfig{
  NetworkServiceConfig._();
  static final NetworkServiceConfig _instance = NetworkServiceConfig._();
  factory NetworkServiceConfig()=> _instance;

  SnackBarCallback? _snackBarCallback;
  UnAuthenticationCallback? _unAuthenticationCallback;
  bool _showLogs = true;
  String _responseValidationKey = "success";


  void initialize({
    SnackBarCallback? snackBar,
    UnAuthenticationCallback? onUnAuthentication,
    bool showLogs = true,
    String responseValidationKey = 'success',}){
    _snackBarCallback = snackBar;
    _unAuthenticationCallback = onUnAuthentication;
    _showLogs = showLogs;
    _responseValidationKey = responseValidationKey;
  }

  // getters
  SnackBarCallback get snackBarCallback => _snackBarCallback ?? (message)=> SnackBar(content: Text(message),duration: Duration(seconds: 2),);
  UnAuthenticationCallback? get unAuthenticationCallback => _unAuthenticationCallback;
  bool get showLogs => _showLogs;
  String get responseValidationKey => _responseValidationKey;

}