# Claude Code Telemetry Installer

This repository contains scripts and configuration to enable OpenTelemetry telemetry collection for Claude Code.

The install script automatically:

- Detects your operating system (Linux, macOS, Windows/WSL)
- Locates the correct Claude Code settings directory
- Creates or updates `~/.claude/settings.json` with telemetry configuration
- Preserves any existing environment variables

## Usage

To install the telemetry script, run the following command:

**User-level installation**:

```bash
curl -s https://raw.githubusercontent.com/UnosquareCOE/claude-code-telemetry-installer/refs/heads/main/install.sh | bash
```

**Project-level installation**:

```bash
curl -s https://raw.githubusercontent.com/UnosquareCOE/claude-code-telemetry-installer/refs/heads/main/project-install.sh | bash -- --project <my-project-name>
```

For local development or when you need to override specific settings, see the [Command-Line Overrides](#command-line-overrides) section below.

## Project-Specific Installation

For project-specific telemetry configuration, use the `project-install.sh` script which creates `.claude/settings.json` in your current project directory:

```bash
# Install for a specific project (required --project flag)
./project-install.sh --project my-webapp

# Or with custom endpoint
./project-install.sh --project api-service --endpoint https://otel.company.com:4317
```

The project installer automatically adds the project name to `OTEL_RESOURCE_ATTRIBUTES` for proper telemetry categorization.

---

# Local development

## Quick Start

1. **Configure your environment variables**:

   ```bash
   cp .env.example .env
   # Edit .env with your specific configuration
   ```

2. **Run the installation script**:

   ```bash
   ./install.sh
   ```

3. **Restart Claude Code** for the changes to take effect.

## Environment Variables

The following environment variables control Claude Code's telemetry behavior:

| Variable                       | Description                         | Default Value                    |
| ------------------------------ | ----------------------------------- | -------------------------------- |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable/disable telemetry collection | `1`                              |
| `OTEL_EXPORTER_OTLP_ENDPOINT`  | OpenTelemetry collector endpoint    | `http://localhost:4317`          |
| `OTEL_EXPORTER_OTLP_PROTOCOL`  | Protocol for OTLP export            | `grpc`                           |
| `OTEL_LOGS_EXPORTER`           | Logs exporter type                  | `otlp`                           |
| `OTEL_LOG_USER_PROMPTS`        | Enable logging of user prompts      | `1`                              |
| `OTEL_METRICS_EXPORTER`        | Metrics exporter type               | `otlp`                           |
| `OTEL_RESOURCE_ATTRIBUTES`     | Resource attributes for telemetry   | `department=engineering_success` |
| `OTEL_SERVICE_NAME`            | Service name for telemetry          | `claude-code`                    |

## Configuration

### Using .env files

The installation script loads configuration from files in this order:

1. `.env` file in the current directory (if exists)
2. `.env.example` file as fallback

Command-line flags override values from both files. To customize your configuration:

```bash
# Copy the example and modify as needed
cp .env.example .env
```

Then edit `.env` with your preferred values:

```bash
# Example custom configuration
CLAUDE_CODE_ENABLE_TELEMETRY=1
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector.example.com:4317
OTEL_RESOURCE_ATTRIBUTES="department=your_team,environment=production"
OTEL_SERVICE_NAME="claude-code-your-team"
```

## Installation Script

The `install.sh` script automatically:

- Loads environment variables from `.env` or `.env.example`
- Detects your operating system (Linux, macOS, Windows/WSL)
- Locates the correct Claude Code settings directory
- Creates or updates `~/.claude/settings.json` with telemetry configuration
- Preserves any existing environment variables

### Usage

```bash
# Run with default configuration (user-level settings)
./install.sh

# Run for project-specific settings (requires --project flag)
./project-install.sh --project my-project-name

# Get help and see all options
./install.sh --help
./project-install.sh --help
```

### Command-Line Overrides

You can override environment variables directly via command-line flags, which take precedence over values in `.env` files:

**User-level configuration** (`install.sh`):

```bash
# Override endpoint and service name
./install.sh --endpoint https://otel.company.com:4317 --service-name "dev-team-claude"

# Override protocol and disable user prompt logging
./install.sh --protocol http --log-prompts 0

# Override resource attributes
./install.sh --resource-attributes "department=engineering,environment=production"
```

**Project-level configuration** (`project-install.sh`):

```bash
# Basic project setup (project flag is required)
./project-install.sh --project my-webapp

# Project with custom endpoint
./project-install.sh --project api-service --endpoint https://otel.company.com:4317

# Project with multiple overrides
./project-install.sh --project dev-tool \
                     --service-name "my-team-claude" \
                     --protocol http \
                     --resource-attributes "team=platform,env=dev"
```

#### Available Flags

**Common flags** (available in both scripts):

| Flag                            | Environment Variable           | Description                      | Valid Values     |
| ------------------------------- | ------------------------------ | -------------------------------- | ---------------- |
| `--endpoint <url>`              | `OTEL_EXPORTER_OTLP_ENDPOINT`  | OpenTelemetry collector endpoint | Any valid URL    |
| `--service-name <name>`         | `OTEL_SERVICE_NAME`            | Service name for telemetry       | Any string       |
| `--enable-telemetry <0\|1>`     | `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable/disable telemetry         | `0` or `1`       |
| `--protocol <grpc\|http>`       | `OTEL_EXPORTER_OTLP_PROTOCOL`  | Export protocol                  | `grpc` or `http` |
| `--log-prompts <0\|1>`          | `OTEL_LOG_USER_PROMPTS`        | Enable logging of user prompts   | `0` or `1`       |
| `--resource-attributes <attrs>` | `OTEL_RESOURCE_ATTRIBUTES`     | Resource attributes              | Key=value pairs  |

**Project-specific flags** (only in `project-install.sh`):

| Flag               | Environment Variable       | Description                            | Valid Values |
| ------------------ | -------------------------- | -------------------------------------- | ------------ |
| `--project <name>` | `OTEL_RESOURCE_ATTRIBUTES` | Project name (required, auto-appended) | Any string   |

#### Precedence Order

Configuration values are applied in the following order (highest to lowest priority):

1. **Command-line flags** (highest priority)
2. **`.env` file** in current directory
3. **`.env.example` file** (fallback default)

### Platform Support

**User-level installation** (`install.sh`):

- **Linux**: Uses `$XDG_CONFIG_HOME/claude-code` or `$HOME/.config/claude-code`
- **macOS**: Uses `$HOME/Library/Application Support/claude-code`
- **Windows**: Uses `%APPDATA%/claude-code` (via Git Bash/WSL)

**Project-level installation** (`project-install.sh`):

- **All platforms**: Uses `.claude/settings.json` in the current project directory

## Requirements

- **jq**: Required for JSON manipulation
  - macOS: `brew install jq`
  - Linux: `apt-get install jq` or `yum install jq`
  - Windows: Available via Git Bash or WSL

## Telemetry Data

When enabled, Claude Code will send telemetry data including:

- **Metrics**: Usage statistics, performance metrics
- **Logs**: Application logs (optionally including user prompts if `OTEL_LOG_USER_PROMPTS=1`)
- **Traces**: Request/response timing and flow

All telemetry data includes the configured resource attributes for categorization and filtering.

## Troubleshooting

### Common Issues

**Script fails with "jq not found"**:

```bash
# Install jq
# macOS:
brew install jq

# Linux:
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # RHEL/CentOS
```

**Environment variables not loading**:

- Ensure `.env` or `.env.example` exists in the current directory
- Check file permissions: `chmod 644 .env`
- Verify file format (no spaces around `=`)

**Changes not taking effect**:

- Restart Claude Code completely
- Verify the settings.json was created:
  - User-level: `~/.claude/settings.json`
  - Project-level: `./.claude/settings.json`

### Verifying Configuration

Check if the configuration was applied correctly:

```bash
# For user-level configuration
cat ~/.claude/settings.json

# For project-level configuration
cat ./.claude/settings.json
```

The file should contain your environment variables in the `env` section.

## Development

### Testing Changes

After modifying the scripts:

1. Test on your platform:

   ```bash
   # Test user-level installation
   ./install.sh

   # Test project-level installation
   ./project-install.sh --project test-project
   ```

2. Verify the generated settings files contain expected values:

   - User-level: `~/.claude/settings.json`
   - Project-level: `./.claude/settings.json`

3. Test with different `.env` configurations and command-line overrides

### Contributing

When making changes:

- Test on multiple platforms if possible
- Update this README if adding new features
- Follow the existing code style and error handling patterns
