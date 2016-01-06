// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'dart:async';

import 'package:atom/atom.dart';
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
    _addCmd('atom-workspace', 'dartino:rebuild-restart-dev',
        (_) => _rebuildRestart());
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

/// Return the path to the dartino plugin, or `null` if unknown.
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
  return '/usr/local/google/home/danrubel/work/git/atom/atom-dartino';
}

/// Return the path to the Dart SDK, or `null` if unknown.
String get _sdkPath {
  // Find the SDK using the dartlang plugin
  String path = atom.config.getValue('dartlang.sdkLocation');
  // if (sdk does not exist) {
  //   showNoSdkMessage();
  //   return null;
  // }
  return path;
}

/// Compile the Dart sources into web/entry.dart.js then restart Atom
void _rebuildRestart() {
  atom.notifications.addInfo('Building atom-dartino plugin', dismissable: true);

  if (_sdkPath == null || _dartinoPluginPath == null) return;
  String pubPath = '$_sdkPath/bin/pub';
  String projPath = _dartinoPluginPath;

  // Save any dirty editors.
  atom.workspace.getTextEditors().forEach((editor) {
    if (editor.isModified()) editor.save();
  });

  // TODO(danrubel) cleanup this HACK
  List<String> args = ['run', 'grinder', 'build'];
  ProcessRunner runner;
  // Run process under bash on the mac, to capture the user's env variables.
  if (isMac) {
    //exec('/bin/bash', ['-l', '-c', 'which dart'])
    String arg = args.join(' ');
    arg = pubPath + ' ' + arg;
    runner =
        new ProcessRunner('/bin/bash', args: ['-l', '-c', arg], cwd: projPath);
  } else {
    runner = new ProcessRunner(pubPath, args: args, cwd: projPath);
  }
  runner.execSimple().then((result) {
    if (result.exit == 0) {
      atom.notifications.addInfo('Build succeeded', dismissable: true);
      new Future.delayed(new Duration(seconds: 2)).then((_) => atom.reload());
    } else {
      atom.notifications.addError('Build failed',
          dismissable: true, detail: '${result.stdout}\n${result.stderr}');
    }
  });

  // return new PubRunJob.local(projPath, args, title: name).schedule().then(
  //     (JobStatus status) {
  //   // Check for an exit code of `0` from grind build.
  //   if (status.isOk && status.result == 0) {
  //     if (runTests) {
  //       _runTests();
  //     } else {
  //       new Future.delayed(new Duration(seconds: 2)).then((_) => atom.reload());
  //     }
  //   }
  // });
}

_runAppOnDevice() async {
  if (_sdkPath == null || _dartinoPluginPath == null) return;
  String dartPath = '$_sdkPath/bin/dart';
  String projPath = _dartinoPluginPath;
  String appPath = '$projPath/bin/device_tty.dart';
  String ttyPath = atom.config.getValue('$pluginId.devicePath');
  if (ttyPath == null || ttyPath.trim().isEmpty) {
    atom.notifications.addError('Device path is not set.',
        detail: 'Please set the device path in '
            'Settings > Packages > $pluginId > Device Path',
        dismissable: true);
    return;
  }

  ProcessRunner runner = new ProcessRunner(dartPath,
      args: [appPath, ttyPath, 'fletch run'], cwd: projPath);
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
