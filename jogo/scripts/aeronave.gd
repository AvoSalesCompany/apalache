class_name Aeronave
extends RefCounted
## Pecas do aviao: casco com janelas, poltronas, bagageiros. Usado no voo e nos destrocos.

const R := 1.46
const RI := 1.38
const BAIA := 0.80
const PISO := -0.78


static func _p(r: float, ang: float, z: float) -> Vector3:
	return Vector3(cos(ang) * r, sin(ang) * r, z)


## casco de z0 ate z0+baias*0.8 (eixo Z). furo(baia, setor) -> true remove o painel
static func casco(pai: Node3D, baias: int, z0: float, furo: Callable = Callable(), janelas: bool = true) -> void:
	var fora := Malha.new()
	var dentro := Malha.new()
	var moldura := Malha.new()
	var vidro := Malha.new()
	var grs := [-90, -72, -54, -36, -19, -1, 20, 35, 52, 70, 90, 110, 128, 145, 160, 181, 199, 216, 234, 252, 270]
	for b in baias:
		var zb := z0 + b * BAIA
		var cortes := [zb, zb + 0.22, zb + 0.58, zb + BAIA]
		for s in grs.size() - 1:
			if furo.is_valid() and furo.call(b, s):
				continue
			var a0 := deg_to_rad(grs[s])
			var a1 := deg_to_rad(grs[s + 1])
			var jan: bool = janelas and (s == 5 or s == 14)
			for q in 3:
				var za: float = cortes[q]
				var zc: float = cortes[q + 1]
				if jan and q == 1:
					# tunel da janela
					var c := [_p(RI, a0, za), _p(RI, a1, za), _p(RI, a1, zc), _p(RI, a0, zc)]
					var d := [_p(R, a0, za), _p(R, a1, za), _p(R, a1, zc), _p(R, a0, zc)]
					var cen: Vector3 = (c[0] + c[2]) * 0.5
					for k in 4:
						var k2 := (k + 1) % 4
						var no: Vector3 = (cen - (c[k] + c[k2]) * 0.5).normalized()
						var i := moldura.vert(c[k], no, Vector2.ZERO)
						moldura.vert(c[k2], no, Vector2.ZERO)
						moldura.vert(d[k2], no, Vector2.ZERO)
						moldura.vert(d[k], no, Vector2.ZERO)
						moldura.quad(i, i + 1, i + 2, i + 3)
						moldura.quad(i, i + 3, i + 2, i + 1)
						# borda arredondada interna
						var m0: Vector3 = c[k].lerp(cen, 0.14)
						var m1: Vector3 = c[k2].lerp(cen, 0.14)
						var ni := -Vector3(cen.x, cen.y, 0).normalized()
						var j := moldura.vert(c[k] + ni * 0.004, ni, Vector2.ZERO)
						moldura.vert(c[k2] + ni * 0.004, ni, Vector2.ZERO)
						moldura.vert(m1 + ni * 0.012, ni, Vector2.ZERO)
						moldura.vert(m0 + ni * 0.012, ni, Vector2.ZERO)
						moldura.quad(j, j + 1, j + 2, j + 3)
						moldura.quad(j, j + 3, j + 2, j + 1)
					continue
				_painel(fora, R, a0, a1, za, zc, 1.0)
				_painel(dentro, RI, a0, a1, za, zc, -1.0)
	var mf := Mat.pbr("blue_metal_plate", 1.0, Color(0.80, 0.82, 0.84), 0.7, 0.35)
	fora.no(mf, pai)
	dentro.no(Mat.liso(Color(0.50, 0.49, 0.46), 0.75), pai)
	moldura.no(Mat.liso(Color(0.40, 0.39, 0.37), 0.6), pai)


static func _painel(m: Malha, r: float, a0: float, a1: float, z0: float, z1: float, sinal: float) -> void:
	var sub := 2
	for k in sub:
		var b0 := lerpf(a0, a1, float(k) / sub)
		var b1 := lerpf(a0, a1, float(k + 1) / sub)
		var i := m.v.size()
		for q in [[b0, z0], [b1, z0], [b1, z1], [b0, z1]]:
			var n := Vector3(cos(q[0]), sin(q[0]), 0) * sinal
			m.vert(_p(r, q[0], q[1]), n, Vector2(q[0] * r, q[1]) * 0.6, Vector3(-sin(q[0]), cos(q[0]), 0))
		if sinal < 0.0:
			m.quad(i, i + 1, i + 2, i + 3)
		else:
			m.quad(i, i + 3, i + 2, i + 1)


