#!/usr/bin/env bash

set -e

arch --x86_64 brew doctor || true
arch --x86_64 brew update || true
arch --x86_64 brew upgrade $(brew outdated --formula -q) || true

arch --x86_64 brew tap valet-sh/core

arch --x86_64 brew update || true

arch --x86_64 brew install vsh-php56
arch --x86_64 brew install vsh-php70
arch --x86_64 brew install vsh-php71
arch --x86_64 brew install vsh-php72
arch --x86_64 brew install vsh-php73
arch --x86_64 brew install vsh-php74
arch --x86_64 brew install vsh-php80
arch --x86_64 brew install vsh-php81
arch --x86_64 brew install vsh-php82

arch --x86_64 brew install vsh-elasticsearch1
arch --x86_64 brew install vsh-elasticsearch2
arch --x86_64 brew install vsh-elasticsearch5
arch --x86_64 brew install vsh-elasticsearch6
arch --x86_64 brew install vsh-elasticsearch7
arch --x86_64 brew install vsh-elasticsearch8
arch --x86_64 brew install vsh-opensearch1

arch --x86_64 brew install vsh-mysql57
arch --x86_64 brew install vsh-mysql80
arch --x86_64 brew install vsh-mariadb104
