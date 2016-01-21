// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serial_port/serial_port.dart';

/// This program communicates with an underlying Dartino device
/// via the TTY file socket on a Linux or Mac.
///
/// With no arguments, this program will return a JSON map
/// containing a list of all connected devices.
///
/// This requires that the serial_port pub package
/// https://pub.dartlang.org/packages/serial_port
/// and manually build that on your machine
/// * cd ~/.pub-cache/hosted/pub.dartlang.org/serial_port-0.3.1
/// * pub get
/// * make
main(List<String> args) async {
  if (args.isEmpty) {
    List<String> portNames = await SerialPort.availablePortNames;
    if (Platform.isMacOS) {
      portNames.retainWhere((n) => n.startsWith('/dev/tty.usb'));
    }
    print(JSON.encode({'portNames': portNames}));
    exit(0);
  }
  var ttyPath = args[0];
  _cmds = new List.from(args.sublist(1));

  var tty = new SerialPort(ttyPath, baudrate: 115200);
  print('opening serial port $ttyPath');
  var timeout = new Duration(seconds: 3);
  await tty.open().timeout(timeout).catchError((e) {
    print('Failed to connect to $ttyPath in $timeout');
    exit(1);
  }, test: (e) => e is TimeoutException);
  print('opened $ttyPath');

  var subscription = tty.onRead.map(BYTES_TO_STRING).listen(print);
  await new Future.delayed(new Duration(milliseconds: 100));

  tty.writeString('\nfletch run\n');

  await new Future.delayed(new Duration(milliseconds: 100));
  await subscription.cancel();

  await tty.close();
  print('closed $ttyPath');

  // var ttyFile = new File(ttyPath);
  // // if (!ttyFile.existsSync()) throw 'Device not connected: $ttyPath';
  // print(ttyFile.statSync());
  //
  // var timeout = new Duration(seconds: 3);
  // _tty = await ttyFile.open(mode: READ).timeout(timeout).catchError((e) {
  //   print('Failed to connect to $ttyPath in $timeout');
  //   exit(1);
  // }, test: (e) => e is TimeoutException);
  // print('opened $ttyPath');
  // await write('\n');
  // await read();
  // while (_cmds.isNotEmpty) {
  //   String cmd = _cmds.removeAt(0);
  //   if (cmd == 'exit') break;
  //   await write('$cmd\n');
  //   await read();
  // }
  // echoLine();
  // print('complete');
}

RandomAccessFile _tty;
List<String> _cmds;
String _lastLine = '';
StringBuffer _line = new StringBuffer();

String echo(List<int> bytes) {
  String ch = UTF8.decode(bytes);
  if (ch != '\n') {
    _line.write(ch);
  } else {
    echoLine();
  }
  return ch;
}

void echoLine() {
  _lastLine = _line.toString();
  print('> $_lastLine');
  _line.clear();
}

Future read() async {
  bool done() {
    if (_line.length == 0) {
      bool halted = _lastLine.startsWith('HALT: ');
      if (halted) _cmds.clear();
      return halted;
    }
    if (_line.length == 1) {
      return _line.toString() == ']';
    }
    return false;
  }
  echo(await _tty.read(1));
  while (!done()) {
    echo(await _tty.read(1));
  }
}

Future write(String text) async {
  for (int byte in UTF8.encode(text)) {
    await _tty.writeByte(byte);
    echo(await _tty.read(1));
  }
}
