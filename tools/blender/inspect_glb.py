#!/usr/bin/env python3
"""inspect_glb.py — verifikasi struktur GLB di level file (data nyata, bukan asumsi).

Print: node names, mesh/primitive count, material names + emissive, accessor
bounds, dan posisi marker (weapon vs engine) untuk cek awal orientasi.
"""
import json
import struct
import sys


def main(path: str) -> None:
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a GLB"
    off = 12
    gltf = None
    bin_chunk = b""
    while off < length:
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON":
            gltf = json.loads(chunk)
        elif ctype == b"BIN\x00":
            bin_chunk = chunk
        off += 8 + clen + (clen & 1)

    print("GLB: version=%d size=%d bytes" % (version, len(data)))
    print("nodes:")
    for n in gltf.get("nodes", []):
        t = n.get("translation", [0, 0, 0])
        print("  - %-18s mesh=%s translation=%s" % (
            n.get("name", "?"), n.get("mesh", "-"),
            ["%.2f" % v for v in t]))
    print("meshes: %d" % len(gltf.get("meshes", [])))
    total_prims = 0
    for m in gltf.get("meshes", []):
        prims = m.get("primitives", [])
        total_prims += len(prims)
        for p in prims:
            pos_acc = gltf["accessors"][p["attributes"]["POSITION"]]
            mn, mx = pos_acc.get("min"), pos_acc.get("max")
            print("  mesh '%s': prims=%d tris~%s pos_min=%s pos_max=%s" % (
                m.get("name", "?"), len(prims),
                pos_acc.get("count", "?") // 3 if p.get("indices") is None else "idx",
                ["%.2f" % v for v in mn] if mn else "-",
                ["%.2f" % v for v in mx] if mx else "-"))
    print("total primitives: %d" % total_prims)
    print("materials:")
    for m in gltf.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        emis = m.get("emissiveFactor", [0, 0, 0])
        print("  - %-28s metallic=%.2f rough=%.2f emissive=%s" % (
            m.get("name", "?"),
            pbr.get("metallicFactor", 1.0), pbr.get("roughnessFactor", 1.0),
            ["%.2f" % v for v in emis]))
    print("images: %d, buffers: %d (bin=%d bytes)" % (
        len(gltf.get("images", [])), len(gltf.get("buffers", [])), len(bin_chunk)))

    # cek awal orientasi: posisi marker relatif (glTF space: +Y up)
    def node_t(name):
        for n in gltf.get("nodes", []):
            if n.get("name") == name:
                return n.get("translation", [0, 0, 0])
        return None
    wpn = node_t("SHP001_Weapon_T")
    eng = node_t("SHP001_Engine_L")
    if wpn and eng:
        print("ORIENTASI-PRECHECK glTF space: weapon=%s engine=%s" % (
            ["%.2f" % v for v in wpn], ["%.2f" % v for v in eng]))
        if wpn[2] > eng[2]:
            print("  → nose (weapon) di +Z glTF (sesuai konvensi glTF front=+Z)")
        elif wpn[2] < eng[2]:
            print("  → nose (weapon) di -Z glTF")
        else:
            print("  → marker tidak terpisah di Z (cek manual)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else
         "/home/user/Last-Space/game/assets/ships/shp_001_basic_interceptor.glb")
