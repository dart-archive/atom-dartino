// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.mac;

import 'dart:async';
import 'dart:io';

import 'package:serial_port/serial_port.dart';

import 'comm.dart';

/// Clients should call [Comm.list] rather than this method.
///
/// Return a list of port names for connected devices.
Future<List<String>> list() async {
  ProcessResult result = await Process.run('ls', ['-1', '/dev']);
  if (result.exitCode != 0) {
    throw 'failed to get a list of connected devices'
        '\n  exit code: $exitCode';
  }
  return result.stdout
      .split('\n')
      .where((String name) => name.startsWith('tty.usb'))
      .map((name) => '/dev/$name')
      .toList();
}

/// Clients should call [Comm.connect] rather than this method.
///
/// Connect to and return a connection to the specified port.
/// If a timeout is not specified, then a default timeout will be used.
/// If the operation times out, then Future `null` will be returned.
/// Any other problem will result in an exception on the returned Future.
Future<CommPort> connect(String portName, Duration timeout) async {
  SerialPort serialPort = new SerialPort(portName, baudrate: 115200);
  bool timedOut = false;
  await serialPort
      .open()
      .timeout(timeout)
      .catchError((e) => timedOut = true, test: (e) => e is TimeoutException);
  if (timedOut || !serialPort.isOpen) return null;
  var comm = new SerialCommPort(portName, serialPort);

  // If establishing a connection times out, return null
  if (await comm.init(timeout)) return comm;
  comm.disconnect();
  return null;
}

/// An implementation of [CommPort] that uses the serial_port package
/// to interact the the connected device.
class SerialCommPort extends CommPort {
  final SerialPort serialPort;
  final StringBuffer _received = new StringBuffer();
  StreamSubscription _subscription;
  Completer _completer = new Completer();

  SerialCommPort(String portName, this.serialPort) : super(portName);

  /// Initialize the connection and return `true` if successful, else `false`.
  Future<bool> init(Duration timeout) async {
    // Setup listener to capture device output
    _subscription =
        serialPort.onRead.map(BYTES_TO_STRING).listen((String data) {
      _received.write(data);
      if (data.contains('\n]')) {
        if (!_completer.isCompleted) _completer.complete();
      }
    });

    // Establish a connection
    String result = await send('', timeout: new Duration(milliseconds: 10));
    if (result != null) return true;
    result = await send('', timeout: new Duration(milliseconds: 10));
    if (result != null) return true;
    result = await send('', timeout: timeout);
    return result != null;
  }

  @override
  Future<String> send(String text, {Duration timeout}) async {
    timeout ??= CommPort.defaultTimeout;
    _received.clear();
    _completer = new Completer();

    // Send the command
    bool success = await serialPort
        .writeString('$text\n')
        .then((_) => true)
        .timeout(timeout)
        .catchError((_) => false, test: (e) => e is TimeoutException);
    if (!success) return null;

    // Wait for a response
    return _completer.future
        .then((_) => _received.toString())
        .timeout(timeout)
        .catchError((_) => null, test: (e) => e is TimeoutException)
        .then((result) {
      return result;
    });
  }

  @override
  Future disconnect() async {
    if (_subscription != null) {
      await _subscription.cancel();
      _subscription = null;
    }
    _received.clear();
    return serialPort.close();
  }
}
