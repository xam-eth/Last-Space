#!/usr/bin/env python3
"""make_aln_001.py — pilot asset ALN-001 "Alien Scout" (Blender headless).

Pilot asset KEDUA (setelah SHP-001): sisi alien/attacker (MASTER_ASSET_INVENTORY.md
Kelompok A — P0). Sebelum bulk generation aset alien (AI_GOVERNANCE.md §11).

Kontrak (ASSET_PIPELINE.md §2 — sama dengan pilot SHP-001):
- 1 unit Blender = 1 meter; origin = pusat badan kapal.
- Depan kapal (nose) menghadap +Y di Blender (back view). Konversi ke Godot:
  (x, y, z) Blender → (x, z, -y) glTF, sehingga nose berakhir di -Z Godot.
  VERIFIKASI akhir oleh test Godot (test_ship_model_aln.gd: weapon_z < engine_z).
- Naming node: ALN001_Body, ALN001_Engine_C, ALN001_Core, ALN001_Weapon_T.
- Material: MAT-002 Alien Hull (gelap, tekstur chitin 1024px), MAT-021 Alien
  Engine Emission (hijau), MAT-022 Alien Core Emission (hijau terang — focal
  point inti energi), MAT-023 Alien Weapon Emission (ungu menyala).
- Skala: kapal kecil 2–6 m (target: hull ~3.5 m — scout lebih kecil/cepat dari
  interceptor 4.2 m).

Art direction (ART_DIRECTION.md §2 Alien): siluet BIOMEKANIS — bentuk asimetris
(head pod kanan lebih besar dari kiri, sirip depan tidak simetris), material
gelap, inti energi bercahaya sebagai focal point. Aksen energi alien = HIJAU
(engine + core), senjata = UNGU menyala — diputuskan saat pilot ini, harus
konsisten untuk semua aset alien berikutnya (beda dari manusia: cyan/red-orange).

Output:
- assets/ships/aln_001_scout.glb   (artefak kontrak pipeline, source)
- assets/ships/aln_001_scout.blend (source .blend)
- assets/ships/aln_001_chitin_1024.png          (source tekstur)
- game/assets/ships/aln_001_scout.tscn          (runtime scene shell)
- game/assets/ships/aln_001_scout.mesh.json     (runtime mesh data)

Catatan runtime: sama seperti SHP-001 — build wasm tidak punya loader glTF/.png,
scene .tscn + mesh.json dibangun runtime oleh asset_model_scene.gd, tekstur
di-embed base64.

Usage: python3 tools/blender/make_aln_001.py   (butuh `source tools/env.sh` di sandbox)
"""
import base64
import json
import math
import os

import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(REPO, "assets", "ships")
GAME_ASSETS = os.path.join(REPO, "game", "assets", "ships")
GLB_PATH = os.path.join(SRC_DIR, "aln_001_scout.glb")
BLEND_PATH = os.path.join(SRC_DIR, "aln_001_scout.blend")
TEX_SRC_PATH = os.path.join(SRC_DIR, "aln_001_chitin_1024.png")
TSCN_PATH = os.path.join(GAME_ASSETS, "aln_001_scout.tscn")
MESH_JSON_PATH = os.path.join(GAME_ASSETS, "aln_001_scout.mesh.json")
TSCN_DATA_PATH = "res://assets/ships/aln_001_scout.mesh.json"

RAD = math.radians

# urutan node (kontrak naming)
NODE_ORDER = ["ALN001_Body", "ALN001_Engine_C", "ALN001_Core", "ALN001_Weapon_T"]


# ---------------------------------------------------------------- tekstur ----
def make_texture(path: str) -> None:
    """Tekstur chitin 1024x1024 (power-of-two) — kulit gelap + sisik hijau gelap."""
    from PIL import Image, ImageDraw

    size = 1024
    img = Image.new("RGB", (size, size), (20, 24, 28))
    d = ImageDraw.Draw(img)
    # gradient vertikal halus (chitin gelap)
    for y in range(size):
        f = y / size
        c = int(20 + 10 * f)
        d.line([(0, y), (size, y)], fill=(c, c + 4, c + 8))
    # sisik/panel: grid 128 px dengan warna hijau gelap (biomekanis)
    for g in range(0, size + 1, 128):
        d.line([(g, 0), (g, size)], fill=(36, 64, 44), width=2)
        d.line([(0, g), (size, g)], fill=(36, 64, 44), width=2)
    # aksen faction: stripe hijau di bagian bawah tekstur
    d.rectangle([0, size - 96, size, size], fill=(0, 110, 55))
    d.rectangle([0, size - 96, size, size - 88], fill=(60, 200, 120))
    # rivets di titik grid
    for gx in range(64, size, 128):
        for gy in range(64, size, 128):
            d.ellipse([gx - 3, gy - 3, gx + 3, gy + 3], fill=(12, 14, 17))
    # gores lengkung (tekstur organik)
    for x in range(-size, size, 256):
        d.arc([x, 200, x + 256, 700], start=200, end=340, fill=(28, 50, 36), width=2)
    img.save(path)
    print("ASSET: texture written %s (%d bytes)" % (path, os.path.getsize(path)))


