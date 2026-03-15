#!/bin/bash
#==============================================================================
# Claudian Build Script - FULL PERMISSION BYPASS MODE
#
# This wrapper script builds Claudian with Claude Code configured to run
# in full automation mode, bypassing all permission prompts.
#
# WARNING: This means Claude will have unrestricted access to execute any
# command without user confirmation. Only use this if you fully trust Claude
# and understand the security implications.
#==============================================================================

set -e

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (required for debootstrap and chroot)"
    echo "Usage: sudo ./build-with-full-bypass.sh"
    exit 1
fi

echo ""
echo "TPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPW"
echo "Q                                                                Q"
echo "Q          CLAUDIAN BUILD - FULL PERMISSION BYPASS MODE          Q"
echo "Q                                                                Q"
echo "ZPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP]"
echo ""
echo "   WARNING: This build will configure Claude Code to run with:"
echo ""
echo "    --allow-dangerously-skip-permissions"
echo "    --permission-mode bypassPermissions"
echo ""
echo "This means Claude will execute ALL commands without asking for"
echo "permission. Only proceed if you understand the security implications."
echo ""
read -p "Type 'yes' to continue with bypass mode: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Build cancelled."
    exit 0
fi

echo ""
echo "Proceeding with full bypass build..."
echo ""

# Set the bypass flag and run the main build script
export BUILD_WITH_BYPASS=yes
"$SCRIPT_DIR/build.sh"
