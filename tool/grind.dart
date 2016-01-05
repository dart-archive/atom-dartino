// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.grind;

import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:atom/build/build.dart';

main(List<String> args) => grind(args);

@Task()
analyze() => new PubApp.global('tuneup').runAsync(['check']);

@DefaultTask()
build() async {
  File inputFile = getFile('web/entry.dart');
  File outputFile = getFile('web/entry.dart.js');

  // --trust-type-annotations? --trust-primitives?
  await Dart2js.compileAsync(inputFile, csp: true);

  // Patch the generated JS so that it works with Atom
  String jsCode = outputFile.readAsStringSync();
  jsCode = patchDart2JSOutput(jsCode);

  // Patch in the GA UA code; replace "UA-000000-0" with a valid code.
  String uaCode = Platform.environment['DARTINO_UA'];
  if (uaCode != null) {
    log('Patching with the dartlang Google Analytics code.');
    jsCode = jsCode.replaceAll('"UA-000000-0"', '"${uaCode}"');
  } else {
    log('No \$DARTINO_UA environment variable set.');
  }

  // Save the modified JS
  outputFile.writeAsStringSync(jsCode);
}

@Task()
test() => Dart.runAsync('test/all.dart');

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
