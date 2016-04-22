// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.grind;

import 'dart:io';

import 'package:atom/build/build.dart';
import 'package:atom/build/publish.dart';
import 'package:grinder/grinder.dart';

main(List<String> args) => grind(args);

@Task()
analyze() => new PubApp.global('tuneup').runAsync(['check']);

@DefaultTask()
build() async {
  File inputFile = getFile('web/entry.dart');
  File outputFile = getFile('web/entry.dart.js');

  // --trust-type-annotations? --trust-primitives?
  await Dart2js.compileAsync(inputFile, csp: true);
  outputFile.writeAsStringSync(patchDart2JSOutput(outputFile.readAsStringSync()));
}

@Task()
@Depends(build) //analyze, build, test, runAtomTests)
publish() => publishAtomPlugin();

// TODO: A no-op for now.
@Task()
test() => null;
// test() => Dart.runAsync('test/all.dart');

// TODO: Removed the `ddc` dep task for now.
@Task()
@Depends(analyze, build, test) //, runAtomTests)
bot() => null;

@Task()
clean() {
  delete(getFile('web/entry.dart.js'));
  delete(getFile('web/entry.dart.js.deps'));
  delete(getFile('web/entry.dart.js.map'));
}
