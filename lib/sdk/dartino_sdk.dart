// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk.dartino;

import 'dart:async';
import 'dart:convert';

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';

import '../dartino.dart' show pluginId;
import '../proc.dart';
import 'sdk.dart';
import 'sdk_util.dart';

class DartinoSdk extends Sdk {
  DartinoSdk(String sdkRootPath) : super(sdkRootPath);

  @override
  Future<String> compile(String srcPath) async {
    String srcDir = srcPath.substring(0, srcPath.lastIndexOf(fs.separator));
    String srcName = srcPath.substring(srcDir.length + 1);
    String dstPath = srcPath.substring(0, srcPath.length - 5) + '.bin';

    String buildScript = sdkRootPath +
        '/platforms/stm32f746g-discovery/bin/build.sh'
            .replaceAll('/', fs.separator);

    //TODO(danrubel) show progress while building rather than individual dialogs
    var info = atom.notifications
        .addInfo('Building application...', detail: srcPath, dismissable: true);
    String stdout = await runProc(buildScript,
        args: [srcPath],
        cwd: srcDir,
        summary: 'building $srcName',
        detail: srcPath);
    info.dismiss();
    if (stdout == null) return null;
    if (!fs.existsSync(dstPath)) {
      atom.notifications.addError('Failed to build the app',
          dismissable: true, detail: 'Expected build to generate $dstPath');
      return null;
    }
    atom.notifications.addSuccess('Build successful.');
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
        String stdout = await runProc('df', summary: 'list connected devices');
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
      var stdout = await runProc('cp',
          args: [dstPath, deviceDir], summary: 'deploy app to device');
      return stdout != null;
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
    //TODO(danrubel) show progress while downloading rather than individual dialogs
    atom.notifications.addInfo('Downloading additional Dartino tools...',
        detail: 'into $sdkRootPath', dismissable: true);
    String stdout = await runProc('bin/dartino',
        args: ['x-download-tools'],
        cwd: sdkRootPath,
        summary: 'download additional Dartino tools');
    return stdout != null;
  }
}
