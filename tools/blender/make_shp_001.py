#!/usr/bin/env python3
"""make_shp_001.py — pilot asset SHP-001 "Basic Interceptor" (Blender headless).

Pilot asset (AI_GOVERNANCE.md §11 / ASSET_PIPELINE.md): satu aset dulu untuk
memvalidasi pipeline sebelum bulk generation.

Kontrak (ASSET_PIPELINE.md §2):
- 1 unit Blender = 1 meter; origin = pusat badan kapal.
- Depan kapal (nose) menghadap +Y di Blender (back view). Konversi ke Godot:
  (x, y, z) Blender → (x, z, -y) Godot (sama dengan konversi +Y-up glTF),
  sehingga nose berakhir di -Z Godot (kontrak: depan = -Z).
  VERIFIKASI akhir oleh test Godot (test_ship_model.gd: weapon_z < engine_z).
- Naming node: SHP001_Body, SHP001_Engine_L, SHP001_Engine_R, SHP001_Weapon_T.
- Material: MAT-001 Human Hull Metal (tekstur panel 1024px), MAT-007 Blue Engine
  Emission (cyan), MAT-008 Red/Orange Weapon Emission.
- Skala: kapal kecil 2–6 m (target: hull ~4.2 m).

Output:
- assets/ships/shp_001_basic_interceptor.glb   (artefak kontrak pipeline, source)
- assets/ships/shp_001_basic_interceptor.blend (source .blend)
- assets/ships/shp_001_hull_1024.png           (source tekstur)
- game/assets/ships/shp_001_basic_interceptor.tscn       (runtime scene shell)
- game/assets/ships/shp_001_basic_interceptor.mesh.json  (runtime mesh data)

Catatan runtime: build wasm Godot tidak memiliki ResourceFormatLoaderGLTF
(loader .glb tidak terdaftar — diverifikasi via strings game.wasm), sehingga
import editor-less menghasilkan scene .tscn + mesh.json yang dibangun runtime
oleh game/scripts/assets/asset_model_scene.gd. Tekstur di-embed sebagai base64
PNG karena loader .png juga tidak terdaftar saat runtime di build ini (decode
via Image.load_png_from_buffer). Di dev machine dengan editor Godot, .glb dapat
diimport langsung (path standar pipeline).

Usage: python3 tools/blender/make_shp_001.py   (butuh `source tools/env.sh` di sandbox)
"""
import base64
import json
import math
import os

import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(REPO, "assets", "ships")
GAME_ASSETS = os.path.join(REPO, "game", "assets", "ships")
GLB_PATH = os.path.join(SRC_DIR, "shp_001_basic_interceptor.glb")
BLEND_PATH = os.path.join(SRC_DIR, "shp_001_basic_interceptor.blend")
TEX_SRC_PATH = os.path.join(SRC_DIR, "shp_001_hull_1024.png")
TSCN_PATH = os.path.join(GAME_ASSETS, "shp_001_basic_interceptor.tscn")
MESH_JSON_PATH = os.path.join(GAME_ASSETS, "shp_001_basic_interceptor.mesh.json")

TSCN_DATA_PATH = "res://assets/ships/shp_001_basic_interceptor.mesh.json"

RAD = math.radians

# urutan node (kontrak naming)
NODE_ORDER = ["SHP001_Body", "SHP001_Engine_L", "SHP001_Engine_R", "SHP001_Weapon_T"]


