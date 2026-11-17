#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# The guides are prose, and prose cannot be tested. A few things in them are
# not prose, though: a table that repeats a file, a number that repeats a list,
# a tool that is named because the Brewfile installs it. Those are compared
# with what they repeat, so the page cannot go on saying it after the code has
# stopped.

GUIDES="$REPO/guides"
TAB="$(printf '\t')"

# The one list of pages, from guide.js: a line each, the file, a tab, its title.
pages() {
  sed -n 's/^ *{ file: "\([^"]*\)", title: "\([^"]*\)" },\{0,1\}$/\1'"$TAB"'\2/p' \
    "$GUIDES/assets/guide.js"
}

@test "the cheat sheet lists the git aliases lib/git.zsh defines, and no others" {
  local defined listed
  defined="$(sed -n "s/^alias \([^=]*\)='\(.*\)'$/\1=\2/p" "$REPO/config/zsh/lib/git.zsh" | sort)"
  [ "$(printf '%s\n' "$defined" | grep -c =)" -ge 5 ] \
    || { echo "found fewer than five aliases in lib/git.zsh, so the search did not work"; return 1; }

  # The first table under the Git heading: a name in one cell and what it runs
  # in the next, two pairs to a row.
  listed="$(awk '/<h2 id="git">/ { on = 1 } on { print } on && /<\/table>/ { exit }' "$GUIDES/tools.html" \
    | grep -oE '<td><code>[^<]+</code></td><td><code>[^<]+</code></td>' \
    | sed -E 's|<td><code>([^<]+)</code></td><td><code>([^<]+)</code></td>|\1=\2|' | sort)"

  [ "$listed" = "$defined" ] || {
    echo "guides/tools.html and config/zsh/lib/git.zsh disagree (< the cheat sheet, > the file):"
    diff <(printf '%s\n' "$listed") <(printf '%s\n' "$defined")
    return 1
  }
}

@test "every guide is in guide.js's list, and numbered by its place in it" {
  local total n=0 file title page wanted
  total="$(pages | grep -c .)"
  [ "$total" -ge 2 ] || { echo "found $total pages in guide.js, so the search did not work"; return 1; }

  while IFS="$TAB" read -r file title; do
    n=$((n + 1))
    [ -f "$GUIDES/$file" ] || { echo "guide.js lists $file, and there is no such page"; return 1; }
    wanted="<p class=\"eyebrow\">Guide $n of $total · $title</p>"
    grep -qF "$wanted" "$GUIDES/$file" || {
      echo "$file should say: $wanted"
      echo "it says:          $(grep -o '<p class="eyebrow">.*</p>' "$GUIDES/$file")"
      return 1
    }
  done < <(pages)

  # A page that is not in the list has no way in: the navigation and the
  # previous and next links are both built from it.
  for page in "$GUIDES"/*.html; do
    pages | grep -q "^$(basename "$page")$TAB" \
      || { echo "$(basename "$page") is not in guide.js's list"; return 1; }
  done
}

@test "both READMEs point at every guide" {
  local file title
  while IFS="$TAB" read -r file title; do
    grep -qF "dotfiles/$file" "$REPO/README.md" \
      || { echo "README.md has no link to $file"; return 1; }
    grep -qF "\`$file\`" "$GUIDES/README.md" \
      || { echo "guides/README.md does not list $file"; return 1; }
  done < <(pages)
}

@test "a tool the guides mark as installed is in the Brewfile" {
  # A tool named because the Brewfile installs it is wrapped in an element
  # that carries its name there: <span data-brew="neovim">Neovim</span>.
  local name count=0 missing=""
  while read -r name; do
    count=$((count + 1))
    grep -qE "^(brew|cask) '$name'" "$REPO/Brewfile" || missing="$missing $name"
  done < <(grep -ohE 'data-brew="[^"]+"' "$GUIDES"/*.html | sed -E 's/data-brew="(.*)"/\1/' | sort -u)
  [ "$count" -ge 10 ] || { echo "only found $count marked tools, so the search did not work"; return 1; }
  [ -z "$missing" ] || { echo "named in the guides and not in the Brewfile:$missing"; return 1; }
}
