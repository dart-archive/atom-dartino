// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

final int promptChar = ']'.codeUnitAt(0);

/// Simple test using basic file I/O to interact with TTY USB device.
main(args) async {
  print('connecting to ${args[0]}');
  RandomAccessFile devFile = await new File(args[0]).open(mode: FileMode.WRITE);

  print('waiting for prompt');
  await devFile.writeString('\n');
  int byte = await devFile.readByte();
  while (byte != promptChar) {
    byte = await devFile.readByte();
  }

  print('running app');
  await devFile.writeString('fletch run\n');
  byte = await devFile.readByte();
  while (byte != promptChar) {
    byte = await devFile.readByte();
  }

  await new Future.delayed(new Duration(seconds: 1));
  await devFile.close();

  print('finished');
}
