import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_utils.dart';

/// Handles all network operations with improved error handling and logging
class NetworkServiceHandler {
  NetworkServiceHandler._();
  static final NetworkServiceHandler _instance = NetworkServiceHandler._();
  factory NetworkServiceHandler() => _instance;

  final _networkServiceConfig = NetworkServiceConfig();
  final _logger = const Logger('NetworkService');

  BuildContext? get context => AppUtils.instance.context;
  bool get showLogs => _networkServiceConfig.showLogs;
  UnAuthenticationCallback? get onUnAuthentication => _networkServiceConfig.unAuthenticationCallback;
  String get validationKey => _networkServiceConfig.responseValidationKey;

  /// Shows a snackbar with the given message if context is available
  void _showSnackBar(String message) {
    if (context == null) return;

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context!);
    scaffoldMessenger?.showSnackBar(
      _networkServiceConfig.snackBarCallback(message),
    );
  }

  /// Logs network responses and errors
  void _logResponse({
    required String message,
    required String url,
    int? statusCode,
    dynamic responseData,
    StackTrace? stackTrace,
    bool isError = false,
  }) {
    if (!showLogs) return;

    final logMessage = StringBuffer()
      ..writeln('${isError ? '❌' : '✅'} $message')
      ..writeln('Endpoint: $url')
      ..writeln('Status Code: $statusCode');

    if (responseData != null && isError) {
      logMessage.writeln('Response: ${prettyJson(responseData)}');

    }

    if (isError) {
      _logger.severe(logMessage.toString(), stackTrace: stackTrace);
    } else {
      _logger.info(logMessage.toString());
    }
  }

  /// Formats JSON for better logging
  String prettyJson(dynamic json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  /// Processes the HTTP response and handles common scenarios
  Future<dynamic> _processResponse({
    required http.Response response,
    required String url,
  }) async {
    try {
      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (jsonResponse[validationKey] == true) {
          _logResponse(
            message: 'Request successful',
            url: url,
            statusCode: response.statusCode,
            responseData: jsonResponse,
          );
          return jsonResponse;
        } else {
          return _handleFailedRequest(
            response: response,
            url: url,
            jsonResponse: jsonResponse,
          );
        }
      } else if (response.statusCode == 401) {
        return _handleUnauthorizedRequest(
          response: response,
          url: url,
          jsonResponse: jsonResponse,
        );
      } else {
        return _handleFailedRequest(
          response: response,
          url: url,
          jsonResponse: jsonResponse,
        );
      }
    } catch (e, stackTrace) {
      _logResponse(
        message: 'Failed to process response: $e',
        url: url,
        statusCode: response.statusCode,
        responseData: response.body,
        stackTrace: stackTrace,
        isError: true,
      );
      _showSnackBar('Something went wrong!');
      return {validationKey: false};
    }
  }

  /// Handles failed requests (non-200 status codes or validationKey=false)
  Future<dynamic> _handleFailedRequest({
    required http.Response response,
    required String url,
    required dynamic jsonResponse,
  }) async {
    final message = (jsonResponse is Map && jsonResponse.containsKey('message'))
        ? jsonResponse['message']
        : 'Something went wrong!';

    _showSnackBar(message);

    _logResponse(
      message: 'Request failed: $message',
      url: url,
      statusCode: response.statusCode,
      responseData: jsonResponse,
      isError: true,
    );

    return jsonResponse;
  }

  /// Handles unauthorized requests (status code 401)
  Future<dynamic> _handleUnauthorizedRequest({
    required http.Response response,
    required String url,
    required dynamic jsonResponse,
  }) async {
    final message = (jsonResponse is Map && jsonResponse.containsKey('message'))
        ? jsonResponse['message']
        : 'Session expired. Please login again.';

    _showSnackBar(message);

    _logResponse(
      message: 'Unauthorized request: $message',
      url: url,
      statusCode: response.statusCode,
      responseData: jsonResponse,
      isError: true,
    );

    await UserSession.instance.deleteToken();

    if (onUnAuthentication != null && context != null) {
      await onUnAuthentication!(context!);
    }

    return jsonResponse;
  }

  /// Returns the appropriate headers based on authentication needs
  Future<Map<String, String>> _getHeaders({
    bool useNonAuthHeaders = false,
    Map<String, String>? customHeaders,
  }) async {
    if (customHeaders != null) return customHeaders;

    if (useNonAuthHeaders) return _nonAuthHeaders;

    return _authHeaders;
  }

  /// Headers for authenticated requests
  Future<Map<String, String>> get _authHeaders async {
    final token = await UserSession.instance.getToken();
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// Headers for non-authenticated requests
  Map<String, String> get _nonAuthHeaders => {
    "Accept": "application/json",
    "Content-Type": "application/json",
  };

  /// Handles multipart/form-data requests (for file uploads)
  Future<http.Response> _handleMultipartRequest({
    required String url,
    required Map<String, dynamic> body,
    required bool useNonAuthHeaders,
    Map<String, String>? customHeaders,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(await _getHeaders(
      useNonAuthHeaders: useNonAuthHeaders,
      customHeaders: customHeaders,
    ));

    // Process each field in the body
    for (final entry in body.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is List) {
        await _processListField(request, key, value);
      } else if (value is File) {
        request.files.add(await http.MultipartFile.fromPath(key, value.path));
      } else if (value != null) {
        request.fields[key] = value.toString();
      }
    }

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  /// Processes list fields in multipart requests
  Future<void> _processListField(
      http.MultipartRequest request,
      String key,
      List<dynamic> value,
      ) async {
    if (value is List<File>) {
      // Handle list of files
      for (var i = 0; i < value.length; i++) {
        request.files.add(await http.MultipartFile.fromPath(
          '$key[$i]',
          value[i].path,
        ));
      }
    } else if (value is List<Map<String, dynamic>>) {
      // Handle list of maps
      for (var i = 0; i < value.length; i++) {
        value[i].forEach((subKey, subValue) {
          request.fields['$key[$i][$subKey]'] = subValue.toString();
        });
      }
    } else {
      // Handle regular list
      for (var i = 0; i < value.length; i++) {
        request.fields['$key[$i]'] = value[i].toString();
      }
    }
  }

  /// Handles regular JSON POST requests
  Future<http.Response> _handleJsonPostRequest({
    required String url,
    required Map<String, dynamic> body,
    required bool useNonAuthHeaders,
    Map<String, String>? customHeaders,
  }) async {
    return await http.post(
      Uri.parse(url),
      headers: await _getHeaders(
        useNonAuthHeaders: useNonAuthHeaders,
        customHeaders: customHeaders,
      ),
      body: jsonEncode(body),
    );
  }

  /// Handles GET requests
  Future<dynamic> getDataHandler(
      String url, {
        FutureOr<void> Function(dynamic response)? onSuccess,
        FutureOr<void> Function(dynamic error)? onError,
        bool useNonAuthHeaders = false,
        Map<String, String>? customHeaders,
      }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(
          useNonAuthHeaders: useNonAuthHeaders,
          customHeaders: customHeaders,
        ),
      );

      final decodedResponse = await _processResponse(response: response, url: url);

      if (decodedResponse[validationKey] == true) {
        await onSuccess?.call(decodedResponse);
      } else {
        await onError?.call(decodedResponse);
      }

      return decodedResponse;
    } catch (error, stackTrace) {
      _logResponse(
        message: 'GET request failed: $error',
        url: url,
        stackTrace: stackTrace,
        isError: true,
      );

      await onError?.call({
        validationKey: false,
        'message': 'An error occurred',
        'error': error.toString(),
      });

      return {validationKey: false};
    }
  }


  /// Handles POST requests with support for file uploads
  Future<dynamic> postDataHandler({
    required String url,
    required Map<String, dynamic> body,
    FutureOr<void> Function(dynamic response)? onSuccess,
    FutureOr<void> Function(dynamic error)? onError,
    bool showSuccessSnackBar = false,
    bool useNonAuthHeaders = false,
    Map<String, String>? customHeaders,
  }) async {
    try {
      final containsFile = body.values.any((value) => value is File || value is List<File>);
      final response = containsFile
          ? await _handleMultipartRequest(
        url: url,
        body: body,
        useNonAuthHeaders: useNonAuthHeaders,
        customHeaders: customHeaders,
      )
          : await _handleJsonPostRequest(
        url: url,
        body: body,
        useNonAuthHeaders: useNonAuthHeaders,
        customHeaders: customHeaders,
      );

      final decodedResponse = await _processResponse(response: response, url: url);

      if (decodedResponse[validationKey] == true) {
        await onSuccess?.call(decodedResponse);

        if (showSuccessSnackBar &&
            (context?.mounted ?? false) &&
            decodedResponse['message'] != null) {
          _showSnackBar(decodedResponse['message']);
        }
      } else {
        await onError?.call(decodedResponse);
      }

      return decodedResponse;
    } catch (error, stackTrace) {
      _logResponse(
        message: 'POST request failed: $error',
        url: url,
        stackTrace: stackTrace,
        isError: true,
      );

      await onError?.call({
        validationKey: false,
        'message': 'An error occurred',
        'error': error.toString(),
      });

      return {validationKey: false};
    }
  }


  /// Handles DELETE requests
  Future<dynamic> deleteDataHandler(
      String url, {
        FutureOr<void> Function(dynamic response)? onSuccess,
        FutureOr<void> Function(dynamic error)? onError,
        Map<String, String>? customHeaders,
      }) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: await _getHeaders(customHeaders: customHeaders),
      );

      final decodedResponse = await _processResponse(response: response, url: url);

      if (decodedResponse[validationKey] == true) {
        await onSuccess?.call(decodedResponse);
      } else {
        await onError?.call(decodedResponse);
      }

      if (context?.mounted ?? false) {
        _showSnackBar(decodedResponse['message'] ??
            (decodedResponse[validationKey] == true ? 'Deleted successfully' : 'Failed to delete'));
      }

      return decodedResponse;
    } catch (error, stackTrace) {
      _logResponse(
        message: 'DELETE request failed: $error',
        url: url,
        stackTrace: stackTrace,
        isError: true,
      );

      await onError?.call({
        validationKey: false,
        'message': 'An error occurred',
        'error': error.toString(),
      });

      return {validationKey: false};
    }
  }
}

/// Simple logger class for network operations
class Logger {
  final String name;

  const Logger(this.name);

  void info(String message) {
    log('ℹ️ $message', name: name);
  }

  void warning(String message) {
    log('⚠️ $message', name: name);
  }

  void severe(String message, {StackTrace? stackTrace}) {
    log('❌ $message', name: name, stackTrace: stackTrace);
  }
}