# ---------------------------------------------------------------- tekstur ----
def make_texture(path: str) -> None:
    """Tekstur panel 1024x1024 (power-of-two) — pola panel + aksen faction cyan."""
    from PIL import Image, ImageDraw

    size = 1024
    img = Image.new("RGB", (size, size), (62, 66, 74))
    d = ImageDraw.Draw(img)
    # gradient vertikal halus (metal)
    for y in range(size):
        f = y / size
        c = int(62 + 14 * f)
        d.line([(0, y), (size, y)], fill=(c, c + 4, c + 12))
    # panel lines (grid 128 px)
    for g in range(0, size + 1, 128):
        d.line([(g, 0), (g, size)], fill=(96, 102, 112), width=2)
        d.line([(0, g), (size, g)], fill=(96, 102, 112), width=2)
    # aksen faction: stripe cyan di bagian bawah tekstur
    d.rectangle([0, size - 96, size, size], fill=(28, 92, 118))
    d.rectangle([0, size - 96, size, size - 88], fill=(70, 200, 255))
    # rivets di titik grid
    for gx in range(64, size, 128):
        for gy in range(64, size, 128):
            d.ellipse([gx - 3, gy - 3, gx + 3, gy + 3], fill=(40, 43, 49))
    # gores diagonal ringan (panel besar)
    for x in range(-size, size, 256):
        d.line([(x, 0), (x + 256, size)], fill=(72, 77, 86), width=1)
    img.save(path)
    print("ASSET: texture written %s (%d bytes)" % (path, os.path.getsize(path)))


