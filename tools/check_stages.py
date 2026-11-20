#!/usr/bin/env python3
"""Stage-pairing checks for Solace-LowEnd.

`tools/validate_pack.py` checks that every program has a pair and that the preprocessor
balances. This one checks the three things that only go wrong *across* a pair, and that
cost hours when they do:

  * a varying the fragment stage reads but the vertex stage never declares - the link
    fails, or worse, the value is undefined and the pack looks almost right;
  * a varying whose type differs between the two stages;
  * more or fewer than one DRAWBUFFERS / RENDERTARGETS directive in a fragment stage.
    None means Iris binds the first eight colour attachments (Intel supports seven);
    two means the pack depends on which one the mod happens to read first.

The output directives are looked for in the *uncommented* text, because that is where
they live: a shaderpack declares them in a comment. Varyings are looked for with the
comments stripped, so a commented-out declaration does not count.

Includes are expanded before scanning, because both problems so far have come out of
shared libraries: `lib/io_geometry.glsl` declares the varyings, `lib/composite_body.glsl`
holds the directive.

A vertex stage must not declare an output directive at all, and `final` is the one
program that writes the screen instead of a buffer, so it is allowed to have none.

Exit code 0 means every pair agrees. Usage:  python3 tools/check_stages.py [repo-root]
"""

import os
import re
import sys

INCLUDE = re.compile(r'#include\s+"([^"]*)"')
VARYING = re.compile(r"^\s*varying\s+(\w+)\s+(\w+)\s*;", re.MULTILINE)
OUTPUT_DIRECTIVE = re.compile(r"(DRAWBUFFERS|RENDERTARGETS)\s*:\s*([0-9]+)")

FOLDERS = ["", "world0", "world-1", "world1"]

ERRORS = []
WARNINGS = []


def error(message):
    ERRORS.append(message)


def warn(message):
    WARNINGS.append(message)


def strip_comments(text):
    """Remove // and /* */ comments so a commented-out line is not counted."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        two = text[i:i + 2]
        if two == "//":
            while i < n and text[i] != "\n":
                i += 1
        elif two == "/*":
            i += 2
            while i < n and text[i:i + 2] != "*/":
                i += 1
            i += 2
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def expand(path, shader_root, stack=None):
    """Inline every #include, so a varying declared in a library is seen.

    Both sides of an `#if` are kept: which branch is compiled depends on the options,
    and a varying that exists in either is a varying the pair can be built with. Cycles
    are stopped rather than followed.
    """
    if stack is None:
        stack = []
    if path in stack or not os.path.isfile(path):
        return ""
    stack = stack + [path]

    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()

    out = []
    for line in text.splitlines(True):
        stripped = line.lstrip()
        match = INCLUDE.search(line) if stripped.startswith("#include") else None
        if match:
            target = match.group(1)
            if target.startswith("/"):
                resolved = os.path.join(shader_root, target.lstrip("/"))
            else:
                resolved = os.path.join(os.path.dirname(path), target)
            out.append(expand(resolved, shader_root, stack))
        else:
            out.append(line)
    return "".join(out)


def varyings(text):
    found = {}
    for kind, name in VARYING.findall(strip_comments(text)):
        found[name] = kind
    return found


def check_program(shader_root, folder, name):
    fragment_path = os.path.join(shader_root, folder, name + ".fsh")
    vertex_path = os.path.join(shader_root, folder, name + ".vsh")
    if not (os.path.isfile(fragment_path) and os.path.isfile(vertex_path)):
        return

    label = "%s/%s" % (folder or ".", name)

    fragment_text = strip_comments(expand(fragment_path, shader_root))
    vertex_text = strip_comments(expand(vertex_path, shader_root))

    fragment_varyings = varyings(fragment_text)
    vertex_varyings = varyings(vertex_text)

    for varying, kind in sorted(fragment_varyings.items()):
        if varying not in vertex_varyings:
            error("%s.fsh reads varying '%s' that its vertex stage never declares"
                  % (label, varying))
        elif vertex_varyings[varying] != kind:
            error("%s: varying '%s' is %s in the vertex stage and %s in the fragment stage"
                  % (label, varying, vertex_varyings[varying], kind))

    for varying in sorted(vertex_varyings):
        if varying not in fragment_varyings:
            warn("%s.vsh declares varying '%s' that its fragment stage never reads"
                 % (label, varying))

    outputs = OUTPUT_DIRECTIVE.findall(expand(fragment_path, shader_root))
    if name != "final":
        if not outputs:
            error("%s.fsh has no DRAWBUFFERS or RENDERTARGETS directive, so every "
                  "colour attachment is bound" % label)
        elif len(outputs) > 1:
            error("%s.fsh declares %d output directives (%s); exactly one program can "
                  "have exactly one" % (label, len(outputs),
                                        ", ".join(kind for kind, _ in outputs)))

    for kind, _ in OUTPUT_DIRECTIVE.findall(expand(vertex_path, shader_root)):
        error("%s.vsh declares %s; a vertex stage has no colour outputs"
              % (label, kind))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))
    shader_root = os.path.join(root, "Solace-LowEnd", "shaders")

    if not os.path.isdir(shader_root):
        print("FAIL: no Solace-LowEnd/shaders under %s" % root)
        return 1

    checked = 0
    for folder in FOLDERS:
        directory = os.path.join(shader_root, folder)
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if not name.endswith(".fsh"):
                continue
            check_program(shader_root, folder, name[:-4])
            checked += 1

    print("Checked %d stage pairs." % checked)

    for message in WARNINGS:
        print("warning: %s" % message)

    if ERRORS:
        print("")
        for message in ERRORS:
            print("error: %s" % message)
        print("")
        print("FAIL: %d error(s), %d warning(s)" % (len(ERRORS), len(WARNINGS)))
        return 1

    print("OK: 0 errors, %d warning(s)" % len(WARNINGS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
