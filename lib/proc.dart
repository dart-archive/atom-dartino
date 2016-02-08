// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.proc;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/process.dart';

/// Execute an external process and return a [Future] that completes
/// with the contents of stdout.
/// If there is a problem, notify the user and return `null`.
Future<String> runProc(String executable,
    {List<String> args: const [],
    String cwd,
    String summary: '',
    String detail: ''}) async {
  var runner = new ProcessRunner(executable, args: args, cwd: cwd);

  var result;
  var exception;
  var stackTrace;
  try {
    // Even with all this, it appears some exceptions thrown in JS
    // to not get translated to Dart, but instead open JS dev tools console.
    result = await runner.execSimple().catchError((e, s) {
      exception = e;
      stackTrace = s;
      return null;
    });
  } catch (e, s) {
    exception = e;
    stackTrace = s;
  }

  if (exception != null || result.exit != 0) {
    detail += '\n$executable $args';
    if (exception != null) {
      detail += '\n$exception\n$stackTrace';
    } else {
      detail += '\nexit code ${result.exit}';
      detail += '\n${result.stderr}\n${result.stdout}';
    }
    atom.notifications
        .addError('Failed to $summary.', detail: detail, dismissable: true);
    return null;
  }
  return result.stdout;
}
