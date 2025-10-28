# Repository Summarizer

A Python tool to fetch and summarize all repositories for a GitHub user.

## Overview

This tool uses the GitHub API to retrieve information about all repositories owned by a specific user and generates a comprehensive markdown summary report.

## Features

- Fetches all public repositories for a GitHub user
- Generates detailed statistics including:
  - Total number of repositories
  - Total stars across all repositories
  - Total forks across all repositories
  - Language breakdown
- Creates a formatted markdown table with:
  - Repository name (with link)
  - Description
  - Primary language
  - Star count
  - Fork count
  - Last update date
- Sorts repositories by popularity (stars) and recency

## Requirements

- Python 3.6 or higher
- Internet connection
- No external dependencies (uses only Python standard library)

## Usage

### Basic Usage

To summarize repositories for the default user (sirnple):

```bash
python3 summarize_repos.py
```

### Specify a Different User

To summarize repositories for a specific GitHub user:

```bash
python3 summarize_repos.py <username>
```

Example:
```bash
python3 summarize_repos.py torvalds
```

## Output

The script generates:

1. A markdown file named `<username>_repositories.md` containing the full summary
2. Console output displaying the same summary

### Sample Output Format

```markdown
# GitHub Repositories Summary for @username

**Total Repositories:** 42

**Generated on:** 2025-10-28 12:00:00

---

## Statistics

- **Total Stars:** 12345
- **Total Forks:** 678
- **Languages Used:** Python, JavaScript, Go, Rust

### Language Breakdown

- **Python:** 15 repositories
- **JavaScript:** 12 repositories
- **Go:** 8 repositories
- **Rust:** 7 repositories

## Repository List

| Repository | Description | Language | ⭐ Stars | 🍴 Forks | 📅 Last Updated |
|------------|-------------|----------|---------|---------|----------------|
| [repo-name](https://github.com/user/repo-name) | A cool project... | Python | 1234 | 56 | 2025-10-15 |
...
```

## API Rate Limiting

The GitHub API has rate limits for unauthenticated requests:
- 60 requests per hour for unauthenticated requests
- 5000 requests per hour for authenticated requests

For most users with reasonable repository counts, the default unauthenticated access is sufficient.

## Error Handling

The script handles common errors:
- **404 Not Found:** User doesn't exist
- **403 Forbidden:** Rate limit exceeded or API access restricted
- **Network errors:** Connection issues

## Notes

- Only public repositories are included in the summary
- Private repositories are not accessible without authentication
- The script uses pagination to handle users with many repositories
- Repositories are sorted by star count (descending) and then by last update date

## License

This tool is part of the shadowsocks_cj project. See the main LICENSE file for details.
