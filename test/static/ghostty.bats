#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

GHOSTTY_CONFIG="$REPO/config/ghostty/config"
PROFILE="$REPO/script/init/Gotham.terminal"

# The installed CLI, which is not on PATH unless something puts it there.
ghostty_bin() {
  if command -v ghostty >/dev/null 2>&1; then command -v ghostty
  elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
    echo /Applications/Ghostty.app/Contents/MacOS/ghostty
  else return 1
  fi
}

@test "ghostty: the config is one Ghostty accepts" {
  local bin
  bin="$(ghostty_bin)" || skip "NOT CHECKED: Ghostty is not installed"
  run "$bin" +validate-config --config-file="$GHOSTTY_CONFIG"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "ghostty: every palette slot is the colour the Terminal.app profile puts there" {
  # tmux.conf colours by ANSI index, so a slot that moves recolours the status
  # line. The profile stores Generic RGB, the Ghostty config sRGB hex, so the
  # profile's colours are converted and each must land nearest the slot it
  # claims: a swap between two similar blues fails, a rounding difference does
  # not.
  run python3 -I - "$PROFILE" "$GHOSTTY_CONFIG" <<'PY'
import plistlib, sys

profile = plistlib.load(open(sys.argv[1], 'rb'))
palette = {}
for line in open(sys.argv[2]):
    line = line.strip()
    if line.startswith('palette'):
        slot, hexval = line.split('=', 1)[1].strip().split('=')
        palette[int(slot)] = hexval.strip().lstrip('#')
if sorted(palette) != list(range(16)):
    sys.exit('palette slots defined: %s' % sorted(palette))

def stored(key):
    for o in plistlib.loads(profile[key])['$objects']:
        if isinstance(o, dict) and 'NSRGB' in o:
            return [float(v) for v in o['NSRGB'].rstrip(b'\0').decode().split()[:3]]
    sys.exit('no RGB colour in ' + key)

def rgb_to_xyz(primaries, white=(0.3127, 0.3290)):
    xyz = lambda x, y: [x / y, 1.0, (1 - x - y) / y]
    cols = [xyz(*p) for p in primaries]
    m = [[cols[j][i] for j in range(3)] for i in range(3)]
    scale = solve(m, xyz(*white))
    return [[m[i][j] * scale[j] for j in range(3)] for i in range(3)]

def solve(m, v):
    a = [row[:] + [v[i]] for i, row in enumerate(m)]
    for c in range(3):
        p = max(range(c, 3), key=lambda r: abs(a[r][c]))
        a[c], a[p] = a[p], a[c]
        for r in range(3):
            if r != c:
                f = a[r][c] / a[c][c]
                a[r] = [x - f * y for x, y in zip(a[r], a[c])]
    return [a[i][3] / a[i][i] for i in range(3)]

def inverse(m):
    cols = [solve(m, [1.0 if i == j else 0.0 for i in range(3)]) for j in range(3)]
    return [[cols[j][i] for j in range(3)] for i in range(3)]

# Apple's Generic RGB (gamma 1.8) to sRGB.
generic = rgb_to_xyz([(.625, .34), (.28, .595), (.155, .07)])
to_srgb = inverse(rgb_to_xyz([(.64, .33), (.30, .60), (.15, .06)]))
def convert(c):
    lin = [v ** 1.8 for v in c]
    xyz = [sum(generic[i][k] * lin[k] for k in range(3)) for i in range(3)]
    out = [min(1, max(0, sum(to_srgb[i][k] * xyz[k] for k in range(3)))) for i in range(3)]
    return [255 * (12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055) for v in out]

def dist(a, h):
    return sum((a[i] - int(h[2 * i:2 * i + 2], 16)) ** 2 for i in range(3))

names = ['Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White']
keys = ['ANSI%sColor' % n for n in names] + ['ANSIBright%sColor' % n for n in names]
bad = 0
for slot, key in enumerate(keys):
    want = convert(stored(key))
    nearest = min(palette, key=lambda s: dist(want, palette[s]))
    if nearest != slot:
        print('slot %d (%s) is nearest slot %d' % (slot, key, nearest))
        bad += 1
sys.exit(1 if bad else 0)
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "ghostty: the font is one the Brewfile installs" {
  grep -qx 'font-family = FiraMono Nerd Font' "$GHOSTTY_CONFIG" \
    || { echo "font-family is not FiraMono Nerd Font"; return 1; }
  grep -qx "cask 'font-fira-mono-nerd-font'" "$REPO/Brewfile" \
    || { echo "the Brewfile no longer installs FiraMono Nerd Font"; return 1; }
}
