---
name: claude-codex-handoff
description: "Delegates scoped tasks from Claude Code to Codex CLI: prompt, exec launch, session resume, and result verification. Use when the user asks to hand a change or audit to Codex from Claude Code, or to coordinate Claude and Codex."
---

# Claude Code → Codex CLI

Claude Code sets the task, accepts the result, and talks to the user.
Codex CLI reads the code, makes scoped edits, and runs checks in its own
session. Claude gets a short handoff report back; full logs stay in files.

## What to delegate

Codex fits edits with clear bounds, refactors, tests, and audits against
concrete criteria. A small task where prompting and acceptance cost more than
the edit is cheaper to do in the current session.

Before delegating, check which tools each side actually has. Claude and Codex
sessions have their own settings, auth, and MCP connections: access on one
agent does not imply access on the other. Pass project rules as paths to files
the executor can read, not as links to skills it does not have.

Visual acceptance needs an agent with a working browser. If only Claude has a
browser, give the live check to Claude or a Claude subagent after Codex
finishes. Static analysis and a build do not confirm how the UI looks.

## Prepare

- Read the project instructions (`AGENTS.md`, `CLAUDE.md` if present) and run
  `git status`. Do not delete, revert, or claim someone else's changes.
- State the goal, allowed files, constraints, and observable acceptance
  criteria. Ask the executor to check the prompt against the current code
  before editing.
- For an ambiguous task, get a plan in `read-only` first, then resume the same
  session for implementation with the accepted decisions.
- Keep prompts, logs, and handoffs in a directory outside the repository. Use
  new filenames for each run so you do not treat an old report as a new one.

Prompt template and reply format: [references/prompt-template.md](references/prompt-template.md).

## Launch

From the target repository or worktree:

```bash
task_dir=$(mktemp -d "${TMPDIR:-/tmp}/claude-codex.XXXXXX")
# Write the task to "$task_dir/prompt.md" from the references template.
codex exec -s workspace-write -c approval_policy=never \
  --output-last-message "$task_dir/handoff.md" - \
  < "$task_dir/prompt.md" > "$task_dir/run.log" 2>&1
codex_exit=$?
printf '%s\n' "$codex_exit" > "$task_dir/exit-code"
```

Available models (Codex CLI 0.154 has no separate `models list` command):

```bash
{ printf '%s\n' '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"model-list","version":"1.0"}}}'; sleep .2; printf '%s\n' '{"method":"initialized","params":{}}' '{"method":"model/list","id":1,"params":{"limit":100,"includeHidden":false}}'; sleep 1; } | codex app-server 2>/dev/null | jq -r 'select(.id == 1) | .result.data[].model'
```

Pass the model with a flag: `codex exec -m <model> ...`.

For simple or medium code edits and mechanics, pick the current Terra model.
For medium and higher complexity, use Sol. For very hard architecture and
multi-step live diagnosis, use Astra.

`-` reads the full prompt from stdin. `--output-last-message` saves the agent's
last message; that is the handoff, not the full run journal. Keep the absolute
path to the run directory so you can recover the prompt after context
compression.

Run long jobs in the background (`run_in_background` in Claude Code, if
available). Wait for completion and check the exit code before acceptance. A
non-zero code is a launch failure even if a handoff exists; read the full
saved log first. Do not load a successful journal into context unless you need
it.

Start from a Git repository. `--skip-git-repo-check` is only for intentional
work outside Git. Do not use it to hide a wrong working directory.

## Resume a session

Take the exact `session id` from the first run's journal and pass it
explicitly:

```bash
codex exec -C /absolute/path/to/repository \
  -s workspace-write -c approval_policy=never \
  resume --output-last-message "$task_dir/handoff-2.md" SESSION_ID - \
  < "$task_dir/prompt-2.md" > "$task_dir/run-2.log" 2>&1
codex_exit=$?
printf '%s\n' "$codex_exit" > "$task_dir/exit-code-2"
```

