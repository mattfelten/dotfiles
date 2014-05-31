Dotfiles
====================

Wow, such dot. Very file.

Dotfiles Installation
------------
All you gotta do is cd in and run `rake`. Easy peasy, lemon squeezy.

OS X defaults
------------
Lets set some sensible OS X defaults:

```bash
. .osx
```

Install Homebrew formulae
------------
When setting up a new Mac, we can install some common [Homebrew](http://brew.sh/) formulae (after installing Homebrew, of course):

```bash
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
brew bundle Brewfile
```

Homebrew will installed [Cask](http://caskroom.io) which will let us install OSX apps as well. Awesome!


Install Node modules
------------

Node & NPM were installed with Homebrew. Lets also install our Node stuff:

```bash
npm update
npm install -g
```
