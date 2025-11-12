"""Basic tests for tools automation."""

import pytest
import os
import sys

def test_python_version():
    """Test that Python version is compatible."""
    assert sys.version_info >= (3, 8)

def test_requirements_file_exists():
    """Test that requirements.txt exists."""
    assert os.path.exists('requirements.txt')

def test_gitignore_exists():
    """Test that .gitignore exists."""
    assert os.path.exists('.gitignore')

def test_readme_exists():
    """Test that README.md exists."""
    assert os.path.exists('README.md')

if __name__ == "__main__":
    pytest.main([__file__])