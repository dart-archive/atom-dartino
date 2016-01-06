// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// This program communicates with an underlying Dartino device
/// via the TTY file socket on a Linux or Mac.
main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: <ttyPath> list-of-cmds');
    exit(1);
  }
  var ttyPath = args[0];
  _cmds = new List.from(args.sublist(1));
  var ttyFile = new File(ttyPath);
  // if (!ttyFile.existsSync()) throw 'Device not connected: $ttyPath';

  _tty = await ttyFile.open(mode: WRITE);
  print('opened $ttyPath');
  await write('\n');
  await read();
  while (_cmds.isNotEmpty) {
    String cmd = _cmds.removeAt(0);
    if (cmd == 'exit') break;
    await write('$cmd\n');
    await read();
  }
  echoLine();
  print('complete');
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
