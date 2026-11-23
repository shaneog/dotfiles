# How I work, in every project

A project's own `CLAUDE.md` or `AGENTS.md` wins wherever it says something
different.

- **No attribution.** A commit message ends with its body, and a pull request
  description is about the change and nothing else: no co-author trailer for a
  tool, no "generated with" footer, no link to a session.
- **Conventional Commits.** The body says why, or what was broken. The diff
  already says what.
- **Nothing private in a public repository.** No machine name, hostname,
  hardware model, OS version or employer, in a file, a commit message or a pull
  request.
- **Measure before claiming.** A speed claim needs a number, and a claim about
  behaviour needs a probe.
- **A test must be able to fail.** Break the thing on purpose, watch the test
  fail, then put it back.
- **Never discard uncommitted work.** No `git checkout --` or
  `git reset --hard` on a file with changes in it.
- **Comments explain the code as it is.** What it used to be goes in the commit
  message.
