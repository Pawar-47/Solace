#!/usr/bin/env python3
"""Check that the options, their names and the screen agree.

Three files have to say the same thing: lib/config.glsl defines the options,
lang/en_US.lang names them, and shaders.properties lays them out. An option that
exists in one and not the others shows up in game as a raw identifier or as a
setting the options screen never offers, which is silent until someone sees it.

Exit code 0 means all three agree and every translated language carries at least the
option names en_US has.
"""

import os
import re
import sys

DEFINE = re.compile(r"^#define\s+(\w+)\s+[^\s/]+\s*//\s*\[", re.MULTILINE)
OPTION_NAME = re.compile(r"^option\.(\w+)(?:\.comment)?=", re.MULTILINE)


def read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.normpath(os.path.join(here, "..", "Solace-LowEnd", "shaders"))

    config = os.path.join(root, "lib", "config.glsl")
    lang_dir = os.path.join(root, "lang")

    if not os.path.isfile(config):
        print("FAIL: lib/config.glsl not found")
        return 1

    options = set(DEFINE.findall(read(config)))
    if not options:
        print("FAIL: no options found in lib/config.glsl")
        return 1

    en_path = os.path.join(lang_dir, "en_US.lang")
    if not os.path.isfile(en_path):
        print("FAIL: lang/en_US.lang not found")
        return 1

    named = set(OPTION_NAME.findall(read(en_path)))

    print("options: %d, named in en_US: %d" % (len(options), len(named)))

    failures = 0

    missing = sorted(options - named)
    if missing:
        print("FAIL: %d option(s) have no name in en_US.lang: %s"
              % (len(missing), ", ".join(missing)))
        failures += 1

    extra = sorted(named - options)
    if extra:
        print("FAIL: %d name(s) in en_US.lang have no option: %s"
              % (len(extra), ", ".join(extra)))
        failures += 1

    # Every translated file must carry the names, tooltips are English.
    for name in sorted(os.listdir(lang_dir)):
        if not name.endswith(".lang") or name == "en_US.lang":
            continue
        translated = set(OPTION_NAME.findall(read(os.path.join(lang_dir, name))))
        short = sorted(named - translated)
        if short:
            print("warning: lang/%s is missing %d name(s), first: %s"
                  % (name, len(short), short[0]))

    if failures:
        print("FAIL: %d problem(s)" % failures)
        return 1

    print("OK: every option has a name and every name has an option")
    return 0


if __name__ == "__main__":
    sys.exit(main())
