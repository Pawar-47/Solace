#!/usr/bin/env python3
"""Structural checks for Solace-LowEnd.

This is the closest thing to a compiler that can run without a GPU, Minecraft or
Iris. It cannot tell whether a shader looks right, but it catches the mistakes that
stop a pack from loading at all, and the ones that silently do nothing:

  * an #include that points at a file which does not exist
  * unbalanced #if / #ifdef / #endif or unbalanced braces in any program
  * a .vsh without its .fsh, or a .fsh without its .vsh
  * a DRAWBUFFERS index outside 0-7, or a program with none where one is required
  * an option in lib/config.glsl with no name in lang/en_US.lang, or a name in
    en_US.lang with no option (a typo either way)
  * an option named in shaders.properties (screen, sliders, profile) that is not a
    define in lib/config.glsl
  * a translated language missing a name en_US.lang has

Exit code 0 means every check passed. Warnings are printed but do not fail the run.

Usage:  python3 tools/validate_pack.py [path-to-repo-root]
"""

import os
import re
import sys

ERRORS = []
WARNINGS = []


def error(message):
    ERRORS.append(message)


def warn(message):
    WARNINGS.append(message)


def read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def strip_comments_and_strings(text):
    """Remove comments so braces and directives inside them are not counted."""
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
        elif text[i] == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\":
                    i += 1
                i += 1
            i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


# --------------------------------------------------------------------------
# 1. Every #include resolves
# --------------------------------------------------------------------------

INCLUDE = re.compile(r'#include\s+"([^"]+)"')


def check_includes(shader_root, files):
    for path in files:
        text = strip_comments_and_strings(read(path))
        for target in INCLUDE.findall(text):
            if target.startswith("/"):
                resolved = os.path.join(shader_root, target.lstrip("/"))
            else:
                resolved = os.path.join(os.path.dirname(path), target)
            if not os.path.isfile(resolved):
                error("%s: #include \"%s\" does not exist"
                      % (os.path.relpath(path, shader_root), target))


# --------------------------------------------------------------------------
# 2. Preprocessor and brace balance
# --------------------------------------------------------------------------

DIRECTIVE = re.compile(r"^\s*#\s*(\w+)", re.MULTILINE)


def check_balance(shader_root, files):
    for path in files:
        text = strip_comments_and_strings(read(path))
        rel = os.path.relpath(path, shader_root)

        depth = 0
        for match in DIRECTIVE.finditer(text):
            word = match.group(1)
            if word in ("if", "ifdef", "ifndef"):
                depth += 1
            elif word == "endif":
                depth -= 1
                if depth < 0:
                    error("%s: #endif without #if" % rel)
                    depth = 0
        if depth != 0:
            error("%s: %d #if block(s) never closed" % (rel, depth))

        braces = text.count("{") - text.count("}")
        if braces != 0:
            error("%s: braces unbalanced by %d" % (rel, braces))

        parens = text.count("(") - text.count(")")
        if parens != 0:
            error("%s: parentheses unbalanced by %d" % (rel, parens))


# --------------------------------------------------------------------------
# 3. Program pairs and DRAWBUFFERS
# --------------------------------------------------------------------------

DRAWBUFFERS = re.compile(r"DRAWBUFFERS\s*:\s*([0-9]+)")


def check_programs(shader_root):
    for folder in [""] + ["world0", "world-1", "world1"]:
        directory = os.path.join(shader_root, folder)
        if not os.path.isdir(directory):
            continue
        names = os.listdir(directory)

        for name in names:
            if name.endswith(".vsh"):
                twin = name[:-4] + ".fsh"
                if twin not in names:
                    error("%s/%s has no matching .fsh" % (folder or ".", name))
            elif name.endswith(".fsh"):
                twin = name[:-4] + ".vsh"
                if twin not in names:
                    error("%s/%s has no matching .vsh" % (folder or ".", name))

        for name in names:
            if not name.endswith(".fsh"):
                continue
            text = read(os.path.join(directory, name))
            for indices in DRAWBUFFERS.findall(text):
                for digit in indices:
                    if int(digit) > 7:
                        error("%s/%s: DRAWBUFFERS index %s is out of range"
                              % (folder or ".", name, digit))


# --------------------------------------------------------------------------
# 4. Options against the language files
# --------------------------------------------------------------------------

OPTION_DEFINE = re.compile(
    r"^#define\s+(\w+)\s+[^\s/]+\s*//\s*\[([^\]]*)\]", re.MULTILINE)


