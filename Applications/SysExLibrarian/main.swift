/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

// Register defaults early
autoreleasepool {
    guard let defaultDefaultsURL = Bundle.main.url(forResource: "Defaults", withExtension: "plist"),
          let defaultDefaults = NSDictionary(contentsOf: defaultDefaultsURL) as? [String: Any] else { fatalError() }

    UserDefaults.standard.register(defaults: defaultDefaults)
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
