// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm;

import 'dart:async';
import 'dart:io';

import 'comm_linux.dart' deferred as linux;
import 'comm_mac.dart' deferred as mac;
import 'comm_windows.dart' deferred as windows;

/// A communication port for interacting with an attached device.
abstract class CommPort {
  static Duration defaultTimeout = new Duration(seconds: 3);

  /// Return a list of port names for connected devices.
  static Future<List<String>> list() async {
    if (Platform.isWindows) {
      await windows.loadLibrary();
      return windows.list();
    } else if (Platform.isMacOS) {
      await mac.loadLibrary();
      return mac.list();
    } else {
      await linux.loadLibrary();
      return linux.list();
    }
  }

  /// Connect to and return a connection to the specified device.
  /// If a timeout is not specified, then a default timeout will be used.
  /// If the operation times out, then Future `null` will be returned.
  /// A connect may timeout if the user does not have the appropriate
  /// permissions to access the given port.
  /// Any other problem will result in an exception on the returned Future.
  static Future<CommPort> open(String portName, {Duration timeout}) async {
    if (Platform.isWindows) {
      await windows.loadLibrary();
      return windows.connect(portName, timeout ?? defaultTimeout);
    } else if (Platform.isMacOS) {
      await mac.loadLibrary();
      return mac.connect(portName, timeout ?? defaultTimeout);
    } else {
      await linux.loadLibrary();
      return linux.connect(portName, timeout ?? defaultTimeout);
    }
  }

  /// The name of the communication port (e.g. /dev/ttyACM0 or COM3).
  final String name;

  CommPort(this.name);

  /// Send a command over the communication port
  /// and return the text that was received.
  /// If a timeout is not specified, then a default timeout will be used.
  /// If the operation times out, then Future `null` will be returned.
  /// Any other problem will result in an exception on the returned Future.
  Future<String> send(String text, {Duration timeout});

  /// Close the port and return a future that completes.
  Future close();
}
