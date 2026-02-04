########################################
# Terminal
########################################

# Use a modified version of the Pro theme by default in Terminal.app
open "./terminal/PaulMillrCustom.terminal"
sleep 1 # Wait a bit to make sure the theme is loaded
defaults write com.apple.terminal 'Default Window Settings' -string 'PaulMillrCustom'
defaults write com.apple.terminal 'Startup Window Settings' -string 'PaulMillrCustom'
