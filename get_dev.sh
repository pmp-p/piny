#!/bin/bash
git clone --no-tags --depth 1 --single-branch --branch wasi-sdk https://github.com/pmp-p/nim-wasi Nim
cd Nim

CC=clang ./build_all.sh
