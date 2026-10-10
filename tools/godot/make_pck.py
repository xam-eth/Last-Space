#!/usr/bin/env python3
"""make_pck.py — Pack a Godot project directory into a .pck file.

Replicates the byte layout written by Godot's own packer
(core/io/pck_packer.cpp, PACK_FORMAT_VERSION_V4) so the resulting pack can be
loaded by the Godot 4.7 web/WASM runtime without needing the editor binary
(which is unavailable in this sandbox).

Layout (all integers little-endian), mirroring pck_packer.cpp:

  header:
    u32 magic        = 0x43504447 ("GDPC")
    u32 version      = 4 (PACK_FORMAT_VERSION_V4)
    u32 ver_major    = 4
    u32 ver_minor    = 7
    u32 ver_patch    = 2
    u32 pack_flags   = PACK_REL_FILEBASE (2)
    u64 file_base    = absolute offset where file data begins
    u64 dir_offset   = absolute offset where the directory begins
    16 x u32 reserved = 0
    zero padding up to ALIGNMENT
  file data: concatenated file contents
  directory:
    u32 file_count
    per file:
      u32 stored_len = len(path_utf8) + pad4   (pad4 = pad to 4-byte boundary)
      bytes path_utf8, zero-padded by pad4
      u64 offset (relative to file_base)
      u64 size
      16 bytes md5 of the file content
      u32 flags = 0

Usage:
    python3 make_pck.py <project_dir> <output.pck>

Every file under <project_dir> is packed under res://<relative_path>.
"""
import hashlib
import os
import struct
import sys

MAGIC = 0x43504447  # "GDPC"
PACK_FORMAT_VERSION_V4 = 4
GODOT_VERSION = (4, 7, 2)
PACK_REL_FILEBASE = 1 << 1
ALIGNMENT = 32


def pad_to(value, alignment):
    rest = value % alignment
    return alignment - rest if rest > 0 else 0


def collect_files(src_dir):
    files = []
    for root, dirs, names in os.walk(src_dir):
        dirs.sort()
        for name in sorted(names):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src_dir).replace(os.sep, "/")
            files.append(("res://" + rel, full))
    files.sort(key=lambda item: item[0])
    return files


def pack(src_dir, out_pck):
    files = collect_files(src_dir)
    if not files:
        raise SystemExit(f"no files found under {src_dir}")

    header_size = 4 * 6 + 8 + 8 + 16 * 4  # fixed part of the header
    file_base = header_size + pad_to(header_size, ALIGNMENT)

    data = bytearray()
    entries = []
    offset = file_base
    for path, full in files:
        with open(full, "rb") as handle:
            content = handle.read()
        entries.append((path, offset, len(content), hashlib.md5(content).digest()))
        data += content
        offset += len(content)

    dir_offset = offset
    directory = bytearray()
    directory += struct.pack("<I", len(entries))
    for path, entry_offset, size, md5 in entries:
        path_bytes = path.encode("utf-8")
        pad = pad_to(len(path_bytes), 4)
        directory += struct.pack("<I", len(path_bytes) + pad)
        directory += path_bytes + b"\x00" * pad
        directory += struct.pack("<Q", entry_offset - file_base)
        directory += struct.pack("<Q", size)
        directory += md5
        directory += struct.pack("<I", 0)  # flags

    with open(out_pck, "wb") as out:
        out.write(struct.pack("<IIIIII", MAGIC, PACK_FORMAT_VERSION_V4,
                              *GODOT_VERSION, PACK_REL_FILEBASE))
        out.write(struct.pack("<Q", file_base))
        out.write(struct.pack("<Q", dir_offset))
        out.write(b"\x00" * 64)  # 16 reserved u32
        out.write(b"\x00" * pad_to(header_size, ALIGNMENT))
        out.write(data)
        out.write(directory)

    print(f"packed {len(entries)} file(s) -> {out_pck} ({os.path.getsize(out_pck)} bytes)")
    for path, _, size, _ in entries:
        print(f"  {path}  ({size} bytes)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: python3 make_pck.py <project_dir> <output.pck>")
    pack(sys.argv[1], sys.argv[2])
