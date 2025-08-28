#!/bin/bash
# Test script to verify the Valheim server setup

echo "🧪 Testing Valheim Server Setup"
echo "==============================="
echo ""

# Check if all required files exist
FILES=(
    "setup.sh"
    "valheim-server.sh" 
    "valheim-server.conf.example"
    "install-service.sh"
    "maintenance.sh"
    "README.md"
)

echo "📁 Checking required files..."
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
        exit 1
    fi
done

echo ""
echo "🔍 Checking file permissions..."
SCRIPTS=("setup.sh" "valheim-server.sh" "install-service.sh" "maintenance.sh")
for script in "${SCRIPTS[@]}"; do
    if [[ -x "$script" ]]; then
        echo "✅ $script (executable)"
    else
        echo "❌ $script (not executable)"
        exit 1
    fi
done

echo ""
echo "📋 Checking script syntax..."
for script in "${SCRIPTS[@]}"; do
    if bash -n "$script"; then
        echo "✅ $script (syntax OK)"
    else
        echo "❌ $script (syntax error)"
        exit 1
    fi
done

echo ""
echo "🎯 Testing help command..."
if ./valheim-server.sh help > /dev/null; then
    echo "✅ valheim-server.sh help works"
else
    echo "❌ valheim-server.sh help failed"
    exit 1
fi

echo ""
echo "✅ All tests passed! Setup appears to be complete."
echo ""
echo "Next steps:"
echo "  1. Run ./setup.sh on a fresh Debian/Ubuntu system"
echo "  2. Edit valheim-server.conf"
echo "  3. Run ./valheim-server.sh start"
