#!/bin/bash

# Cross-platform script to merge telemetry environment variables with Claude Code managed settings
# Works on Linux, macOS, and Windows (with Git Bash/WSL)

set -e

# Global variables to store command-line overrides
CLI_OVERRIDE_ENDPOINT=""
CLI_OVERRIDE_SERVICE_NAME=""
CLI_OVERRIDE_ENABLE_TELEMETRY=""
CLI_OVERRIDE_PROTOCOL=""
CLI_OVERRIDE_LOG_PROMPTS=""
CLI_OVERRIDE_RESOURCE_ATTRIBUTES=""

# Default environment variable values (from .env.example)
DEFAULT_CLAUDE_CODE_ENABLE_TELEMETRY="1"
DEFAULT_OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
DEFAULT_OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
DEFAULT_OTEL_LOGS_EXPORTER="otlp"
DEFAULT_OTEL_LOG_USER_PROMPTS="1"
DEFAULT_OTEL_METRICS_EXPORTER="otlp"
DEFAULT_OTEL_RESOURCE_ATTRIBUTES="department=engineering_success"
DEFAULT_OTEL_SERVICE_NAME="claude-code"

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ "$(uname -r)" == *microsoft* ]]; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to get Claude Code settings directory based on OS
get_settings_dir() {
    local os="$1"
    case "$os" in
        linux|wsl)
            echo "${XDG_CONFIG_HOME:-$HOME/.config}/claude-code"
            ;;
        macos)
            echo "$HOME/Library/Application Support/claude-code"
            ;;
        windows)
            echo "${APPDATA}/claude-code"
            ;;
        *)
            echo "Unsupported operating system: $os" >&2
            exit 1
            ;;
    esac
}

# Function to load environment variables from .env files
load_env_variables() {
    # Set default values first
    export CLAUDE_CODE_ENABLE_TELEMETRY="$DEFAULT_CLAUDE_CODE_ENABLE_TELEMETRY"
    export OTEL_EXPORTER_OTLP_ENDPOINT="$DEFAULT_OTEL_EXPORTER_OTLP_ENDPOINT"
    export OTEL_EXPORTER_OTLP_PROTOCOL="$DEFAULT_OTEL_EXPORTER_OTLP_PROTOCOL"
    export OTEL_LOGS_EXPORTER="$DEFAULT_OTEL_LOGS_EXPORTER"
    export OTEL_LOG_USER_PROMPTS="$DEFAULT_OTEL_LOG_USER_PROMPTS"
    export OTEL_METRICS_EXPORTER="$DEFAULT_OTEL_METRICS_EXPORTER"
    export OTEL_RESOURCE_ATTRIBUTES="$DEFAULT_OTEL_RESOURCE_ATTRIBUTES"
    export OTEL_SERVICE_NAME="$DEFAULT_OTEL_SERVICE_NAME"
    
    # Try to load from .env first, then fallback to .env.example
    local env_file=".env"
    if [[ ! -f "$env_file" ]]; then
        env_file=".env.example"
        if [[ ! -f "$env_file" ]]; then
            echo "Using embedded default values (no .env or .env.example found)"
        else
            echo "Using .env.example as .env file not found"
            # Source the environment file
            set -a  # automatically export all variables
            source "$env_file"
            set +a  # turn off automatic export
        fi
    else
        echo "Loading environment variables from .env"
        # Source the environment file
        set -a  # automatically export all variables
        source "$env_file"
        set +a  # turn off automatic export
    fi
    
    # Apply command-line overrides (these take precedence over file values)
    if [[ -n "$CLI_OVERRIDE_ENDPOINT" ]]; then
        export OTEL_EXPORTER_OTLP_ENDPOINT="$CLI_OVERRIDE_ENDPOINT"
        echo "Override: OTEL_EXPORTER_OTLP_ENDPOINT=$CLI_OVERRIDE_ENDPOINT"
    fi
    if [[ -n "$CLI_OVERRIDE_SERVICE_NAME" ]]; then
        export OTEL_SERVICE_NAME="$CLI_OVERRIDE_SERVICE_NAME"
        echo "Override: OTEL_SERVICE_NAME=$CLI_OVERRIDE_SERVICE_NAME"
    fi
    if [[ -n "$CLI_OVERRIDE_ENABLE_TELEMETRY" ]]; then
        export CLAUDE_CODE_ENABLE_TELEMETRY="$CLI_OVERRIDE_ENABLE_TELEMETRY"
        echo "Override: CLAUDE_CODE_ENABLE_TELEMETRY=$CLI_OVERRIDE_ENABLE_TELEMETRY"
    fi
    if [[ -n "$CLI_OVERRIDE_PROTOCOL" ]]; then
        export OTEL_EXPORTER_OTLP_PROTOCOL="$CLI_OVERRIDE_PROTOCOL"
        echo "Override: OTEL_EXPORTER_OTLP_PROTOCOL=$CLI_OVERRIDE_PROTOCOL"
    fi
    if [[ -n "$CLI_OVERRIDE_LOG_PROMPTS" ]]; then
        export OTEL_LOG_USER_PROMPTS="$CLI_OVERRIDE_LOG_PROMPTS"
        echo "Override: OTEL_LOG_USER_PROMPTS=$CLI_OVERRIDE_LOG_PROMPTS"
    fi
    if [[ -n "$CLI_OVERRIDE_RESOURCE_ATTRIBUTES" ]]; then
        export OTEL_RESOURCE_ATTRIBUTES="$CLI_OVERRIDE_RESOURCE_ATTRIBUTES"
        echo "Override: OTEL_RESOURCE_ATTRIBUTES=$CLI_OVERRIDE_RESOURCE_ATTRIBUTES"
    fi
}

