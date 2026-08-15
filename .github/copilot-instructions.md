# Project continuity

- At the start of every session, read @docs/PROJECT_STATE.md, then inspect
  `git status`, the current branch, and recent commits before acting.
- Treat GitHub as the source of truth for source code, durable decisions, and
  collaborator-visible project state.
- Update `docs/PROJECT_STATE.md` at every major milestone and before stopping,
  switching tasks, or handing work to another agent.
- Each state update must record the objective, completed work, current branch,
  released commit/build, uncommitted changes, blockers, relevant pipeline or PR
  links, and the exact next action.
- Commit and push completed checkpoints to the active feature branch. Do not
  rely on `git stash` or unpushed commits for cross-machine recovery.
- Never leave a final deliverable or reusable source only under
  `~/.copilot/session-state`.
- Store machine-local checkpoints and intermediate artifacts under
  `.copilot-local/`; copy anything collaborators need into a tracked project
  directory.

# Release safety

- Every push to `main` starts Xcode Cloud and can produce a TestFlight archive.
- Validate release candidates on a branch before promoting them to `main`.
- Bump `CURRENT_PROJECT_VERSION` only for the intended TestFlight release.
- Promote the validated candidate and release bump to `main` in one push, then
  confirm both GitHub Actions and Xcode Cloud.
- Do not merge documentation-only or continuity-only work into `main`
  separately when it would create an unintended TestFlight build. Bundle it
  with the next requested release unless the user explicitly directs otherwise.

# Security

- Never commit credentials, tokens, signing assets, authentication state, or
  Copilot configuration files that may contain secrets.
