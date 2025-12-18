#!/bin/bash

# Build the iOS app
xcodebuild -project GaugeWatcher.xcodeproj -scheme GaugeWatcher -destination 'platform=iOS Simulator,name=iPhone 17' build | xcbeautify

# Build the macOS app
xcodebuild -project GaugeWatcher.xcodeproj -scheme GaugeWatcherMac -destination 'platform=macOS' build | xcbeautify