# ---------------------------------------------------------------- material ---
def make_materials(tex_path: str):
    mat_hull = bpy.data.materials.new("MAT002_Alien_Hull")
    mat_hull.use_nodes = True
    bsdf = mat_hull.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 0.25
    bsdf.inputs["Roughness"].default_value = 0.6
    img = bpy.data.images.load(tex_path)
    tex = mat_hull.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat_hull.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    mat_eng = bpy.data.materials.new("MAT021_Alien_Engine_Emission")
    mat_eng.use_nodes = True
    bsdf_e = mat_eng.node_tree.nodes["Principled BSDF"]
    bsdf_e.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf_e.inputs["Metallic"].default_value = 0.0
    bsdf_e.inputs["Roughness"].default_value = 0.4
    bsdf_e.inputs["Emission Color"].default_value = (0.15, 0.9, 0.35, 1.0)
    bsdf_e.inputs["Emission Strength"].default_value = 4.0

    mat_core = bpy.data.materials.new("MAT022_Alien_Core_Emission")
    mat_core.use_nodes = True
    bsdf_c = mat_core.node_tree.nodes["Principled BSDF"]
    bsdf_c.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf_c.inputs["Metallic"].default_value = 0.0
    bsdf_c.inputs["Roughness"].default_value = 0.3
    bsdf_c.inputs["Emission Color"].default_value = (0.4, 1.0, 0.55, 1.0)
    bsdf_c.inputs["Emission Strength"].default_value = 6.0

    mat_wpn = bpy.data.materials.new("MAT023_Alien_Weapon_Emission")
    mat_wpn.use_nodes = True
    bsdf_w = mat_wpn.node_tree.nodes["Principled BSDF"]
    bsdf_w.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf_w.inputs["Metallic"].default_value = 0.0
    bsdf_w.inputs["Roughness"].default_value = 0.4
    bsdf_w.inputs["Emission Color"].default_value = (0.85, 0.25, 1.0, 1.0)
    bsdf_w.inputs["Emission Strength"].default_value = 4.0
    return mat_hull, mat_eng, mat_core, mat_wpn


