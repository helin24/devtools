// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:html_shim/html.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../../devtools.dart' as devtools show version;
import '../config_specific/logger.dart';
import '../devtools_api.dart' as server;
import '../globals.dart';
import '../ui/analytics_constants.dart';
import '../ui/gtags.dart';
import '../version.dart';

export '../ui/analytics_constants.dart';

// Dimensions1 AppType values:
const String appTypeFlutter = 'flutter';
const String appTypeWeb = 'web';
// Dimensions2 BuildType values:
const String buildTypeDebug = 'debug';
const String buildTypeProfile = 'profile';
// Dimensions3 PlatformType values:
//    android
//    linux
//    ios
//    macos
//    windows
//    fuchsia
//    unknown     VM Service before version 3.24
// Dimension4 devToolsPlatformType values:
const String devToolsPlatformTypeMac = 'MacIntel';
const String devToolsPlatformTypeLinux = 'Linux';
const String devToolsPlatformTypeWindows = 'Windows';
// Start with Android_n.n.n
const String devToolsPlatformTypeAndroid = 'Android_';
// Dimension5 devToolsChrome starts with
const String devToolsChromeName = 'Chrome/'; // starts with and ends with n.n.n
const String devToolsChromeIos = 'Crios/'; // starts with and ends with n.n.n
const String devToolsChromeOS = 'CrOS'; // Chrome OS
// Dimension6 devToolsVersion

// Dimension7 ideLaunched
const String ideLaunchedQuery = 'ide'; // '&ide=' query parameter
const String ideLaunchedCLI = 'CLI'; // Command Line Interface

@JS('gtagsEnabled')
external bool isGtagsEnabled();

/// Is the query parameter &gtags= set to reset?
@JS('gtagsReset')
external bool isGtagsReset();

@JS('initializeGA')
external void initializeGA();

@JS()
@anonymous
class GtagEventDevTools extends GtagEvent {
  external factory GtagEventDevTools({
    String event_category,
    String event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String send_to, // UA ID of target GA property to receive event data.

    int value,
    bool non_interaction,
    dynamic custom_map,
    String user_app, // dimension1 (flutter or web)
    String user_build, // dimension2 (debug or profile)
    String user_platform, // dimension3 (android/ios/fuchsia/linux/mac/windows)
    String devtools_platform, // dimension4 linux/android/mac/windows
    String devtools_chrome, // dimension5 Chrome version #
    String devtools_version, // dimension6 DevTools version #
    String ide_launched, // dimension7 Devtools launched (CLI, VSCode, Android)

    int gpu_duration,
    int ui_duration,
  });

  @override
  external String get event_category;

  @override
  external String get event_label;

  @override
  external String get send_to;

  @override
  external int get value; // Positive number.

  @override
  external bool get non_interaction;

  @override
  external dynamic get custom_map;

  // Custom dimensions:
  external String get user_app;

  external String get user_build;

  external String get user_platform;

  external String get devtools_platform;

  external String get devtools_chrome;

  external String get devtools_version;

  external String get ide_launched;

  // Custom metrics:
  external int get gpu_duration;

  external int get ui_duration;
}

@JS()
@anonymous
class GtagExceptionDevTools extends GtagException {
  external factory GtagExceptionDevTools({
    String description,
    bool fatal,
    String user_app, // dimension1 (flutter or web)
    String user_build, // dimension2 (debug or profile)
    String user_platform, // dimension3 (android or ios)
    String devtools_platform, // dimension4 linux/android/mac/windows
    String devtools_chrome, // dimension5 Chrome version #
    String devtools_version, // dimension6 DevTools version #
    String ide_launched, // dimension7 IDE launched DevTools
  });

  @override
  external String get description; // Description of the error.
  @override
  external bool get fatal; // Fatal error.

  // Custom dimensions:
  external String get user_app;

  external String get user_build;

  external String get user_platform;

  external String get devtools_platform;

  external String get devtools_chrome;

  external String get devtools_version;

  external String get ide_launched;
}

void _logWarning(HttpRequest response, String apiType, [String respText]) {
  log(
    'HttpRequest $apiType failed status = ${response.status}'
    '${respText ??= ', responseText = $respText}'}',
    LogLevel.warning,
  );
}