# ---------------------------------------------------------------- material ---
def make_materials(tex_path: str):
    mat_hull = bpy.data.materials.new("MAT001_Human_Hull_Metal")
    mat_hull.use_nodes = True
    bsdf = mat_hull.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 0.55
    bsdf.inputs["Roughness"].default_value = 0.35
    img = bpy.data.images.load(tex_path)
    tex = mat_hull.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat_hull.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    mat_eng = bpy.data.materials.new("MAT007_Blue_Engine_Emission")
    mat_eng.use_nodes = True
    bsdf_e = mat_eng.node_tree.nodes["Principled BSDF"]
    bsdf_e.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf_e.inputs["Metallic"].default_value = 0.0
    bsdf_e.inputs["Roughness"].default_value = 0.4
    bsdf_e.inputs["Emission Color"].default_value = (0.15, 0.75, 1.0, 1.0)
    bsdf_e.inputs["Emission Strength"].default_value = 4.0

    mat_wpn = bpy.data.materials.new("MAT008_Weapon_Emission")
    mat_wpn.use_nodes = True
    bsdf_w = mat_wpn.node_tree.nodes["Principled BSDF"]
    bsdf_w.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf_w.inputs["Metallic"].default_value = 0.0
    bsdf_w.inputs["Roughness"].default_value = 0.4
    bsdf_w.inputs["Emission Color"].default_value = (1.0, 0.32, 0.08, 1.0)
    bsdf_w.inputs["Emission Strength"].default_value = 4.0
    return mat_hull, mat_eng, mat_wpn


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
    """Fuselage + nose + tail + swept wings + V-tails + canopy → join jadi SHP001_Body.

    Nose menghadap +Y (back view Blender) → setelah konversi → -Z Godot.
    Panjang hull total ~4.2 m.
    """
    parts = []
    parts.append(_add("h_fuselage", bpy.ops.mesh.primitive_cylinder_add,
                      mat, vertices=8, radius=0.32, depth=2.2,
                      location=(0, 0, 0), rotation=(RAD(90), 0, 0)))
    # nose: cone tip ke +Y (depan), base menempel fuselage di y=+1.1
    parts.append(_add("h_nose", bpy.ops.mesh.primitive_cone_add,
                      mat, vertices=8, radius1=0.32, radius2=0.02, depth=1.1,
                      location=(0, 1.65, 0), rotation=(RAD(-90), 0, 0)))
    # tail cone: mengecil ke belakang (-Y)
    parts.append(_add("h_tail", bpy.ops.mesh.primitive_cone_add,
                      mat, vertices=8, radius1=0.32, radius2=0.14, depth=0.9,
                      location=(0, -1.55, 0), rotation=(RAD(90), 0, 0)))
    # swept wings (outer tip menyapu ke belakang = -Y)
    parts.append(_add("h_wing_r", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(0.85, -0.10, -0.02),
                      rotation=(0, 0, RAD(-20))))
    parts[-1].scale = (1.55, 1.0, 0.045)
    parts.append(_add("h_wing_l", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(-0.85, -0.10, -0.02),
                      rotation=(0, 0, RAD(20))))
    parts[-1].scale = (1.55, 1.0, 0.045)
    # V-tails (sirip belakang -Y, miring keluar)
    parts.append(_add("h_vtail_r", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(0.26, -1.25, 0.38),
                      rotation=(0, RAD(14), 0)))
    parts[-1].scale = (0.045, 0.5, 0.6)
    parts.append(_add("h_vtail_l", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(-0.26, -1.25, 0.38),
                      rotation=(0, RAD(-14), 0)))
    parts[-1].scale = (0.045, 0.5, 0.6)
    # canopy (kokpit, depan +Y, atas)
    parts.append(_add("h_canopy", bpy.ops.mesh.primitive_cube_add,
                      mat, size=1.0, location=(0, 0.5, 0.34)))
    parts[-1].scale = (0.3, 0.55, 0.24)

    # terapkan transformasi, lalu join semua bagian hull
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "SHP001_Body"
    _clean_mesh(body)
    bpy.ops.object.shade_smooth()

    # UV untuk tekstur panel (smart project — low-poly hull sederhana)
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
        "asset_id": "SHP-001",
        "name": "Basic Interceptor",
        "source_glb": "assets/ships/shp_001_basic_interceptor.glb (source, di luar PCK)",
        "texture_source": "assets/ships/shp_001_hull_1024.png",
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
        '[node name="SHP001BasicInterceptor" type="Node3D"]\n'
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
    wpn = next(n for n in nodes if n["name"] == "SHP001_Weapon_T")
    eng = next(n for n in nodes if n["name"] == "SHP001_Engine_L")
    z_wpn = sum(v[2] for v in wpn["vertices"]) / len(wpn["vertices"])
    z_eng = sum(v[2] for v in eng["vertices"]) / len(eng["vertices"])
    print("ASSET: orientasi precheck Godot space: weapon_z=%.2f engine_z=%.2f -> %s" % (
        z_wpn, z_eng, "NOSE -Z OK" if z_wpn < z_eng else "SALAH ARAH"))


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(SRC_DIR, exist_ok=True)
    os.makedirs(GAME_ASSETS, exist_ok=True)

    make_texture(TEX_SRC_PATH)
    mat_hull, mat_eng, mat_wpn = make_materials(TEX_SRC_PATH)

    body = build_hull(mat_hull)

    # mesin (belakang = -Y, emission cyan) — penanda attachment point
    _add("SHP001_Engine_R", bpy.ops.mesh.primitive_cylinder_add,
         mat_eng, vertices=8, radius=0.17, depth=0.8,
         location=(0.42, -1.7, 0), rotation=(RAD(90), 0, 0))
    _add("SHP001_Engine_L", bpy.ops.mesh.primitive_cylinder_add,
         mat_eng, vertices=8, radius=0.17, depth=0.8,
         location=(-0.42, -1.7, 0), rotation=(RAD(90), 0, 0))
    # titik senjata (nose = +Y, emission red-orange) — penanda attachment point
    _add("SHP001_Weapon_T", bpy.ops.mesh.primitive_ico_sphere_add,
         mat_wpn, radius=0.08, subdivisions=2, location=(0, 2.32, 0))

    # terapkan transformasi semua objek (origin tetap di pusat badan = world origin)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    # geometri bersih untuk objek di luar body (engine, weapon)
    for name in ["SHP001_Engine_R", "SHP001_Engine_L", "SHP001_Weapon_T"]:
        _clean_mesh(bpy.data.objects[name])

    # statistik (data nyata untuk laporan)
    mesh = body.data
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    print("ASSET: SHP001_Body tris=%d verts=%d" % (len(mesh.polygons), len(mesh.vertices)))
    print("ASSET: hull bounds blender x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f]"
          % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    print("ASSET: hull length (y, nose=+Y) = %.2f m" % (max(ys) - min(ys)))

    # jangan simpan backup .blend1 (anti-pattern ASSET_ACCEPTANCE_CRITERIA.md §6)
    try:
        bpy.context.preferences.filepaths.save_versions = 0
    except Exception:
        pass
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    # jangan simpan backup .blend1 (anti-pattern ASSET_ACCEPTANCE_CRITERIA.md §6)
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
