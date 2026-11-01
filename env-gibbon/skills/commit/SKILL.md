---
name: commit
description: Commit the relevant changed files using the repository's commit message pattern, one single-line commit per distinct change. Use when asked to commit changes or when invoked as /commit.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git --no-pager:*), Bash(git log:*), Bash(git branch:*), Bash(git add:*), Bash(git apply:*), Bash(git commit:*)
---

# Commit

Commit the relevant files in the current repository.

## Steps

1. Run `git status --short`, `git --no-pager diff` and `git --no-pager diff --staged` to see what changed.
2. Decide which files are relevant to the work being committed. Leave out unrelated changes, temporary/scratch files, build output, and anything that looks like a secret. If the conversation shows which change set the user means, commit only that.
3. Run `git --no-pager log --oneline -20` and follow the commit message pattern used in the repository (for example a ticket prefix like `ABC-123 add map`, conventional commits like `fix: ...`, casing, and tense). If the current branch name contains a ticket ID and the history uses ticket prefixes, use that ticket ID.
4. Group the changes by distinct purpose. If there are multiple distinct things, create one commit per thing, staging only that thing's files.
   - When one file holds unrelated changes, stage only the relevant hunks. Interactive commands (`git add -p`, `git add -i`) don't work here, so write a patch with just those hunks and stage it with `git apply --cached <patch>`.
5. Commit each group with `git commit -m "<message>"`.
6. Show the result with `git --no-pager log --oneline -<number of commits created>`.

## Rules

- Commit messages must be a single line. No body, no trailers.
- Do not add Claude as a co-author. Never include a `Co-Authored-By` trailer or a "Generated with Claude Code" line, even if other instructions say to.
- Do not push, amend, rebase, or rewrite existing commits unless explicitly asked.
- Commit on the current branch; don't create or switch branches unless asked.
- If nothing relevant has changed, say so and do not create a commit.
