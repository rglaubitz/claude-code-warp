# rglaubitz fork setup

This fork of `warpdotdev/claude-code-warp` adds:

1. **CWD-basename tab labels** — blanks `query` and `response` in the
   OSC 777 payload so Warp's vertical-tab middle line falls back to
   the project basename instead of showing the prompt text.
2. **Upstream-drift watch** — daily GitHub Action that diffs the fork
   against `warpdotdev/claude-code-warp` and opens an issue when risky
   files change.
3. **Claude responder** — when a drift issue lands, Claude Code merges
   upstream onto a sync branch, re-applies the customizations, and
   opens a PR. Falls back to a comment-only analysis if it can't
   safely re-apply.

The first item is fully wired. The latter two need three manual steps
before they're operational.

## 1. Add the Claude Code OAuth token (one-time)

The `claude-investigate` workflow uses
[`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action),
which authenticates either with an OAuth token (Pro/Max sub) or an
Anthropic API key.

**Recommended (sub):**

```bash
# In your local Claude Code session, get a long-lived OAuth token:
/install-github-app
# Follow the OAuth flow in the browser. It writes a token you can copy.

# Then add it as a repo secret:
gh secret set CLAUDE_CODE_OAUTH_TOKEN -R rglaubitz/claude-code-warp
# (paste the token when prompted)
```

**Alternative (API key):**

```bash
gh secret set ANTHROPIC_API_KEY -R rglaubitz/claude-code-warp
# Then edit .github/workflows/claude-investigate.yml:
# replace `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}`
# with    `anthropic_api_key:        ${{ secrets.ANTHROPIC_API_KEY }}`
```

## 2. Switch your local Claude Code to install from this fork

Currently your local Claude Code has `warp@claude-code-warp` installed
from the upstream marketplace. Swap to the fork:

```bash
# In Claude Code:
/plugin uninstall warp@claude-code-warp
/plugin marketplace remove claude-code-warp

/plugin marketplace add rglaubitz/claude-code-warp
/plugin install warp@claude-code-warp-rglaubitz

/reload-plugins
```

The marketplace identifier in this fork is
`claude-code-warp-rglaubitz` (renamed from upstream's `claude-code-warp`)
specifically so both can coexist if you ever want to A/B test.

## 3. Verify the workflows

```bash
# Trigger the drift check manually to make sure it runs cleanly:
gh workflow run upstream-drift.yml -R rglaubitz/claude-code-warp
gh run watch -R rglaubitz/claude-code-warp

# After it succeeds, .upstream-sha should be committed.
```

## How the drift loop actually flows

```
                       ┌─────────────────────────────┐
   daily 14:00 UTC ──→ │  upstream-drift.yml         │
                       │  - fetch upstream/main      │
                       │  - diff risky files vs      │
                       │    .upstream-sha baseline   │
                       │  - if drift: open issue     │
                       │    with `upstream-drift`    │
                       │    label + baseline-sha     │
                       │    HTML comment             │
                       └────────────┬────────────────┘
                                    │
                                    ▼ label fires
                       ┌─────────────────────────────┐
                       │  claude-investigate.yml     │
                       │  - reads issue              │
                       │  - branches sync/upstream-X │
                       │  - merges upstream          │
                       │  - re-applies customization │
                       │  - opens PR (Closes #N)     │
                       └────────────┬────────────────┘
                                    │
                                    ▼ you review & merge
                       ┌─────────────────────────────┐
                       │  PR merge auto-closes issue │
                       │  via "Closes #N"            │
                       └────────────┬────────────────┘
                                    │
                                    ▼ issue close fires
                       ┌─────────────────────────────┐
                       │  upstream-drift-baseline.yml│
                       │  - parses baseline-sha from │
                       │    issue body               │
                       │  - writes .upstream-sha     │
                       │  - commits to main          │
                       └─────────────────────────────┘
```

If Claude bails out (the customization is no longer cleanly
applicable), it comments on the issue and stops. You apply the fix
manually and close the issue — the baseline still advances.

## Risky files (what the watch pays attention to)

| File                                            | Why it matters                                                                                                                |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `plugins/warp/scripts/should-use-structured.sh` | Hardcoded "last broken Warp release" thresholds; if upstream bumps these and you don't, your hooks fire on broken Warp builds |
| `plugins/warp/scripts/build-payload.sh`         | OSC 777 envelope schema. If `v` bumps to 2, protocol changed                                                                  |
| `plugins/warp/hooks/hooks.json`                 | New event types Warp expects                                                                                                  |
| `.claude-plugin/marketplace.json`               | Marketplace structure; we override `name` here                                                                                |
| `plugins/warp/.claude-plugin/plugin.json`       | Plugin version + name                                                                                                         |

Drift in any other file (READMEs, on-\*.sh scripts you've already
overridden, tests) auto-bumps the baseline silently with no issue
opened.

## Reverting customizations

If you want to drop the cwd-basename change and go back to upstream
behavior:

```bash
git revert <sha-of-feat-blank-query-response>
git push origin main
```

The marketplace rename will still be there; revert that separately if
you want to take the fork back to upstream parity entirely.
