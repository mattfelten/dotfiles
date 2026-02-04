#!/usr/bin/env bash

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Pin dock to right bottom
defaults write com.apple.dock orientation right
defaults write com.apple.dock pinning -string end

# Set the icon size of Dock items to 24 pixels
defaults write com.apple.dock tilesize -int 24

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Do not hide and show the Dock
defaults write com.apple.dock autohide -bool false

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Wipe all (default) app icons from the Dock
# This is only really useful when setting up a new Mac, or if you don’t use
# the Dock to launch apps.
#defaults write com.apple.dock persistent-apps -array

# Add some spacers to the Dock
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="small-spacer-tile";}';
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="small-spacer-tile";}';
# defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}';

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center

# Top left screen corner (Default: 2 Mission Control)
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tl-modifier -int 0
# Top right screen corner (Default: 4 Desktop)
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0
# Bottom left screen corner (Default: 5 Start screen saver)
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0

killall Dock &> /dev/null
