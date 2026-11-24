class_name Sdf
extends RefCounted
## Modelagem organica: soma suave de capsulas -> malha (surface nets), com pesos de osso.

var pr := []          # [a, b, ra, rb, osso, cor]
var k := 0.06
var rugas: Callable   # func(p, d) -> d


func cap(a: Vector3, b: Vector3, ra: float, rb: float, osso: int = 0, cor: Color = Color.WHITE) -> void:
	pr.append([a, b, ra, rb, osso, cor])


func d1(p: Vector3, q: Array) -> float:
	var a: Vector3 = q[0]
	var ba: Vector3 = q[1] - a
	var l := ba.length_squared()
	var u := 0.0
	if l > 0.000001:
		u = clampf((p - a).dot(ba) / l, 0.0, 1.0)
	return p.distance_to(a + ba * u) - lerpf(q[2], q[3], u)


func dist(p: Vector3) -> float:
	var d := 1e9
	for q in pr:
		var e := d1(p, q)
		if e > d + k:
			continue
		if d > e + k:
			d = e
		else:
			var hh := clampf(0.5 + 0.5 * (d - e) / k, 0.0, 1.0)
			d = lerpf(d, e, hh) - k * hh * (1.0 - hh)
	if rugas.is_valid():
		d = rugas.call(p, d)
	return d


func gerar(cx: AABB, h: float, ossos: Array = []) -> Dictionary:
	var nx := int(cx.size.x / h) + 2
	var ny := int(cx.size.y / h) + 2
	var nz := int(cx.size.z / h) + 2
	var val := PackedFloat32Array()
	val.resize(nx * ny * nz)
	val.fill(1.0)
	var B := 4
	var o := cx.position
	for bz in range(0, nz, B):
		for by in range(0, ny, B):
			for bx in range(0, nx, B):
				var cen := o + Vector3(bx + B * 0.5, by + B * 0.5, bz + B * 0.5) * h
				var dc := dist(cen)
				var lim := h * B * 1.05
				if dc > lim:
					continue
				for z in range(bz, mini(bz + B, nz)):
					for y in range(by, mini(by + B, ny)):
						for x in range(bx, mini(bx + B, nx)):
							val[(z * ny + y) * nx + x] = -1.0 if dc < -lim else dist(o + Vector3(x, y, z) * h)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cores := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var pesos := PackedFloat32Array()
	var mapa := {}
	var off := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var ar := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for z in nz - 1:
		for y in ny - 1:
			for x in nx - 1:
				var vs := []
				var masc := 0
				for i in 8:
					var f: Vector3i = off[i]
					var vv := val[((z + f.z) * ny + y + f.y) * nx + x + f.x]
					vs.append(vv)
					if vv < 0.0:
						masc |= 1 << i
				if masc == 0 or masc == 255:
					continue
				var s := Vector3.ZERO
				var cnt := 0
				for e in ar:
					var a: float = vs[e[0]]
					var b: float = vs[e[1]]
					if (a < 0.0) != (b < 0.0):
						var u := a / (a - b)
						s += Vector3(off[e[0]]).lerp(Vector3(off[e[1]]), u)
						cnt += 1
				var p := o + (Vector3(x, y, z) + s / cnt) * h
				var e := h * 0.6
				var g := Vector3(dist(p + Vector3(e, 0, 0)) - dist(p - Vector3(e, 0, 0)), dist(p + Vector3(0, e, 0)) - dist(p - Vector3(0, e, 0)), dist(p + Vector3(0, 0, e)) - dist(p - Vector3(0, 0, e))).normalized()
				p -= g * clampf(dist(p), -h, h) * 0.8
				mapa[(z * ny + y) * nx + x] = verts.size()
				verts.push_back(p)
				norms.push_back(g)
				uv.push_back(Vector2(p.x, p.y))
				uv2.push_back(Vector2(p.z, 0))
				# cor e pesos
				var tc := Color(0, 0, 0, 0)
				var tw := 0.0
				var po := {}
				for q in pr:
					var dd := maxf(d1(p, q), 0.0)
					var w := exp(-dd * dd / (2.0 * 0.018 * 0.018))
					if w > 0.0001:
						tc += (q[5] as Color) * w
						tw += w
					var w2 := exp(-dd * dd / (2.0 * 0.055 * 0.055))
					po[q[4]] = maxf(po.get(q[4], 0.0), w2)
				cores.push_back(tc / tw if tw > 0.0 else Color.BLACK)
				if not ossos.is_empty():
					var lista := []
					for b in po:
						lista.append([po[b], b])
					lista.sort_custom(func(x1, x2): return x1[0] > x2[0])
					var soma := 0.0
					for i in mini(4, lista.size()):
						soma += lista[i][0]
					for i in 4:
						if i < lista.size():
							bones.push_back(lista[i][1])
							pesos.push_back(lista[i][0] / soma if soma > 0.0 else (1.0 if i == 0 else 0.0))
						else:
							bones.push_back(0)
							pesos.push_back(0.0)
	var idx := PackedInt32Array()
	var at := func(x: int, y: int, z: int) -> int: return mapa.get((z * ny + y) * nx + x, -1)
	for z in range(1, nz - 1):
		for y in range(1, ny - 1):
			for x in range(1, nx - 1):
				var v0 := val[(z * ny + y) * nx + x] < 0.0
				var vx := val[(z * ny + y) * nx + x + 1] < 0.0
				var vy := val[(z * ny + y + 1) * nx + x] < 0.0
				var vz := val[((z + 1) * ny + y) * nx + x] < 0.0
				if v0 != vx:
					_q(idx, at.call(x, y - 1, z - 1), at.call(x, y, z - 1), at.call(x, y, z), at.call(x, y - 1, z), v0)
				if v0 != vy:
					_q(idx, at.call(x - 1, y, z - 1), at.call(x - 1, y, z), at.call(x, y, z), at.call(x, y, z - 1), v0)
				if v0 != vz:
					_q(idx, at.call(x - 1, y - 1, z), at.call(x, y - 1, z), at.call(x, y, z), at.call(x - 1, y, z), v0)
	return {"v": verts, "n": norms, "c": cores, "uv": uv, "uv2": uv2, "b": bones, "w": pesos, "i": idx}


func _q(idx: PackedInt32Array, a: int, b: int, c: int, d: int, dentro: bool) -> void:
	if a < 0 or b < 0 or c < 0 or d < 0:
		return
	# Godot: frente = sentido horario
	if dentro:
		idx.append_array(PackedInt32Array([a, c, b, a, d, c]))
	else:
		idx.append_array(PackedInt32Array([a, b, c, a, c, d]))


static func malha(d: Dictionary) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = d.v
	a[Mesh.ARRAY_NORMAL] = d.n
	a[Mesh.ARRAY_COLOR] = d.c
	a[Mesh.ARRAY_TEX_UV] = d.uv
	a[Mesh.ARRAY_TEX_UV2] = d.uv2
	a[Mesh.ARRAY_INDEX] = d.i
	if d.b.size() > 0:
		a[Mesh.ARRAY_BONES] = d.b
		a[Mesh.ARRAY_WEIGHTS] = d.w
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m