Replace the path and `SESSION_ID` with real values. Send the refinement and
any bound changes; the rest of the task context is already in the session.
`-C`, `-s`, and `-c` belong to `exec`; `--output-last-message` in this example
belongs to `resume`.

Do not use `resume --last` while orchestrating: after another run it may pick
the wrong session. Do not pass `--ephemeral` if you will need to continue.
With `--json`, the id is in the `thread.started` event as `thread_id`; save it
with the other run artifacts.

### Session context size

Whether to resume or start a new session depends on context size and how close
the tasks are, not on one number. Continue a small follow-up on the same topic
even at 40–50% of the window. For a new or distant topic, start a fresh
session even at 20–30%; pass the needed facts as a short list in the prompt —
a fresh session can already see the working tree and the MR description.

Measure context size, not spend: `tokens used` at the end of the log is the
cumulative session cost. Current size is `last_token_usage.input_tokens` on
the last record in
`~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-*<session id>*.jsonl`. The window
is `model_context_window` in the same file. Checked on Codex CLI 0.154
(17 September 2026).

```bash
~/.claude/skills/claude-codex-handoff/scripts/codex-ctx.sh <session id>
```

The script prints the context size and the share of the window.

## Permissions

Pick the sandbox explicitly, including on resume:

- `read-only` — read, plan, and review without changing project files.
- `workspace-write` — edits in the working directory. Network is off by
  default, but that depends on configuration. For an allowed networked task
  there is `-c sandbox_workspace_write.network_access=true`.
- `danger-full-access` — no sandbox limits; use only with already agreed
  access and suitable isolation, for example inside a prepared container.

`approval_policy=never` means no interactive prompts. It does not grant extra
privileges. If an action is blocked, record the exact reason and the
capability required. Do not turn restrictions off automatically. Docker and
local sockets depend on the OS, sandbox, and environment config.

If Claude Code blocks the launch itself, say which command was denied;
changing access settings needs the user's permission. Do not add broad
allow-rules or change the global config to bypass a denial.

## Parallel work

Two executors may edit one checkout only with explicitly disjoint
responsibilities. Name the other agent's files in both prompts. Count
generated files, lock files, build artifacts, ports, and databases.

For overlapping edits use separate worktrees. Integrate after you inspect the
diff and run checks on the target branch; delete a worktree only after the
work is kept. Start the live check after edits and the build finish so the
checker does not see a half-done state.

## Independent review

If you need a review, start a new session `codex exec -s read-only`. Pass the
task goal, project rules, and the base and target SHAs. For uncommitted
edits, freeze the review scope and do not change it during the review.

Do not give the reviewer the implementer's handoff or your own correctness
claims: let it inspect the code independently. Ask only for findings with
severity, `file:line`, a failure scenario, and a recommended fix. Ordinary
`exec` can take those criteria in the prompt; you do not need a separate
`review` interface.

Send agreed findings to the working session with `resume`. Check disputed
claims against the code and reproducible scenarios; a count of agreeing
agents is not evidence. Do not start another broad review instead of a
pointed question.

## Acceptance

The handoff is the executor's claims. The accepting agent checks the result:

1. Read the constraints and unfinished items, then the launch exit code.
2. Reconcile files with `git status`, `git diff --stat`, and the diff itself;
   include new untracked files that a plain `git diff` misses.
3. Confirm each criterion with a matching artifact: a test result, a live
   scenario, an API response, a screenshot, or a checked document. Re-run the
   key check if you do not have an independent result.
4. Keep the full check output and the real exit code. Do not replace it with
   the code of `tail` or `tee`; on failure read the whole log, in chunks if it
   is large.
5. If a required check is unavailable, say so and why. Do not call the result
   fully verified, and do not hide a failure behind retries.

Commits, publishes, and external-system changes happen only inside the user's
task. Delegation itself grants no extra authority.
