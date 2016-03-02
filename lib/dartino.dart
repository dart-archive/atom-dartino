// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.plugin;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/atom_utils.dart';
import 'package:atom/utils/package_deps.dart' as package_deps;
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';
import 'package:atom/node/shell.dart';
import 'package:atom/utils/disposable.dart';
import 'package:logging/logging.dart';

import 'sdk/sdk.dart';
import 'usb.dart';

export 'package:atom/atom.dart' show registerPackage;

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
      //TODO(danrubel) Remove this once Dartino compile/deploy/run
      // has been integrated into the base Dart launch manager in dartlang
      _logger.info('hide atom toolbar');
      atom.config.setValue('atom-toolbar.visible', false);

      await package_deps.install('Dartino', this);
      _checkSdkInstalled();
    });

    // Register commands.
    _addCmd('atom-workspace', 'dartino:create-new-proj', _createNewProject);
    _addCmd('atom-workspace', 'dartino:settings', openDartinoSettings);
    _addCmd('atom-workspace', 'dartino:run-app-on-device', _runAppOnDevice);
    _addCmd('atom-workspace', 'dartino:getting-started', _showGettingStarted);
    _addCmd('atom-workspace', 'dartino:sdk-docs', _showSdkDocs);
  }

  Map config() {
    //TODO(danrubel) combine separate sdk paths into single $pluginId.sdkPath
    _disposables
        .add(atom.config.observe('$pluginId.sodPath', {}, _checkSdkValid));
    _disposables
        .add(atom.config.observe('$pluginId.dartinoPath', {}, _checkSdkValid));
    return {
      'devicePath': {
        'title': 'Device path.',
        'description': 'The /dev/tty* path for accessing a connected device.',
        'type': 'string',
        'default': '',
        'order': 1
      },
      'sodPath': {
        'title': 'SOD root directory.',
        'description': 'The directory in which https://github.com/domokit/sod'
            ' has been checked out and built.',
        'type': 'string',
        'default': '',
        'order': 2
      },
      'dartinoPath': {
        'title': 'Dartino root directory.',
        'description': 'The directory in which http://dartino.github.io/sdk/'
            ' has been downloaded and unzipped.',
        'type': 'string',
        'default': '',
        'order': 2
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
    disconnectDevices();
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

void openDartinoSettings([_]) {
  atom.workspace.open('atom://config/packages/dartino');
}

/// If an SDK is not configured, offer to download and install it.
void _checkSdkInstalled([_]) {
  String path = atom.config.getValue('$pluginId.dartinoPath');
  if (path == null) path = atom.config.getValue('$pluginId.sodPath');
  if (path != null && path.trim().isNotEmpty) return;
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

final Duration _checkSdkTimeout = new Duration(seconds: 3);
bool _skipSdkCheck = true; // skip check on startup
Timer _checkSdkTimer;

/// If an SDK is configured, validate it... but not on startup
void _checkSdkValid([_]) {
  if (_skipSdkCheck) {
    _skipSdkCheck = false;
    return;
  }
  _checkSdkTimer?.cancel();
  _checkSdkTimer = new Timer(_checkSdkTimeout, () {
    _dispatch('dartino:validate-sdk');
  });
}

_createNewProject([_]) async {
  var sdk = await findSdk(null);
  if (sdk == null) return;

  String projectName = 'stm32f746g_discovery_project';
  String parentPath = fs.dirname(sdk.sdkRootPath);
  String projectPath = fs.join(parentPath, projectName);
  projectPath = await promptUser('Enter the path to the project to create:',
      defaultText: projectPath, selectLastWord: true);
  if (projectPath == null) return;

  //TODO(danrubel) move this functionality into dartino create project
  try {
    var dir = new Directory.fromPath(projectPath);
    if (!dir.existsSync()) await dir.create();
    if (!dir.getEntriesSync().isEmpty) {
      atom.notifications.addError('Project already exists',
          detail: projectPath, dismissable: true);
      return;
    }
    dir.getFile('dartino.yaml').writeSync(
        r'''# This is an empty Dartino configuration file. Currently this is only used as a
# placeholder to enable the Dartino Atom package.''');
    dir.getFile('main.dart').writeSync(r'''import 'dart:dartino';
import 'package:stm32f746g_disco/stm32f746g_disco.dart';

main() {
  // TODO: Add your Dartino code here.
}''');
  } catch (e, s) {
    atom.notifications.addError('Failed to create new project',
        detail: '$projectPath\n$e\n$s', dismissable: true);
    return;
  }

  atom.project.addPath(projectPath);
  var editor = await atom.workspace.open(fs.join(projectPath, 'main.dart'));
  // Focus the file in the files view 'tree-view:reveal-active-file'.
  var view = atom.views.getView(editor);
  atom.commands.dispatch(view, 'tree-view:reveal-active-file');
}

void _dispatch(String commandName) {
  var view = atom.views.getView(atom.workspace);
  atom.commands.dispatch(view, commandName);
}

/// Return the portName for the connected device.
/// If there is a problem, notify the user and return `null`.
Future<String> _findPortName() async {
  String portName = atom.config.getValue('$pluginId.devicePath');

  // If no path specified, then try to find connected device
  if (portName == null || portName.trim().isEmpty) {
    List<String> portNames = await connectedDevices();
    if (portNames == null) return null;
    int count = portNames.length;
    if (count == 0) {
      atom.notifications.addError('Found no connected devices.',
          detail: 'Please connect the device and try again.\n'
              'If the device is already connected, '
              'please set the device path in\n'
              'Settings > Packages > $pluginId > Device Path',
          dismissable: true);
      return null;
    }
    if (count != 1) {
      atom.notifications.addError('Found $count connected devices.',
          detail: 'Please set the device path in\n'
              'Settings > Packages > $pluginId > Device Path',
          dismissable: true);
      return null;
    }
    portName = portNames[0];
  }
  return portName;
}

/// Return `true` the file at the given path is launchable on the device.
/// If not, notify the user and return `false`.
bool _isLaunchable(String srcPath) {
  //TODO(danrubel) assert that active editor is a Dart file
  // in a SOD or Dartino project... and is launchable.
  if (!srcPath.endsWith('.dart')) {
    atom.notifications.addError('Cannot launch app in active editor.',
        detail: 'The active editor must contain the *.dart file'
            ' to be launched on the device',
        dismissable: true);
    return false;
  }
  return true;
}

/// Build, deploy, and launch the app in the current editor
/// on a connected device.
_runAppOnDevice(event) async {
  //TODO(danrubel) integrate this into the dartlang launch functionality
  TextEditor editor = atom.workspace.getActiveTextEditor();
  String srcPath = editor.getPath();

  // Determine which SDK is associated with this app
  Sdk sdk = await findSdk(srcPath);
  if (sdk == null) return;

  // Determine the app to be built, deployed, and launched on the device
  if (!_isLaunchable(srcPath)) return;

  // Save any dirty editors before building app
  atom.workspace.getTextEditors().forEach((editor) {
    if (editor.isModified()) editor.save();
  });

  // Build the app to be run
  String dstPath = await sdk.compile(srcPath);
  if (dstPath == null) return;

  // Find the device on which to run the app
  String portName = await _findPortName();
  if (portName == null) return;

  // Deploy and run the app on the device
  if (await sdk.deployAndRun(portName, dstPath)) {
    atom.notifications.addInfo('Launched app on device');
  }
}

_showGettingStarted(event) {
  shell.openExternal('https://dartino.org/index.html');
}

_showSdkDocs(event) async {
  Sdk sdk = await findSdk(null);
  if (sdk == null) return;
  // TODO(danrubel) convert Windows file path to URI
  var uri = new Uri.file(fs.join(sdk.sdkRootPath, 'docs', 'index.html'));
  shell.openExternal(uri.toString());
}
