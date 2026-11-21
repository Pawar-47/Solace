#!/usr/bin/env python3
"""Compile every program with a real GLSL front end.

The repository's other checks are structural: includes resolve, pairs match, options
have names. None of them can tell whether the source is legal GLSL, which is why this
pack shipped twice with errors that stopped the shader pack from loading at all:

    composite.fsh: error: 'R11F_G11F_B10F' undeclared
    textured: error: no matching function for call to 'sat (vec2)'

`glslangValidator` is a real front end for the same language, and it runs headless.
This script expands the includes (Iris resolves them itself, the validator needs them
inlined), writes each stage to a temporary file and compiles it.

It is not a substitute for Iris: it does not know the mod's own uniforms, it does not
run the pipeline, and a program can be legal GLSL and still draw nothing. It does catch
every class of error that has been reported so far.

Needs glslangValidator on PATH:  apt install glslang-tools
Usage:  python3 tools/compile_check.py [repo-root]
"""

import os
import re
import subprocess
import sys
import tempfile

INCLUDE = re.compile(r'#include\s+"([^"]*)"')
FOLDERS = ["", "world0", "world-1", "world1"]


def expand(path, shader_root, stack=None):
    """Inline #include, the way the mod does before compiling."""
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

    failures = []
    compiled = 0

    with tempfile.TemporaryDirectory() as work:
        for folder in FOLDERS:
            directory = os.path.join(shader_root, folder)
            if not os.path.isdir(directory):
                continue
            for name in sorted(os.listdir(directory)):
                if not name.endswith((".vsh", ".fsh")):
                    continue
                stage = "vert" if name.endswith(".vsh") else "frag"
                source = os.path.join(directory, name)
                label = "%s/%s" % (folder or ".", name)

                expanded = expand(source, shader_root)
                if not expanded.strip():
                    failures.append((label, "expanded to nothing"))
                    continue

                target = os.path.join(work, "%s_%s.%s"
                                      % (folder or "root", name.rsplit(".", 1)[0], stage))
                with open(target, "w", encoding="utf-8") as handle:
                    handle.write(expanded)

                result = subprocess.run(
                    ["glslangValidator", "-S", stage, target],
                    capture_output=True, text=True)
                compiled += 1
                if result.returncode != 0:
                    output = (result.stdout + result.stderr).strip()
                    # Point at the pack's own file, not the temporary one.
                    output = output.replace(target, label)
                    failures.append((label, output))

    print("Compiled %d stage(s) with glslangValidator." % compiled)

    if failures:
        print("")
        for label, message in failures:
            print("=== %s" % label)
            print(message)
            print("")
        print("FAIL: %d stage(s) did not compile" % len(failures))
        return 1

    print("OK: every stage compiles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
