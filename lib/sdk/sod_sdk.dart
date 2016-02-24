// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.sdk.sod;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';

import '../dartino.dart' show pluginId;
import '../proc.dart';
import '../usb.dart';
import 'sdk.dart';
import 'sdk_util.dart';

class SodSdk extends Sdk {
  SodSdk(String sdkRoot) : super(sdkRoot);

  @override
  Future<String> compile(String srcPath) async {
    String srcDir = srcPath.substring(0, srcPath.lastIndexOf(fs.separator));
    String srcName = srcPath.substring(srcDir.length + 1);
    String dstPath = srcPath.substring(0, srcPath.length - 5) + '.snap';

    //TODO(danrubel) show progress while building rather than individual dialogs
    var info = atom.notifications
        .addInfo('Building application...', detail: dstPath, dismissable: true);
    String stdout = await runProc('make',
        args: [dstPath], cwd: sdkRootPath, summary: 'build $srcName');
    info.dismiss();
    if (stdout == null) return null;
    atom.notifications.addSuccess('Build successful.');
    return dstPath;
  }

  @override
  Future<bool> deployAndRun(String deviceName, String dstPath) {
    return sendDeviceCmd(deviceName, 'run', args: {'path': dstPath});
  }

  @override
  Future<bool> verifyInstall({String suggestion}) async {
    if (!checkSdkFile(
        'SOD',
        sdkRootPath,
        ['makefile', 'third_party/openocd/README.md'],
        suggestion ?? 'Please use gclient to install SOD and set the SOD path in\n'
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
