// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'serial/comm.dart';
import 'serial/tftp_client.dart';

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
  _comm = await CommPort.open(portName).catchError((e, s) {
    _error('Exception connecting to $portName', e, s);
    exit(1);
  });
  if (_comm == null) {
    _error('Timed out connecting to $portName');
    exit(1);
  }

  // Notify client of successful connect
  print('connected to $portName');
  _success();

  // Setup a client request stream
  StreamController<String> controller = new StreamController();
  // _comm.disconnected.then((_) {
  //   controller.add('exit');
  // });
  StreamSubscription stdinSubscription = stdin
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen((String line) {
    controller.add(line);
  });

  // Process requests until exit
  await for (String line in controller.stream) {
    if (!await _processRequest(line)) break;
  }

  print('disconnecting');
  await stdinSubscription.cancel();
  await _comm.close();
  _comm = null;
  print('disconnected');
}

/// The connection to the device.
CommPort _comm;

//==== Processing =============================

/// Process the given client command.
/// Return a future that completes when the reqeust has been processed
/// with `true` if processing should continue, else `false`.
Future<bool> _processRequest(String line) async {
  String cmd;
  Map args;
  if (line.startsWith('{')) {
    Map json = JSON.decode(line);
    cmd = json['request'];
    args = json['arguments'];
  } else {
    List<String> split = line.split(' ');
    cmd = split[0].trim();
    args = {};
    for (int index = 1; index + 1 < split.length; index += 2) {
      args[split[index]] = split[index + 1];
    }
  }
  if (cmd == 'exit') return _exit();
  if (cmd == 'run') return _run(args);
  _error('Unknown command: $line');
  return true;
}

//==== Commands =============================

/// Deploy the application specificed in the arguments to the device
/// and then run that application on the device.
/// Return a future that completes when the operation is finished.
Future<bool> _run(Map args) async {
  if (args == null) return _runDefaultApp();
  String snapPath = args['path'];
  if (snapPath == null || snapPath.isEmpty) return _runDefaultApp();
  String snapName = snapPath.split(Platform.pathSeparator).last;

  // Ping the device to see if it is connected
  String deviceIp = '192.168.0.98';
  print('ping $deviceIp to see if it is connected');
  Process process = await Process.start('ping', ['-c1', deviceIp]);
  var exitCode = await process.exitCode
      .timeout(new Duration(seconds: 5))
      .catchError((e) => 92, test: (e) => e is TimeoutException);
  if (exitCode != 0) {
    _error('Failed to ping device at $deviceIp');
    return true;
  }

  // Signal the device to receive the payload
  //   ] fletch lines.snap
  //   waiting for lines.snap via TFTP. mode: run
  //       --- send binary via tftp here ---
  //   ] starting fletch-vm...
  //   loading snapshot: 31651 bytes ...
  //   running program...
  print('request device receive binary');
  String response = await _comm.send('fletch $snapName');
  if (response == null) {
    _error('Request timed out.');
    return true;
  }
  if (!response.contains('waiting for') || !response.contains('via TFTP')) {
    _error('Unexpected response from device:\n$response');
    return true;
  }

  print('send binary to device using tftp $deviceIp');
  String errMsg = await new TftpClient(deviceIp).putBinary(snapPath, snapName);
  if (errMsg != null) {
    _error('Failed to send $snapPath to $deviceIp.\n$errMsg');
    return true;
  }

  _success();
  return true;
}

/// Run the default app that is already flashed on the device.
Future<bool> _runDefaultApp() async {
  String response = await _comm.send('fletch run');
  print('device response $response');
  if (response == null) {
    _error('Request timed out');
    return true;
  }
  if (response.contains('starting fletch-vm')) {
    _success(detail: response);
  } else {
    _error('Did not receive confirmation that app started', response);
  }
  return true;
}

/// Close connections and exit this application without stopping the device.
Future<bool> _exit() async {
  _success();
  return false;
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
