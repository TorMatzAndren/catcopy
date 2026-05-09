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

One clipboard backend is required.

For X11:

    sudo apt install xclip

or:

    sudo apt install xsel

For Wayland:

    sudo apt install wl-clipboard

catcopy chooses the backend deterministically:

- Wayland session: wl-copy
- X11 session: xclip, then xsel
- macOS support when available: pbcopy
- Generic fallback: wl-copy, xclip, xsel

## Tested Platforms

Currently verified locally on:

- Linux/X11 with xclip

Implemented but not yet personally verified on real target systems:

- Wayland with wl-copy
- X11 with xsel fallback
- macOS with pbcopy

Native Windows clipboard support is not implemented yet.


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

Tip:
  Some interactive tools format output for terminal display.
  For Ollama captures, prefer:

    c --batch name -- ollama run --nowordwrap <model> "<prompt>"

## Batch Mode & Real-World Usage

When running multiple commands, you can accumulate output into a single clipboard buffer:

    c --batch myrun --clear
    c --batch myrun -- command1
    c --batch myrun -- command2
    c --batch myrun --show

Each command is appended and the full result is copied to the clipboard.

## Handling Interactive / Streaming Tools

Some CLI tools like Ollama, progress bars, or spinners format output for interactive terminals.
This can result in messy or wrapped output when captured.

catcopy automatically removes most terminal control sequences in batch mode.

However, some tools require explicit flags for clean output.

Example for Ollama:

    c --batch run -- ollama run --nowordwrap qwen3:8b "Explain something"

This avoids broken word wrapping in captured output.

## Design Philosophy

catcopy does not try to fix or reinterpret command output.

Instead:

- It captures output deterministically
- It cleans terminal control sequences
- It leaves semantic formatting to the command itself

If output is malformed, the correct fix is usually to adjust the command, not catcopy.