static func piso(pai: Node3D, comp: float, z0: float) -> void:
	var m := Malha.new()
	m.cx(Vector3(0, PISO - 0.04, z0 + comp * 0.5), Vector3(2.3, 0.08, comp), Vector3.ZERO, 0.8)
	m.no(Mat.pbr("dirty_carpet", 1.0, Color(0.26, 0.28, 0.36)), pai)
	var t := Malha.new()
	for sx in [-1.0, 1.0]:
		t.cx(Vector3(0.27 * sx, PISO + 0.004, z0 + comp * 0.5), Vector3(0.03, 0.008, comp))
	t.no(Mat.liso(Color(0.5, 0.5, 0.5), 0.4, 0.8), pai)


static func bagageiro(pai: Node3D, comp: float, z0: float) -> void:
	var m := Malha.new()
	for sx in [-1.0, 1.0]:
		var n := int(comp / 1.6)
		for i in n:
			var z := z0 + (i + 0.5) * comp / n
			m.cx(Vector3(0.86 * sx, 0.86, z), Vector3(0.46, 0.34, comp / n - 0.025), Vector3(0, 0, 0.5 * sx))
	m.no(Mat.liso(Color(0.58, 0.57, 0.53), 0.5), pai)
	var l := Malha.new()
	for sx in [-1.0, 1.0]:
		l.cx(Vector3(0.63 * sx, 0.64, z0 + comp * 0.5), Vector3(0.05, 0.012, comp))
	l.no(Mat.liso(Color(0.3, 0.3, 0.3), 0.4), pai)


static var _polt: ArrayMesh
## poltrona: origem no piso, olhando para -Z
static func poltrona() -> ArrayMesh:
	if _polt:
		return _polt
	var f := Malha.new()
	for i in 5:
		var z := 0.20 - i * 0.095
		f.tubo([Vector3(-0.215, 0.42, z), Vector3(-0.15, 0.435, z), Vector3(0.15, 0.435, z), Vector3(0.215, 0.42, z)], [0.052, 0.07, 0.07, 0.052], 8, 1.5, 1.0, Color(0, 0, 0.5), true)
	for i in 7:
		var y := 0.50 + i * 0.098
		var z := 0.235 + i * 0.021
		var lg := 0.215 if i < 5 else 0.17
		f.tubo([Vector3(-lg, y, z), Vector3(-lg * 0.7, y, z - 0.012), Vector3(lg * 0.7, y, z - 0.012), Vector3(lg, y, z)], [0.052, 0.068, 0.068, 0.052], 8, 1.5, 1.0, Color(0, 0, 0.5), true)
	var m := ArrayMesh.new()
	f.aplicar(m, Mat.pbr("fabric_pattern_07", 1.0, Color(0.20, 0.25, 0.42)))
	var d := Malha.new()
	d.cx(Vector3(0, 0.80, 0.335), Vector3(0.43, 0.66, 0.05), Vector3(0.21, 0, 0))
	d.cx(Vector3(0, 0.37, 0.0), Vector3(0.44, 0.06, 0.5))
	for sx in [-1.0, 1.0]:
		d.cx(Vector3(0.25 * sx, 0.60, 0.06), Vector3(0.045, 0.045, 0.40))
		d.cx(Vector3(0.25 * sx, 0.48, 0.20), Vector3(0.035, 0.25, 0.06))
		d.cx(Vector3(0.19 * sx, 0.18, 0.06), Vector3(0.04, 0.36, 0.34))
	d.cx(Vector3(0, 0.72, 0.365), Vector3(0.36, 0.22, 0.02), Vector3(0.21, 0, 0))
	d.aplicar(m, Mat.liso(Color(0.16, 0.16, 0.18), 0.55))
	# cinto afivelado
	var c := Malha.new()
	c.tubo([Vector3(-0.22, 0.47, 0.16), Vector3(-0.1, 0.545, 0.05), Vector3(0.1, 0.545, 0.05), Vector3(0.22, 0.47, 0.16)], [0.022, 0.022, 0.022, 0.022], 4, 1.0, 1.0)
	c.cx(Vector3(0, 0.56, 0.045), Vector3(0.07, 0.02, 0.055))
	c.aplicar(m, Mat.liso(Color(0.35, 0.35, 0.37), 0.35, 0.6))
	_polt = m
	return m


