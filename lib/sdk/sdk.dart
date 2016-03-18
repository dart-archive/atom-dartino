// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/notification.dart';

import '../dartino.dart' show pluginId, openDartinoSettings;
import 'dartino_sdk.dart';
import 'sod_sdk.dart';

/// Return the SDK associated with the given application.
/// If the SDK cannot be determined, notify the user and return `null`.
Future<Sdk> findSdk(String srcPath) async {
  //TODO(danrubel) read the dartino.yaml file to determine the associated SDK
  // and support both SDKs in the same workspace
  Sdk sdk = rawDartinoSdk();
  if (sdk == null) sdk = rawSodSdk();

  if (sdk == null) {
    atom.notifications.addError('No SOD or Dartino path specified.',
        detail: 'Please download SOD or Dartino and set the path in\n'
            'Settings > Packages > $pluginId > SOD root directory.\n'
            'See Dartino settings for more information.',
        dismissable: true,
        buttons: [
          new NotificationButton('Open settings', openDartinoSettings)
        ]);
    return null;
  }

  return await sdk.verifyInstall() ? sdk : null;
}

/// Return the Dartino SDK as specified in the settings
/// or `null` if not specified. The returned SDK may not be valid.
DartinoSdk rawDartinoSdk() {
  String path = atom.config.getValue('$pluginId.dartinoPath');
  if (path == null) return null;
  path = path.trim();
  if (path.isEmpty) return null;
  return new DartinoSdk(path);
}

/// Return the Sod SDK as specified in the settings
/// or `null` if not specified. The returned SDK may not be valid.
SodSdk rawSodSdk() {
  String path = atom.config.getValue('$pluginId.sodPath');
  if (path == null) return null;
  path = path.trim();
  if (path.isEmpty) return null;
  return new SodSdk(path);
}

/// Common interface for all Dartino based SDKs.
abstract class Sdk {
  final String sdkRootPath;

  Sdk(this.sdkRootPath);

  /// Rebuild the binary to be deployed and return the path for that file.
  /// If there is a problem, notify the user and return `null`.
  Future<String> compile(String srcPath);

  /// Deploy the application at [dstPath] to the device on [deviceName],
  /// launch the application, and return `true`.
  /// If there is a problem, notify the user and return `false`.
  Future<bool> deployAndRun(String deviceName, String dstPath);

  /// Return `true` if the SDK is correctly installed and usable.
  /// If there is a problem, notify the user and automatically fix if possible.
  /// If the problem persists, return `false`.
  Future<bool> verifyInstall({String suggestion});
}
