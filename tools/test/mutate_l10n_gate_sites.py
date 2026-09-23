# FertilizerDepot l10n gate battery (MAINTENANCE row 63): the repaired tr() helpers in
# src/ui/DepotDialog.lua and src/ui/DepotSettingsDialog.lua, the two sites
# l10n_gate_sites_test.lua drives through production's own methods, and the other two
# helpers (DepotManager, FdRfPdaGuest), which no bar drives: l10n_gate_identity_test.lua
# holds all four to one text, so a divergence in an undriven copy is killed there
# (mutations M1 to M3, Bob's finding on #77).
#
# KILLED* means killed only by a Lua error: a weak kill, treated as a failure.
#
# Anchors are written with "\n"; in a CRLF file they are matched as "\r\n".
#
# RUN IT ALONE, through the test lock. A battery edits production files in place.
#
# Usage: py tools/test/mutate_l10n_gate_sites.py [id-prefix ...]
import hashlib, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def p(rel): return os.path.join(ROOT, rel)

DIALOG = "src/ui/DepotDialog.lua"
SETTINGS = "src/ui/DepotSettingsDialog.lua"
MANAGER = "src/DepotManager.lua"
GUEST = "src/gui/FdRfPdaGuest.lua"

GATE_BODY = '''    local i18n = g_i18n
    if i18n == nil or type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function" then
        return fallback or key
    end
    local okHas, has = pcall(i18n.hasText, i18n, key)
    if not okHas or has ~= true then return fallback or key end
    local ok, text = pcall(i18n.getText, i18n, key)
    if not ok or type(text) ~= "string" or text == "" then return fallback or key end
    return text
'''

SHIPPED_SETTINGS = '''    local i18n = g_i18n
    if i18n then
        local ok, text = pcall(function() return i18n:getText(key) end)
        if ok and text and text ~= "" and text ~= ("$l10n_" .. key) then
            return text
        end
    end
    return fallback or key
'''

SHIPPED_DIALOG = '''    local i18n = g_i18n
    if i18n then
        local ok, text = pcall(function() return i18n:getText(key) end)
        if ok and text and text ~= "" and text ~= ("$l10n_" .. key)
           and not text:find("^Missing '") then
            return text
        end
    end
    return fallback or key
'''

MUTATIONS = [
 ("S1-settings-shipped-guard", SETTINGS, [(GATE_BODY, SHIPPED_SETTINGS, 1)],
  "the exposed shipped shape: only the dead $l10n_ comparison, so a missing key reaches the option list as the engine's sentence"),
 ("S2-dialog-shipped-defended-guard", DIALOG, [(GATE_BODY, SHIPPED_DIALOG, 1)],
  "the defended shipped shape: the sentence's prefix instead of hasText, so a key-returning i18n is believed"),
 ("S3-hastext-dropped", DIALOG,
  [("    local okHas, has = pcall(i18n.hasText, i18n, key)\n    if not okHas or has ~= true then return fallback or key end\n", "", 1)],
  "no hasText question at all: the missing sentence passes the type and empty checks"),
 ("S4-truthy-hastext-accepted", DIALOG,
  [("    if not okHas or has ~= true then return fallback or key end", "    if not okHas or not has then return fallback or key end", 1)],
  "a truthy non-boolean hasText is taken as the engine's true"),
 ("S5-type-check-dropped", DIALOG,
  [('    if not ok or type(text) ~= "string" or text == "" then return fallback or key end', '    if not ok or text == "" then return fallback or key end', 1)],
  "a key that exists with a non-string value is returned"),
 ("S6-empty-check-dropped", DIALOG,
  [('    if not ok or type(text) ~= "string" or text == "" then return fallback or key end', '    if not ok or type(text) ~= "string" then return fallback or key end', 1)],
  "a key that exists with an empty value is returned as empty"),
 ("S7-hastext-not-pcalled", DIALOG,
  [("    local okHas, has = pcall(i18n.hasText, i18n, key)", "    local okHas, has = true, i18n:hasText(key)", 1)],
  "an i18n whose hasText raises takes the dialog down"),
 ("S8-gettext-not-pcalled", DIALOG,
  [("    local ok, text = pcall(i18n.getText, i18n, key)", "    local ok, text = true, i18n:getText(key)", 1)],
  "an i18n whose getText raises takes the dialog down"),
 ("S9-no-i18n-not-refused", DIALOG,
  [('    if i18n == nil or type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function" then',
    '    if i18n ~= nil and (type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function") then', 1)],
  "a nil i18n reaches the pcall and errors instead of falling back"),

 # ── the undriven copies, held by the text-identity row ──────────────────────
 ("M1-guest-helper-diverges", GUEST,
  [("    local okHas, has = pcall(i18n.hasText, i18n, key)\n    if not okHas or has ~= true then return fallback or key end\n", "", 1)],
  "FdRfPdaGuest's copy loses its hasText question while the driven copies keep theirs"),
 ("M2-manager-helper-diverges", MANAGER,
  [("    if not okHas or has ~= true then return fallback or key end", "    if not okHas or not has then return fallback or key end", 1)],
  "DepotManager's copy accepts a truthy hasText while the driven copies do not"),
 ("M3-guest-helper-old-shape", GUEST,
  [(GATE_BODY, SHIPPED_SETTINGS, 1)],
  "FdRfPdaGuest's copy is the exposed shipped shape again"),
]


