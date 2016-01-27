// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'package:atom/atom.dart';
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

_runAppOnDevice() async {
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

  // TODO build and deploy the app to be run

  // Run the app on the device
  if (await sendDeviceCmd(ttyPath, 'run')) {
    atom.notifications.addInfo('Launched app on device', dismissable: true);
  }
}

