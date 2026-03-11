#!/usr/bin/env bash

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Trackpad: enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: map bottom right corner to right-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2

# Remap Spotlight shortcut to Control+Space.
#
# System shortcuts like Spotlight live in com.apple.symbolichotkeys under AppleSymbolicHotKeys.
# Key 64 = Spotlight Search. The parameters array is: (ascii, keycode, modifier).
#   ascii 32    = space
#   keycode 49  = spacebar
#   modifier 262144 = Control (0x40000)
#
# `defaults write -dict-add` silently fails for nested plist structures, so PlistBuddy
# is required. We delete first to ensure a clean write (errors suppressed if key is absent).
#
# After writing, cfprefsd must be restarted for the change to take effect at runtime.
# activateSettings -u signals the system to reload hotkey bindings.
PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
/usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys:64" "$PLIST" 2>/dev/null
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:enabled bool true" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value:parameters array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value:parameters:0 integer 32" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value:parameters:1 integer 49" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value:parameters:2 integer 262144" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:value:type string standard" "$PLIST"
killall cfprefsd
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
