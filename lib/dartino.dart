// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/command.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/notification.dart';
import 'package:atom/node/package.dart';
import 'package:atom/node/process.dart';
import 'package:atom/node/shell.dart';
import 'package:atom/utils/debounce.dart';
import 'package:atom/utils/disposable.dart';
import 'package:atom/utils/package_deps.dart' as package_deps;
import 'package:logging/logging.dart';

export 'package:atom/node/package.dart' show registerPackage;

const pluginId = 'dartino';

final Logger _logger = new Logger(pluginId);

class DartinoDevPackage extends AtomPackage {
  final Disposables _disposables = new Disposables(catchExceptions: true);

  DartinoDevPackage() : super(pluginId);

  void activate([dynamic state]) {
    _setupLogging();
    _logger.info("activated");
    _logger.fine("Running on Chrome version ${process.chromeVersion}.");

    new Future.delayed(Duration.ZERO, () async {
      await package_deps.install('Dartino', this);
      _checkSdkInstalled();
      _dispatch('dartino:enable');
    });

    // Register commands.
    _addCmd('atom-workspace', 'dartino:settings', openDartinoSettings);
    _addCmd('atom-workspace', 'dartino:getting-started', _showGettingStarted);
  }

  Map config() {
    _disposables.add(new DisposeableSubscription(atom.config
        .onDidChange('$pluginId.sdkPath')
        .transform(new Debounce(new Duration(seconds: 3)))
        .listen(([_]) {
      _dispatch('dartino:validate-sdk');
    })));
    return {
      'devicePath': {
        'title': 'Device path.',
        'description': 'The /dev/tty* path for accessing a connected device'
            ' or "local" to run without a device',
        'type': 'string',
        'default': '',
        'order': 2
      },
      'sdkPath': {
        'title': 'SDK root directory.',
        'description': 'The directory containing the Dartino SDK',
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

void openDartinoSettings([AtomEvent _]) {
  atom.workspace.open('atom://config/packages/dartino');
}

/// If an SDK is not configured, offer to download and install it.
void _checkSdkInstalled([_]) {
  String path = atom.config.getValue('$pluginId.sdkPath')?.trim();
  if (path == null || path.isEmpty) {
    path = fs.join(fs.homedir, 'dartino-sdk');
    if (fs.existsSync(path)) {
      atom.config.setValue('$pluginId.sdkPath', path);
    } else {
      path = null;
    }
  }
  if (path != null && path.isNotEmpty) return;
  Notification info;
  info = atom.notifications.addInfo('Install Dartino SDK?',
      detail: 'No Dartino SDK has been configured.\n'
          ' \n'
          'Would you like the Dartino SDK\n'
          'automatically downloaded and installed?\n'
          ' \n'
          'Or would you like to open the settings page and specify\n'
          'the location of an already installed Dartino SDK?',
      buttons: [
        new NotificationButton('Install SDK', () {
          info.dismiss();
          _dispatch('dartino:install-sdk');
        }),
        new NotificationButton('Open Settings', () {
          info.dismiss();
          openDartinoSettings();
        })
      ],
      dismissable: true);
}

void _dispatch(String commandName) {
  var view = atom.views.getView(atom.workspace);
  atom.commands.dispatch(view, commandName);
}

_showGettingStarted(event) {
  shell.openExternal('https://dartino.org/index.html');
}
