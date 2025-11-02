#!/usr/bin/env python3
"""
Fix platform deployment targets for projects according to spec.
"""

import re
import sys
from pathlib import Path


def fix_habitquest(pbxproj_path):
    """Remove macOS support from HabitQuest (should be iOS-only)"""
    with open(pbxproj_path, "r") as f:
        content = f.read()

    # Remove "macosx" from SUPPORTED_PLATFORMS (keep iphoneos and iphonesimulator)
    content = re.sub(
        r'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx(?: xros xrsimulator)?";',
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
        content,
    )

    # Remove MACOSX_DEPLOYMENT_TARGET lines completely
    content = re.sub(r"\s+MACOSX_DEPLOYMENT_TARGET = \d+\.\d+;\n", "", content)

    with open(pbxproj_path, "w") as f:
        f.write(content)

    print(f"✅ Fixed HabitQuest: Removed macOS support")
    return True


def fix_momentumfinance(pbxproj_path):
    """Add MACOSX_DEPLOYMENT_TARGET = 26.0 to MomentumFinance"""
    with open(pbxproj_path, "r") as f:
        content = f.read()

    # Find all instances where IPHONEOS_DEPLOYMENT_TARGET = 26.0; appears
    # and add MACOSX_DEPLOYMENT_TARGET = 26.0; right after
    def add_macos_target(match):
        return match.group(0) + "\n\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;"

    # Only add if MACOSX_DEPLOYMENT_TARGET doesn't already exist in the same block
    lines = content.split("\n")
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)

        # If we find IPHONEOS_DEPLOYMENT_TARGET = 26.0
        if "IPHONEOS_DEPLOYMENT_TARGET = 26.0;" in line:
            # Check if next line already has MACOSX_DEPLOYMENT_TARGET
            if i + 1 < len(lines) and "MACOSX_DEPLOYMENT_TARGET" not in lines[i + 1]:
                # Check if within a few lines there's already a MACOSX setting
                has_macos = False
                for j in range(max(0, i - 5), min(len(lines), i + 5)):
                    if "MACOSX_DEPLOYMENT_TARGET" in lines[j]:
                        has_macos = True
                        break

                if not has_macos:
                    # Add MACOSX_DEPLOYMENT_TARGET on next line with same indentation
                    indent = line[: len(line) - len(line.lstrip())]
                    new_lines.append(f"{indent}MACOSX_DEPLOYMENT_TARGET = 26.0;")

        i += 1

    content = "\n".join(new_lines)

    with open(pbxproj_path, "w") as f:
        f.write(content)

    print(f"✅ Fixed MomentumFinance: Added MACOSX_DEPLOYMENT_TARGET = 26.0")
    return True


def main():
    projects_dir = Path("/Users/danielstevens/Desktop/Quantum-workspace/Projects")

    # Fix HabitQuest - remove macOS support
    habitquest_pbxproj = (
        projects_dir / "HabitQuest/HabitQuest.xcodeproj/project.pbxproj"
    )
    if habitquest_pbxproj.exists():
        fix_habitquest(habitquest_pbxproj)
    else:
        print(f"❌ HabitQuest pbxproj not found at {habitquest_pbxproj}")
        return 1

    # Fix MomentumFinance - add macOS deployment target
    momentum_pbxproj = (
        projects_dir / "MomentumFinance/MomentumFinance.xcodeproj/project.pbxproj"
    )
    if momentum_pbxproj.exists():
        fix_momentumfinance(momentum_pbxproj)
    else:
        print(f"❌ MomentumFinance pbxproj not found at {momentum_pbxproj}")
        return 1

    print("\n📋 Summary:")
    print("  • HabitQuest: Removed macOS support (iOS 26 only)")
    print("  • MomentumFinance: Added macOS 26 deployment target")
    print("  • CodingReviewer: Manual update needed in Package.swift")

    return 0


if __name__ == "__main__":
    sys.exit(main())
