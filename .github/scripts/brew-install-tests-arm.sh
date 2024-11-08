#!/usr/bin/env bash

set -e

arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

arch --x86_64 /usr/local/bin/brew doctor || true
arch --x86_64 /usr/local/bin/brew update || true
arch --x86_64 /usr/local/bin/brew upgrade $(brew outdated --formula -q) || true

arch --x86_64 /usr/local/bin/brew tap valet-sh/core

arch --x86_64 /usr/local/bin/brew update || true

arch --x86_64 /usr/local/bin/brew install vsh-php56
arch --x86_64 /usr/local/bin/brew install vsh-php70
arch --x86_64 /usr/local/bin/brew install vsh-php71
arch --x86_64 /usr/local/bin/brew install vsh-php72
arch --x86_64 /usr/local/bin/brew install vsh-php73
arch --x86_64 /usr/local/bin/brew install vsh-php74
arch --x86_64 /usr/local/bin/brew install vsh-php80
arch --x86_64 /usr/local/bin/brew install vsh-php81
arch --x86_64 /usr/local/bin/brew install vsh-php82

arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch1
arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch2
arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch5
arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch6
arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch7
arch --x86_64 /usr/local/bin/brew install vsh-elasticsearch8
arch --x86_64 /usr/local/bin/brew install vsh-opensearch1

arch --x86_64 /usr/local/bin/brew install vsh-mysql57
arch --x86_64 /usr/local/bin/brew install vsh-mysql80
arch --x86_64 /usr/local/bin/brew install vsh-mariadb104
