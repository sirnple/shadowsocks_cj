#!/usr/bin/env python3
"""
Tests for the repository summarizer tool.
This tests the core functionality without requiring network access.
"""

import sys
import os

# Add the parent directory to path to import the module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import functions from summarize_repos
from summarize_repos import format_date, generate_markdown_summary


def test_format_date():
    """Test date formatting function."""
    test_cases = [
        ("2025-10-28T11:55:00Z", "2025-10-28"),
        ("2024-01-15T08:30:00Z", "2024-01-15"),
    ]
    
    for input_date, expected_output in test_cases:
        result = format_date(input_date)
        assert result == expected_output, f"Expected {expected_output}, got {result}"
    
    print("✓ test_format_date passed")


def test_generate_markdown_summary():
    """Test markdown generation with mock data."""
    mock_repos = [
        {
            'name': 'test-repo-1',
            'html_url': 'https://github.com/testuser/test-repo-1',
            'description': 'A test repository',
            'language': 'Python',
            'stargazers_count': 42,
            'forks_count': 5,
            'updated_at': '2025-10-28T11:55:00Z'
        },
        {
            'name': 'test-repo-2',
            'html_url': 'https://github.com/testuser/test-repo-2',
            'description': None,
            'language': None,
            'stargazers_count': 10,
            'forks_count': 2,
            'updated_at': '2025-09-15T08:30:00Z'
        }
    ]
    
    result = generate_markdown_summary("testuser", mock_repos)
    
    # Check that result contains expected content
    assert "# GitHub Repositories Summary for @testuser" in result
    assert "**Total Repositories:** 2" in result
    assert "**Total Stars:** 52" in result
    assert "**Total Forks:** 7" in result
    assert "test-repo-1" in result
    assert "test-repo-2" in result
    assert "Python" in result
    assert "No description" in result
    
    print("✓ test_generate_markdown_summary passed")


def test_markdown_table_format():
    """Test that the markdown table is properly formatted."""
    mock_repos = [
        {
            'name': 'repo1',
            'html_url': 'https://github.com/user/repo1',
            'description': 'Test',
            'language': 'Python',
            'stargazers_count': 1,
            'forks_count': 0,
            'updated_at': '2025-10-28T11:55:00Z'
        }
    ]
    
    result = generate_markdown_summary("user", mock_repos)
    
    # Check table headers
    assert "| Repository | Description | Language |" in result
    assert "|------------|-------------|----------|" in result
    
    # Check that repo appears in table
    assert "[repo1](https://github.com/user/repo1)" in result
    
    print("✓ test_markdown_table_format passed")


def test_language_statistics():
    """Test language breakdown statistics."""
    mock_repos = [
        {
            'name': 'repo1',
            'html_url': 'https://github.com/user/repo1',
            'description': 'Test',
            'language': 'Python',
            'stargazers_count': 1,
            'forks_count': 0,
            'updated_at': '2025-10-28T11:55:00Z'
        },
        {
            'name': 'repo2',
            'html_url': 'https://github.com/user/repo2',
            'description': 'Test',
            'language': 'Python',
            'stargazers_count': 1,
            'forks_count': 0,
            'updated_at': '2025-10-28T11:55:00Z'
        },
        {
            'name': 'repo3',
            'html_url': 'https://github.com/user/repo3',
            'description': 'Test',
            'language': 'JavaScript',
            'stargazers_count': 1,
            'forks_count': 0,
            'updated_at': '2025-10-28T11:55:00Z'
        }
    ]
    
    result = generate_markdown_summary("user", mock_repos)
    
    # Check language breakdown
    assert "### Language Breakdown" in result
    assert "**Python:** 2 repositories" in result
    assert "**JavaScript:** 1 repositories" in result
    
    print("✓ test_language_statistics passed")


def main():
    """Run all tests."""
    print("Running repository summarizer tests...\n")
    
    test_format_date()
    test_generate_markdown_summary()
    test_markdown_table_format()
    test_language_statistics()
    
    print("\n✓ All tests passed!")


if __name__ == "__main__":
    main()
