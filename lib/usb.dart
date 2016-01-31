// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.dartino.usb;

import 'dart:async';
import 'dart:convert';

import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/process.dart';
import 'package:logging/logging.dart';

import 'dartino.dart' show pluginId;

/// A map of ttyPath to connected Device
final Map<String, Device> _devices = {};

final Logger _logger = new Logger('$pluginId/usb');

/// The default communication timeout.
final Duration _timeout = new Duration(seconds: 4);

/// Return a list of port names for USB connected TTY devices.
/// If there is an error, notify the user and return `null`.
Future<List<String>> connectedDevices() async {
  if (_vmPath == null || _deviceCommPath == null) return null;
  ProcessRunner runner = new ProcessRunner(_vmPath, args: [_deviceCommPath]);
  ProcessResult processResult = await runner.execSimple();
  String stdout = processResult.stdout;
  if (processResult.exit != 0) {
    atom.notifications.addError('Failed to find connected devices',
        dismissable: true,
        detail: 'Please set the device path in '
            'Settings > Packages > $pluginId > Device Path\n\n'
            'exit code ${processResult.exit}\n${stdout}'
            '\n${processResult.stderr}');
    return null;
  }
  for (String line in stdout.split('\n')) {
    if (line.startsWith('{')) {
      Map result = _decodeResult(line, stdout);
      if (result != null) {
        List<String> list = result['list'];
        if (list != null) return list;
      }
      return null;
    }
  }
  _notifyRequestFailed(null, stdout);
  return null;
}

/// Send commands to a connected device.
/// Return `true` if successful, otherwise notify the user and return `false`.
Future<bool> sendDeviceCmd(ttyPath, String cmd, {Map args}) async {
  Device device = _devices[ttyPath];
  if (device == null) {
    device = new Device(ttyPath);
    if (!await device.connect()) return false;
    _devices[ttyPath] = device;
  }
  return device.send(cmd, args);
}

/// A connected device with an active communication connection.
class Device {
  final String ttyPath;
  ProcessRunner _runner;
  StreamSubscription<String> _stderrSubscription;
  StreamSubscription<String> _stdoutSubcription;
  Completer<String> _responseCompleter;
  final StringBuffer _rawOutput = new StringBuffer();

  Device(this.ttyPath);

  /// Connect to the device.
  /// Return `true` if successfully connected,
  /// otherwise notify the user and return `false`.
  Future<bool> connect() async {
    _logger.fine('connect');
    if (_runner != null) throw 'already connected to $ttyPath';
    if (_vmPath == null || _deviceCommPath == null) return false;

    // Launch an external process to communicate with the device
    List<String> runnerArgs = [_deviceCommPath, ttyPath];
    _logger.fine('launching process: $_vmPath $runnerArgs');
    _runner = new ProcessRunner(_vmPath, args: runnerArgs);
    _runner.execStreaming().then((int exitCode) {
      _logger.fine('Device disconnected [$exitCode]: $ttyPath');
      _runner = null;
      _cleanup();
    });
    _logger.fine('launched');

    // Wait for process to start
    _stderrSubscription =
        _runner.onStderr.transform(new LineSplitter()).listen(_processStderr);
    _stdoutSubcription =
        _runner.onStdout.transform(new LineSplitter()).listen(_processStdout);
    _responseCompleter = new Completer();
    _logger.fine('waiting for process to start');
    if (await _nextResult() == null) return false;
    _logger.fine('process started');
    return true;
  }

  /// Send the specified command and return `true` if successful.
  /// If there is a problem, notify the user and return `false`.
  Future<bool> send(String cmd, Map args) async {
    Future<Map> futureResult = _nextResult();
    Map request = {'request': cmd};
    if (args != null) request['arguments'] = args;
    _runner.write('${JSON.encode(request)}\n');
    Map result = await futureResult;
    return result != null;
  }

