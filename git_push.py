#!/usr/bin/env python3
"""
git_push.py — stage, commit, and push all changes using pure Python
(no shell scripting; uses subprocess to call git directly).

Usage:
    python3 git_push.py "commit message here"
    python3 git_push.py -b develop "msg"
    python3 git_push.py --dry-run "msg"
"""

import argparse
import subprocess
import sys

def run_cmd(cmd, dry_run=False):
    print(f"$ {' '.join(cmd)}")
    if dry_run:
        return 0
    result = subprocess.run(cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)
    return result.returncode

def main():
    parser = argparse.ArgumentParser(description="Stage, commit, and push repository changes.")
    parser.add_argument("message", nargs="?", default="chore: automated commit", help="Commit message")
    parser.add_argument("-b", "--branch", default="main", help="Target branch (default: main)")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing")

    args = parser.parse_args()

    # Stage all changes
    run_cmd(["git", "add", "-A"], dry_run=args.dry_run)

    # Check if there are staged changes
    status_result = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
    if status_result.returncode == 0 and not args.dry_run:
        print("No changes staged for commit.")
        return

    # Commit changes
    run_cmd(["git", "commit", "-m", args.message], dry_run=args.dry_run)

    # Push to remote branch
    run_cmd(["git", "push", "origin", args.branch], dry_run=args.dry_run)

if __name__ == "__main__":
    main()
