#!/bin/sh

/usr/local/bin/pwsh -nologo -NonInteractive -file "$(dirname "$0")/StartPlugin.ps1" "$@"
