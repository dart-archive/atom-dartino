// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../bin/serial/comm.dart';

/// Simple test for accessing STM32 Discovery with SOD using comm library.
main(List<String> args) async {
  List<String> names = await CommPort.list();
  if (names.length == 0) {
    print('Did not find any connected devices.');
    exit(1);
  }
  print('Connected devices:');
  for (String name in names) {
    print('  $name');
  }
  String portName = names[0];
  print('Connecting to $portName');
  CommPort port = await CommPort.open(portName);
  if (port == null) {
    print('Timed out trying to connect');
    exit(1);
  }
  print('Sending command');
  String result = await port.send('fletch run');
  print('--- Response ------------\n$result\n-------------------------');
  await port.close();
  print('Disconnected');
}
