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

final Logger _logger = new Logger('atom-dartino');

class DartinoDevPackage extends AtomPackage {
  final Disposables disposables = new Disposables(catchExceptions: true);

  DartinoDevPackage() : super('dartino');

  void activate([dynamic state]) {
    _setupLogging();
    _logger.info("activated");
    _logger.fine("Running on Chrome version ${process.chromeVersion}.");

    // Register commands.
    _addCmd('atom-workspace', 'dartino:rebuild-restart-dev',
        (_) => _rebuildRestart());
    _addCmd('atom-workspace', 'dartino:run-app-on-device',
        (_) => _runAppOnDevice());
  }

  void deactivate() {
    _logger.info('deactivated');
    disposables.dispose();
  }

  void _addCmd(String target, String command, void callback(AtomEvent e)) {
    disposables.add(atom.commands.add(target, command, callback));
  }
}

/// Compile the Dart sources into web/entry.dart.js then restart Atom
void _rebuildRestart() {
  atom.notifications.addInfo('Building atom-dartino plugin', dismissable: true);
  // TODO(danrubel) cleanup this HACK
  // Find the SDK using the dartlang plugin
  String sdkPath = '/usr/local/google/home/danrubel/work/eclipse3/dart-sdk';
  String projPath =
      '/usr/local/google/home/danrubel/work/git/atom/atom-dartino';

  // Save any dirty editors.
  atom.workspace.getTextEditors().forEach((editor) {
    if (editor.isModified()) editor.save();
  });

  // TODO(danrubel) cleanup this HACK
  String command = '$sdkPath/bin/pub';
  List<String> args = ['run', 'grinder', 'build'];
  ProcessRunner runner;
  // Run process under bash on the mac, to capture the user's env variables.
  if (process.platform == 'darwin') {
    //exec('/bin/bash', ['-l', '-c', 'which dart'])
    String arg = args.join(' ');
    arg = command + ' ' + arg;
    runner =
        new ProcessRunner('/bin/bash', args: ['-l', '-c', arg], cwd: projPath);
  } else {
    runner = new ProcessRunner(command, args: args, cwd: projPath);
  }
  runner.execSimple().then((result) {
    if (result.exit == 0) {
      atom.notifications.addInfo('Build succeeded', dismissable: true);
      new Future.delayed(new Duration(seconds: 2)).then((_) => atom.reload());
    } else {
      atom.notifications.addInfo('Build failed',
          dismissable: true, detail: '${result.stdout}\n${result.stderr}');
    }
  });
}

void _runAppOnDevice() {
  _logger.log(Level.INFO, 'runAppOnDevice');
  Notification _notification;
  _notification = atom.notifications
      .addInfo('Run app on device?', dismissable: true, buttons: [
    new NotificationButton('Run…', () {
      _notification.dismiss();
      _logger.log(Level.INFO, 'runAppOnDevice - run clicked');
    })
  ]);
}

void _setupLogging() {
  // TODO(danrubel) cleanup this HACK
  Logger.root.level = Level.FINE;
  // disposables.add(atom.config.observe('${pluginId}.logging', null, (val) {
  //   if (val == null) return;
  //
  //   for (Level level in Level.LEVELS) {
  //     if (val.toUpperCase() == level.name) {
  //       Logger.root.level = level;
  //       break;
  //     }
  //   }
  //
  //   _logger.info("logging level: ${Logger.root.level}");
  // }));
}
