# Prompt for Codex CLI

Copy the template into a file outside the repository. Fill in concrete paths,
bounds, and checks; drop items that do not apply. Do not put secrets in the
prompt.

```markdown
# Context

Repository: <absolute path>, worktree: <path>, branch: <name>.
Goal: <what behavior should change and why>.
Read first: <AGENTS.md / CLAUDE.md if present>, <project document>.
Check this prompt against the current code before editing; report contradictions.

# What to do

1. <file or module>: <concrete change>.
2. <next change, if needed>.

# Bounds

- Your scope: <files or modules>.
- You are not alone in the repository: <other agent> is changing <files>.
  Keep their changes and account for them in your work.
- If you need to leave the bounds, explain why before that edit.
- Do not commit or push: leave the result in the working tree.
- Do not change secrets, access settings, or config outside the task.
- <Project constraints: public API, compatibility, localizations, and so on>.

# Acceptance and checks

- <Observable scenario and expected result>.
- <Exact relevant check command>; expect exit code 0.
- git diff --check; expect exit code 0.
- Save the full output of each check under <artifact directory> and record
  its exit code. If a check is unavailable or failed, say why.
- <Who checks the UI and how, if the task has visual criteria>.

# Final handoff

1. Changed files — one line on what each edit did.
2. Checks — exact commands, exit codes, and paths to full logs.
3. What failed or was done differently — reason and impact.
4. Remaining questions — only decisions that need the owner.
```

For a follow-up on `SESSION_ID`, a separate refinement file is enough:

```markdown
Fix <concrete finding>.
Updated acceptance criterion: <scenario>.
Task bounds are unchanged. Write new check results to separate files.
Return the handoff in the same format.
```
