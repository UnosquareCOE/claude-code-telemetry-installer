# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start

To set up telemetry for Claude Code:

```bash
# Copy and customize environment variables
cp .env.example .env
# Edit .env with your configuration

# Run the installation script
./install.sh

# Restart Claude Code for changes to take effect
```

## Architecture

This repository contains a cross-platform installer for Claude Code's OpenTelemetry telemetry system. The core components are:

- **install.sh**: Main installation script that merges environment variables into Claude Code's `~/.claude/settings.json`
- **.env.example**: Template with default telemetry configuration values
- **specs/**: Contains specifications for future features (Entra ID authentication)

### Installation Script Flow

The `install.sh` script:
1. Loads environment variables from `.env` (or falls back to `.env.example`)
2. Detects the operating system (Linux, macOS, Windows/WSL)
3. Locates the correct Claude Code settings directory for the platform
4. Creates or merges telemetry environment variables into `~/.claude/settings.json`
5. Preserves any existing configuration while adding telemetry settings

### Cross-Platform Support

The script supports different Claude Code settings locations:
- **Linux/WSL**: `$XDG_CONFIG_HOME/claude-code` or `$HOME/.config/claude-code`
- **macOS**: `$HOME/Library/Application Support/claude-code`
- **Windows**: `%APPDATA%/claude-code` (via Git Bash/WSL)

## Environment Variables

Key OpenTelemetry configuration variables:
- `CLAUDE_CODE_ENABLE_TELEMETRY`: Enable/disable telemetry (default: 1)
- `OTEL_EXPORTER_OTLP_ENDPOINT`: Collector endpoint (default: http://localhost:4317)
- `OTEL_EXPORTER_OTLP_PROTOCOL`: Export protocol (default: grpc)
- `OTEL_RESOURCE_ATTRIBUTES`: Resource attributes for categorization
- `OTEL_SERVICE_NAME`: Service identifier for telemetry data

## Dependencies

- **jq**: Required for JSON manipulation when merging existing settings
- **bash**: Script requires bash 4.0+ for modern features

## Testing Changes

After modifying the installation script:
1. Test with different `.env` configurations
2. Verify `~/.claude/settings.json` contains expected values
3. Test on multiple platforms if possible

## Future Features

The specs directory contains the specification for Entra ID device code flow authentication, which will add authenticated user identification to telemetry data via `OTEL_RESOURCE_ATTRIBUTES`.