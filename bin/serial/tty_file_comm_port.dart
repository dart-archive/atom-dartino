// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.tty_file;

import 'dart:async';
import 'dart:io';

import 'comm.dart';

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
