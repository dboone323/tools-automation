import pytest
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import fix_platform_targets


class TestFixPlatformTargets:
    """Comprehensive tests for fix_platform_targets.py"""

    def test_fix_habitquest_removes_macos_support(self):
        """Test that fix_habitquest removes macOS from SUPPORTED_PLATFORMS"""
        habitquest_content = """/* Begin PBXNativeTarget section */
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
MACOSX_DEPLOYMENT_TARGET = 13.0;
/* End PBXNativeTarget section */"""

        expected_content = """/* Begin PBXNativeTarget section */
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
/* End PBXNativeTarget section */"""

        with tempfile.NamedTemporaryFile(
            mode="w+", suffix=".pbxproj", delete=False
        ) as f:
            f.write(habitquest_content)
            temp_path = f.name

        try:
            result = fix_platform_targets.fix_habitquest(Path(temp_path))
            assert result is True

            with open(temp_path, "r") as f:
                modified_content = f.read()

            assert (
                'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' in modified_content
            )
            assert "macosx" not in modified_content
            assert "MACOSX_DEPLOYMENT_TARGET" not in modified_content
        finally:
            os.unlink(temp_path)

    def test_fix_habitquest_no_macos_present(self):
        """Test fix_habitquest when macOS is not present"""
        habitquest_content = """/* Begin PBXNativeTarget section */
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
/* End PBXNativeTarget section */"""

        with tempfile.NamedTemporaryFile(
            mode="w+", suffix=".pbxproj", delete=False
        ) as f:
            f.write(habitquest_content)
            temp_path = f.name

        try:
            result = fix_platform_targets.fix_habitquest(Path(temp_path))
            assert result is True

            with open(temp_path, "r") as f:
                modified_content = f.read()

            assert (
                'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' in modified_content
            )
        finally:
            os.unlink(temp_path)

    def test_fix_momentumfinance_adds_macos_target(self):
        """Test that fix_momentumfinance adds MACOSX_DEPLOYMENT_TARGET"""
        momentum_content = """/* Begin PBXNativeTarget section */
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
TVOS_DEPLOYMENT_TARGET = 26.0;
/* End PBXNativeTarget section */"""

        expected_addition = """IPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;"""

        with tempfile.NamedTemporaryFile(
            mode="w+", suffix=".pbxproj", delete=False
        ) as f:
            f.write(momentum_content)
            temp_path = f.name

        try:
            result = fix_platform_targets.fix_momentumfinance(Path(temp_path))
            assert result is True

            with open(temp_path, "r") as f:
                modified_content = f.read()

            assert "MACOSX_DEPLOYMENT_TARGET = 26.0;" in modified_content
        finally:
            os.unlink(temp_path)

    def test_fix_momentumfinance_macos_already_present(self):
        """Test fix_momentumfinance when MACOSX_DEPLOYMENT_TARGET already exists"""
        momentum_content = """/* Begin PBXNativeTarget section */
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
MACOSX_DEPLOYMENT_TARGET = 25.0;
/* End PBXNativeTarget section */"""

        with tempfile.NamedTemporaryFile(
            mode="w+", suffix=".pbxproj", delete=False
        ) as f:
            f.write(momentum_content)
            temp_path = f.name

        try:
            result = fix_platform_targets.fix_momentumfinance(Path(temp_path))
            assert result is True

            with open(temp_path, "r") as f:
                modified_content = f.read()

            # Should not add another MACOSX_DEPLOYMENT_TARGET
            assert modified_content.count("MACOSX_DEPLOYMENT_TARGET") == 1
            assert "MACOSX_DEPLOYMENT_TARGET = 25.0;" in modified_content
        finally:
            os.unlink(temp_path)

    def test_fix_momentumfinance_multiple_iphoneos_targets(self):
        """Test fix_momentumfinance with multiple IPHONEOS_DEPLOYMENT_TARGET entries"""
        momentum_content = """/* Begin PBXNativeTarget section */
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
TVOS_DEPLOYMENT_TARGET = 26.0;
/* End PBXNativeTarget section */
/* Begin PBXNativeTarget section */
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
WATCHOS_DEPLOYMENT_TARGET = 26.0;
/* End PBXNativeTarget section */"""

        with tempfile.NamedTemporaryFile(
            mode="w+", suffix=".pbxproj", delete=False
        ) as f:
            f.write(momentum_content)
            temp_path = f.name

        try:
            result = fix_platform_targets.fix_momentumfinance(Path(temp_path))
            assert result is True

            with open(temp_path, "r") as f:
                modified_content = f.read()

            # Should add MACOSX_DEPLOYMENT_TARGET after each IPHONEOS_DEPLOYMENT_TARGET
            assert modified_content.count("MACOSX_DEPLOYMENT_TARGET = 26.0;") == 2
        finally:
            os.unlink(temp_path)

    @patch("pathlib.Path.exists")
    def test_main_habitquest_not_found(self, mock_exists):
        """Test main function when HabitQuest pbxproj is not found"""
        mock_exists.return_value = False

        result = fix_platform_targets.main()
        assert result == 1

    def test_main_momentumfinance_not_found(self):
        """Test main function when MomentumFinance pbxproj is not found"""
        with patch("fix_platform_targets.Path") as mock_path, patch(
            "builtins.open", new_callable=mock_open
        ) as mock_file:

            # Set up file content for HabitQuest
            mock_file.return_value.read.return_value = """
            /* Begin PBXBuildFile section */
            /* End PBXBuildFile section */
            """

            # Create mock path objects with proper exists behavior and string conversion
            habitquest_path = Mock()
            habitquest_path.exists.return_value = True
            habitquest_path.__str__ = Mock(
                return_value="/Users/danielstevens/Desktop/Quantum-workspace/Projects/HabitQuest/HabitQuest.xcodeproj/project.pbxproj"
            )

            momentum_path = Mock()
            momentum_path.exists.return_value = False
            momentum_path.__str__ = Mock(
                return_value="/Users/danielstevens/Desktop/Quantum-workspace/Projects/MomentumFinance/MomentumFinance.xcodeproj/project.pbxproj"
            )

            projects_dir_mock = Mock()
            projects_dir_mock.exists.return_value = True

            def projects_dir_div(self, other):
                if "HabitQuest/HabitQuest.xcodeproj/project.pbxproj" in str(other):
                    return habitquest_path
                elif "MomentumFinance/MomentumFinance.xcodeproj/project.pbxproj" in str(
                    other
                ):
                    return momentum_path
                return Mock()  # Default mock for other paths

            projects_dir_mock.__truediv__ = projects_dir_div

            def path_constructor(path_str):
                if (
                    path_str
                    == "/Users/danielstevens/Desktop/Quantum-workspace/Projects"
                ):
                    return projects_dir_mock
                # For other paths, return a mock that exists
                other_mock = Mock()
                other_mock.exists.return_value = True
                return other_mock

            mock_path.side_effect = path_constructor

            result = fix_platform_targets.main()
            assert result == 1

    @patch("fix_platform_targets.fix_habitquest")
    @patch("fix_platform_targets.fix_momentumfinance")
    @patch("pathlib.Path.exists")
    def test_main_success(self, mock_exists, mock_momentum, mock_habit):
        """Test main function successful execution"""
        mock_exists.return_value = True
        mock_habit.return_value = True
        mock_momentum.return_value = True

        result = fix_platform_targets.main()
        assert result == 0

        mock_habit.assert_called_once()
        mock_momentum.assert_called_once()

    @patch("fix_platform_targets.fix_habitquest")
    @patch("fix_platform_targets.fix_momentumfinance")
    @patch("pathlib.Path.exists")
    @patch("builtins.print")
    def test_main_with_print_output(
        self, mock_print, mock_exists, mock_momentum, mock_habit
    ):
        """Test main function output"""
        mock_exists.return_value = True
        mock_habit.return_value = True
        mock_momentum.return_value = True

        result = fix_platform_targets.main()
        assert result == 0

        # Check that summary is printed
        mock_print.assert_any_call("\n📋 Summary:")
        mock_print.assert_any_call(
            "  • HabitQuest: Removed macOS support (iOS 26 only)"
        )
        mock_print.assert_any_call(
            "  • MomentumFinance: Added macOS 26 deployment target"
        )
        mock_print.assert_any_call(
            "  • CodingReviewer: Manual update needed in Package.swift"
        )
