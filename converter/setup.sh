#!/usr/bin/env bash

set -xe

mkdir downloads

# download and unpack Odin
wget https://github.com/odin-lang/Odin/releases/download/dev-2026-09/odin-linux-amd64-dev-2026-09.tar.gz
tar -xf odin-linux-amd64-dev-2026-09.tar.gz
rm odin-linux-amd64-dev-2026-09.tar.gz
# move to downloads
mv odin-linux-amd64-nightly+2026-09-01 downloads