# Function to create managed-settings.json with proper structure
create_managed_settings() {
    local settings_file="$1"
    local temp_file="${settings_file}.tmp"
    
    # Check if the file already exists
    if [[ -f "$settings_file" ]]; then
        echo "Found existing managed-settings.json, merging with telemetry environment variables..."
        
        # Check if jq is available for JSON manipulation
        if command -v jq >/dev/null 2>&1; then
            # Use jq to merge the existing settings with all environment variables
            jq --arg claude_telemetry "$CLAUDE_CODE_ENABLE_TELEMETRY" \
               --arg otel_endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
               --arg otel_protocol "$OTEL_EXPORTER_OTLP_PROTOCOL" \
               --arg otel_logs "$OTEL_LOGS_EXPORTER" \
               --arg otel_log_prompts "$OTEL_LOG_USER_PROMPTS" \
               --arg otel_metrics "$OTEL_METRICS_EXPORTER" \
               --arg otel_resource "$OTEL_RESOURCE_ATTRIBUTES" \
               --arg otel_service "$OTEL_SERVICE_NAME" \
               '.env.CLAUDE_CODE_ENABLE_TELEMETRY = $claude_telemetry |
                .env.OTEL_EXPORTER_OTLP_ENDPOINT = $otel_endpoint |
                .env.OTEL_EXPORTER_OTLP_PROTOCOL = $otel_protocol |
                .env.OTEL_LOGS_EXPORTER = $otel_logs |
                .env.OTEL_LOG_USER_PROMPTS = $otel_log_prompts |
                .env.OTEL_METRICS_EXPORTER = $otel_metrics |
                .env.OTEL_RESOURCE_ATTRIBUTES = $otel_resource |
                .env.OTEL_SERVICE_NAME = $otel_service' "$settings_file" > "$temp_file"
        else
            echo "Error: jq is required for merging complex environment variables."
            echo "Please install jq or create the file manually."
            exit 1
        fi
    else
        echo "Creating new managed-settings.json with telemetry environment variables..."
        
        # Create new managed-settings.json with all telemetry environment variables from .env
        cat > "$temp_file" << EOF
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "$CLAUDE_CODE_ENABLE_TELEMETRY",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "$OTEL_EXPORTER_OTLP_ENDPOINT",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "$OTEL_EXPORTER_OTLP_PROTOCOL",
    "OTEL_LOGS_EXPORTER": "$OTEL_LOGS_EXPORTER",
    "OTEL_LOG_USER_PROMPTS": "$OTEL_LOG_USER_PROMPTS",
    "OTEL_METRICS_EXPORTER": "$OTEL_METRICS_EXPORTER",
    "OTEL_RESOURCE_ATTRIBUTES": "$OTEL_RESOURCE_ATTRIBUTES",
    "OTEL_SERVICE_NAME": "$OTEL_SERVICE_NAME"
  }
}
EOF
    fi
    
    # Move temp file to final location
    mv "$temp_file" "$settings_file"
    echo "Successfully updated managed-settings.json"
}

