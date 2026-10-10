class_name MeshUtil
extends RefCounted
## MeshUtil — helper geometri untuk verifikasi aset (ASSET_ACCEPTANCE_CRITERIA.md).
## AABB dihitung parent-relative (mi → root), sehingga tidak bergantung global
## transform yang tersinkron — aman dipakai di _ready maupun test headless.
## Catatan: jangan inisialisasi AABB dengan idiom INF — AABB.expand (min/max)
## menghasilkan NaN karena end = INF + (-INF). Inisialisasi dari corner pertama.


static func aabb_in_root(mi: MeshInstance3D, root: Node3D) -> AABB:
	## AABB satu mesh dalam space `root`.
	var t := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).get_transform() * t
		n = n.get_parent()
	var local := AABB()
	if mi.mesh != null:
		local = mi.mesh.get_aabb()
	var corners: Array[Vector3] = []
	for cx in [local.position.x, local.position.x + local.size.x]:
		for cy in [local.position.y, local.position.y + local.size.y]:
			for cz in [local.position.z, local.position.z + local.size.z]:
				corners.append(t * Vector3(cx, cy, cz))
	var out := AABB(corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		out = out.expand(corners[i])
	return out


static func model_aabb(root: Node3D) -> AABB:
	## AABB gabungan semua mesh di bawah root. AABB() (zero) jika tanpa mesh.
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var a := aabb_in_root(inst, root)
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


static func tri_count(mesh: Mesh) -> int:
	## Jumlah segitiga satu mesh (dari index buffer, fallback vertex buffer).
	if mesh == null:
		return 0
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var idx: Array = arrays[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			total += idx.size() / 3
		else:
			var verts: Array = arrays[Mesh.ARRAY_VERTEX]
			if verts != null:
				total += verts.size() / 3
	return total
