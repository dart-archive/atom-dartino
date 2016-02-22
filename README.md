# atom-dartino

[![Build Status](https://travis-ci.org/dartino/atom-dartino.svg?branch=master)](https://travis-ci.org/dartino/atom-dartino)

This package is a [Dartino](http://dartino.github.io/sdk/)
and [SoD](https://github.com/domokit/sod) development plugin
for [Atom](https://atom.io)
built on top of the Atom [dartlang](https://atom.io/packages/dartlang) plugin.

## Features

- Source code analysis of [SoD](https://github.com/domokit/sod)
and [Dartino](http://dartino.github.io/sdk/) applications.
- Single command to compile, deploy, and run code
on connected device.

## Installation

- Install Atom [atom.io](https://atom.io/)
- Install this [dartino](https://atom.io/packages/dartino) package
  (with `apm install dartino` or through the Atom UI)
- Install [Dart SDK](https://www.dartlang.org/downloads/)
  version 1.15.0-dev.4.0 or better
- Install the [Dartino SDK](http://gsdview.appspot.com/dartino-archive/channels/dev/raw/0.3.0-dev.5.2/sdk/)
  version 0.3.0-dev.5.2 or better

## Setup in Atom

- Open the dartlang plugin settings page and change
  the Dart SDK Location to point to your installed Dart SDK
- Open the dartino plugin settings page and change the Dartino root directory
  to the location of your installed Dartino SDK

## Quick Start

- Connect computer USB to CN14 USB ST-LINK on STM32 Discovery board
- Pull down the File menu and select Add Project folder
- In the dialog that appears, select the dartino-sdk/samples directory
- In the file tree on the left, select samples/stm32f746g-discovery/lines.dart
  to open that file
- Click in the editor
- To compile, deploy, and run the Dartino application in the active editor
  on the connected device, either press ctrl-f6
  or select Packages > Dartino > Run app on device

## Terms and Privacy

The Dart plugin for Atom (the "Plugin") is an open-source project, contributed
to by Google. By using the Plugin, you consent to be bound by Google's general
Terms of Service and Google's general
[Privacy Policy](http://www.google.com/intl/en/policies/privacy/).

## License

See the [LICENSE](https://github.com/dartino/atom-dartino/blob/master/LICENSE)
file.