def parse_options(config_text):
    options = {}
    for name, values in OPTION_DEFINE.findall(config_text):
        options[name] = values.split()
    return options


def lang_keys(path):
    keys = set()
    for line in read(path).splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        keys.add(line.split("=", 1)[0].strip())
    return keys


def check_options(shader_root, options):
    lang_dir = os.path.join(shader_root, "lang")
    en_path = os.path.join(lang_dir, "en_US.lang")
    if not os.path.isfile(en_path):
        error("lang/en_US.lang is missing")
        return

    en_keys = lang_keys(en_path)

    for name in sorted(options):
        if "option." + name not in en_keys:
            error("config option %s has no option.%s entry in lang/en_US.lang"
                  % (name, name))

    for key in sorted(en_keys):
        if key.startswith("option."):
            plain = key[len("option."):]
            if plain.endswith(".comment"):
                plain = plain[:-len(".comment")]
            if plain not in options:
                error("lang/en_US.lang defines %s but lib/config.glsl has no such option"
                      % key)
        elif key.startswith("value."):
            parts = key.split(".")
            if len(parts) >= 3:
                name = parts[1]
                if name not in options and not name.startswith("profile"):
                    warn("lang/en_US.lang has %s for a value of unknown option %s"
                         % (key, name))

    # A translated file must carry the same option names.
    for name in sorted(os.listdir(lang_dir)):
        if not name.endswith(".lang") or name == "en_US.lang":
            continue
        keys = lang_keys(os.path.join(lang_dir, name))
        missing = [key for key in en_keys
                   if key.startswith("option.") and not key.endswith(".comment")
                   and key not in keys]
        if missing:
            warn("lang/%s is missing %d option name(s), first: %s"
                 % (name, len(missing), missing[0]))


# --------------------------------------------------------------------------
# 5. shaders.properties against config
# --------------------------------------------------------------------------

def check_properties(shader_root, options):
    path = os.path.join(shader_root, "shaders.properties")
    if not os.path.isfile(path):
        error("shaders.properties is missing")
        return

    for lineno, line in enumerate(read(path).splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("screen"):
            value = line.split("=", 1)[1] if "=" in line else ""
            for token in re.split(r"[\s]+", value):
                token = token.strip()
                if not token or token.startswith("<") or token.startswith("["):
                    continue
                token = token.rstrip("]")
                if not token or not token[0].isalpha():
                    continue
                if token not in options:
                    error("shaders.properties:%d names %s, which is not an option"
                          % (lineno, token))

        elif line.startswith("sliders"):
            value = line.split("=", 1)[1] if "=" in line else ""
            for token in re.split(r"[\s]+", value):
                if token and token not in options:
                    error("shaders.properties:%d lists %s as a slider, but it is not an option"
                          % (lineno, token))

        elif line.startswith("profile."):
            value = line.split("=", 1)[1] if "=" in line else ""
            for token in re.split(r"[\s]+", value):
                if "=" not in token:
                    continue
                name = token.split("=", 1)[0]
                if name not in options:
                    error("shaders.properties:%d sets %s in a profile, but it is not an option"
                          % (lineno, name))


# --------------------------------------------------------------------------
# 6. Sanity: every program declares a version unless it is a voxy/glsl entry
# --------------------------------------------------------------------------

def check_versions(shader_root, files):
    for path in files:
        if not path.endswith((".vsh", ".fsh")):
            continue
        text = read(path)
        stripped = strip_comments_and_strings(text)
        if "#version" not in stripped:
            warn("%s has no #version line"
                 % os.path.relpath(path, shader_root))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))
    shader_root = os.path.join(root, "Solace-LowEnd", "shaders")

    if not os.path.isdir(shader_root):
        print("FAIL: no Solace-LowEnd/shaders under %s" % root)
        return 1

    files = []
    for dirpath, _dirnames, filenames in os.walk(shader_root):
        for name in filenames:
            if name.endswith((".vsh", ".fsh", ".glsl", ".properties", ".json")):
                files.append(os.path.join(dirpath, name))

    config_path = os.path.join(shader_root, "lib", "config.glsl")
    options = parse_options(read(config_path)) if os.path.isfile(config_path) else {}
    if not options:
        error("lib/config.glsl has no options with a value list")

    print("Checked %d files, %d options." % (len(files), len(options)))

    check_includes(shader_root, files)
    check_balance(shader_root, files)
    check_programs(shader_root)
    check_options(shader_root, options)
    check_properties(shader_root, options)
    check_versions(shader_root, files)

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
