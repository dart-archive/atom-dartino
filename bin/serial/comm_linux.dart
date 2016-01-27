// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.linux;

import 'dart:async';
import 'dart:io';

import 'comm.dart';

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
  if (ttyFile == null) {
    return null;
  }
  var comm = new TtyFileCommPort(portName, ttyFile);

  // If establishing a connection times out, return null
  if (await comm.init(timeout)) return comm;
  comm.disconnect();
  return null;
}

/// An implementation of [CommPort] that uses /dev/ttyACM*
/// to interact the the connected device.
class TtyFileCommPort extends CommPort {
  /// The connection to the device.
  final RandomAccessFile ttyFile;

  TtyFileCommPort(String name, this.ttyFile) : super(name);

  /// Initialize the connection and return `true` if successful, else `false`.
  Future<bool> init(Duration timeout) =>
      send('', timeout: timeout).then((result) => result != null);

  @override
  Future<String> send(String text, {Duration timeout}) async {
    timeout ??= CommPort.defaultTimeout;

    // Send the command
    bool success = await ttyFile
        .writeString('$text\n')
        .then((_) => true)
        .timeout(timeout)
        .catchError((_) => false, test: (e) => e is TimeoutException);
    if (!success) return null;

    // Wait for a response
    bool newline = false;
    StringBuffer received = new StringBuffer();
    while (true) {
      int byte = await ttyFile
          .readByte()
          .timeout(timeout)
          .catchError((_) => null, test: (e) => e is TimeoutException);
      if (byte == null) return null;
      var ch = new String.fromCharCode(byte);
      received.write(ch);
      if (newline && ch == ']') {
        return received.toString();
      }
      newline = ch == '\n' || ch == '\r';
    }
  }

  @override
  Future disconnect() => ttyFile.close();
}
