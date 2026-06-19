#!/usr/bin/env sh

# Check for required environment variables
if [ -z "$CU_USER" ] || [ -z "$CU_PASS" ]; then
    if [ -z "$CU_USER" ]; then
        echo "Error: CU_USER environment variable is not set" >&2
    fi
    if [ -z "$CU_PASS" ]; then
        echo "Error: CU_PASS environment variable is not set" >&2
    fi
    echo "" >&2
    echo "Best practices for secrets:" >&2
    echo "  • Never type secrets directly on the command line - they are saved in shell history" >&2
    echo "  • Use a separate secrets file and source it: source ~/.cu_secrets.sh" >&2
    echo "  • content of said file: export CU_USER='your-email'; export CU_PASS='your-password'" >&2
    echo "  • Add your secrets file to .gitignore and set permissions: chmod 600 ~/.cu_secrets.sh" >&2
    echo "  • Never commit secrets to version control" >&2
    exit 1
fi

curl -s -X POST -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"email\":\"$CU_USER\",\"password\":\"$CU_PASS\"}" "https://api.camelotunchained.com/auth/token" | jq -r '"Authorization: Bearer \(.access_token)"' > auth_token.curl
