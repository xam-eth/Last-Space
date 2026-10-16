#!/usr/bin/env python3
"""make_fortress.py — aset benteng & bangunan Last-Space (Blender headless).

Menjawab kritik pemain 2026-10-16 (M3 #9):
  - "game arena nya itu harusnya dibuat seperti di dalam markas luar angkasa
     punya benteng"  → `FRT-001` platform benteng + `FRT-002` command core.
  - "semua component layout dan icon masih memakai code/html5, bukan asset"
     → bangunan TIDAK lagi dibangun dari primitif kode di Godot; model datang
       dari berkas aset (GLB + mesh.json runtime) hasil script ini.

Kontrak (ASSET_PIPELINE.md §2, ASSET_ACCEPTANCE_CRITERIA.md §2):
  - 1 unit Blender = 1 meter; origin di titik jangkar (pusat dasar objek).
  - Bangunan menghadap -Z Godot (sisi depan = -Y Blender), konversi (x,y,z)→(x,z,-y).
  - Material memakai library MAT-xxx; tekstur PNG 512 power-of-two dari
    `assets/fortress/*_512.png` (dibuat tools/art/make_fortress_textures.py).
  - Geometri bersih: weld + triangulasi (no n-gon), poly count dijaga rendah.

Aset yang dihasilkan (satu file per aset):
  FRT-001  Fortress Platform   — dek heksagonal benteng (arena gameplay)
  FRT-002  Command Core        — markas utama (command_core)
  ECO-001  Energy Reactor      — energy_reactor
  ECO-004  Mineral Extractor   — mineral_extractor
  ECO-010  Fighter Hangar      — fighter_hangar
  DEF-001  Laser Turret        — laser_turret
  DEF-008  Shield Generator    — shield_generator

Output per aset: assets/fortress/<id>.glb, .blend (source),
                 game/assets/fortress/<id>.mesh.json + <id>.tscn (runtime).

Usage: source tools/env.sh && python3 tools/blender/make_fortress.py
"""
import base64
import json
import math
import os

import bpy

RAD = math.radians
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(REPO, "assets", "fortress")
GAME_DIR = os.path.join(REPO, "game", "assets", "fortress")
TEX_DECK = os.path.join(SRC_DIR, "deck_plating_512.png")
TEX_HULL = os.path.join(SRC_DIR, "hull_panel_512.png")
TEX_DECK_EMI = os.path.join(SRC_DIR, "deck_plating_512_emissive.png")
TEX_HULL_EMI = os.path.join(SRC_DIR, "hull_panel_512_emissive.png")

MAT_DECK = "MAT004_Dark_Metal_Deck"
MAT_HULL = "MAT001_Human_Hull_Metal"
MAT_CERAMIC = "MAT005_Ceramic_Armor"
MAT_CORE = "MAT006_Energy_Core_Emission"
MAT_SHIELD = "MAT009_Shield_Material"
MAT_WEAPON = "MAT008_Red_Orange_Weapon_Emission"