# Function to parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --endpoint)
                if [[ -z "$2" ]]; then
                    echo "Error: --endpoint requires a value" >&2
                    exit 1
                fi
                CLI_OVERRIDE_ENDPOINT="$2"
                shift 2
                ;;
            --service-name)
                if [[ -z "$2" ]]; then
                    echo "Error: --service-name requires a value" >&2
                    exit 1
                fi
                CLI_OVERRIDE_SERVICE_NAME="$2"
                shift 2
                ;;
            --enable-telemetry)
                if [[ -z "$2" ]] || [[ "$2" != "0" && "$2" != "1" ]]; then
                    echo "Error: --enable-telemetry requires 0 or 1" >&2
                    exit 1
                fi
                CLI_OVERRIDE_ENABLE_TELEMETRY="$2"
                shift 2
                ;;
            --protocol)
                if [[ -z "$2" ]] || [[ "$2" != "grpc" && "$2" != "http" ]]; then
                    echo "Error: --protocol requires 'grpc' or 'http'" >&2
                    exit 1
                fi
                CLI_OVERRIDE_PROTOCOL="$2"
                shift 2
                ;;
            --log-prompts)
                if [[ -z "$2" ]] || [[ "$2" != "0" && "$2" != "1" ]]; then
                    echo "Error: --log-prompts requires 0 or 1" >&2
                    exit 1
                fi
                CLI_OVERRIDE_LOG_PROMPTS="$2"
                shift 2
                ;;
            --resource-attributes)
                if [[ -z "$2" ]]; then
                    echo "Error: --resource-attributes requires a value" >&2
                    exit 1
                fi
                CLI_OVERRIDE_RESOURCE_ATTRIBUTES="$2"
                shift 2
                ;;
            --help|-h)
                # Help is handled later in the script
                return 0
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Use --help to see available options" >&2
                exit 1
                ;;
        esac
    done
}

# Function to display the current settings
display_settings() {
    local settings_file="$1"
    echo ""
    echo "Current managed-settings.json content:"
    echo "======================================"
    if command -v jq >/dev/null 2>&1; then
        jq '.' "$settings_file"
    else
        cat "$settings_file"
    fi
    echo "======================================"
}

# Main execution
main() {
    # Parse command-line arguments first
    parse_arguments "$@"
    
    echo "Claude Code Environment Variable Merger"
    echo "======================================="
    
    # Load environment variables from .env or .env.example
    load_env_variables
    
    # Detect operating system
    local os
    os=$(detect_os)
    echo "Detected OS: $os"
    
    # Get Claude Code settings directory
    local settings_dir
    settings_dir=$(get_settings_dir "$os")
    echo "Settings directory: $settings_dir"
    
    # Create settings directory if it doesn't exist
    if [[ ! -d "$settings_dir" ]]; then
        echo "Creating settings directory: $settings_dir"
        mkdir -p "$settings_dir"
    fi
    
    # Path to managed-settings.json
    local settings_file="$settings_dir/managed-settings.json"
    echo "Settings file: $settings_file"
    
    # Create or update managed-settings.json
    create_managed_settings "$settings_file"
    
    # Display current settings
    display_settings "$settings_file"
    
    echo ""
    echo "✅ Successfully merged telemetry environment variables into Claude Code managed settings!"
    echo ""
    echo "The following environment variables are now available to Claude Code:"
    echo "  - CLAUDE_CODE_ENABLE_TELEMETRY=$CLAUDE_CODE_ENABLE_TELEMETRY"
    echo "  - OTEL_EXPORTER_OTLP_ENDPOINT=$OTEL_EXPORTER_OTLP_ENDPOINT"
    echo "  - OTEL_EXPORTER_OTLP_PROTOCOL=$OTEL_EXPORTER_OTLP_PROTOCOL"
    echo "  - OTEL_LOGS_EXPORTER=$OTEL_LOGS_EXPORTER"
    echo "  - OTEL_LOG_USER_PROMPTS=$OTEL_LOG_USER_PROMPTS"
    echo "  - OTEL_METRICS_EXPORTER=$OTEL_METRICS_EXPORTER"
    echo "  - OTEL_RESOURCE_ATTRIBUTES=$OTEL_RESOURCE_ATTRIBUTES"
    echo "  - OTEL_SERVICE_NAME=$OTEL_SERVICE_NAME"
    echo ""
    echo "You may need to restart Claude Code for the changes to take effect."
    
    # Additional guidance based on OS
    case "$os" in
        wsl)
            echo ""
            echo "Note: On WSL, make sure you're running this script in your Linux environment,"
            echo "not from Windows PowerShell or Command Prompt."
            ;;
        windows)
            echo ""
            echo "Note: On Windows, this script works best with Git Bash or WSL."
            echo "If using Command Prompt, consider running via WSL instead."
            ;;
    esac
}