// TODO(terry): Move to an API scheme similar to the VM service extension where
// '/api/devToolsEnabled' returns the value (identical VM service) and
// '/api/devToolsEnabled?value=true' sets the value.

/// Request Flutter tool stored property value enabled (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return bool or null, null implies Flutter Tool has never been run.
Future<bool> get isFlutterGAEnabled async {
  bool enabled = false;

  final resp = await HttpRequest.request(
    server.apiGetFlutterGAEnabled,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    // A return value of 'null' implies Flutter tool has never been run.
    enabled = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetFlutterGAEnabled);
  }

  return enabled;
}

/// Request Flutter tool stored property value clientID (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return as a String or null, null implies Flutter Tool has never been run.
Future<String> flutterGAClientID() async {
  String clientId;

  final resp = await HttpRequest.request(
    server.apiGetFlutterGAClientId,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    // Return value 'null' implies Flutter tool has never been run return null.
    clientId = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetFlutterGAClientId);
  }
  return clientId;
}

/// Requests all .devtools properties to be reset to their default values in the
/// file '~/.devtools'.
void resetDevToolsFile() async {
  final resp = await HttpRequest.request(
    server.apiResetDevTools,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    assert(json.decode(resp.responseText));
  } else {
    _logWarning(resp, server.apiResetDevTools);
  }
}

/// Request DevTools property value 'firstRun' (GA dialog) stored in the file
/// '~\.devtools'.
Future<bool> get isFirstRun async {
  bool firstRun = false;

  final resp = await HttpRequest.request(
    server.apiGetDevToolsFirstRun,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    firstRun = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetDevToolsFirstRun);
  }
  return firstRun;
}

bool _gaEnabled;

// Exposed function to JS via allowInterop.
bool gaEnabled() => _gaEnabled;

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~\.devtools'.
Future<bool> get isEnabled async {
  if (_gaEnabled != null) return _gaEnabled;

  bool enabled = false;

  final resp = await HttpRequest.request(
    server.apiGetDevToolsEnabled,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    enabled = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetDevToolsEnabled);
  }

  _gaEnabled = enabled;

  return enabled;
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/.devtools'.
void setEnabled([bool value = true]) async {
  final resp = await HttpRequest.request(
    '${server.apiSetDevToolsEnabled}'
    '?${server.devToolsEnabledPropertyName}=$value',
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    assert(json.decode(resp.responseText) == value);
    _gaEnabled = value;
  } else {
    _logWarning(resp, server.apiSetDevToolsEnabled, resp.responseText);
  }
}

/// Request DevTools property value 'surveyActionTaken' stored in the file
/// '~\.devtools'.
Future<bool> get isSurveyActionTaken async {
  bool surveyActionTaken = false;

  final resp = await HttpRequest.request(
    '${server.apiGetSurveyActionTaken}',
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    surveyActionTaken = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetSurveyActionTaken);
  }
  return surveyActionTaken;
}

/// Set DevTools property value 'surveyActionTaken' stored in the file
/// '~\.devtools'.
void setSurveyActionTaken([bool value = true]) async {
  final resp = await HttpRequest.request(
    // Format of request is e.g., api/setDevToolsEnabled?surveyActionTaken=true
    '${server.apiSetSurveyActionTaken}'
    '?${server.surveyActionTakenPropertyName}=$value',
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    assert(json.decode(resp.responseText) == value);
  } else {
    _logWarning(resp, server.apiSetSurveyActionTaken, resp.responseText);
  }
}

/// Request DevTools property value 'surveyShownCount' stored in the file
/// '~\.devtools'.
Future<int> get surveyShownCount async {
  int surveyShownCount;

  final resp = await HttpRequest.request(
    '${server.apiGetSurveyShownCount}',
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    surveyShownCount = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiGetSurveyShownCount);
  }
  return surveyShownCount;
}

/// Increment DevTools property value 'surveyShownCount' stored in the file
/// '~\.devtools'.
Future<int> get incrementSurveyShownCount async {
  // Any failure will still return 1.
  int surveyShownCount = 1;

  final resp = await HttpRequest.request(
    server.apiIncrementSurveyShownCount,
    method: 'POST',
  );
  if (resp.status == HttpStatus.ok) {
    surveyShownCount = json.decode(resp.responseText);
  } else {
    _logWarning(resp, server.apiIncrementSurveyShownCount);
  }
  return surveyShownCount;
}

