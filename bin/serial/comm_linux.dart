// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.linux;

import 'dart:async';
import 'dart:io';

import 'comm.dart';
import 'tty_file_comm_port.dart';

/// Clients should call [Comm.list] rather than this method.
///
/// Return a list of port names for connected devices.
Future<List<String>> list() async {
  ProcessResult result = await Process.run('ls', ['-1', '/dev']);
  if (result.exitCode != 0) {
    throw 'failed to get a list of connected devices'
        '\n  exit code: $exitCode';
  }
  return result.stdout
      .split('\n')
      .where((String name) => name.startsWith('ttyACM'))
      .map((name) => '/dev/$name')
      .toList();
}

/// Clients should call [Comm.connect] rather than this method.
///
/// Connect to and return a connection to the specified port.
/// If a timeout is not specified, then a default timeout will be used.
/// If the operation times out, then Future `null` will be returned.
/// Any other problem will result in an exception on the returned Future.
Future<CommPort> connect(String portName, Duration timeout) async {
  RandomAccessFile ttyFile = await new File(portName)
      .open(mode: FileMode.WRITE)
      .timeout(timeout)
      .catchError((e) => null, test: (e) => e is TimeoutException);
  if (ttyFile == null)
    return null;
  var comm = new TtyFileCommPort(portName, ttyFile);

  // If establishing a connection times out, return null
  if (await comm.init(timeout)) return comm;
  comm.close();
  return null;
}
