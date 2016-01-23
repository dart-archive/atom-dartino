// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';
import 'package:atom/utils/disposable.dart';
import 'package:logging/logging.dart';

import 'usb.dart';

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
        'default': '',
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
  List<String> allPkgRoots = atom.packages.getPackageDirPaths();
  for (String pkgsRoot in allPkgRoots) {
    String path = fs.join(pkgsRoot, pluginId);
    if (fs.existsSync(path)) return path;
  }
  atom.notifications.addError('Cannot find $pluginId package directory.',
      detail: 'Cannot find $pluginId in ${allPkgRoots[0]}', dismissable: true);
  return null;
}

/// Return the path to the device communications utility.
/// If not found, report an error to the user and return `null`.
String get _deviceCommPath {
  if (_dartinoPluginPath == null) return null;
  String path = fs.join(_dartinoPluginPath, 'bin', 'device_comm.dart');
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find device communication utility.',
        detail: 'Cannot find device communication utility at $path',
        dismissable: true);
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
  if (_vmPath == null || _deviceCommPath == null) return;
  String ttyPath = atom.config.getValue('$pluginId.devicePath');

  // If no path specified, then try to find connected device
  if (ttyPath == null || ttyPath.trim().isEmpty) {
    List<String> portNames = await connectedDevices();
    if (portNames == null) return;
    int count = portNames.length;
    if (count == 0) {
      atom.notifications.addError('Found no connected devices.',
          detail: 'Please connect the device and try again.\n'
              'If the device is already connected, '
              'please set the device path in '
              'Settings > Packages > $pluginId > Device Path',
          dismissable: true);
      return;
    }
    if (count != 1) {
      atom.notifications.addError('Found $count connected devices.',
          detail: 'Please set the device path in '
              'Settings > Packages > $pluginId > Device Path',
          dismissable: true);
      return;
    }
    ttyPath = portNames[0];
  }

  // Check that the specified connection is valid
  if (!fs.existsSync(ttyPath)) {
    atom.notifications.addError('Cannot find device.',
        detail: 'Cannot find device at $ttyPath. '
            'Please connect the device or set the device path in '
            'Settings > Packages > $pluginId > Device Path',
        dismissable: true);
    return;
  }

  // TODO build and deploy the app to be run

  // Run the app on the device
  if ((await _runDeviceComm([ttyPath, 'fletch', 'run'])).exit == 0) {
    atom.notifications.addInfo('Launched app on device', dismissable: true);
  }
}

/// Launch the deviceComm with the given arguments and return the result.
/// Notify the user if there is a problem.
Future<ProcessResult> _runDeviceComm(List<String> args) async {
  List runnerArgs = [_deviceCommPath]..addAll(args);
  ProcessRunner runner =
      new ProcessRunner(_vmPath, args: runnerArgs, cwd: _dartinoPluginPath);
  ProcessResult result = await runner.execSimple();
  if (result.exit != 0) {
    atom.notifications.addError('Launch failed',
        dismissable: true,
        detail: 'exit code ${result.exit}\n${result.stdout}'
            '\n${result.stderr}');
  }
  return result;
}
