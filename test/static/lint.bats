#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

@test "every zsh file parses" {
  local f
  for f in "$REPO"/config/zsh/.zshenv "$REPO"/config/zsh/.zprofile \
           "$REPO"/config/zsh/.zshrc "$REPO"/config/zsh/.zlogin \
           "$REPO"/config/zsh/lib/*.zsh; do
    run "$ZSH_BIN" -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
  done
}

@test "every autoloaded function parses" {
  local f
  for f in "$REPO"/config/zsh/autoload/*; do
    run "$ZSH_BIN" -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
  done
}

@test "bash scripts parse and pass shellcheck" {
  local f
  for f in "$REPO"/script/* "$REPO"/test/vm/*; do
    [ -f "$f" ] || continue
    case "$f" in *.terminal) continue ;; esac
    run bash -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
    run shellcheck --severity=warning "$f"
    [ "$status" -eq 0 ] || { echo "shellcheck: $f"; echo "$output"; return 1; }
  done
}

@test "karabiner config is valid json" {
  run jq empty "$REPO/config/karabiner/karabiner.json"
  [ "$status" -eq 0 ]
}

@test "starship config is valid toml" {
  run python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" \
    "$REPO/config/starship.toml"
  [ "$status" -eq 0 ]
}

@test "git config parses and keeps signing wired up" {
  run git config --file "$REPO/config/git/config" --list
  [ "$status" -eq 0 ]
  run git config --file "$REPO/config/git/config" --get gpg.ssh.allowedSignersFile
  [ "$status" -eq 0 ]
  run git config --file "$REPO/config/git/config" --get commit.gpgsign
  assert_equal "$output" "true"
}

@test "allowed signers file is well formed" {
  # principal, then options/keytype, then the key material
  run grep -cE '^[^#].* (ssh-ed25519|ssh-rsa|ecdsa-) ' "$REPO/config/git/allowed_signers"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "tmux config loads without error" {
  # The config bootstraps TPM by cloning it, so hand it a throwaway HOME with a
  # stub already in place. Otherwise this "static" test clones plugins over
  # the network -- into this repo, since ~/.config is a symlink to it.
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.config/tmux/plugins/tpm"
  printf '#!/bin/sh\nexit 0\n' > "$home/.config/tmux/plugins/tpm/tpm"
  chmod +x "$home/.config/tmux/plugins/tpm/tpm"

  run env HOME="$home" tmux -L dotfiles-test -f "$REPO/config/tmux/tmux.conf" \
    new-session -d -s probe
  [ "$status" -eq 0 ] || echo "$output"
  tmux -L dotfiles-test kill-server 2>/dev/null || true
  [ "$status" -eq 0 ]

  # and nothing was fetched
  [ "$(ls "$home/.config/tmux/plugins")" = "tpm" ] \
    || { echo "the config fetched plugins during a static test"; return 1; }
}

@test "Brewfile is parseable and declares the test tooling" {
  run brew bundle list --file "$REPO/Brewfile"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx bats-core
  echo "$output" | grep -qx shellcheck
}

@test "script/macos only touches known domains" {
  local known="NSGlobalDomain com.apple.desktopservices com.apple.dock com.apple.finder com.apple.print.PrintingPrefs com.apple.Terminal nvram"
  local d
  # the settings table
  for d in $(grep -oE '^[[:space:]]+"[A-Za-z][A-Za-z0-9.]*\|' "$REPO/script/macos" \
               | tr -d '"|[:blank:]' | sort -u); do
    echo "$known" | grep -qw "$d" || { echo "unknown domain in the table: $d"; return 1; }
  done
  # and anything written outside it
  for d in $(grep -oE '^[[:space:]]*defaults write [A-Za-z0-9.-]+' "$REPO/script/macos" \
               | awk '{print $3}' | sort -u); do
    echo "$known" | grep -qw "$d" || { echo "unknown domain written directly: $d"; return 1; }
  done
}

@test "every settings table entry is well formed" {
  # A typo'd row would otherwise do nothing at all, quietly.
  local line type when count=0
  while IFS= read -r line; do
    count=$((count + 1))
    [ "$(echo "$line" | awk -F'|' '{print NF}')" -eq 6 ] \
      || { echo "expected 6 fields: $line"; return 1; }
    type="$(echo "$line" | cut -d'|' -f3)"
    case "$type" in
      -bool|-int|-float|-string|-array) ;;
      *) echo "unknown type '$type' in: $line"; return 1 ;;
    esac
    when="$(echo "$line" | cut -d'|' -f5)"
    case "$when" in
      now|relaunch|logout|reboot) ;;
      *) echo "unknown 'when' value '$when' in: $line"; return 1 ;;
    esac
  done < <(grep -E '^[[:space:]]+"[^"]*(\|[^"]*){5}"$' "$REPO/script/macos" \
             | sed 's/^[[:space:]]*"//; s/"$//')
  [ "$count" -ge 20 ] || { echo "only found $count settings, the table did not parse"; return 1; }
}

@test "workflows ask for no more than they need" {
  command -v yq >/dev/null || skip "yq not installed"
  # The repository default is a write token, so a workflow that says nothing gets
  # one. Neither of these writes to the repo.
  local wf
  for wf in "$REPO"/.github/workflows/*.yml; do
    run yq -e '.permissions.contents == "read"' "$wf"
    [ "$status" -eq 0 ] || { echo "$(basename "$wf") does not restrict its token"; return 1; }
    run yq -e '.permissions | keys | length == 1' "$wf"
    [ "$status" -eq 0 ] || { echo "$(basename "$wf") grants more than contents"; return 1; }
  done
}

@test "github workflows are valid yaml and run the whole suite" {
  command -v yq >/dev/null || skip "yq not installed"
  local wf="$REPO/.github/workflows/test.yml"
  run yq -e '.jobs | keys' "$wf"
  [ "$status" -eq 0 ]
  # every tier is actually wired up in CI
  local tier
  for tier in static unit integration; do
    grep -q "bats.*test/$tier" "$wf" || { echo "CI never runs test/$tier"; return 1; }
  done
}

@test "no stray runtime state is lurking under config/" {
  # ~/.config is a symlink into this repo, so tools write their state here.
  # Anything new must be a deliberate decision: track it, or ignore it.
  # Left alone, an allowlisted directory can silently accumulate state that a
  # broad `git add` would then publish.
  local stray
  stray="$(cd "$REPO" && git ls-files --others --exclude-standard -- config/)"
  [ -z "$stray" ] || { echo "untracked and unignored under config/:"; echo "$stray"; return 1; }
}

@test "every config entry is deliberately tracked or deliberately ignored" {
  # ~/.config is a symlink into this repo, so tools create directories here.
  # config/* ignores everything by default, which is the safe direction for a
  # public repo -- but it also means a directory you meant to version is
  # silently absent. Require each entry to be classified by a rule of its own:
  # tracked, or matched by something more specific than the blanket rule.
  #
  # Machine-local or otherwise unpublishable entries belong in
  # .git/info/exclude, which counts as an explicit rule without appearing in
  # the tracked .gitignore.
  local blanket unclassified="" exclude_file
  blanket="$(grep -n '^config/\*' "$REPO/.gitignore" | cut -d: -f1 | tr '\n' ' ')"
  exclude_file="$(cd "$REPO" && git rev-parse --absolute-git-dir)/info/exclude"
  local entry rule line
  for entry in "$REPO"/config/*; do
    entry="config/$(basename "$entry")"
    git -C "$REPO" ls-files --error-unmatch "$entry" >/dev/null 2>&1 && continue
    rule="$(git -C "$REPO" check-ignore -v "$entry" 2>/dev/null)"
    if [ -z "$rule" ]; then
      unclassified="$unclassified\n  $entry (neither tracked nor ignored)"
      continue
    fi
    # Only the blanket config/* rule matched, so nothing was decided about this
    # path. .gitignore outranks .git/info/exclude, so check-ignore will always
    # report the blanket rule even when a local classification exists -- consult
    # the exclude file directly.
    case "$rule" in
      *.gitignore:*)
        line="$(echo "$rule" | cut -d: -f2)"
        case " $blanket " in
          *" $line "*)
            grep -qE "^${entry}/?\$" "$exclude_file" 2>/dev/null && continue
            unclassified="$unclassified\n  $entry (only the blanket rule)"
            ;;
        esac
        ;;
    esac
  done
  if [ -n "$unclassified" ]; then
    printf 'unclassified config entries:%b\n' "$unclassified"
    echo "add a specific rule to .gitignore, or to .git/info/exclude if it should not be published"
    return 1
  fi
}

@test "no secrets in the history" {
  command -v gitleaks >/dev/null || skip "gitleaks not installed"
  # A custom format.pretty stops gitleaks finding commit boundaries: it reports
  # "0 commits scanned" and then "no leaks found", which reads exactly like a
  # pass. This repo no longer sets one, but the caller's own config might, so
  # neutralise it rather than trusting the environment -- and fail below if
  # nothing was actually scanned.
  run env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=format.pretty GIT_CONFIG_VALUE_0=medium \
    gitleaks git --no-banner --redact --exit-code 1 "$REPO"
  echo "$output"
  [ "$status" -eq 0 ] || { echo "gitleaks found something in the history"; return 1; }
  # a scan that scanned nothing is not a pass
  echo "$output" | grep -qE "[1-9][0-9]* commits scanned" \
    || { echo "gitleaks scanned no commits, so this proved nothing"; return 1; }
}

@test "BSD-only invocations name the BSD binary" {
  # This repo is macOS-only, but a shell with GNU coreutils earlier on PATH --
  # which a managed setup may well arrange -- turns `stat -f` into a filesystem
  # query and makes `sed -i ''` read its expression as a filename. Both fail
  # quietly enough to be mistaken for something else, so the flags that only BSD
  # accepts must name /usr/bin explicitly.
  local offenders
  offenders="$(grep -rnE "(^|[^/n])\bsed -i ''|(^|[^/])\bstat -f " \
    "$REPO/test" "$REPO/script" "$REPO/config" 2>/dev/null \
    | grep -v "usr/bin/" | grep -v "lint.bats" || true)"
  [ -z "$offenders" ] || { echo "unpinned BSD invocations:"; echo "$offenders"; return 1; }
}

@test "no test asserts with a bare negated command" {
  # Regression: `! grep -q attach-session "$LOG"` passed while the log held
  # exactly that. Bash exempts a !-negated command from errexit, so a failed one
  # is ignored unless it happens to be the test's last line -- and then it breaks
  # the moment a line is added below it. refute_contains fails from anywhere.
  local offenders
  offenders="$(grep -rn '^[[:space:]]*! ' "$REPO"/test/*/*.bats 2>/dev/null \
    | grep -v 'lint.bats' || true)"
  [ -z "$offenders" ] \
    || { echo "negated assertions are inert unless last; use refute_contains:";
         echo "$offenders"; return 1; }
}
