// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';
import 'package:atom/utils/disposable.dart';
import 'package:logging/logging.dart';

export 'package:atom/atom.dart' show registerPackage;

const pluginId = 'dartino';

class DartinoDevPackage extends AtomPackage {
  final Logger _logger = new Logger(pluginId);
  final Disposables _disposables = new Disposables(catchExceptions: true);

  DartinoDevPackage() : super(pluginId);

  void activate([dynamic state]) {
    _setupLogging();
    _logger.info("activated");
    _logger.fine("Running on Chrome version ${process.chromeVersion}.");

    // Register commands.
    _addCmd('atom-workspace', 'dartino:settings',
        (_) => atom.workspace.open('atom://config/packages/dartino'));
    _addCmd('atom-workspace', 'dartino:run-app-on-device',
        (_) => _runAppOnDevice());
  }

  Map config() {
    return {
      'devicePath': {
        'title': 'Device path.',
        'description': 'The /dev/tty* path for accessing a connected device.',
        'type': 'string',
        'default': (isMac ? '/dev/tty.usbmodem14143' : '/dev/ttyACM0'),
        'order': 1
      },
      // development
      'logging': {
        'title': 'Log plugin diagnostics to the devtools console.',
        'description': 'This is for plugin development only!',
        'type': 'string',
        'default': 'info',
        'enum': ['error', 'warning', 'info', 'fine', 'finer'],
        'order': 3
      },
    };
  }

  void deactivate() {
    _logger.info('deactivated');
    _disposables.dispose();
  }

  void _addCmd(String target, String command, void callback(AtomEvent e)) {
    _disposables.add(atom.commands.add(target, command, callback));
  }

  void _setupLogging() {
    _disposables.add(atom.config.observe('${pluginId}.logging', null, (val) {
      if (val == null) return;
      for (Level level in Level.LEVELS) {
        if (val.toUpperCase() == level.name) {
          Logger.root.level = level;
          break;
        }
      }
      _logger.info("logging level: ${Logger.root.level}");
    }));
  }
}

/// Return the path to the dartino plugin.
/// If not found, report an error to the user and return `null`.
String get _dartinoPluginPath {
  // TODO(danrubel) cleanup this HACK
  // Find the `dartlang` project.
  // Directory proj = atom.project.getDirectories().firstWhere(
  //     (d) => d.getBaseName().endsWith('atom-dartino'), orElse: () => null
  // );
  // if (proj == null) {
  //   atom.notifications.addWarning("Unable to find project '${'dartlang'}'.");
  //   return new Future.value();
  // }
  if (isMac) return '/Users/danrubel/work/git/atom/atom-dartino';
  return '/usr/local/google/home/danrubel/work/git/atom/atom-dartino';
}

String get _deviceTtyPath {
  if (_dartinoPluginPath == null) return null;
  String path = fs.join(_dartinoPluginPath, 'bin', 'device_tty.dart');
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find Device TTY utility.',
        detail: 'Cannot find Device TTY utility at $path', dismissable: true);
    return null;
  }
  return path;
}

/// Return the path to the Dart SDK as configured in the dartlang plugin.
/// If not found, report an error to the user and return `null`.
String get _sdkPath {
  String path = atom.config.getValue('dartlang.sdkLocation');
  if (path == null || path.trim().isEmpty) {
    atom.notifications.addError('Dart SDK is not set.',
        detail: 'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find Dart SDK.',
        detail: 'Cannot find Dart SDK at $path. '
            'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  return path;
}

/// Return the path to the VM in the Dart SDK.
/// If not found, report an error to the user and return `null`.
String get _vmPath {
  if (_sdkPath == null) return null;
  String path = fs.join(_sdkPath, 'bin', 'dart');
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find Dart VM in the Dart SDK.',
        detail: 'Cannot find Dart VM at $path. '
            'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  return path;
}

_runAppOnDevice() async {
  if (_vmPath == null || _deviceTtyPath == null)
    return;
  String ttyPath = atom.config.getValue('$pluginId.devicePath');
  if (ttyPath == null || ttyPath.trim().isEmpty) {
    atom.notifications.addError('Device path is not set.',
        detail: 'Please set the device path in '
            'Settings > Packages > $pluginId > Device Path',
        dismissable: true);
    return;
  }
  if (!fs.existsSync(ttyPath)) {
    atom.notifications.addError('Cannot find device.',
        detail: 'Cannot find device at $ttyPath. '
         'Please connect the device or set the device path in '
            'Settings > Packages > $pluginId > Device Path',
        dismissable: true);
    return;
  }
  ProcessRunner runner = new ProcessRunner(_vmPath,
      args: [_deviceTtyPath, ttyPath, 'fletch run'], cwd: _dartinoPluginPath);
  runner.execSimple().then((result) {
    if (result.exit == 0) {
      atom.notifications.addInfo('Launched app on device', dismissable: true);
    } else {
      atom.notifications.addError('Launch failed',
          dismissable: true,
          detail: 'exit code ${result.exit}\n${result.stdout}'
              '\n${result.stderr}');
    }
  });
}