void screen(
  String screenName, [
  int value = 0,
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: screenViewEvent,
      value: value,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
    ),
  );
}

void select(
  String screenName,
  String selectedItem, [
  int value = 0,
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: selectEvent,
      event_label: selectedItem,
      value: value,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
    ),
  );
}

// Used only for Timeline Frame selection.
void selectFrame(
  String screenName,
  String selectedItem, [
  int gpuDuration, // Custom metric
  int uiDuration, // Custom metric
]) {
  GTag.event(
    screenName,
    GtagEventDevTools(
      event_category: selectEvent,
      event_label: selectedItem,
      gpu_duration: gpuDuration,
      ui_duration: uiDuration,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
    ),
  );
}

String _lastGaError;

void error(
  String errorMessage,
  bool fatal,
) {
  // Don't keep recording same last error.
  if (_lastGaError == errorMessage) return;
  _lastGaError = errorMessage;

  GTag.exception(
    GtagExceptionDevTools(
      description: errorMessage,
      fatal: fatal,
      user_app: userAppType,
      user_build: userBuildType,
      user_platform: userPlatformType,
      devtools_platform: devtoolsPlatformType,
      devtools_chrome: devtoolsChrome,
      devtools_version: devtoolsVersion,
      ide_launched: ideLaunched,
    ),
  );
}

////////////////////////////////////////////////////////////////////////////////
// Utilities to collect all platform and DevTools state for Analytics.
////////////////////////////////////////////////////////////////////////////////

// GA dimensions:
String _userAppType = ''; // dimension1
String _userBuildType = ''; // dimension2
String _userPlatformType = ''; // dimension3

String _devtoolsPlatformType =
    ''; // dimension4 MacIntel/Linux/Windows/Android_n
String _devtoolsChrome = ''; // dimension5 Chrome/n.n.n  or Crios/n.n.n

const String devtoolsVersion = devtools.version; //dimension6 n.n.n

String _ideLaunched = ''; // dimension7 IDE launched DevTools (VSCode, CLI, ...)

String get userAppType => _userAppType;

set userAppType(String __userAppType) {
  _userAppType = __userAppType;
}

String get userBuildType => _userBuildType;

set userBuildType(String __userBuildType) {
  _userBuildType = __userBuildType;
}

String get userPlatformType => _userPlatformType;

set userPlatformType(String __userPlatformType) {
  _userPlatformType = __userPlatformType;
}

String get devtoolsPlatformType => _devtoolsPlatformType;

set devtoolsPlatformType(String __devtoolsPlatformType) {
  _devtoolsPlatformType = __devtoolsPlatformType;
}

String get devtoolsChrome => _devtoolsChrome;

set devtoolsChrome(String __devtoolsChrome) {
  _devtoolsChrome = __devtoolsChrome;
}

String get ideLaunched => _ideLaunched;

set ideLaunched(String __ideLaunched) {
  _ideLaunched = __ideLaunched;
}

bool _analyticsComputed = false;

bool get isDimensionsComputed => _analyticsComputed;

void dimensionsComputed() {
  _analyticsComputed = true;
}

// Computes the running application.
Future<void> computeUserApplicationCustomGTagData() async {
  if (isDimensionsComputed) return;

  final isFlutter = await serviceManager.connectedApp.isFlutterApp;
  final isWebApp = await serviceManager.connectedApp.isDartWebApp;
  final isProfile = await serviceManager.connectedApp.isProfileBuild;
  final isAnyFlutterApp = await serviceManager.connectedApp.isAnyFlutterApp;

  if (isFlutter) {
    userPlatformType = (await serviceManager.service.isProtocolVersionSupported(
            supportedVersion: SemanticVersion(major: 3, minor: 24)))
        ? serviceManager.vm.operatingSystem
        : 'unknown';
  }

  if (isAnyFlutterApp) {
    if (isFlutter) {
      userAppType = appTypeFlutter;
    }
    if (isWebApp) {
      userAppType = appTypeWeb;
    }
  }
  userBuildType = isProfile ? buildTypeProfile : buildTypeDebug;

  _analyticsComputed = true;
}

void exposeGaDevToolsEnabledToJs() {
  setProperty(window, 'gaDevToolsEnabled', allowInterop(gaEnabled));
}