# Check for help flag
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Claude Code Telemetry Environment Variable Merger"
    echo ""
    echo "This script merges OpenTelemetry environment variables from .env files into Claude Code's managed-settings.json file."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --endpoint <url>                Set OTEL_EXPORTER_OTLP_ENDPOINT"
    echo "  --service-name <name>           Set OTEL_SERVICE_NAME"
    echo "  --enable-telemetry <0|1>        Set CLAUDE_CODE_ENABLE_TELEMETRY"
    echo "  --protocol <grpc|http>          Set OTEL_EXPORTER_OTLP_PROTOCOL"
    echo "  --log-prompts <0|1>             Set OTEL_LOG_USER_PROMPTS"
    echo "  --resource-attributes <attrs>   Set OTEL_RESOURCE_ATTRIBUTES"
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Use defaults from .env files"
    echo "  $0 --endpoint http://otel.company.com:4317  # Override endpoint"
    echo "  $0 --service-name dev-team --protocol http # Multiple overrides"
    echo ""
    echo "The script automatically:"
    echo "  - Loads environment variables from .env (or falls back to .env.example)"
    echo "  - Applies command-line overrides (these take precedence over file values)"
    echo "  - Detects your operating system (Linux, macOS, Windows/WSL)"
    echo "  - Locates the correct Claude Code settings directory"
    echo "  - Creates or updates managed-settings.json with telemetry environment variables"
    echo "  - Preserves existing environment variables if any"
    echo ""
    echo "Environment variable sources (in order of precedence):"
    echo "  1. Command-line flags (highest priority)"
    echo "  2. .env file in current directory"
    echo "  3. .env.example file in current directory (fallback)"
    echo ""
    echo "Environment variables:"
    echo "  - CLAUDE_CODE_ENABLE_TELEMETRY   Enable/disable telemetry (0|1)"
    echo "  - OTEL_EXPORTER_OTLP_ENDPOINT    OpenTelemetry collector endpoint"
    echo "  - OTEL_EXPORTER_OTLP_PROTOCOL    Export protocol (grpc|http)"
    echo "  - OTEL_LOGS_EXPORTER             Logs exporter type"
    echo "  - OTEL_LOG_USER_PROMPTS          Log user prompts (0|1)"
    echo "  - OTEL_METRICS_EXPORTER          Metrics exporter type"
    echo "  - OTEL_RESOURCE_ATTRIBUTES       Resource attributes (key=value pairs)"
    echo "  - OTEL_SERVICE_NAME              Service name identifier"
    echo ""
    echo "Requirements:"
    echo "  - jq (required for JSON manipulation)"
    echo "  - .env or .env.example file in current directory"
    echo ""
    echo "Supported platforms:"
    echo "  - Linux"
    echo "  - macOS" 
    echo "  - Windows (Git Bash/WSL)"
    echo ""
    exit 0
fi

# Run main function
main "$@"