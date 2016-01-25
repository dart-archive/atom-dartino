// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Simple test using basic shell apps to interact with TTY USB device.
main(args) async {
  print('connecting to ${args[0]}');
  // new File(args[0]).writeAsStringSync('');
  Process echo = await Process.start('echo', ['', '>', args[0]], runInShell: true);
  echo.exitCode.then((exitCode) => print('echo exit code $exitCode'));
  await new Future.delayed(new Duration(milliseconds: 1000));
  Process cat = await Process.start('cat', [args[0]]);
  StreamSubscription stderrSubscription = cat.stderr.transform(UTF8.decoder).listen((data) => print);
  StreamSubscription stdoutSubscription = cat.stdout.transform(UTF8.decoder).listen((data) => print);
  cat.exitCode.then((exitCode) => print('cat exit code $exitCode'));
  print('connected');
  // new File(args[0]).writeAsStringSync('fletch run');
  await new Future.delayed(new Duration(milliseconds: 1000));
  echo = await Process.start('echo', ['fletch run', '>', args[0]]);
  echo.exitCode.then((exitCode) => print('echo exit code $exitCode'));
  await new Future.delayed(new Duration(milliseconds: 10000));
  await stdoutSubscription.cancel();
  await stderrSubscription.cancel();
  print('finished');
}