# --------------------------------------------------------------- material ---
def _textured_mat(name: str, tex_path: str, metallic: float, roughness: float,
                  emissive_path: str = "", emission_tex: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    img = bpy.data.images.load(tex_path)
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission_tex > 0.0 and emissive_path:
        ## Peta EMISSIVE TERPISAH (hanya garis panel yang menyala) — pelajaran
        ## foto M3 #9: memakai tekstur albedo penuh sebagai emission membuat
        ## seluruh dek jadi abu-abu pucat dan detail hilang.
        eimg = bpy.data.images.load(emissive_path)
        etex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        etex.image = eimg
        mat.node_tree.links.new(etex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission_tex
    return mat


def _plain_mat(name: str, albedo, metallic: float, roughness: float,
               emission=None, strength: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (albedo[0], albedo[1], albedo[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


# ----------------------------------------------------------------- helper ---
def _add(name, op, mat, **kw):
    op(**kw)
    obj = bpy.context.active_object
    obj.name = name
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def _clean_mesh(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")


def _uv_cube(obj, tile_m: float = 2.0) -> None:
    """UV box projection (CUBE) — `tile_m` = meter per satu ubin tekstur, supaya
    skala pola panel konsisten antar aset (temuan: cube_size=1 membuat pola
    terlalu rapat pada platform 85 m)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=tile_m)
    bpy.ops.object.mode_set(mode="OBJECT")


def _join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    _clean_mesh(obj)
    return obj


def _box(name, mat, loc, size, rot=(0, 0, 0)):
    o = _add(name, bpy.ops.mesh.primitive_cube_add, mat, size=1.0,
             location=loc, rotation=(RAD(rot[0]), RAD(rot[1]), RAD(rot[2])))
    o.scale = size
    return o


def _cyl(name, mat, loc, radius, depth, verts=12, rot=(0, 0, 0), scale=(1, 1, 1)):
    o = _add(name, bpy.ops.mesh.primitive_cylinder_add, mat, vertices=verts,
             radius=radius, depth=depth,
             location=loc, rotation=(RAD(rot[0]), RAD(rot[1]), RAD(rot[2])))
    o.scale = scale
    return o


# ------------------------------------------------------------ kit builder ---
def kit_plinth(mat, size_x, size_y, h=0.3, name="Plinth"):
    """Plinth modular: alas bertingkat — semua bangunan berdiri di atas plinth
    (pola base-builder: setiap struktur menempati satu slot platform)."""
    base = _box(name + "_base", mat, (0, 0, h * 0.5), (size_x, size_y, h))
    lip = _box(name + "_lip", mat, (0, 0, h + 0.02), (size_x * 1.06, size_y * 1.06, 0.06))
    return [base, lip]


def kit_greebles(mat, half_x, half_y, z, count=4):
    """Detail kecil di sekeliling body: pipa/vent/blok teknis (silhouette kaya)."""
    out = []
    step = (2.0 * half_x) / (count + 1)
    for i in range(count):
        x = -half_x + step * (i + 1)
        out.append(_box("Greeble_%d" % i, mat, (x, half_y * 0.86, z),
                        (step * 0.5, 0.16, 0.22)))
        out.append(_box("GreebleB_%d" % i, mat, (x, -half_y * 0.86, z - 0.1),
                        (step * 0.35, 0.12, 0.16)))
    return out


# ------------------------------------------------------------------ assets ---
def build_platform(mat_deck, mat_hull):
    """FRT-001 — dek benteng heksagonal (12 sisi) 2 tingkat + 4 pylon docking.
    Radius 42 m ≈ menutup seluruh arena 80×80 m (apothem 40,5 m)."""
    parts = []
    deck = _add("FRT001_Deck", bpy.ops.mesh.primitive_cylinder_add, mat_deck,
                vertices=12, radius=42.0, depth=0.6, location=(0, 0, 0))
    parts.append(deck)
    rim = _add("FRT001_Rim", bpy.ops.mesh.primitive_cylinder_add, mat_hull,
               vertices=12, radius=42.6, depth=0.28, location=(0, 0, 0.36))
    parts.append(rim)
    lower = _add("FRT001_UnderDeck", bpy.ops.mesh.primitive_cylinder_add, mat_hull,
                 vertices=12, radius=33.0, depth=1.6, location=(0, 0, -1.1))
    parts.append(lower)
    for i in range(4):
        ang = 45.0 + 90.0 * i
        x = math.cos(RAD(ang)) * 36.0
        y = math.sin(RAD(ang)) * 36.0
        parts.append(_box("FRT001_Pylon_%d" % i, mat_hull, (x, y, 1.5),
                          (2.4, 2.4, 3.0), rot=(0, 0, ang)))
        parts.append(_cyl("FRT001_PylonCap_%d" % i, mat_hull, (x, y, 3.2),
                          1.4, 0.5, verts=8))
    body = _join(parts, "FRT001_Body")
    _uv_cube(body, 24.0)  ## platform: 24 m per ubin (pola panel ~3 m — kalibrasi foto)
    return body


def build_command_core(mat_hull, mat_deck, mat_core):
    """FRT-002 — markas utama: bunker bertingkat + 4 menara sudut + inti energi
    + antena. Footprint 8×8 m, tinggi ~9 m (monumental vs bangunan lain)."""
    parts = kit_plinth(mat_deck, 8.0, 8.0, h=0.4)
    parts.append(_box("Core_bunker1", mat_hull, (0, 0, 2.0), (7.0, 7.0, 3.2)))
    parts.append(_box("Core_bunker2", mat_hull, (0, 0, 4.2), (5.6, 5.6, 1.4)))
    parts.append(_box("Core_bunker3", mat_hull, (0, 0, 5.6), (3.6, 3.6, 1.4)))
    core = _add("Core_crystal", bpy.ops.mesh.primitive_ico_sphere_add, mat_core,
                radius=1.05, subdivisions=2, location=(0, 0, 7.0))
    parts.append(core)
    for i in range(4):
        ang = 45.0 + 90.0 * i
        x = math.cos(RAD(ang)) * 2.9
        y = math.sin(RAD(ang)) * 2.9
        parts.append(_cyl("Core_tower_%d" % i, mat_hull, (x, y, 5.2),
                          0.62, 3.4, verts=8))
        parts.append(_box("Core_towerTop_%d" % i, mat_core,
                          (x, y, 7.15), (1.1, 1.1, 0.3)))
    parts.append(_add("Core_radar", bpy.ops.mesh.primitive_cylinder_add, mat_deck,
                      vertices=10, radius=0.18, depth=4.0, location=(0, 0, 9.4),
                      rotation=(RAD(90), 0, 0)))
    parts.append(_add("Core_radarDish", bpy.ops.mesh.primitive_uv_sphere_add, mat_deck,
                      segments=12, ring_count=6, radius=1.5,
                      location=(0, 0.0, 10.6), rotation=(RAD(90), 0, 0)))
    parts[-1].scale = (1.0, 1.0, 0.30)
    parts += kit_greebles(mat_hull, 3.5, 3.5, 3.5, count=3)
    body = _join(parts, "FRT002_CommandCore")
    _uv_cube(body, 4.0)
    return body


def build_reactor(mat_hull, mat_deck, mat_core):
    """ECO-001 Energy Reactor — tabung inti bersirip + cincin emissive."""
    parts = kit_plinth(mat_deck, 4.6, 4.6, h=0.3)
    parts.append(_cyl("Reactor_vessel", mat_hull, (0, 0, 2.2), 1.5, 3.4, verts=12))
    parts.append(_cyl("Reactor_core", mat_core, (0, 0, 2.4), 1.15, 2.2, verts=12))
    for i in range(3):
        parts.append(_add("Reactor_ring_%d" % i, bpy.ops.mesh.primitive_torus_add,
                          mat_hull, major_radius=1.72, minor_radius=0.14,
                          major_segments=12, minor_segments=6,
                          location=(0, 0, 1.1 + 1.1 * i)))
    for i in range(4):
        ang = 45.0 + 90.0 * i
        parts.append(_box("Reactor_fin_%d" % i, mat_hull,
                          (math.cos(RAD(ang)) * 1.75, math.sin(RAD(ang)) * 1.75, 2.2),
                          (0.5, 0.22, 2.6), rot=(0, 0, ang)))
    parts.append(_cyl("Reactor_cap", mat_deck, (0, 0, 4.05), 1.1, 0.5, verts=12))
    parts.append(_add("Reactor_glow", bpy.ops.mesh.primitive_ico_sphere_add, mat_core,
                      radius=0.55, subdivisions=1, location=(0, 0, 4.5)))
    return _join(parts, "ECO001_EnergyReactor")


def build_extractor(mat_hull, mat_deck, mat_core):
    """ECO-004 Mineral Extractor — menara bor + lengan ekstraksi + tangki."""
    parts = kit_plinth(mat_deck, 5.0, 5.0, h=0.3)
    parts.append(_box("Ext_frame", mat_hull, (0, 0, 1.5), (3.6, 3.6, 2.4)))
    parts.append(_cyl("Ext_drill", mat_core, (0, 0, 3.6), 0.55, 3.0, verts=10))
    parts.append(_add("Ext_drillTip", bpy.ops.mesh.primitive_cone_add, mat_hull,
                      vertices=10, radius1=0.55, radius2=0.05, depth=1.2,
                      location=(0, 0, 1.5)))
    parts.append(_box("Ext_armR", mat_hull, (2.6, 0, 2.2), (2.0, 0.6, 0.6), rot=(0, 0, -8)))
    parts.append(_box("Ext_armL", mat_hull, (-2.6, 0, 2.2), (2.0, 0.6, 0.6), rot=(0, 0, 8)))
    parts.append(_cyl("Ext_tank1", mat_deck, (1.7, -1.7, 1.3), 0.75, 2.0, verts=10))
    parts.append(_cyl("Ext_tank2", mat_deck, (-1.7, -1.7, 1.3), 0.75, 2.0, verts=10))
    parts += kit_greebles(mat_hull, 1.8, 1.8, 2.55, count=2)
    return _join(parts, "ECO004_MineralExtractor")


def build_hangar(mat_hull, mat_deck, mat_core):
    """ECO-010 Fighter Hangar — hanggar berpeluncur ganda + pintu emissive."""
    parts = kit_plinth(mat_deck, 6.4, 5.2, h=0.3)
    parts.append(_box("Hangar_body", mat_hull, (0, 0, 1.9), (5.8, 4.4, 3.2)))
    parts.append(_box("Hangar_roof", mat_hull, (0, -0.4, 3.7), (5.0, 3.4, 0.5)))
    parts.append(_box("Hangar_doorGlow", mat_core, (0, -2.32, 1.9), (3.6, 0.22, 1.6)))
    for i in (-1, 1):
        parts.append(_box("Hangar_pad_%d" % i, mat_deck, (1.9 * i, 2.9, 0.55),
                          (1.8, 2.0, 0.5)))
        parts.append(_box("Hangar_padGlow_%d" % i, mat_core, (1.9 * i, 2.9, 0.84),
                          (1.2, 1.4, 0.12)))
        parts.append(_cyl("Hangar_tower_%d" % i, mat_deck, (3.1 * i, -2.4, 2.6),
                          0.45, 4.4, verts=8))
    parts += kit_greebles(mat_hull, 2.6, 1.9, 3.1, count=3)
    return _join(parts, "ECO010_FighterHangar")


def build_turret(mat_hull, mat_deck, mat_weapon):
    """DEF-001 Basic Laser Turret — basis + laras terpisah (kontrak turret)."""
    parts = kit_plinth(mat_deck, 2.8, 2.8, h=0.25)
    parts.append(_cyl("Turret_base", mat_hull, (0, 0, 0.75), 1.15, 1.0, verts=12))
    parts.append(_cyl("Turret_ring", mat_deck, (0, 0, 1.32), 0.95, 0.35, verts=12))
    barrel_l = _box("Turret_barrelL", mat_hull, (-0.28, 1.5, 1.65),
                    (0.28, 2.6, 0.28))
    barrel_r = _box("Turret_barrelR", mat_hull, (0.28, 1.5, 1.65),
                    (0.28, 2.6, 0.28))
    tip_l = _cyl("Turret_tipL", mat_weapon, (-0.28, 2.75, 1.65), 0.16, 0.3,
                 verts=8, rot=(90, 0, 0))
    tip_r = _cyl("Turret_tipR", mat_weapon, (0.28, 2.75, 1.65), 0.16, 0.3,
                 verts=8, rot=(90, 0, 0))
    parts += [barrel_l, barrel_r, tip_l, tip_r]
    body = _join(parts, "DEF001_LaserTurret")
    return body


def build_shield(mat_hull, mat_deck, mat_shield):
    """DEF-008 Shield Generator — emitter 4 tiang + kubah perisai transparan."""
    parts = kit_plinth(mat_deck, 4.2, 4.2, h=0.3)
    parts.append(_cyl("Shield_hub", mat_hull, (0, 0, 1.4), 1.0, 2.2, verts=10))
    for i in range(4):
        ang = 45.0 + 90.0 * i
        x = math.cos(RAD(ang)) * 1.55
        y = math.sin(RAD(ang)) * 1.55
        parts.append(_cyl("Shield_emitter_%d" % i, mat_hull, (x, y, 1.9),
                          0.32, 3.4, verts=8))
        parts.append(_add("Shield_tip_%d" % i, bpy.ops.mesh.primitive_ico_sphere_add,
                          mat_deck, radius=0.36, subdivisions=1, location=(x, y, 3.8)))
    parts.append(_add("Shield_dome", bpy.ops.mesh.primitive_uv_sphere_add, mat_shield,
                      segments=16, ring_count=8, radius=3.0, location=(0, 0, 1.95)))
    parts[-1].scale = (1.0, 1.0, 0.62)   ## dasar kubah tepat di lantai (min_z 0)
    return _join(parts, "DEF008_ShieldGenerator")


# --------------------------------------------------- runtime (tscn + json) ---
def _to_godot(x: float, y: float, z: float):
    return (x, z, -y)


def _mat_params(mat) -> dict:
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    textured = False
    emis_tex = False
    for link in mat.node_tree.links:
        if link.to_node == bsdf and link.from_node.bl_idname == "ShaderNodeTexImage":
            if link.to_socket.name == "Base Color":
                textured = True
            if link.to_socket.name == "Emission Color":
                emis_tex = True
    base = bsdf.inputs["Base Color"].default_value
    emis = bsdf.inputs["Emission Color"].default_value
    strength = 0.0
    if "Emission Strength" in bsdf.inputs:
        strength = bsdf.inputs["Emission Strength"].default_value
    return {
        "albedo": [round(base[0], 4), round(base[1], 4), round(base[2], 4), 1.0],
        "metallic": round(bsdf.inputs["Metallic"].default_value, 4),
        "roughness": round(bsdf.inputs["Roughness"].default_value, 4),
        "textured": textured,
        "emission": [round(emis[0], 4), round(emis[1], 4), round(emis[2], 4)],
        "emission_strength": round(strength, 4),
        "emissive_textured": emis_tex,
    }


def _extract_nodes(obj) -> list:
    """Ekspor mesh sebagai SATU NODE PER MATERIAL.

    Pelajaran nyata (audit M3 #9): sebelumnya seluruh objek join diekspor dengan
    `materials[0]` saja → inti reaktor, ujung laras senjata, dan kubah perisai
    yang punya material emissive TERPISAH ikut menjadi material dek (model jadi
    gelap & tidak ada bagian menyala). Sekarang tiap material menjadi surface
    node sendiri, lengkap dengan material_params-nya.
    """
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    has_uv = uv_layer is not None
    corners = mesh.corner_normals
    by_mat = {}
    for lt in mesh.loop_triangles:
        mi = lt.material_index
        by_mat.setdefault(mi, []).append(lt)
    out = []
    for mat_index in sorted(by_mat.keys()):
        weld = {}
        vertices, normals, uvs, indices = [], [], [], []
        for lt in by_mat[mat_index]:
            for k in range(3):
                v_idx = lt.vertices[k]
                co = mesh.vertices[v_idx].co
                nrm = corners[lt.loops[k]].vector
                if has_uv:
                    uv = uv_layer.data[lt.loops[k]].uv
                    uv_g = (uv.x, 1.0 - uv.y)
                else:
                    uv_g = (0.0, 0.0)
                key = (round(co.x, 5), round(co.y, 5), round(co.z, 5),
                       round(nrm.x, 4), round(nrm.y, 4), round(nrm.z, 4),
                       round(uv_g[0], 5), round(uv_g[1], 5))
                idx = weld.get(key)
                if idx is None:
                    idx = len(vertices)
                    weld[key] = idx
                    gx, gy, gz = _to_godot(co.x, co.y, co.z)
                    nx, ny, nz = _to_godot(nrm.x, nrm.y, nrm.z)
                    vertices.append([round(gx, 5), round(gy, 5), round(gz, 5)])
                    normals.append([round(nx, 5), round(ny, 5), round(nz, 5)])
                    uvs.append([round(uv_g[0], 5), round(uv_g[1], 5)])
                indices.append(idx)
        mat = mesh.materials[mat_index] if mat_index < len(mesh.materials) else None
        mat_name = mat.name if mat is not None else ""
        nm = obj.name if mat_index == 0 else "%s_m%d" % (obj.name, mat_index)
        out.append({"name": nm, "vertices": vertices, "normals": normals, "uvs": uvs,
                    "indices": indices, "material": mat_name,
                    "material_params": _mat_params(mat) if mat is not None else None,
                    "tris": len(indices) // 3})
    return out


def write_runtime(asset_id: str, display: str, obj, tex_map: dict) -> dict:
    """Tulis <id>.mesh.json + <id>.tscn (multi-material, tekstur di-embed base64)."""
    os.makedirs(GAME_DIR, exist_ok=True)
    nodes = _extract_nodes(obj)
    materials = {}
    for nd in nodes:
        if nd["material"] and nd["material_params"]:
            materials[nd["material"]] = nd["material_params"]
    ## Peta tekstur PER MATERIAL (albedo + emissive terpisah).
    textures = {}
    for mat_name in materials.keys():
        path = tex_map.get(mat_name, "")
        entry = {}
        if path and os.path.exists(path):
            with open(path, "rb") as fh:
                entry["albedo_b64"] = base64.b64encode(fh.read()).decode("ascii")
            ep = path.replace(".png", "_emissive.png")
            if os.path.exists(ep):
                with open(ep, "rb") as fh:
                    entry["emissive_b64"] = base64.b64encode(fh.read()).decode("ascii")
        textures[mat_name] = entry
    ## Kompatibilitas: field tunggal = material pertama yang bertekstur.
    first_tex = ""
    first_emi = ""
    for mat_name, entry in textures.items():
        if entry.get("albedo_b64") and not first_tex:
            first_tex = entry["albedo_b64"]
            first_emi = entry.get("emissive_b64", "")
    doc = {
        "asset_id": asset_id,
        "name": display,
        "source_glb": "assets/fortress/%s.glb (source, di luar PCK)" % asset_id.lower(),
        "texture_source": "assets/fortress/*_512.png (generate + seamless, tools/art/...)",
        "space": "godot (depan -Z, 1 unit = 1 m)",
        "texture_png_base64": first_tex,
        "texture_emissive_png_base64": first_emi,
        "textures": textures,
        "nodes": nodes,
        "materials": materials,
    }
    json_path = os.path.join(GAME_DIR, "%s.mesh.json" % asset_id.lower())
    with open(json_path, "w") as fh:
        json.dump(doc, fh, separators=(",", ":"))
    tscn_path = os.path.join(GAME_DIR, "%s.tscn" % asset_id.lower())
    with open(tscn_path, "w") as fh:
        fh.write('[gd_scene load_steps=2 format=3]\n\n'
                 '[ext_resource type="Script" path="res://scripts/assets/asset_model_scene.gd" id="1_model"]\n\n'
                 '[node name="%s" type="Node3D"]\n'
                 'script = ExtResource("1_model")\n'
                 'data_path = "res://assets/fortress/%s.mesh.json"\n'
                 % (asset_id.replace("-", ""), asset_id.lower()))
    return {"json": json_path, "nodes": len(nodes),
            "tris": sum(nd["tris"] for nd in nodes),
            "bytes": os.path.getsize(json_path)}


def _make_materials():
    mat_deck = _textured_mat(MAT_DECK, TEX_DECK, metallic=0.05, roughness=0.72,
                             emissive_path=TEX_DECK_EMI, emission_tex=0.30)
    mat_hull = _textured_mat(MAT_HULL, TEX_HULL, metallic=0.10, roughness=0.58,
                             emissive_path=TEX_HULL_EMI, emission_tex=0.22)
    mat_ceramic = _plain_mat(MAT_CERAMIC, (0.62, 0.66, 0.72), 0.05, 0.5)
    mat_core = _plain_mat(MAT_CORE, (0.05, 0.10, 0.14), 0.0, 0.3,
                          emission=(0.30, 0.90, 1.0), strength=6.0)
    mat_shield = _plain_mat(MAT_SHIELD, (0.20, 0.70, 1.0), 0.0, 0.1,
                            emission=(0.25, 0.70, 1.0), strength=1.4)
    mat_weapon = _plain_mat(MAT_WEAPON, (0.10, 0.04, 0.0), 0.0, 0.4,
                            emission=(1.0, 0.40, 0.12), strength=5.0)
    return mat_deck, mat_hull, mat_ceramic, mat_core, mat_shield, mat_weapon


BUILDERS = [
    ("FRT-001", "Fortress Platform", "build_platform"),
    ("FRT-002", "Command Core", "build_command_core"),
    ("ECO-001", "Energy Reactor", "build_reactor"),
    ("ECO-004", "Mineral Extractor", "build_extractor"),
    ("ECO-010", "Fighter Hangar", "build_hangar"),
    ("DEF-001", "Laser Turret", "build_turret"),
    ("DEF-008", "Shield Generator", "build_shield"),
]


def main() -> None:
    os.makedirs(SRC_DIR, exist_ok=True)
    os.makedirs(GAME_DIR, exist_ok=True)
    tex_map = {MAT_DECK: TEX_DECK, MAT_HULL: TEX_HULL, MAT_CERAMIC: TEX_DECK}
    report = []
    for asset_id, display, builder_name in BUILDERS:
        ## Scene BARU per aset (pelajaran: satu scene untuk 7 aset membuat GLB
        ## tiap aset memuat SEMUA model — file source jadi salah/polusi).
        bpy.ops.wm.read_factory_settings(use_empty=True)
        deck, hull, ceramic, core, shield, weapon = _make_materials()
        builder = globals()[builder_name]
        if builder_name == "build_platform":
            obj = builder(deck, hull)
        elif builder_name == "build_command_core":
            obj = builder(hull, deck, core)
        elif builder_name in ("build_reactor", "build_extractor", "build_hangar"):
            obj = builder(hull, deck, core)
        elif builder_name == "build_turret":
            obj = builder(hull, deck, weapon)
        else:
            obj = builder(hull, deck, shield)

        slug = asset_id.lower()
        blend = os.path.join(SRC_DIR, "%s.blend" % slug)
        glb = os.path.join(SRC_DIR, "%s.glb" % slug)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.context.preferences.filepaths.save_versions = 0
        except Exception:
            pass
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        if os.path.exists(blend + "1"):
            os.remove(blend + "1")
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB",
                                  export_yup=True, export_materials="EXPORT")
        # scene per aset: objek = satu-satunya isi scene → GLB bersih
        obj_count = len([o for o in bpy.data.objects])
        rt = write_runtime(asset_id, display, obj, tex_map)
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        report.append({
            "id": asset_id, "name": display, "tris": rt["tris"], "nodes": rt["nodes"],
            "glb_bytes": os.path.getsize(glb), "json_bytes": rt["bytes"],
            "objects_in_scene": obj_count,
            "size_m": [round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2),
                       round(max(zs) - min(zs), 2)],
            "min_z": round(min(zs), 3),
        })
        print("ASSET: %s %s tris=%d nodes=%d objs=%d glb=%dB size=%s" % (
            asset_id, display, rt["tris"], rt["nodes"], obj_count,
            os.path.getsize(glb), report[-1]["size_m"]))

    with open(os.path.join(SRC_DIR, "make_fortress_report.json"), "w") as fh:
        json.dump(report, fh, indent=2)
    print("ASSET: selesai — %d aset → %s" % (len(report), GAME_DIR))


if __name__ == "__main__":
    main()
