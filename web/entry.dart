// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.entry;

import 'package:atom_dartino/dartino.dart';
import 'package:logging/logging.dart';

main() {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord r) {
    String tag = '${r.level.name.toLowerCase()} • ${r.loggerName}:';
    print('${tag} ${r.message}');

    if (r.error != null)      print('${tag}   ${r.error}');
    if (r.stackTrace != null) print('${tag}   ${r.stackTrace}');
  });

  registerPackage(new DartinoDevPackage());
}
