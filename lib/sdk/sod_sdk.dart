// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk.sod;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/process.dart';
import 'package:atom_dartino/dartino.dart' show pluginId;
import 'package:atom_dartino/sdk/sdk.dart';
import 'package:atom_dartino/sdk/sdk_util.dart';
import 'package:atom_dartino/usb.dart';

class SodSdk extends Sdk {
  SodSdk(String sdkRoot) : super(sdkRoot);

  @override
  Future<String> compile(String srcPath) async {
    String dstPath = srcPath.substring(0, srcPath.length - 5) + '.snap';

    ProcessRunner runner =
        new ProcessRunner('make', args: [dstPath], cwd: sdkRootPath);
    //TODO(danrubel) show progress while building
    atom.notifications
        .addInfo('Building application...', detail: dstPath, dismissable: true);
    ProcessResult processResult = await runner.execSimple();
    String stdout = processResult.stdout;
    if (processResult.exit != 0) {
      atom.notifications.addError('Failed to build the app',
          dismissable: true,
          detail: 'exit code ${processResult.exit}\n${stdout}'
              '\n${processResult.stderr}');
      return null;
    }
    atom.notifications.addSuccess('Build successful.', dismissable: true);
    return dstPath;
  }

  @override
  Future<bool> deployAndRun(String deviceName, String dstPath) {
    return sendDeviceCmd(deviceName, 'run', args: {'path': dstPath});
  }

  @override
  Future<bool> verifyInstall() async {
    if (!checkSdkFile(
        'SOD',
        sdkRootPath,
        ['makefile', 'third_party/openocd/README.md'],
        'Please use gclient to install SOD and set the SOD path in\n'
        'Settings > Packages > $pluginId > SOD root directory')) return false;
    if (!checkSdkFile(
        'SOD',
        sdkRootPath,
        ['third_party/lk/platform/stm32f7xx/init.c'],
        'It appears that SOD was install using git clone rather than gclient.\n'
        'Please use gclient to install SOD as per SOD build instructions'))
      return false;
    return true;
  }
}