static func fileiras(pai: Node3D, n: int, z0: float, pular: Array = []) -> void:
	for i in n:
		for k in 4:
			if [i, k] in pular:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = poltrona()
			mi.position = Vector3([-0.98, -0.50, 0.50, 0.98][k], PISO, z0 + (i + 0.5) * BAIA)
			pai.add_child(mi)


## asa direita + motor (para ver pela janela / destroco)
static func asa(pai: Node3D, lado: float = 1.0) -> Dictionary:
	var m := Malha.new()
	var perfil := [[-0.95, 0.0], [-0.8, 0.10], [-0.3, 0.15], [0.3, 0.11], [0.95, 0.0], [0.3, -0.05], [-0.3, -0.08], [-0.8, -0.06]]
	var est := [[1.2, 1.0, 0.0], [4.0, 0.9, 0.10], [10.5, 0.48, 0.42]]
	for i in est.size() - 1:
		for k in perfil.size():
			var k2 := (k + 1) % perfil.size()
			var q := []
			for par in [[i, k], [i, k2], [i + 1, k2], [i + 1, k]]:
				var e: Array = est[par[0]]
				var pf: Array = perfil[par[1]]
				q.append(Vector3(e[0] * lado, e[2] + pf[1] * e[1], pf[0] * e[1] * 1.15))
			var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
			var cen: Vector3 = (q[0] + q[2]) * 0.5
			if n.dot(cen - Vector3(cen.x, est[i][2], 0)) < 0:
				n = -n
			var ini := m.v.size()
			for a in 4:
				m.vert(q[a], n, Vector2(q[a].x, q[a].z) * 0.5, Vector3.RIGHT)
			m.quad(ini, ini + 1, ini + 2, ini + 3)
			m.quad(ini, ini + 3, ini + 2, ini + 1)
	m.no(Mat.pbr("blue_metal_plate", 1.0, Color(0.72, 0.74, 0.77), 0.65, 0.3), pai)
	var g := Malha.new()
	var mx := 3.4 * lado
	g.tubo([Vector3(mx, 0.02, -2.35), Vector3(mx, 0.02, -2.2), Vector3(mx, 0.05, -1.5), Vector3(mx, 0.05, 0.2), Vector3(mx, 0.08, 1.3)], [0.14, 0.36, 0.46, 0.44, 0.16], 18, 0.6, 2.0, Color(0, 0, 0.5), true)
	g.no(Mat.pbr("blue_metal_plate", 1.0, Color(0.62, 0.64, 0.68), 0.6, 0.35), pai)
	var helice := Node3D.new()
	helice.position = Vector3(mx, 0.02, -2.42)
	pai.add_child(helice)
	var h := Malha.new()
	for k in 4:
		var tr := Transform3D(Basis(Vector3.BACK, TAU * k / 4), Vector3.ZERO)
		h.caixa(tr * Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 0.62, 0)), Vector3(0.14, 1.1, 0.02))
	h.tubo([Vector3(0, 0, -0.22), Vector3(0, 0, -0.05), Vector3(0, 0, 0.1)], [0.02, 0.15, 0.17], 12, 1, 1, Color(0, 0, 0.5), true)
	var hm := h.no(Mat.liso(Color(0.06, 0.06, 0.07), 0.4, 0.4), helice)
	return {"helice": helice, "motor": Vector3(mx, 0.1, -0.6), "ponta": Vector3(10.5 * lado, 0.44, 0)}


static func cockpit(pai: Node3D, z: float) -> void:
	# nariz arredondado
	var m := Malha.new()
	m.tubo([Vector3(0, 0, z), Vector3(0, -0.04, z - 0.9), Vector3(0, -0.14, z - 1.7), Vector3(0, -0.30, z - 2.4), Vector3(0, -0.40, z - 2.7)], [R, R * 0.96, R * 0.80, R * 0.48, 0.08], 22, 0.6, 3.0, Color(0, 0, 0.5), true)
	m.no(Mat.pbr("blue_metal_plate", 1.0, Color(0.76, 0.78, 0.80), 0.7, 0.35), pai)
	var v := Malha.new()
	for i in 4:
		var a := lerpf(0.75, PI - 0.75, (i + 0.5) / 4)
		v.cx(Vector3(cos(a) * 1.22, sin(a) * 1.15 - 0.06, z - 1.22), Vector3(0.50, 0.34, 0.06), Vector3(-0.62, 0, a - PI * 0.5))
	v.no(Mat.liso(Color(0.01, 0.012, 0.016), 0.08, 0.2), pai)
