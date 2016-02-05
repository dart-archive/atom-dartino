// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk.dartino;

import 'dart:async';
import 'dart:convert';

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';
import 'package:atom_dartino/sdk/sdk.dart';
import 'package:atom_dartino/sdk/sdk_util.dart';

import '../dartino.dart' show pluginId;
import 'package:atom_dartino/proc.dart';

class DartinoSdk extends Sdk {
  DartinoSdk(String sdkRootPath) : super(sdkRootPath);

  @override
  Future<String> compile(String srcPath) async {
    String srcDir = srcPath.substring(0, srcPath.lastIndexOf(fs.separator));
    String dstPath = srcPath.substring(0, srcPath.length - 5) + '.bin';

    String buildScript = sdkRootPath +
        '/platforms/stm32f746g-discovery/bin/build.sh'
            .replaceAll('/', fs.separator);
    ProcessRunner runner =
        new ProcessRunner(buildScript, args: [srcPath], cwd: srcDir);

    //TODO(danrubel) show progress while building
    atom.notifications
        .addInfo('Building application...', detail: srcPath, dismissable: true);
    ProcessResult processResult = await runner.execSimple();
    String stdout = processResult.stdout;
    if (processResult.exit != 0) {
      atom.notifications.addError('Failed to build the app',
          dismissable: true,
          detail: 'exit code ${processResult.exit}\n${stdout}'
              '\n${processResult.stderr}');
      return null;
    }
    if (!fs.existsSync(dstPath)) {
      atom.notifications.addError('Failed to build the app',
          dismissable: true, detail: 'Expected build to generate $dstPath');
      return null;
    }
    atom.notifications.addSuccess('Build successful.', dismissable: true);
    return dstPath;
  }

  @override
  Future<bool> deployAndRun(String deviceName, String dstPath) async {
    //TODO(danrubel) move this into the command line utility
    if (isMac || isLinux) {
      var deviceDir;
      if (isMac) {
        deviceDir = '/Volumes/DIS_F746NG';
      } else {
        deviceDir = '/media';
        String stdout = await runSync('df', summary: 'list connected devices');
        if (stdout == null) return false;
        for (String line in LineSplitter.split(stdout)) {
          if (line.endsWith('/DIS_F746NG')) {
            deviceDir = line.substring(line.lastIndexOf(' /') + 1);
            break;
          }
        }
      }
      var deviceFile = '$deviceDir/MBED.HTM';
      if (!fs.existsSync(deviceFile)) {
        atom.notifications.addError('Cannot find connected device.',
            detail: deviceFile, dismissable: true);
        return false;
      }
      var runner = new ProcessRunner('cp', args: [dstPath, deviceDir]);
      var result = await runner.execSimple();
      if (result.exit != 0) {
        atom.notifications.addError('Failed to deploy app to device.',
            detail: 'Device $deviceDir\nexit code ${result.exit}\n'
                '${result.stdout}\n${result.stderr}\n',
            dismissable: true);
        return false;
      }
      return true;
    }
    if (isWindows) {
      // TODO
    }
    atom.notifications.addError('OS not supported yet.', dismissable: true);
    return false;
  }

  @override
  Future<bool> verifyInstall() async {
    if (!checkSdkFile(
        'Dartino',
        sdkRootPath,
        ['platforms/stm32f746g-discovery/bin/build.sh'],
        'Please download the SDK set the Dartino SDK path in\n'
        'Settings > Packages > $pluginId > Dartino root directory')) {
      return false;
    }

    // Check to see if tools have already been downloaded
    String relPath = 'tools/gcc-arm-embedded/bin/arm-none-eabi-gcc';
    relPath = relPath.replaceAll('/', fs.separator);
    if (fs.existsSync(fs.join(sdkRootPath, relPath))) return true;

    // Launch external process to download tools
    ProcessRunner runner = new ProcessRunner('bin/dartino',
        args: ['x-download-tools'], cwd: sdkRootPath);
    //TODO(danrubel) show progress while building
    atom.notifications.addInfo('Downloading additional Dartino tools...',
        detail: 'into $sdkRootPath', dismissable: true);
    ProcessResult processResult = await runner.execSimple();
    String stdout = processResult.stdout;
    if (processResult.exit != 0) {
      atom.notifications.addError('Failed to download additional tools',
          dismissable: true,
          detail: 'Please run  bin/dartino x-download-tools\n'
              'from $sdkRootPath\n-----\n'
              'exit code ${processResult.exit}\n${stdout}'
              '\n${processResult.stderr}');
      return false;
    }
    return true;
  }
}
