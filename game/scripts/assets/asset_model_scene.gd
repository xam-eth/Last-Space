class_name AssetModelScene
extends Node3D
## AssetModelScene — runtime scene hasil konversi aset (pipeline editor-less,
## ASSET_PIPELINE.md §import): membaca mesh data JSON (sudah di space Godot,
## depan -Z, 1 unit = 1 m) dan membangun MeshInstance3D + material per node.
##
## Alasan: build wasm Godot tidak memiliki ResourceFormatLoaderGLTF (loader .glb
## tidak terdaftar), sehingga aset .glb tidak bisa di-load langsung saat runtime.
## Di dev machine dengan editor Godot, .glb dapat diimport langsung.
## Dibuat oleh tools/blender/make_shp_001.py (jangan edit manual).

@export var data_path: String = ""


func _ready() -> void:
	if data_path == "":
		push_error("AssetModelScene: data_path kosong")
		return
	var text := FileAccess.get_file_as_string(data_path)
	if text == "":
		push_error("AssetModelScene: tidak bisa baca %s" % data_path)
		return
	var data: Dictionary = JSON.parse_string(text)
	if data == null:
		push_error("AssetModelScene: JSON invalid: %s" % data_path)
		return
	var materials: Dictionary = {}
	var mat_defs: Dictionary = data.get("materials", {})
	var tex_b64 := String(data.get("texture_png_base64", ""))
	var emi_b64 := String(data.get("texture_emissive_png_base64", ""))
	## Peta tekstur PER MATERIAL (M3 #9): satu aset kini punya beberapa material
	## (dek, lambung, inti energi, senjata, perisai) — masing-masing teksturnya
	## sendiri. Field tunggal lama tetap dipakai sebagai fallback.
	var tex_map: Dictionary = data.get("textures", {})
	for mat_name in mat_defs.keys():
		var entry: Dictionary = tex_map.get(mat_name, {})
		materials[mat_name] = _build_material(mat_defs[mat_name],
			String(entry.get("albedo_b64", tex_b64)),
			String(entry.get("emissive_b64", emi_b64)))
	var nodes: Array = data.get("nodes", [])
	for node_data in nodes:
		var nd: Dictionary = node_data
		var mi := MeshInstance3D.new()
		mi.name = String(nd.get("name", "Mesh"))
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vec3_array(nd.get("vertices", []))
		arrays[Mesh.ARRAY_NORMAL] = _vec3_array(nd.get("normals", []))
		arrays[Mesh.ARRAY_TEX_UV] = _vec2_array(nd.get("uvs", []))
		arrays[Mesh.ARRAY_INDEX] = _int_array(nd.get("indices", []))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat_name := String(nd.get("material", ""))
		if materials.has(mat_name):
			mesh.surface_set_material(0, materials[mat_name])
		mi.mesh = mesh
		add_child(mi)
	## Marker NILAI NYATA material (dipakai audit M3 #9: "kenapa model gelap?"
	## harus dijawab dengan data, bukan dugaan).
	var dbg: Array[String] = []
	for mi2 in find_children("*", "MeshInstance3D", true, false):
		var m2 := (mi2 as MeshInstance3D).mesh
		if m2 == null:
			continue
		## PENTING: material dipasang PER-SURFACE (surface_set_material), jadi
		## `mesh.material` selalu null. Semua kode yang membaca/mengubah material
		## aset (audit ini, _emissive_count, BuildingModel.tint) WAJIB lewat
		## surface_get_material(0) — temuan nyata M3 #9.
		var sm := m2.surface_get_material(0) as StandardMaterial3D
		if sm == null:
			continue
		dbg.append("%s:albedo_tex=%s emis_tex=%s albedo=%s metal=%.2f rough=%.2f emis_energy=%.2f" % [
			(mi2 as Node).name, str(sm.albedo_texture != null), str(sm.emission_texture != null),
			str(sm.albedo_color), sm.metallic, sm.roughness, sm.emission_energy_multiplier])
	print("QA:ASSET:MAT path=%s %s" % [data_path.get_file(), " | ".join(dbg)])
	QaMarkers.marker("ASSET", "MODEL_BUILT", {"nodes": nodes.size(), "path": data_path})


func _build_material(m: Dictionary, tex_b64: String, emi_b64: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var albedo: Array = m.get("albedo", [1.0, 1.0, 1.0, 1.0])
	mat.albedo_color = Color(albedo[0], albedo[1], albedo[2], albedo[3])
	mat.metallic = float(m.get("metallic", 0.0))
	mat.roughness = float(m.get("roughness", 1.0))
	var emis: Array = m.get("emission", [0.0, 0.0, 0.0])
	var strength := float(m.get("emission_strength", 0.0))
	if bool(m.get("emissive_textured", false)) and emi_b64 != "":
		var eimg := Image.new()
		if eimg.load_png_from_buffer(Marshalls.base64_to_raw(emi_b64)) == OK:
			mat.emission_texture = ImageTexture.create_from_image(eimg)
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if strength > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(emis[0], emis[1], emis[2])
		mat.emission_energy_multiplier = strength
	# Tekstur embedded base64 PNG → decode via Image.load_png_from_buffer
	# (build wasm tidak punya loader .png saat runtime).
	if bool(m.get("textured", false)) and tex_b64 != "":
		var raw := Marshalls.base64_to_raw(tex_b64)
		var img := Image.new()
		var err := img.load_png_from_buffer(raw)
		if err == OK:
			mat.albedo_texture = ImageTexture.create_from_image(img)
		else:
			push_warning("AssetModelScene: decode PNG gagal (err=%d)" % err)
	return mat


func _vec3_array(rows: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(rows.size())
	for i in rows.size():
		var r: Array = rows[i]
		out[i] = Vector3(r[0], r[1], r[2])
	return out


func _vec2_array(rows: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(rows.size())
	for i in rows.size():
		var r: Array = rows[i]
		out[i] = Vector2(r[0], r[1])
	return out


func _int_array(values: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(values.size())
	for i in values.size():
		out[i] = int(values[i])
	return out
