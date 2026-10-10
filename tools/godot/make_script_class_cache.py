#!/usr/bin/env python3
"""make_script_class_cache.py — Generate .godot/global_script_class_cache.cfg

Godot resolves `class_name` (global script classes) at parse time via the
global script class cache, which the EDITOR normally generates. We have no
editor in this sandbox, so we generate the same file ourselves by scanning
scripts for `class_name` / `extends` declarations.

Format (ConfigFile, read by ProjectSettings::get_global_class_list):
    list=[{"base": "...", "class": "...", "icon": "", "is_abstract": false,
           "is_tool": false, "language": "GDScript", "path": "res://..."}, ...]

Usage:
    python3 make_script_class_cache.py <project_dir>
Writes <project_dir>/.godot/global_script_class_cache.cfg
"""
import os
import re
import sys

CLASS_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_][A-Za-z0-9_.]*)", re.M)


def scan_scripts(src_dir):
    classes = []
    for root, dirs, names in os.walk(src_dir):
        dirs.sort()
        for name in sorted(names):
            if not name.endswith(".gd"):
                continue
            full = os.path.join(root, name)
            with open(full, encoding="utf-8") as f:
                text = f.read()
            m = CLASS_RE.search(text)
            if not m:
                continue
            e = EXTENDS_RE.search(text)
            base = e.group(1) if e else "RefCounted"
            rel = os.path.relpath(full, src_dir).replace(os.sep, "/")
            classes.append({
                "class": m.group(1),
                "language": "GDScript",
                "path": "res://" + rel,
                "base": base,
                "icon": "",
                "is_abstract": False,
                "is_tool": False,
            })
    classes.sort(key=lambda c: c["class"])
    return classes


def serialize(classes):
    def q(s):
        return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')

    def d(dct):
        return "{" + ", ".join("%s: %s" % (q(k), v) for k, v in dct.items()) + "}"

    def val(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, str):
            return q(v)
        return str(v)

    items = []
    for c in classes:
        # key order matches ScriptServer::save_global_classes
        ordered = {
            "class": q(c["class"]),
            "language": q(c["language"]),
            "path": q(c["path"]),
            "base": q(c["base"]),
            "icon": q(c["icon"]),
            "is_abstract": val(c["is_abstract"]),
            "is_tool": val(c["is_tool"]),
        }
        items.append(d(ordered))
    return "list=[%s]\n" % ", ".join(items)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: python3 make_script_class_cache.py <project_dir>")
    project_dir = sys.argv[1]
    classes = scan_scripts(project_dir)
    if not classes:
        raise SystemExit("no class_name scripts found under %s" % project_dir)
    out_dir = os.path.join(project_dir, ".godot")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "global_script_class_cache.cfg")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(serialize(classes))
    print("wrote %s (%d global classes)" % (out_path, len(classes)))
    for c in classes:
        print("  %s (extends %s) <- %s" % (c["class"], c["base"], c["path"]))


if __name__ == "__main__":
    main()
