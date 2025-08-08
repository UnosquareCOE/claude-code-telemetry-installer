# Claude Code Telemetry Installer

This repository contains scripts and configuration to enable OpenTelemetry telemetry collection for Claude Code.

The install script automatically:

- Detects your operating system (Linux, macOS, Windows/WSL)
- Locates the correct Claude Code settings directory
- Creates or updates `managed-settings.json` with telemetry configuration
- Preserves any existing environment variables

## Usage

To install the telemetry script, run the following command:

```bash
curl -s https://raw.githubusercontent.com/UnosquareCOE/claude-code-telemetry-installer/refs/heads/main/install.sh | bash
```

For local development or when you need to override specific settings, see the [Command-Line Overrides](#command-line-overrides) section below.

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
- Creates or updates `managed-settings.json` with telemetry configuration
- Preserves any existing environment variables

### Usage

```bash
# Run with default configuration
./install.sh

# Get help and see all options
./install.sh --help
```

### Command-Line Overrides

You can override environment variables directly via command-line flags, which take precedence over values in `.env` files:

```bash
# Override endpoint and service name
./install.sh --endpoint https://otel.company.com:4317 --service-name "dev-team-claude"

# Override protocol and disable user prompt logging
./install.sh --protocol http --log-prompts 0

# Override resource attributes
./install.sh --resource-attributes "department=engineering,environment=production"

# Multiple overrides
./install.sh --endpoint https://collector.example.com:4317 \
             --service-name "my-team-claude" \
             --enable-telemetry 1 \
             --protocol grpc \
             --log-prompts 1 \
             --resource-attributes "team=platform,env=dev"
```

#### Available Flags

| Flag                            | Environment Variable           | Description                      | Valid Values     |
| ------------------------------- | ------------------------------ | -------------------------------- | ---------------- |
| `--endpoint <url>`              | `OTEL_EXPORTER_OTLP_ENDPOINT`  | OpenTelemetry collector endpoint | Any valid URL    |
| `--service-name <name>`         | `OTEL_SERVICE_NAME`            | Service name for telemetry       | Any string       |
| `--enable-telemetry <0\|1>`     | `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable/disable telemetry         | `0` or `1`       |
| `--protocol <grpc\|http>`       | `OTEL_EXPORTER_OTLP_PROTOCOL`  | Export protocol                  | `grpc` or `http` |
| `--log-prompts <0\|1>`          | `OTEL_LOG_USER_PROMPTS`        | Enable logging of user prompts   | `0` or `1`       |
| `--resource-attributes <attrs>` | `OTEL_RESOURCE_ATTRIBUTES`     | Resource attributes              | Key=value pairs  |

#### Precedence Order

Configuration values are applied in the following order (highest to lowest priority):

1. **Command-line flags** (highest priority)
2. **`.env` file** in current directory
3. **`.env.example` file** (fallback default)

### Platform Support

The script supports:

- **Linux**: Uses `$XDG_CONFIG_HOME/claude-code` or `$HOME/.config/claude-code`
- **macOS**: Uses `$HOME/Library/Application Support/claude-code`
- **Windows**: Uses `%APPDATA%/claude-code` (via Git Bash/WSL)

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
- Verify the managed-settings.json was created:
  - macOS: `~/Library/Application Support/claude-code/managed-settings.json`
  - Linux: `~/.config/claude-code/managed-settings.json`

### Verifying Configuration

Check if the configuration was applied correctly:

```bash
# macOS
cat ~/Library/Application\ Support/claude-code/managed-settings.json

# Linux
cat ~/.config/claude-code/managed-settings.json
```

The file should contain your environment variables in the `env` section.

## Development

### Testing Changes

After modifying the script:

1. Test on your platform:

   ```bash
   ./install.sh
   ```

2. Verify the generated `managed-settings.json` contains expected values

3. Test with different `.env` configurations

### Contributing

When making changes:

- Test on multiple platforms if possible
- Update this README if adding new features
- Follow the existing code style and error handling patterns

## Security Notes

- The `.env` file may contain sensitive endpoints or credentials
- Add `.env` to `.gitignore` to prevent accidental commits
- Use `.env.example` for documentation and defaults only
