#!/bin/bash

# Cross-platform script to merge telemetry environment variables with Claude Code managed settings
# Works on Linux, macOS, and Windows (with Git Bash/WSL)

set -e

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
    # Try to load from .env first, then fallback to .env.example
    local env_file=".env"
    if [[ ! -f "$env_file" ]]; then
        env_file=".env.example"
        if [[ ! -f "$env_file" ]]; then
            echo "Error: Neither .env nor .env.example found in current directory" >&2
            exit 1
        fi
        echo "Using .env.example as .env file not found"
    else
        echo "Loading environment variables from .env"
    fi
    
    # Source the environment file
    set -a  # automatically export all variables
    source "$env_file"
    set +a  # turn off automatic export
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
    echo "Usage: $0"
    echo ""
    echo "The script automatically:"
    echo "  - Loads environment variables from .env (or falls back to .env.example)"
    echo "  - Detects your operating system (Linux, macOS, Windows/WSL)"
    echo "  - Locates the correct Claude Code settings directory"
    echo "  - Creates or updates managed-settings.json with telemetry environment variables"
    echo "  - Preserves existing environment variables if any"
    echo ""
    echo "Environment variable sources (in order of preference):"
    echo "  1. .env file in current directory"
    echo "  2. .env.example file in current directory (fallback)"
    echo ""
    echo "Expected environment variables:"
    echo "  - CLAUDE_CODE_ENABLE_TELEMETRY"
    echo "  - OTEL_EXPORTER_OTLP_ENDPOINT"
    echo "  - OTEL_EXPORTER_OTLP_PROTOCOL"
    echo "  - OTEL_LOGS_EXPORTER"
    echo "  - OTEL_LOG_USER_PROMPTS"
    echo "  - OTEL_METRICS_EXPORTER"
    echo "  - OTEL_RESOURCE_ATTRIBUTES"
    echo "  - OTEL_SERVICE_NAME"
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
main