  /// Disconnect and discard the connection to this device.
  void _cleanup() {
    _devices.remove(ttyPath);
    _stderrSubscription?.cancel();
    _stderrSubscription = null;
    _stdoutSubcription?.cancel();
    _stdoutSubcription = null;
    _runner?.kill();
    _runner = null;
  }

  /// Wait for and return the next result from the device comm app.
  /// If there is a problem, notify the user and return null.
  Future<Map> _nextResult() async {
    _responseCompleter = new Completer();
    _rawOutput.clear();
    String line =
        await _responseCompleter.future.timeout(_timeout).catchError((e) {
      atom.notifications.addError(
          'Timed out waiting for response from $ttyPath',
          dismissable: true,
          detail: _rawOutput.toString());
      return null;
    }, test: (e) => e is TimeoutException);
    if (line == null) return null;
    return _decodeResult(line, _rawOutput.toString());
  }

  void _processStderr(String line) {
    _rawOutput.writeln(line);
  }

  /// Redirect any JSON formatted output to response processing.
  void _processStdout(String line) {
    _rawOutput.writeln(line);
    if (line.startsWith('{') && !_responseCompleter.isCompleted) {
      _responseCompleter.complete(line);
    }
  }
}

/// Decode a JSON response and return the result.
/// If there is an error, notify the user and return null.
Map _decodeResult(String line, [String rawOutput]) {
  Map response = JSON.decode(line);
  Map result = response['result'];
  if (result != null) return result;
  _notifyRequestFailed(response, rawOutput);
  return null;
}

/// Notify the user that the request has failed
void _notifyRequestFailed(Map response, [String rawOutput]) {
  String message = 'Request failed';
  String detail = rawOutput;
  if (response != null) {
    var error = response['error'];
    if (error is Map) {
      message = error['message'];
      detail = _inflate(error['detail']) ?? detail;
    }
  }
  atom.notifications.addError(message, dismissable: true, detail: detail);
}

/// Expand inlined newlines
String _inflate(String data) =>
    data?.replaceAll('\\n', '\n')?.replaceAll('\\\\', '\\');

/// Return the path to the dartino plugin.
/// If not found, report an error to the user and return `null`.
String get _dartinoPluginPath {
  List<String> allPkgRoots = atom.packages.getPackageDirPaths();
  for (String pkgsRoot in allPkgRoots) {
    String path = fs.join(pkgsRoot, pluginId);
    if (fs.existsSync(path)) return path;
  }
  atom.notifications.addError('Cannot find $pluginId package directory.',
      detail: 'Cannot find $pluginId in ${allPkgRoots[0]}', dismissable: true);
  return null;
}

/// Return the path to the device communications utility.
/// If not found, report an error to the user and return `null`.
String get _deviceCommPath {
  if (_dartinoPluginPath == null) return null;
  String path = fs.join(_dartinoPluginPath, 'bin', 'device_comm.dart');
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find device communication utility.',
        detail: 'Cannot find device communication utility at $path',
        dismissable: true);
    return null;
  }
  return path;
}

/// Return the path to the Dart SDK as configured in the dartlang plugin.
/// If not found, report an error to the user and return `null`.
String get _sdkPath {
  String path = atom.config.getValue('dartlang.sdkLocation');
  if (path == null || path.trim().isEmpty) {
    atom.notifications.addError('Dart SDK is not set.',
        detail: 'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find Dart SDK.',
        detail: 'Cannot find Dart SDK at $path. '
            'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  return path;
}

/// Return the path to the VM in the Dart SDK.
/// If not found, report an error to the user and return `null`.
String get _vmPath {
  if (_sdkPath == null) return null;
  String path = fs.join(_sdkPath, 'bin', 'dart');
  if (!fs.existsSync(path)) {
    atom.notifications.addError('Cannot find Dart VM in the Dart SDK.',
        detail: 'Cannot find Dart VM at $path. '
            'Please set the Dart SDK path in '
            'Settings > Packages > dartlang > Dart SDK Location',
        dismissable: true);
    return null;
  }
  return path;
}