def sha(b): return hashlib.sha256(b).hexdigest()


def run_suite():
    r = subprocess.run(["node", "run-tests.mjs"], cwd=os.path.join(ROOT, "tools", "test"),
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    strip = lambda l: (re.sub(r"\x1b\[[0-9;]*m", "", l).strip()
                       .encode("ascii", "replace").decode("ascii"))
    fails = [strip(l) for l in out.splitlines() if "FAIL" in l and "assertions passed" not in l]
    crashes = [strip(l) for l in out.splitlines() if "Lua error while loading/running" in l]
    return r.returncode, fails, crashes


only = sys.argv[1:]
rc, fails, crashes = run_suite()
if rc != 0:
    print("BASELINE IS NOT GREEN; fix that before trusting any mutation result.")
    for l in fails[:10]:
        print("   " + l)
    sys.exit(2)
print("baseline green")

killed, crashkills, survived, badedit = [], [], [], []

for mid, rel, edits, why in MUTATIONS:
    if only and not any(mid.startswith(o) for o in only):
        continue
    path = p(rel)
    with open(path, "rb") as f:
        original = f.read()
    crlf = b"\r\n" in original
    enc = lambda s: (s.replace("\n", "\r\n") if crlf else s).encode("utf-8")

    ok, mutated = True, original
    for old, new, want in edits:
        ob, nb = enc(old), enc(new)
        n = mutated.count(ob)
        if n != want:
            badedit.append((mid, "anchor matched %dx, expected %d" % (n, want)))
            print("  !! %s: ANCHOR MISMATCH (%d != %d), mutation NOT applied" % (mid, n, want))
            ok = False
            break
        mutated = mutated.replace(ob, nb, want)
    if not ok:
        continue

    with open(path, "wb") as f:
        f.write(mutated)
    with open(path, "rb") as f:
        landed = f.read()
    if landed == original or landed != mutated:
        with open(path, "wb") as f:
            f.write(original)
        badedit.append((mid, "edit did not land"))
        print("  !! %s: EDIT DID NOT LAND" % mid)
        continue

    try:
        rc, fails, crashes = run_suite()
    finally:
        with open(path, "wb") as f:
            f.write(original)
    with open(path, "rb") as f:
        if sha(f.read()) != sha(original):
            print("  !! %s: RESTORE FAILED, stopping" % mid)
            sys.exit(3)

    named = [l for l in fails if l.startswith("FAIL ")]
    if rc != 0:
        killed.append(mid)
        tag = "KILLED  "
        if crashes and not named:
            crashkills.append(mid)
            tag = "KILLED* "
    else:
        survived.append((mid, why))
        tag = "SURVIVED"
    print("  %s %s  [%s]" % (tag, mid, rel))
    print("        (%s)" % why)
    for l in named[:4]:
        print("        " + l[:170])
    for l in crashes[:2]:
        print("        CRASH " + l[:170])

print("\n==== MUTATION RESULT ====")
print("killed   %d (of which %d only by a Lua error, marked KILLED*)" % (len(killed), len(crashkills)))
print("survived %d" % len(survived))
print("bad edit %d" % len(badedit))
for mid, why in survived:
    print("--- SURVIVED %s: %s" % (mid, why))
for mid, msg in badedit:
    print("--- BAD EDIT %s: %s" % (mid, msg))
print("all files restored byte-identical (hash-checked per mutation)")
sys.exit(1 if (survived or badedit or crashkills) else 0)
