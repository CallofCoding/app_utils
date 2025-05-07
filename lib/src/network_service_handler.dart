import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app_utils/src/core/app_utils_config.dart';
import 'package:app_utils/src/core/network_service_config.dart';
import 'package:app_utils/src/core/user_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class NetworkServiceHandler{
  NetworkServiceHandler._();
  static final NetworkServiceHandler _instance = NetworkServiceHandler._();
  factory NetworkServiceHandler()=> _instance;


  final NetworkServiceConfig _networkServiceConfig = NetworkServiceConfig();

  BuildContext? get context => AppUtilsConfig.instance.context;
  bool get showLogs => _networkServiceConfig.showLogs;
  UnAuthenticationCallback? get onUnAuthentication => _networkServiceConfig.unAuthenticationCallback;
  String get validationKey => _networkServiceConfig.responseValidationKey;

   showSnackBar(String message){
    if(context == null) return;
    ScaffoldMessengerState? scaffoldMessengerState = ScaffoldMessenger.maybeOf(context!);
    if(scaffoldMessengerState != null){
      return scaffoldMessengerState.showSnackBar(_networkServiceConfig.snackBarCallback(message));
    }
  }



  dynamic _decodeResponse(http.Response response,{required String url}) async {
    dynamic data ;
    try{
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse[validationKey] == true) {
          if(showLogs){
            log('-------Successfully hit Api-----------', name: 'NetworkServiceHandler');
          }
        } else {
          // show error for status is not ture but status code is 200
          if ((jsonResponse as Map<String, dynamic>).containsKey('message')) {
            showSnackBar(jsonResponse['message']);
            if(showLogs){
              log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\n$validationKey : ${jsonResponse[validationKey]}\nMessage : ${jsonResponse['message']}\nEndpoint : $url',name: 'NetworkServiceHandler');
            }
          } else {
            showSnackBar('Something went wrong!');
            if(showLogs){
              log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\n$validationKey : ${jsonResponse[validationKey]}\nEndpoint : $url',name: 'NetworkServiceHandler');
            }
          }
        }
        data = jsonResponse;
      } else if (response.statusCode == 401) {
        var jsonResponse = jsonDecode(response.body);
        if ((jsonResponse as Map<String, dynamic>).containsKey('message')) {
          showSnackBar(jsonResponse['message']);
          if(showLogs){
            log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\nMessage : ${jsonResponse['message']}\nEndpoint : $url ',name: 'NetworkServiceHandler');
          }
        } else {
          showSnackBar('Something went wrong!');
          if(showLogs){
            log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\nEndpoint : $url',name: 'NetworkServiceHandler');
          }
        }

        data = jsonResponse;

        await UserSession.instance.deleteToken();
        if(onUnAuthentication != null && context != null){
          await onUnAuthentication!(context!);
        }

      } else {
        // show error for status code is not 200 and print message also
        var jsonResponse = jsonDecode(response.body);

        if ((jsonResponse as Map<String, dynamic>).containsKey('message')) {
          showSnackBar(jsonResponse['message']);
          if(showLogs){
            log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\nMessage : ${jsonResponse['message']}\nEndpoint : $url ',name: 'NetworkServiceHandler');
          }
        } else {
          showSnackBar('Something went wrong!');
          if(showLogs){
            log('--------Exception Occur-------\nStatus Code : ${response.statusCode}\nEndpoint : $url',name: 'NetworkServiceHandler');
          }
        }

        data = jsonResponse;
      }
      return data;
    }catch(e,stackTrace){
      showSnackBar('Something went wrong!');
      if(showLogs){
        log('--------try-catch Exception Occur-------\nStatus Code : ${response.statusCode}\nBody : ${response.body}\nEndpoint : $url\nDetails: $e',name: 'NetworkServiceHandler',stackTrace: stackTrace);
      }
      return {validationKey: false};
    }
  }

  Future<Map<String, String>> _headers() async {
     String? token = await UserSession.instance.getToken();
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token"
    };
  }

  Map<String,String> _nonAuthHeaders(){
    return {
      "Accept": "application/json",
      "Content-Type": "application/json"
    };
  }

  dynamic postDataHandler({
    required String url,
    required Map<String, dynamic> body,
    FutureOr<void> Function(dynamic response)? onSuccess,
    void Function(dynamic error)? onError, // Added onError callback
    bool showSuccessSnackBar = false,
    bool useNonAuthHeaders = false,
    Map<String,String>? customHeaders,
  }) async {
    bool containsFile = body.values.any((value) => value is File || value is List<File>);
    http.Response response;

    try {
      if (containsFile) {
        var request = http.MultipartRequest('POST', Uri.parse(url));

        // Add headers

        if(customHeaders != null){
          request.headers.addAll(customHeaders);
        }else if (useNonAuthHeaders) {
          request.headers.addAll(_nonAuthHeaders());
        } else {
          request.headers.addAll(await _headers());
        }

        // Add other fields (non-file fields) to the request
        for (var entry in body.entries) {
          var key = entry.key;
          var value = entry.value;

          if (value is List) {
            if (value is List<File>) {
              for (var i = 0; i < value.length; i++) {
                request.files.add(await http.MultipartFile.fromPath('$key[$i]', value[i].path));
              }
            } else if (value is List<Map<String, dynamic>>) {
              for (var i = 0; i < value.length; i++) {
                value[i].forEach((subKey, subValue) {
                  request.fields['$key[$i][$subKey]'] = subValue.toString();
                });
              }
            } else {
              for (var i = 0; i < value.length; i++) {
                request.fields['$key[$i]'] = value[i].toString();
              }
            }
          } else if (value is File) {
            request.files.add(await http.MultipartFile.fromPath(key, value.path));
          } else {
            request.fields[key] = value.toString();
          }
        }

        // Send request
        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.post(
          Uri.parse(url),
          headers: customHeaders ?? (useNonAuthHeaders ? _nonAuthHeaders() : await _headers()),
          body: jsonEncode(body),
        );
      }

      var decodedResponse = _decodeResponse(response, url: url);

      if (decodedResponse?[validationKey] == true) {
        if (onSuccess != null) {
          await onSuccess(decodedResponse);
        }
        if (showSuccessSnackBar && (context?.mounted ?? false) && decodedResponse['message'] != null) {
          showSnackBar(decodedResponse['message']);
        }
      } else {
        if (onError != null) {
          onError(decodedResponse);
        }
      }

      return decodedResponse;
    } catch (error) {
      if (onError != null) {
        onError(error.toString());
      }
      return {validationKey: false, 'message': 'An error occurred', 'error': error.toString()};
    }
  }

  Future<dynamic> getDataHandler(String url,{FutureOr<void> Function(dynamic response)? onSuccess, bool useNonAuthHeaders = false, Map<String,String>? customHeaders})async {
    var response = await http.get(
        Uri.parse(url), headers: customHeaders ?? (useNonAuthHeaders ? _nonAuthHeaders() : await _headers()));

    var decodedResponse = await _decodeResponse(response, url: url);
    // print(decodedResponse);
    if (decodedResponse[validationKey] == true) {
      if (onSuccess != null) {
        await onSuccess(decodedResponse);
      }
      return decodedResponse;
    }
  }

  Future<dynamic> deleteDataHandler(String url,{FutureOr<void> Function(dynamic response)? onSuccess, Map<String,String>? customHeaders})async{
    var response = await http.delete(Uri.parse(url),headers: customHeaders ?? await _headers());
    var decodedJson = await _decodeResponse(response, url: url);
    if(decodedJson[validationKey] == true){
      if(context?.mounted ?? false){
        if(onSuccess != null){
          await onSuccess(decodedJson);
        }
        showSnackBar(decodedJson['message']);
      }
    }
  }


}