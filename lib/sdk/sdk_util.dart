// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk.util;

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';

import '../dartino.dart' show pluginId, openDartinoSettings;

/// Return `true` if the given file exists within the SOD SDK.
/// If not, notify the user and return `false`.
bool checkSdkFile(
    String sdkName, String sdkPath, List<String> relPaths, String suggestion) {
  for (String relPath in relPaths) {
    relPath = relPath.replaceAll('/', fs.separator);
    var path = fs.join(sdkPath, relPath);
    if (!fs.existsSync(path)) {
      atom.notifications.addError('Invalid $sdkName directory specified.',
          detail: 'Could not find "$relPath" in\n$sdkPath.\n$suggestion',
          dismissable: true,
          buttons: [
            new NotificationButton('Open settings', openDartinoSettings)
          ]);
      return false;
    }
  }
  return true;
}
