#!/usr/bin/env python3
"""
Repository Summarizer
A tool to fetch and summarize all repositories for a GitHub user.
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime
from typing import List, Dict, Any


def fetch_user_repositories(username: str) -> List[Dict[str, Any]]:
    """
    Fetch all repositories for a given GitHub user.
    
    Args:
        username: GitHub username
        
    Returns:
        List of repository dictionaries
    """
    repos = []
    page = 1
    per_page = 100
    
    while True:
        url = f"https://api.github.com/users/{username}/repos?page={page}&per_page={per_page}&sort=updated"
        
        try:
            request = urllib.request.Request(url)
            request.add_header('Accept', 'application/vnd.github.v3+json')
            request.add_header('User-Agent', 'Repository-Summarizer/1.0')
            
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.loads(response.read().decode('utf-8'))
                
                if not data:
                    break
                    
                repos.extend(data)
                
                # If we got fewer than per_page results, we're done
                if len(data) < per_page:
                    break
                    
                page += 1
                
        except urllib.error.HTTPError as e:
            print(f"Error fetching repositories: {e.code} - {e.reason}", file=sys.stderr)
            if e.code == 404:
                print(f"User '{username}' not found", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            print(f"Network error: {e.reason}", file=sys.stderr)
            sys.exit(1)
    
    return repos


def format_date(date_str: str) -> str:
    """Format ISO date string to readable format."""
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt.strftime('%Y-%m-%d')
    except:
        return date_str


def generate_markdown_summary(username: str, repos: List[Dict[str, Any]]) -> str:
    """
    Generate a markdown summary of repositories.
    
    Args:
        username: GitHub username
        repos: List of repository dictionaries
        
    Returns:
        Markdown formatted string
    """
    # Sort repositories by stars (descending) and then by update date
    sorted_repos = sorted(repos, key=lambda r: (r['stargazers_count'], r['updated_at']), reverse=True)
    
    md = f"# GitHub Repositories Summary for @{username}\n\n"
    md += f"**Total Repositories:** {len(repos)}\n\n"
    md += f"**Generated on:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    md += "---\n\n"
    
    # Statistics
    total_stars = sum(r['stargazers_count'] for r in repos)
    total_forks = sum(r['forks_count'] for r in repos)
    languages = {}
    
    for repo in repos:
        lang = repo.get('language') or 'Unknown'
        languages[lang] = languages.get(lang, 0) + 1
    
    md += "## Statistics\n\n"
    md += f"- **Total Stars:** {total_stars}\n"
    md += f"- **Total Forks:** {total_forks}\n"
    md += f"- **Languages Used:** {', '.join(sorted(languages.keys()))}\n\n"
    
    # Language breakdown
    md += "### Language Breakdown\n\n"
    for lang, count in sorted(languages.items(), key=lambda x: x[1], reverse=True):
        repo_word = "repository" if count == 1 else "repositories"
        md += f"- **{lang}:** {count} {repo_word}\n"
    md += "\n"
    
    # Repository table
    md += "## Repository List\n\n"
    md += "| Repository | Description | Language | ⭐ Stars | 🍴 Forks | 📅 Last Updated |\n"
    md += "|------------|-------------|----------|---------|---------|----------------|\n"
    
    for repo in sorted_repos:
        name = repo['name']
        url = repo['html_url']
        description = (repo.get('description') or 'No description')[:60]
        if len(repo.get('description') or '') > 60:
            description += '...'
        language = repo.get('language') or 'N/A'
        stars = repo['stargazers_count']
        forks = repo['forks_count']
        updated = format_date(repo['updated_at'])
        
        md += f"| [{name}]({url}) | {description} | {language} | {stars} | {forks} | {updated} |\n"
    
    md += "\n---\n\n"
    md += "*This summary was generated automatically using the GitHub API.*\n"
    
    return md


def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        username = sys.argv[1]
    else:
        username = "sirnple"  # Default user
    
    print(f"Fetching repositories for user: {username}...")
    
    repos = fetch_user_repositories(username)
    
    if not repos:
        print(f"No repositories found for user '{username}'")
        sys.exit(0)
    
    print(f"Found {len(repos)} repositories. Generating summary...")
    
    summary = generate_markdown_summary(username, repos)
    
    # Write to file
    output_file = f"{username}_repositories.md"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(summary)
    
    print(f"Summary written to: {output_file}")
    
    # Also print to stdout
    print("\n" + "="*80 + "\n")
    print(summary)


if __name__ == "__main__":
    main()
