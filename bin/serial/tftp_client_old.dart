// Copyright (c) 2016, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino.device.comm.tftp;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The default timeout when interacting with tftp.
Duration _timeout = new Duration(seconds: 3);

/// A simple wrapper for tftp to push a binary to a connected device.
class TftpClient {
  /// Send a binary file to the specified address and return `null`.
  /// If there is a problem, return an error message.
  static Future<String> sendBinary(String ipAddress, String filePath) async {
    TftpClient tftp = new TftpClient(ipAddress);
    String errMsg = await tftp.init();
    if (errMsg != null) return errMsg;
    errMsg = await tftp.putBinary(filePath);
    await tftp.disconnect();
    return errMsg;
  }

  /// The IP address of the connected device.
  final String ipAddress;

  /// The tftp process.
  Process _process;
  StreamSubscription _stderrSubscription;
  StreamSubscription _stdoutSubscription;

  /// Content received from the tftp application.
  final StringBuffer _received = new StringBuffer();
  Completer _completer;

  TftpClient(this.ipAddress);

  /// Initialize the connection and return `null` if successful.
  /// If there is a problem, return an error message.
  Future<String> init([Duration timeout]) async {
    print('launching tftp $ipAddress');
    var launchException;
    _process = await Process
        .start('tftp', [ipAddress])
        .timeout(timeout ?? _timeout)
        .catchError((e) {
          launchException = e;
          return null;
        });
    if (_process == null) {
      return 'Failed to launch tftp application.\n'
          'Plese check that it is installed.\n$launchException';
    }

    print('launched tftp $ipAddress');
    _stderrSubscription =
        _process.stderr.transform(UTF8.decoder).listen((String data) {
      print('stderr: $data');
      _received.write(data);
      if (!_completer.isCompleted) _completer.complete();
    });
    _stdoutSubscription =
        _process.stdout.transform(UTF8.decoder).listen((String data) {
      print('stdout: $data');
      _received.write(data);
      if (!_completer.isCompleted) _completer.complete();
    });
    if (await _waitForPrompt() == null) {
      await disconnect();
      return 'Failed to connect to tftp application:\n$_received';
    }
    return null;
  }

  /// Push a binary file to the connected device and return `null`.
  /// If there is a problem return an error message.
  Future<String> putBinary(String filePath) async {
    //   $ tftp 192.168.0.98
    //   tftp> binary
    //   tftp> put lines.snap
    //   Sent 31651 bytes in 0.0 seconds
    //   tftp> quit

    _process.stdin.writeln('binary');
    if (await _waitForPrompt() == null) {
      return 'Failed to set binary mode\n$_received';
    }
    _process.stdin.writeln('put $filePath');
    String result = await _waitForPrompt();
    if (result == null) {
      return 'No response sending $filePath\n$_received';
    }
    if (!result.contains('Sent')) {
      return 'Failed to send $filePath\n$_received';
    }
    return null;
  }

  /// Returns a future that completes when the tftp application has exited.
  Future disconnect() async {
    _process.stdin.writeln('quit');
    _stdoutSubscription.cancel();
    _stderrSubscription.cancel();
    await _process.exitCode.timeout(_timeout).catchError((e) {
      _process.kill();
    }, test: (e) => e is TimeoutException);
    _process = null;
  }

  /// Return a String containing the response from the tftp application.
  /// If the response does not include a prompt, then return `null`.
  Future<String> _waitForPrompt() async {
    _received.clear();
    print('writing newline after clearing received buffer');
    _process.stdin.writeln('\n');
    String result;
    bool timedOut = false;
    print('waiting for tftp prompt');
    while (result == null && !timedOut) {
      _completer = new Completer();
      await _completer.future.timeout(_timeout).then((_) {
        result = _received.toString();
        print('Received: $result');
        if (!result.contains('tftp>')) result = null;
      }).catchError((e) {
        print('Timed out waiting for tftp prompt');
        timedOut = true;
      }, test: (e) => e is TimeoutException);
    }
    return result;
  }
}
