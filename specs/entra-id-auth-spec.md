# Entra ID Device Code Flow Authentication Specification

## Overview

This specification outlines the implementation of Microsoft Entra ID (Azure AD) device code flow authentication using pure bash scripting with curl, designed to integrate with Claude Code's OpenTelemetry (OTEL) telemetry system by adding authenticated user identification to `OTEL_RESOURCE_ATTRIBUTES`.

## Requirements

### Dependencies
- `curl` - for HTTP requests
- `jq` - for JSON parsing (preferred) or pure bash/sed/grep alternatives
- `bash` 4.0+ - for associative arrays and modern features

### Azure Configuration
- Azure app registration with device code flow enabled
- Public client application (no client secret required)
- Required API permissions: `User.Read` (Microsoft Graph)

## Authentication Flow

### 1. Device Code Request

**Endpoint:** `POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode`

**Request:**
```bash
curl -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/devicecode" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}&scope=https://graph.microsoft.com/User.Read offline_access"
```

**Response:**
```json
{
  "user_code": "FXNK-MJRL",
  "device_code": "FAQaBBRAAAAABiL1...",
  "verification_uri": "https://microsoft.com/devicelogin",
  "expires_in": 900,
  "interval": 5,
  "message": "To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code FXNK-MJRL to authenticate."
}
```

### 2. User Authentication Display

Display user instructions:
```bash
echo "Authentication Required"
echo "======================"
echo "1. Open: ${verification_uri}"
echo "2. Enter code: ${user_code}"
echo "3. Complete authentication in browser"
echo ""
echo "Waiting for authentication..."
```

### 3. Token Polling

**Endpoint:** `POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`

**Request:**
```bash
curl -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=${CLIENT_ID}&device_code=${device_code}"
```

**Response States:**

**Pending (continue polling):**
```json
{
  "error": "authorization_pending",
  "error_description": "The authorization request is still pending."
}
```

**Success:**
```json
{
  "token_type": "Bearer",
  "scope": "https://graph.microsoft.com/User.Read",
  "expires_in": 3600,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh_token": "AwABAAAAvPM1KaPlrEqdFSBzjqfTGAMxZGUTdM0t4B4...",
  "id_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0..."
}
```

**Error States:**
- `authorization_declined` - User denied the request
- `bad_verification_code` - Invalid device code
- `expired_token` - Device code expired

### 4. User Profile Retrieval

**Endpoint:** `GET https://graph.microsoft.com/v1.0/me`

**Request:**
```bash
curl -X GET \
  "https://graph.microsoft.com/v1.0/me" \
  -H "Authorization: Bearer ${access_token}" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users/$entity",
  "businessPhones": [],
  "displayName": "John Doe",
  "givenName": "John",
  "jobTitle": "Developer",
  "mail": "john.doe@company.com",
  "mobilePhone": null,
  "officeLocation": null,
  "preferredLanguage": "en-US",
  "surname": "Doe",
  "userPrincipalName": "john.doe@company.com",
  "id": "12345678-1234-1234-1234-123456789012"
}
```

## Implementation Structure

### Configuration Variables

```bash
# Azure App Registration Configuration
TENANT_ID="${ENTRA_TENANT_ID:-common}"
CLIENT_ID="${ENTRA_CLIENT_ID}"
SCOPE="https://graph.microsoft.com/User.Read offline_access"

# Authentication Settings
AUTH_CACHE_FILE="${HOME}/.claude-code-auth"
TOKEN_EXPIRY_BUFFER=300  # 5 minutes before actual expiry
POLLING_INTERVAL=5       # seconds
MAX_POLLING_ATTEMPTS=180 # 15 minutes total
```

### Core Functions

#### `request_device_code()`
- Makes initial device code request
- Parses and stores device_code, user_code, verification_uri
- Handles network errors

#### `display_user_instructions()`
- Shows formatted authentication instructions
- Includes user code and verification URL

#### `poll_for_token()`
- Implements polling loop with proper intervals
- Handles all response states (pending, success, error)
- Respects rate limiting

#### `get_user_profile()`
- Calls Microsoft Graph API
- Extracts user ID from response
- Handles API errors and token validation

#### `cache_auth_data()`
- Securely stores authentication tokens
- Includes expiration times
- Encrypts sensitive data

#### `check_cached_auth()`
- Validates existing cached authentication
- Checks token expiration
- Handles refresh if needed

### JSON Parsing Strategy

**With jq (preferred):**
```bash
user_id=$(echo "$response" | jq -r '.id')
access_token=$(echo "$response" | jq -r '.access_token')
```

**Pure bash alternative:**
```bash
user_id=$(echo "$response" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
access_token=$(echo "$response" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
```

## OTEL Integration

### Environment Variable Management

```bash
# Read existing OTEL_RESOURCE_ATTRIBUTES
existing_attrs="${OTEL_RESOURCE_ATTRIBUTES:-}"

# Add user ID
if [[ -n "$existing_attrs" ]]; then
    export OTEL_RESOURCE_ATTRIBUTES="user.id=${user_id},${existing_attrs}"
else
    export OTEL_RESOURCE_ATTRIBUTES="user.id=${user_id}"
fi
```

### Integration with Claude Code

The authentication script should be executed before Claude Code starts:

```bash
# In wrapper script or profile
source ./entra-id-auth.sh
claude-code "$@"
```

## Error Handling

### Network Errors
- Retry with exponential backoff
- Clear error messages for connectivity issues
- Fallback for offline scenarios

### Authentication Errors
- Handle user denial gracefully
- Clear expired token cache
- Provide re-authentication instructions

### API Errors
- Handle Microsoft Graph API rate limiting
- Token refresh on 401 responses
- Clear error messages for permission issues

## Security Considerations

### Token Storage
- Use secure file permissions (600)
- Consider encryption for sensitive data
- Clear tokens on logout/error

### Environment Variables
- Validate all input parameters
- Sanitize data before shell operations
- Avoid logging sensitive information

## Testing Strategy

### Unit Tests
- Mock curl responses
- Test JSON parsing functions
- Validate error handling paths

### Integration Tests
- Test against Azure test tenant
- Validate OTEL integration
- Test token refresh scenarios

## Configuration Example

### Environment Setup
```bash
# Required
export ENTRA_CLIENT_ID="12345678-1234-1234-1234-123456789012"
export ENTRA_TENANT_ID="87654321-4321-4321-4321-210987654321"

# Optional
export ENTRA_AUTH_CACHE="${HOME}/.claude-code-auth"
export ENTRA_AUTH_TIMEOUT=900  # 15 minutes
```

### App Registration Requirements
- Application type: Public client
- Redirect URIs: Not required for device code flow
- API permissions: Microsoft Graph > User.Read
- Grant admin consent if required by organization

## Future Enhancements

### Refresh Token Handling
- Automatic token refresh
- Background renewal
- Silent re-authentication

### Multi-Tenant Support
- Organization-specific tenant configuration
- Guest user handling
- B2B authentication scenarios

### Enhanced Telemetry
- Authentication success/failure metrics
- User session tracking
- Performance monitoring

## Dependencies and Compatibility

### Operating System Support
- Linux (bash 4.0+)
- macOS (bash 4.0+)
- Windows (WSL/Git Bash)

### Required Tools
- curl (any modern version)
- jq (optional but recommended)
- Standard POSIX utilities (sed, grep, awk)