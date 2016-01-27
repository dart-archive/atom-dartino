// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.windows;

import 'dart:async';

import 'comm.dart';

/// Clients should call [Comm.list] rather than this method.
///
/// Return a list of port names for connected devices.
Future<List<String>> list() async {
  throw 'Windows not supported yet';
}

/// Clients should call [Comm.connect] rather than this method.
///
/// Connect to and return a connection to the specified port.
/// If a timeout is not specified, then a default timeout will be used.
/// If the operation times out, then Future `null` will be returned.
/// Any other problem will result in an exception on the returned Future.
Future<CommPort> connect(String portName, Duration timeout) async {
  throw 'Windows not supported yet';
}
