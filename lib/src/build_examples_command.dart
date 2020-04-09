// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class BuildExamplesCommand extends PluginCommand {
  BuildExamplesCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addFlag(kWindows, defaultsTo: false);
    argParser.addFlag(kMacos, defaultsTo: false);
    argParser.addFlag(kIpa, defaultsTo: io.Platform.isMacOS);
    argParser.addFlag(kApk);
  }

  @override
  final String name = 'build-examples';

  @override
  final String description =
      'Builds all example apps (IPA for iOS and APK for Android).\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    if (!argResults[kIpa] && !argResults[kApk] && !argResults[kMacos] && !argResults[kWindows]) {
      print('Neither --windows, --macos, --apk nor --ipa were specified, so not building '
          'anything.');
      return;
    }

    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (Directory plugin in getPlugins()) {
      for (Directory example in getExamplesForPlugin(plugin)) {
        final String packageName =
            p.relative(example.path, from: packagesDir.path);

        if (argResults[kMacos]) {
          print('\nBUILDING macos for $packageName');;
          if (isMacOsPlugin(plugin, fileSystem)) {
            // TODO(https://github.com/flutter/flutter/issues/46236):
            // Builing macos without running flutter pub get first results
            // in an error.
            int exitCode = await processRunner.runAndStream(
                'flutter', <String>['pub', 'get'],
                workingDir: example);
            if (exitCode != 0) {
              failingPackages.add('$packageName (macos)');
            } else {
              exitCode = await processRunner.runAndStream(
                'flutter', <String>['build', kMacos],
                workingDir: example);
              if (exitCode != 0) {
                failingPackages.add('$packageName (macos)');
              }
            }
          } else {
            print('macOS is not supported by this plugin');
          }
        }

        if (argResults[kWindows]) {
          print('\nBUILDING windows for $packageName');
          print(example);
          if (isWindowsPlugin(plugin, fileSystem)) {
            final Directory windowsFolder =
              fileSystem.directory(p.join(example.path, 'windows'));
            if (windowsFolder.existsSync()) {
              print('deleting');
              windowsFolder.deleteSync();
            }
            print('Trying ===');
            print(example.existsSync());
            final int createCode = await processRunner.runAndStream(
                'flutter', <String>['create', '.'],
                workingDir: example);
                print('Create code: $createCode');

            final int exitCode = await processRunner.runAndStream(
                'flutter', <String>['build', kWindows],
                workingDir: example);
            if (exitCode != 0) {
              print('Exit code $exitCode');
              failingPackages.add('$packageName (windows)');
            }
          } else {
            print('Windows is not supported by this plugin');
          }
          print('afger');
        }

        if (argResults[kIpa]) {
          print('\nBUILDING IPA for $packageName');
          final int exitCode = await processRunner.runAndStream(
              'flutter', <String>['build', 'ios', '--no-codesign'],
              workingDir: example);
          if (exitCode != 0) {
            failingPackages.add('$packageName (ipa)');
          }
        }

        if (argResults[kApk]) {
          print('\nBUILDING APK for $packageName');
          final int exitCode = await processRunner.runAndStream(
              'flutter', <String>['build', 'apk'],
              workingDir: example);
          if (exitCode != 0) {
            failingPackages.add('$packageName (apk)');
          }
        }
      }
    }
    print('\n\n');

    if (failingPackages.isNotEmpty) {
      print('The following build are failing (see above for details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
      throw ToolExit(1);
    }

    print('All builds successful!');
  }
}
