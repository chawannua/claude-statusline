# Claude Statusline

[![Release](https://img.shields.io/github/v/release/chawannua/claude-statusline?color=cc785c&label=version&style=flat-square)](https://github.com/chawannua/claude-statusline/releases)
![License](https://img.shields.io/github/license/chawannua/claude-statusline?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue?style=flat-square)
![Stars](https://img.shields.io/github/stars/chawannua/claude-statusline?style=flat-square)

Nordic minimalist statusline for Claude.

## Preview

```text
~ chawannua/claude-statusline ❯ 
```

## Features

- Minimalist design
- Git status integration
- Fast and responsive

## Versioning

This project follows strict [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes (e.g. `BREAKING CHANGE` or `feat!:`, `refactor!:`)
- **MINOR**: New features (e.g. `feat:`, `feat(...):`)
- **PATCH**: Bug fixes, refactors, docs, style (e.g. `fix:`, `refactor:`, `perf:`, `docs:`, `chore:`)

## Quick Install

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chawannua/claude-statusline/main/statusline.ps1" -OutFile "$HOME\statusline.ps1"
. $HOME\statusline.ps1
```

## Configuration

You can customize the prompt by editing the variables in `statusline.ps1`.