# ------------------------------------------------------------------ helper ---
def _add(name, op, mat, **kw):
    op(**kw)
    obj = bpy.context.active_object
    obj.name = name
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def _clean_mesh(obj) -> None:
    """Geometri bersih: hilangkan vertex ganda + triangulasi (no n-gon)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")


def build_hull(mat):
    """Biomekanis ASIMETRIS: hull + head pod kanan (besar) + pod kiri (kecil) +
    dorsal ridges (mekanis) + sirip depan tidak simetris + tail stinger + keel
    → join jadi ALN001_Body.

    Nose menghadap +Y (back view Blender) → setelah konversi → -Z Godot.
    Panjang total ~3.5 m (scout lebih kecil dari interceptor 4.2 m).
    """
    parts = []
    # main hull (y -0.9 .. 0.9)
    parts.append(_add("a_hull", bpy.ops.mesh.primitive_cylinder_add,
                      mat, vertices=10, radius=0.26, depth=1.8,
                      location=(0, 0, 0), rotation=(RAD(90), 0, 0)))
    # head pod KANAN (mata besar, asimetris) — depan +Y, atas
    parts.append(_add("a_head_r", bpy.ops.mesh.primitive_ico_sphere_add,
                      mat, radius=0.20, subdivisions=1,
                      location=(0.16, 0.92, 0.04)))
    # head pod KIRI (kecil — asimetri)
    parts.append(_add("a_head_l", bpy.ops.mesh.primitive_ico_sphere_add,
                      mat, radius=0.12, subdivisions=1,
                      location=(-0.22, 0.55, -0.02)))
    # dorsal ridges (mekanis, punggung z+)
    for i, y in enumerate([-0.35, 0.05, 0.45]):
        parts.append(_add("a_ridge_%d" % i, bpy.ops.mesh.primitive_cube_add,
                          mat, size=1.0, location=(0, y, 0.26)))
        parts[-1].scale = (0.10, 0.16, 0.09)
    # sirip depan KANAN (besar, menyapu ke depan-atas)
    parts.append(_add("a_fin_r", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(0.52, 0.42, -0.04),
                      rotation=(0, 0, RAD(-35))))
    parts[-1].scale = (0.55, 0.32, 0.05)
    # sirip depan KIRI (kecil — asimetri)
    parts.append(_add("a_fin_l", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(-0.42, 0.28, -0.04),
                      rotation=(0, 0, RAD(28))))
    parts[-1].scale = (0.38, 0.26, 0.05)
    # tail stinger (cone runcing ke belakang -Y)
    parts.append(_add("a_tail", bpy.ops.mesh.primitive_cone_add,
                      mat, vertices=10, radius1=0.26, radius2=0.03, depth=0.85,
                      location=(0, -1.32, 0), rotation=(RAD(90), 0, 0)))
    # keel bawah (sirip perut)
    parts.append(_add("a_keel", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(0, -0.52, 0)))
    parts[-1].scale = (0.16, 0.45, 0.05)

    # terapkan transformasi, lalu join semua bagian hull
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "ALN001_Body"
    _clean_mesh(body)
    bpy.ops.object.shade_smooth()

    # UV untuk tekstur chitin (smart project — low-poly hull sederhana)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=RAD(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    return body


# ------------------------------------------------- runtime (tscn + json) ----
def _to_godot(x: float, y: float, z: float):
    """Konversi sumbu Blender → Godot (sama dengan konversi +Y-up glTF):
    (x, y, z) → (x, z, -y). Nose Blender +Y → Godot -Z."""
    return (x, z, -y)


def _extract_node(obj) -> dict:
    """Ekstrak mesh satu objek (sudah transform_apply → local == world) ke data
    Godot: weld per-corner (pos, normal, uv) agar indeks valid untuk Godot."""
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    has_uv = uv_layer is not None
    corners = mesh.corner_normals  # normal per-corner (flat/smooth sesuai shading)

    weld = {}
    vertices, normals, uvs, indices = [], [], [], []
    for lt in mesh.loop_triangles:
        for k in range(3):
            v_idx = lt.vertices[k]
            co = mesh.vertices[v_idx].co
            nrm = corners[lt.loops[k]].vector
            if has_uv:
                uv = uv_layer.data[lt.loops[k]].uv
                # Blender UV origin bottom-left → Godot/glTF top-left: flip v
                uv_g = (uv.x, 1.0 - uv.y)
            else:
                uv_g = (0.0, 0.0)
            key = (round(co.x, 6), round(co.y, 6), round(co.z, 6),
                   round(nrm.x, 6), round(nrm.y, 6), round(nrm.z, 6),
                   round(uv_g[0], 6), round(uv_g[1], 6))
            idx = weld.get(key)
            if idx is None:
                idx = len(vertices)
                weld[key] = idx
                gx, gy, gz = _to_godot(co.x, co.y, co.z)
                nx, ny, nz = _to_godot(nrm.x, nrm.y, nrm.z)
                vertices.append([round(gx, 6), round(gy, 6), round(gz, 6)])
                normals.append([round(nx, 6), round(ny, 6), round(nz, 6)])
                uvs.append([round(uv_g[0], 6), round(uv_g[1], 6)])
            indices.append(idx)

    # material pertama pada objek
    mat_name = ""
    mat_params = None
    if len(obj.data.materials) > 0 and obj.data.materials[0] is not None:
        mat = obj.data.materials[0]
        mat_name = mat.name
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        textured = False
        for link in mat.node_tree.links:
            if link.to_node == bsdf and link.to_socket.name == "Base Color":
                if link.from_node.bl_idname == "ShaderNodeTexImage":
                    textured = True
        base = bsdf.inputs["Base Color"].default_value
        emis = bsdf.inputs["Emission Color"].default_value
        mat_params = {
            "albedo": [round(base[0], 4), round(base[1], 4), round(base[2], 4), 1.0],
            "metallic": round(bsdf.inputs["Metallic"].default_value, 4),
            "roughness": round(bsdf.inputs["Roughness"].default_value, 4),
            "textured": textured,
            "emission": [round(emis[0], 4), round(emis[1], 4), round(emis[2], 4)],
            "emission_strength": round(bsdf.inputs["Emission Strength"].default_value, 4),
        }
    return {
        "name": obj.name,
        "vertices": vertices,
        "normals": normals,
        "uvs": uvs,
        "indices": indices,
        "material": mat_name,
        "material_params": mat_params,
        "tris": len(indices) // 3,
    }


def write_runtime_assets() -> None:
    """Tulis scene .tscn shell + mesh.json (space Godot, tekstur embedded base64)."""
    os.makedirs(GAME_ASSETS, exist_ok=True)

    nodes = []
    materials = {}
    for name in NODE_ORDER:
        obj = bpy.data.objects.get(name)
        if obj is None:
            raise RuntimeError("objek tidak ditemukan: %s" % name)
        nd = _extract_node(obj)
        nodes.append(nd)
        if nd["material"] and nd["material_params"]:
            materials[nd["material"]] = nd["material_params"]

    with open(TEX_SRC_PATH, "rb") as f:
        tex_b64 = base64.b64encode(f.read()).decode("ascii")

    doc = {
        "asset_id": "ALN-001",
        "name": "Alien Scout",
        "source_glb": "assets/ships/aln_001_scout.glb (source, di luar PCK)",
        "texture_source": "assets/ships/aln_001_chitin_1024.png",
        "texture_png_base64": tex_b64,
        "space": "godot (depan -Z, 1 unit = 1 m)",
        "nodes": nodes,
        "materials": materials,
    }
    with open(MESH_JSON_PATH, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    print("ASSET: mesh.json written %s (%d bytes)" % (MESH_JSON_PATH, os.path.getsize(MESH_JSON_PATH)))

    tscn = (
        '[gd_scene load_steps=2 format=3]\n'
        '\n'
        '[ext_resource type="Script" path="res://scripts/assets/asset_model_scene.gd" id="1_model"]\n'
        '\n'
        '[node name="ALN001AlienScout" type="Node3D"]\n'
        'script = ExtResource("1_model")\n'
        'data_path = "%s"\n' % TSCN_DATA_PATH
    )
    with open(TSCN_PATH, "w") as f:
        f.write(tscn)
    print("ASSET: tscn written %s (%d bytes)" % (TSCN_PATH, os.path.getsize(TSCN_PATH)))
    print("ASSET: texture embedded base64 (%d chars)" % len(tex_b64))

    total_tris = sum(n["tris"] for n in nodes)
    total_verts = sum(len(n["vertices"]) for n in nodes)
    print("ASSET: runtime total tris=%d verts=%d nodes=%d" % (total_tris, total_verts, len(nodes)))
    # cek awal orientasi (space Godot): nose (weapon) harus di -Z, engine di +Z
    wpn = next(n for n in nodes if n["name"] == "ALN001_Weapon_T")
    eng = next(n for n in nodes if n["name"] == "ALN001_Engine_C")
    z_wpn = sum(v[2] for v in wpn["vertices"]) / len(wpn["vertices"])
    z_eng = sum(v[2] for v in eng["vertices"]) / len(eng["vertices"])
    print("ASSET: orientasi precheck Godot space: weapon_z=%.2f engine_z=%.2f -> %s" % (
        z_wpn, z_eng, "NOSE -Z OK" if z_wpn < z_eng else "SALAH ARAH"))


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(SRC_DIR, exist_ok=True)
    os.makedirs(GAME_ASSETS, exist_ok=True)

    make_texture(TEX_SRC_PATH)
    mat_hull, mat_eng, mat_core, mat_wpn = make_materials(TEX_SRC_PATH)

    body = build_hull(mat_hull)

    # mesin (belakang = -Y, emission hijau) — penanda attachment point
    _add("ALN001_Engine_C", bpy.ops.mesh.primitive_cylinder_add,
         mat_eng, vertices=8, radius=0.15, depth=0.7,
         location=(0, -1.55, 0), rotation=(RAD(90), 0, 0))
    # inti energi (punggung tengah, emission hijau terang — focal point)
    _add("ALN001_Core", bpy.ops.mesh.primitive_ico_sphere_add,
         mat_core, radius=0.12, subdivisions=2, location=(0, 0.12, 0.30))
    # titik senjata (nose = +Y, emission ungu) — penanda attachment point
    _add("ALN001_Weapon_T", bpy.ops.mesh.primitive_ico_sphere_add,
         mat_wpn, radius=0.07, subdivisions=2, location=(0, 1.72, 0))

    # terapkan transformasi semua objek (origin tetap di pusat badan = world origin)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    # geometri bersih untuk objek di luar body (engine, core, weapon)
    for name in ["ALN001_Engine_C", "ALN001_Core", "ALN001_Weapon_T"]:
        _clean_mesh(bpy.data.objects[name])

    # statistik (data nyata untuk laporan)
    mesh = body.data
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    print("ASSET: ALN001_Body tris=%d verts=%d" % (len(mesh.polygons), len(mesh.vertices)))
    print("ASSET: hull bounds blender x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f]"
          % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    print("ASSET: hull length (y, nose=+Y) = %.2f m" % (max(ys) - min(ys)))

    # jangan simpan backup .blend1 (anti-pattern ASSET_ACCEPTANCE_CRITERIA.md §6)
    try:
        bpy.context.preferences.filepaths.save_versions = 0
    except Exception:
        pass
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    if os.path.exists(BLEND_PATH + "1"):
        os.remove(BLEND_PATH + "1")
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print("ASSET: GLB written %s (%d bytes)" % (GLB_PATH, os.path.getsize(GLB_PATH)))
    print("ASSET: blend source %s (%d bytes)" % (BLEND_PATH, os.path.getsize(BLEND_PATH)))

    write_runtime_assets()


if __name__ == "__main__":
    main()
