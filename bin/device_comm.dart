// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'serial/comm.dart';

/// This program communicates with an underlying Dartino device.
///
/// Launch: device_comm.dart <portName>
/// where <portName> is the path used to communicate with the tty device
/// (e.g. dart device_comm.dart /dev/tty.usbmodem1314)
///
/// If no arguments are supplied, then this returns a list of connected
/// devices and exits. If a portName is supplied, then a communications port
/// is opened to that device and this listens on stdin for commands.
///
/// Send commands to the device via stdin where each line is considered a command.
/// If the line starts with '{' then it is interpreted as a JSON formatted
/// command otherwise the line is interpreted as a simple command.
///
/// Results from executing commands are sent to stdout.
/// Any output line that starts with '{' is JSON formatted progress update
/// or command result where as all other lines are debugging output
/// and should be ignored.
main(List<String> args) async {
  if (args.length == 0) {
    List<String> list = await CommPort.list().catchError((e, s) {
      _error('Exception listing connected devices', e, s);
      exit(1);
    });
    if (list == null) {
      _error('Timed out listing connected devices');
      exit(1);
    }
    _success(list: list);
    exit(0);
  }
  if (args.length != 1) {
    _error('Expected no arguments or <portName>,'
        ' but found ${args.length} arguments');
    exit(1);
  }
  var portName = args[0];

  // Connect
  print('connecting to $portName');
  _comm = await CommPort.connect(portName).catchError((e, s) {
    _error('Exception connecting to $portName', e, s);
    exit(1);
  });
  if (_comm == null) {
    _error('Timed out connecting to $portName');
    exit(1);
  }
  print('connected to $portName');

  // Setup stream to listen for client commands
  _running = true;
  while (_running) {
    await _processRequest(stdin.readLineSync());
  }

  print('disconnecting');
  await _comm.disconnect();
  _comm = null;
  print('disconnected');
}

/// The connection to the device.
CommPort _comm;

bool _running;

/// The default timeout when waiting on information from the device
Duration _timeout = new Duration(seconds: 3);

//==== Processing =============================

/// Process the given client command.
Future _processRequest(String line) async {
  print('received request $line');
  String cmd;
  if (line.startsWith('{')) {
    cmd = JSON.decode(line)['request'];
  } else {
    cmd = line.trim();
  }
  print('processing request $cmd');
  if (cmd == 'run') return _runDefaultApp();
  if (cmd == 'exit') return _exit();
  _error('Unknown command: $line');
}

//==== Commands =============================

/// Run the default app that is already flashed on the device.
_runDefaultApp() async {
  String response = await _comm.send('fletch run');
  print('device response $response');
  if (response == null) return;
  if (response.contains('starting fletch-vm')) {
    _success(detail: response);
  } else {
    _error('Did not receive confirmation that app started', response);
  }
}

/// Close connections and exit this application without stopping the device.
Future _exit() async {
  _success();
  _running = false;
}

//==== Utility =============================

/// Send an error message back to the client.
void _error(String message, [exception, stackTrace]) {
  Map<String, dynamic> error = {};
  error['message'] = message;
  if (exception != null || stackTrace != null) {
    StringBuffer detail = new StringBuffer();
    if (exception != null) detail.writeln(exception);
    if (stackTrace != null) detail.write(_inline(stackTrace));
    error['detail'] = detail.toString();
  }
  print(JSON.encode({'error': error}));
}

/// Send a success message back to the client.
void _success({List<String> list, String detail}) {
  Map<String, dynamic> result = {'message': 'success'};
  if (list != null) result['list'] = list;
  if (detail != null) result['detail'] = _inline(detail);
  print(JSON.encode({'result': result}));
}

/// Encode the given data such that
///   \ --> \\
///   carriage return newline --> \n
///   carriage return --> \n
///   newline --> \n
String _inline(data) => data
    .toString()
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\r', '\\n')
    .replaceAll('\n', '\\n');
