# dartino plugin changelog

## 0.0.10
- added menu cmd that opens the Dartino SDK samples as a project in Atom

## 0.0.9
- update readme to remove Dart SDK installation step
  now that it's bundled with the Dartino SDK.
- support SoD development over USB without ethernet connection.

## 0.0.8
- prevent dartino apps from being run using Dart VM
- warn the user of missing dartino.yaml and offers to create it
- for analysis, use Dart SDK that ships as part of Dartino SDK

## 0.0.7
- echo output from app running on device
- initial support for launching apps on Dartuino board
- soft reboot rather than power cycle when deploying SOD apps

## 0.0.6
- prompt to install SDK on startup if not already installed
- validate the specified SDK path
- integrate launch into the existing dartlang plugin launching framework
- update 'Create new Project' to use 'dartino create project' command

## 0.0.5
- hide atom-toolbar on startup (until Dartino launch is integrated in dartlang)
- auto install dartlang plugin if not already installed
- updated readme with installation and getting started instructions

## 0.0.4
- project folder containing `dartino.yaml` is analyzed as Dartino project
- auto save editors before running on device
- menu actions for 'Getting Started', 'SDK Docs', and 'Create new Project'
- auto close/cleanup compile/launch dialogs

## 0.0.3
- add support to compile, deploy, run Dartino app on STM32 Discovery board from Linux

## 0.0.2
- add support to compile, deploy, run Dartino app on STM32 Discovery board from Mac
- same support to compile, deploy, run SoD app on STM32 Discovery board from Linux

## 0.0.1
- initial version
