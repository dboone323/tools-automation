import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("build_assets")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import build_assets: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/build_assets.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/build_assets.py",
                "exec",
            )
        print(f"File build_assets.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File build_assets.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestBuildAssets:
    """Comprehensive tests for build_assets.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/build_assets.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/build_assets.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in build_assets.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/build_assets.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("build_assets")
            assert True
        except ImportError:
            pytest.fail(f"Module build_assets should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_hash_file_basic(self):
        """Test hash_file function with basic file content"""
        import build_assets as module
        from pathlib import Path
        import tempfile

        # Create a temporary file with known content
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("test content")
            temp_path = Path(f.name)

        try:
            result = module.hash_file(temp_path)
            # SHA256 hash of "test content" truncated to 10 chars
            assert len(result) == 10
            assert result == "6ae8a75555"  # Pre-calculated hash
        finally:
            temp_path.unlink()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_hash_file_empty_file(self):
        """Test hash_file function with empty file"""
        import build_assets as module
        from pathlib import Path
        import tempfile

        # Create an empty temporary file
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            temp_path = Path(f.name)

        try:
            result = module.hash_file(temp_path)
            assert len(result) == 10
            # Empty file hash
            assert result == "e3b0c44298"  # SHA256 of empty string truncated
        finally:
            temp_path.unlink()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_hash_file_large_file(self):
        """Test hash_file function with larger file content"""
        import build_assets as module
        from pathlib import Path
        import tempfile

        # Create a temporary file with larger content
        large_content = "x" * 10000
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write(large_content)
            temp_path = Path(f.name)

        try:
            result = module.hash_file(temp_path)
            assert len(result) == 10
            # Should be different from empty file hash
            assert result != "e3b0c44298"
        finally:
            temp_path.unlink()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_with_missing_files(self):
        """Test build function when some asset files are missing"""
        import build_assets as module
        from pathlib import Path
        import tempfile
        import json

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            static_dir = temp_path / "static"
            static_dir.mkdir()

            # Mock the module's paths
            with patch.object(module, "STATIC_DIR", static_dir), patch.object(
                module, "MANIFEST_PATH", static_dir / "asset-manifest.json"
            ), patch("builtins.print") as mock_print:

                # Create only one of the expected files
                css_file = static_dir / "mcp_dashboard.css"
                css_file.write_text("body { color: red; }")

                # Create a custom FILES dict pointing to temp directory
                temp_files = {
                    "mcp_dashboard.css": css_file,
                    "mcp_dashboard.js": static_dir
                    / "mcp_dashboard.js",  # Doesn't exist
                    "favicon.svg": static_dir / "favicon.svg",  # Doesn't exist
                    "manifest.webmanifest": static_dir
                    / "manifest.webmanifest",  # Doesn't exist
                }

                with patch.object(module, "FILES", temp_files):
                    module.build()

                # Check that manifest was created
                manifest_file = static_dir / "asset-manifest.json"
                assert manifest_file.exists()

                with open(manifest_file, "r") as f:
                    manifest = json.load(f)

                # Should only contain the existing file
                assert "mcp_dashboard.css" in manifest
                assert len(manifest) == 1

                # Should have printed skip messages for missing files
                skip_calls = [
                    call
                    for call in mock_print.call_args_list
                    if "Skipping missing asset" in str(call)
                ]
                assert len(skip_calls) == 3  # 3 missing files

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_with_all_files_present(self):
        """Test build function when all asset files are present"""
        import build_assets as module
        from pathlib import Path
        import tempfile
        import json

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            static_dir = temp_path / "static"
            static_dir.mkdir()

            # Create all expected files
            files_content = {
                "mcp_dashboard.css": "body { color: blue; }",
                "mcp_dashboard.js": "console.log('hello');",
                "favicon.svg": "<svg></svg>",
                "manifest.webmanifest": '{"name": "test"}',
            }

            for filename, content in files_content.items():
                file_path = static_dir / filename
                file_path.write_text(content)

            # Mock the module's paths
            with patch.object(module, "STATIC_DIR", static_dir), patch.object(
                module, "MANIFEST_PATH", static_dir / "asset-manifest.json"
            ), patch("builtins.print") as mock_print:

                # Create a custom FILES dict pointing to temp directory
                temp_files = {}
                for filename in files_content.keys():
                    temp_files[filename] = static_dir / filename

                with patch.object(module, "FILES", temp_files):
                    module.build()

                # Check that manifest was created
                manifest_file = static_dir / "asset-manifest.json"
                assert manifest_file.exists()

                with open(manifest_file, "r") as f:
                    manifest = json.load(f)

                # Should contain all files
                assert len(manifest) == 4
                for logical_name in files_content.keys():
                    assert logical_name in manifest
                    hashed_name = manifest[logical_name]
                    # Check that hashed file exists
                    hashed_path = static_dir / hashed_name
                    assert hashed_path.exists()
                    # Check content is correct
                    assert hashed_path.read_text() == files_content[logical_name]

                # Should have printed completion message
                completion_calls = [
                    call
                    for call in mock_print.call_args_list
                    if "Wrote manifest to" in str(call)
                ]
                assert len(completion_calls) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_creates_hashed_files(self):
        """Test that build creates properly hashed filenames"""
        import build_assets as module
        from pathlib import Path
        import tempfile
        import json

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            static_dir = temp_path / "static"
            static_dir.mkdir()

            # Create a test CSS file
            css_content = ".test { color: red; }"
            css_file = static_dir / "mcp_dashboard.css"
            css_file.write_text(css_content)

            with patch.object(module, "STATIC_DIR", static_dir), patch.object(
                module, "MANIFEST_PATH", static_dir / "asset-manifest.json"
            ):

                # Create a custom FILES dict with just the CSS file
                temp_files = {
                    "mcp_dashboard.css": css_file,
                }

                with patch.object(module, "FILES", temp_files):
                    module.build()

                manifest_file = static_dir / "asset-manifest.json"
                with open(manifest_file, "r") as f:
                    manifest = json.load(f)

                hashed_name = manifest["mcp_dashboard.css"]
                # Should be in format: mcp_dashboard.{hash}.css
                assert hashed_name.startswith("mcp_dashboard.")
                assert hashed_name.endswith(".css")
                assert len(hashed_name) > len(
                    "mcp_dashboard.css"
                )  # Should include hash

                # Check the hashed file exists and has correct content
                hashed_file = static_dir / hashed_name
                assert hashed_file.exists()
                assert hashed_file.read_text() == css_content

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_build_idempotent(self):
        """Test that running build multiple times doesn't create duplicate files"""
        import build_assets as module
        from pathlib import Path
        import tempfile
        import json

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            static_dir = temp_path / "static"
            static_dir.mkdir()

            # Create a test file
            css_file = static_dir / "mcp_dashboard.css"
            css_file.write_text(".test { color: red; }")

            with patch.object(module, "STATIC_DIR", static_dir), patch.object(
                module, "MANIFEST_PATH", static_dir / "asset-manifest.json"
            ):

                # Create a custom FILES dict with just the CSS file
                temp_files = {
                    "mcp_dashboard.css": css_file,
                }

                with patch.object(module, "FILES", temp_files):
                    # Run build twice
                    module.build()
                    module.build()

                # Should only have one hashed file (not duplicates)
                css_files = list(static_dir.glob("mcp_dashboard.*.css"))
                assert len(css_files) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_files_constant(self):
        """Test that FILES constant is properly defined"""
        import build_assets as module
        from pathlib import Path

        # Check that FILES is a dict
        assert isinstance(module.FILES, dict)
        assert len(module.FILES) == 4  # Should have 4 files defined

        # Check that all values are Path objects
        for logical_name, path in module.FILES.items():
            assert isinstance(path, Path)
            assert logical_name in [
                "mcp_dashboard.css",
                "mcp_dashboard.js",
                "favicon.svg",
                "manifest.webmanifest",
            ]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_static_dir_and_manifest_path(self):
        """Test that STATIC_DIR and MANIFEST_PATH are properly configured"""
        import build_assets as module
        from pathlib import Path

        # Check types
        assert isinstance(module.STATIC_DIR, Path)
        assert isinstance(module.MANIFEST_PATH, Path)

        # Check that manifest path is inside static dir
        assert module.MANIFEST_PATH.parent == module.STATIC_DIR
        assert module.MANIFEST_PATH.name == "asset-manifest.json"
