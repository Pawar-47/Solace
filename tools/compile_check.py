#!/usr/bin/env python3
"""Compile every program with a real GLSL front end, under every profile.

The repository's other checks are structural: includes resolve, pairs match, options
have names. None of them can tell whether the source is legal GLSL, which is why this
pack shipped with errors that stopped it loading at all:

    composite.fsh: error: 'R11F G11F B10F' undeclared
    textured: error: no matching function for call to 'sat (vec2)'
    composite.fsh: error: '%' : not supported for this version

`glslangValidator` is a real front end for the same language, and it runs headless.

Two things it has to reproduce before it means anything:

  * includes, because the mod resolves them and the validator does not;
  * the option set, because much of this pack only exists inside `#if`. The defaults
    are compiled first, then every profile in shaders.properties, with that profile's
    values patched into lib/config.glsl. PerformancePlus turns on shadows, volumetric
    clouds, every post effect and auto exposure at once, so it compiles code the
    default set never sees.

It is not a substitute for Iris: it does not run the pipeline, and a program can be
legal GLSL and still draw nothing. It does catch every error that has been reported.

Needs glslangValidator on PATH:  apt install glslang-tools
Usage:  python3 tools/compile_check.py [repo-root]
"""

import os
import re
import subprocess
import sys
import tempfile

INCLUDE = re.compile(r'#include\s+"([^"]*)"')
DEFINE = re.compile(r'^(\s*#define\s+(\w+)\s+)(\S+)(.*)$', re.MULTILINE)
PROFILE = re.compile(r'^profile\.(\w+)\s*=\s*(.+)$', re.MULTILINE)
FOLDERS = ["", "world0", "world-1", "world1"]


def apply_overrides(text, overrides):
    """Patch the profile's values into lib/config.glsl, leaving the rest of the line."""
    def swap(match):
        prefix, name, value, rest = match.groups()
        if name in overrides:
            return prefix + overrides[name] + rest
        return match.group(0)
    return DEFINE.sub(swap, text)


def expand(path, shader_root, overrides, stack=None):
    """Inline #include, the way the mod does before compiling."""
    if stack is None:
        stack = []
    if path in stack or not os.path.isfile(path):
        return ""
    stack = stack + [path]

    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()

    if overrides and os.path.basename(path) == "config.glsl":
        text = apply_overrides(text, overrides)

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
            out.append(expand(resolved, shader_root, overrides, stack))
        else:
            out.append(line)
    return "".join(out)


def read_profiles(shader_root):
    """The option sets worth compiling: the defaults, the diagnostic build, each profile."""
    profiles = [("default", {}), ("diagnostic", {"SOLACE_DIAG": "1"})]
    path = os.path.join(shader_root, "shaders.properties")
    if not os.path.isfile(path):
        return profiles

    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()

    for name, values in PROFILE.findall(text):
        overrides = {}
        for token in values.split():
            if "=" not in token:
                continue
            option, value = token.split("=", 1)
            if option and value:
                overrides[option] = value
        if overrides:
            profiles.append((name, overrides))
    return profiles


def compile_stage(glslang, shader_root, folder, name, stage, overrides, work):
    source = os.path.join(shader_root, folder, name)
    label = "%s/%s" % (folder or ".", name)

    expanded = expand(source, shader_root, overrides)
    if not expanded.strip():
        return label, "expanded to nothing"

    target = os.path.join(work, "%s_%s.%s"
                          % (folder or "root", name.rsplit(".", 1)[0], stage))
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(expanded)

    result = subprocess.run([glslang, "-S", stage, target],
                            capture_output=True, text=True)
    if result.returncode == 0:
        return label, None
    return label, (result.stdout + result.stderr).strip().replace(target, label)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))
    shader_root = os.path.join(root, "Solace-LowEnd", "shaders")

    if not os.path.isdir(shader_root):
        print("FAIL: no Solace-LowEnd/shaders under %s" % root)
        return 1

    try:
        subprocess.run(["glslangValidator", "--version"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=True)
    except (OSError, subprocess.CalledProcessError):
        print("SKIP: glslangValidator is not installed (apt install glslang-tools)")
        return 0

    programs = []
    for folder in FOLDERS:
        directory = os.path.join(shader_root, folder)
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.endswith(".vsh"):
                programs.append((folder, name, "vert"))
            elif name.endswith(".fsh"):
                programs.append((folder, name, "frag"))

    failures = []
    total = 0

    with tempfile.TemporaryDirectory() as work:
        for profile, overrides in read_profiles(shader_root):
            failed = []
            for folder, name, stage in programs:
                label, message = compile_stage(
                    "glslangValidator", shader_root, folder, name, stage, overrides, work)
                total += 1
                if message:
                    failed.append((label, message))

            print("%-16s %d stage(s), %d failed"
                  % (profile, len(programs), len(failed)))
            for label, message in failed:
                failures.append((profile, label, message))

    print("")
    if failures:
        for profile, label, message in failures:
            print("=== [%s] %s" % (profile, label))
            print(message)
            print("")
        print("FAIL: %d stage(s) did not compile out of %d" % (len(failures), total))
        return 1

    print("OK: all %d stages compile under every profile" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
