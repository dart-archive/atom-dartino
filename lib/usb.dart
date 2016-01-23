// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.usb;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/process.dart';

import 'dartino.dart' show pluginId;

/// Return a list paths for USB connected TTY devices.
/// If there is an error, notify the user and return `null`.
Future<List<String>> connectedDevices() async {
  if (isWindows) {
    atom.notifications.addError('Windows not supported yet', dismissable: true);
    return null;
  }
  ProcessRunner runner = new ProcessRunner('ls', args: ['-1', '/dev']);
  ProcessResult result = await runner.execSimple();
  if (result.exit != 0) {
    atom.notifications.addError('Failed to find connected devices',
        dismissable: true,
        detail: 'Please set the device path in '
            'Settings > Packages > $pluginId > Device Path\n\n'
            'exit code ${result.exit}\n${result.stdout}'
            '\n${result.stderr}');
    return null;
  }
  return result.stdout
      .split('\n')
      .where((String name) =>
          name.startsWith('tty.usb') || name.startsWith('ttyS'))
      .map((name) => '/dev/$name')
      .toList();
}
