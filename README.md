# catcopy

catcopy is a tiny clipboard pipeline tool for Linux.

It installs two commands:

- c
- catcopy

Both do the same thing.

## Features

c file1 file2

Copies files with transport headers.

echo "hello" | c

Copies stdin directly.

c -- git status --porcelain=v1 --branch

Runs a command and copies stdout.

c -- sed -n '1,120p' file.py
c -- jq '.' data.json

Works with normal Unix tools.

## Requirements

One clipboard backend is required:

sudo apt install xclip

or:

sudo apt install wl-clipboard

## Install from source

sudo ./install.sh

## Uninstall

sudo ./uninstall.sh

## Build .deb

./build-deb.sh

Install the package:

sudo apt install ./dist/catcopy_0.1.0_all.deb

## Usage

c --help
catcopy --help

## Notes

File mode adds transport headers:

===== TRANSPORT HEADER (NOT PART OF FILE) =====
PATH: example.txt
NOTE: Do NOT include this header in any saved documents.
===============================================

Stdin mode and command mode copy raw output without headers.
