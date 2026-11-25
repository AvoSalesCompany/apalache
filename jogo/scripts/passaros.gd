class_name Passaros
extends Node3D
## Revoada: um bando de corvos explode das arvores e foge. Cada passaro bate asa por codigo.

var _p := []
var _dir := Vector3.FORWARD
var _t := 0.0
static var _m: Array = []


static func revoada(pai: Node3D, pos: Vector3, n: int, dir: Vector3) -> void:
	var r := Passaros.new()
	pai.add_child(r)
	r.global_position = pos
	r._dir = dir.normalized()
	r._nasce(n)
	Som.em("revoada", pos, 6.0, 160, randf_range(0.95, 1.05), "Eco", 18.0)
	for i in 3:
		Som.em("corvo%d" % randi_range(1, 3), pos + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 2.0, 160, randf_range(0.9, 1.1), "Eco", 16.0)


static func malhas() -> Array:
	if _m.is_empty():
		var c := Malha.new()
		c.tubo([Vector3(0, 0, 0.24), Vector3(0, 0, 0.14), Vector3(0, 0, 0.0), Vector3(0, 0.005, -0.12), Vector3(0, 0.015, -0.19), Vector3(0, 0.008, -0.235)], [0.008, 0.045, 0.058, 0.046, 0.032, 0.004], 8)
		c.cx(Vector3(0, 0, 0.24), Vector3(0.10, 0.006, 0.16))
		var a := Malha.new()
		for q in [[0.0, 0.05, 0.14, 0.0], [0.17, 0.19, 0.17, 0.015], [0.36, 0.13, 0.20, 0.0]]: pass
		# asa: tres segmentos em leque
		var pts := [[0.03, -0.09, 0.09], [0.20, -0.13, 0.12], [0.38, -0.10, 0.13], [0.52, 0.00, 0.11]]
		for k in 3:
			var p0: Array = pts[k]
			var p1: Array = pts[k + 1]
			var i0 := a.vert(Vector3(p0[0], 0, p0[1]), Vector3.UP, Vector2.ZERO)
			a.vert(Vector3(p1[0], 0, p1[1]), Vector3.UP, Vector2.ZERO)
			a.vert(Vector3(p1[0], 0, p1[2]), Vector3.UP, Vector2.ZERO)
			a.vert(Vector3(p0[0], 0, p0[2]), Vector3.UP, Vector2.ZERO)
			a.quad(i0, i0 + 1, i0 + 2, i0 + 3)
		var mt := Mat.liso(Color(0.018, 0.018, 0.022), 0.5, 0, Color.BLACK, 0, true)
		_m = [c.malha(mt), a.malha(mt)]
	return _m


func _nasce(n: int) -> void:
	var ms := malhas()
	for i in n:
		var b := Node3D.new()
		add_child(b)
		b.position = Vector3(randf_range(-7, 7), randf_range(-4, 3), randf_range(-7, 7))
		var c := MeshInstance3D.new()
		c.mesh = ms[0]
		b.add_child(c)
		var asas := []
		for sx in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = ms[1]
			w.scale.x = sx
			b.add_child(w)
			asas.append(w)
		for m in [c] + asas: m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.scale = Vector3.ONE * randf_range(0.85, 1.25)
		_p.append({"n": b, "a": asas, "v": Vector3(randf_range(-3, 3), randf_range(2.5, 6.0), randf_range(-3, 3)), "f": randf() * TAU, "k": randf_range(0.85, 1.2), "e": randf_range(0.0, 0.7)})


func _process(dt: float) -> void:
	_t += dt
	if _t > 16.0:
		queue_free()
		return
	for q in _p:
		if _t < q.e: continue
		var alvo: Vector3 = _dir * 13.0 * q.k + Vector3(sin(_t * 1.3 + q.f) * 2.0, 2.2 * clampf(3.0 - _t * 0.5, 0.15, 1.0) + sin(_t * 2.1 + q.f) * 0.7, cos(_t * 1.1 + q.f) * 2.0)
		q.v = (q.v as Vector3).lerp(alvo, minf(1.0, dt * 1.6))
		var b: Node3D = q.n
		b.position += q.v * dt
		var d: Vector3 = (q.v as Vector3).normalized()
		b.rotation = Vector3(asin(clampf(d.y, -1, 1)) * 0.7, atan2(-d.x, -d.z), sin(_t * 1.7 + q.f) * 0.25)
		q.f += dt * lerpf(22.0, 15.0, clampf(_t * 0.25, 0, 1)) * q.k
		var w := sin(q.f) * 0.95 + 0.12
		q.a[0].rotation.z = -w
		q.a[1].rotation.z = w