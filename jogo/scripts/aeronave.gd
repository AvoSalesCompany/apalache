class_name Aeronave
extends RefCounted
## Bimotor regional de 19 lugares (1+2, janelas ovais grandes, sem bagageiro no teto),
## no estilo dos turboelices dos anos 80. Usado no voo e nos destrocos.

const R := 1.22
const RI := 1.13
const BAIA := 0.80
const PISO := -0.72
const BANCOS := [-0.68, 0.23, 0.70]
# setores do lado direito, de baixo para cima; o setor 3 e o da janela
const ANG := [-90.0, -62.0, -38.0, -14.0, 40.0, 65.0, 90.0]
const JZ := 0.150          # meia largura da janela
const JS := 0.215          # meia altura (arco)


static func _p(r: float, ang: float, z: float, lado: float) -> Vector3:
	return Vector3(cos(ang) * r * lado, sin(ang) * r, z)


static func m_casco(queimado: float = 0.0, faixa: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fuselagem.gdshader")
	m.set_shader_parameter("nor", Mat.tex("blue_metal_plate_nor.jpg"))
	m.set_shader_parameter("queimado", queimado)
	m.set_shader_parameter("faixa", faixa)
	return m


static func m_forro(cor: Color, sujo: float = 0.35, emenda: float = 1.0, tecido: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/forro.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("sujo", sujo)
	m.set_shader_parameter("emenda", emenda)
	m.set_shader_parameter("tecido", tecido)
	return m


static func m_vidro(forca: float = 1.0, rachado: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vidro.gdshader")
	m.set_shader_parameter("forca", forca)
	m.set_shader_parameter("rachado", rachado)
	return m


static func _quad(m: Malha, a: int, b: int, c: int, d: int, quer: Vector3) -> void:
	var f := (m.v[c] - m.v[a]).cross(m.v[b] - m.v[a])
	if f.length_squared() < 1e-12:
		f = (m.v[d] - m.v[a]).cross(m.v[c] - m.v[a])
	if f.dot(quer) >= 0.0:
		m.quad(a, b, c, d)
	else:
		m.quad(a, d, c, b)


## anel de pontos do oval da janela
static func _thetas() -> Array:
	var t := []
	for i in 44:
		t.append(TAU * i / 44.0)
	var hs := deg_to_rad(27.0) * RI
	for q in [atan2(hs, 0.40), PI - atan2(hs, 0.40), PI + atan2(hs, 0.40), TAU - atan2(hs, 0.40)]:
		t.append(q)
	t.sort()
	return t


static func _oval(th: float, e: float) -> Vector2:
	var c := cos(th)
	var s := sin(th)
	return Vector2(JZ * signf(c) * pow(absf(c), 0.78), JS * signf(s) * pow(absf(s), 0.78)) * e


static func _borda(th: float) -> Vector2:
	var hs := deg_to_rad(27.0) * RI
	var c := cos(th)
	var s := sin(th)
	var k := 1.0 / maxf(absf(c) / 0.40, absf(s) / hs)
	return Vector2(c, s) * k


static func _painel(m: Malha, r: float, a0: float, a1: float, z0: float, z1: float, lado: float, dentro: bool) -> void:
	var n := maxi(1, int(round(rad_to_deg(a1 - a0) / 6.0)))
	for k in n:
		var b0 := lerpf(a0, a1, float(k) / n)
		var b1 := lerpf(a0, a1, float(k + 1) / n)
		var i := m.v.size()
		for q in [[b0, z0], [b1, z0], [b1, z1], [b0, z1]]:
			var no := Vector3(cos(q[0]) * lado, sin(q[0]), 0)
			m.vert(_p(r, q[0], q[1], lado), -no if dentro else no, Vector2(q[0] * r, q[1]), Vector3(-sin(q[0]) * lado, cos(q[0]), 0))
		var cen := Vector3(cos((b0 + b1) * 0.5) * lado, sin((b0 + b1) * 0.5), 0)
		_quad(m, i, i + 1, i + 2, i + 3, -cen if dentro else cen)


static func _painel_janela(m: Malha, r: float, zb: float, lado: float, dentro: bool, esc: float) -> void:
	var th := _thetas()
	var ac := deg_to_rad(13.0)
	var an := 5
	var ini := m.v.size()
	var nt := th.size()
	for j in an + 1:
		var f := pow(float(j) / an, 0.85)
		for k in nt:
			var p := _borda(th[k]).lerp(_oval(th[k], esc), f)
			var a := ac + p.y / RI
			var no := Vector3(cos(a) * lado, sin(a), 0)
			m.vert(_p(r, a, zb + 0.40 + p.x, lado), -no if dentro else no, Vector2(a * r, zb + 0.40 + p.x), Vector3(-sin(a) * lado, cos(a), 0))
	var cen := Vector3(cos(ac) * lado, sin(ac), 0)
	for j in an:
		for k in nt:
			var k2 := (k + 1) % nt
			_quad(m, ini + j * nt + k, ini + j * nt + k2, ini + (j + 1) * nt + k2, ini + (j + 1) * nt + k, -cen if dentro else cen)


## aneis: [[escala, raio], ...] -> moldura torneada em volta da janela
static func _moldura(m: Malha, aneis: Array, zb: float, lado: float, dentro: bool) -> void:
	var ac := deg_to_rad(13.0)
	var n := 44
	var vi := m.v.size()
	var ii := m.idx.size()
	for q in aneis:
		for k in n:
			var p := _oval(TAU * k / n, q[0])
			var a := ac + p.y / RI
			m.vert(_p(q[1], a, zb + 0.40 + p.x, lado), Vector3.UP, Vector2(a, p.x), Vector3(0, 0, 1))
	var eixo := Vector3(cos(ac) * lado, sin(ac), 0)
	for j in aneis.size() - 1:
		for k in n:
			var k2 := (k + 1) % n
			var a := vi + j * n + k
			var b := vi + j * n + k2
			var c := vi + (j + 1) * n + k2
			var d := vi + (j + 1) * n + k
			var meio := (m.v[a] + m.v[c]) * 0.5
			var cen := _p(aneis[j][1], ac, zb + 0.40, lado)
			var quer := (cen - meio).normalized() * 0.6 + (-eixo if dentro else eixo)
			_quad(m, a, b, c, d, quer)
	m.suaviza(vi, ii)


static func _vidro(m: Malha, r: float, zb: float, lado: float, esc: float) -> void:
	var ac := deg_to_rad(13.0)
	var n := 40
	var no := Vector3(-cos(ac) * lado, -sin(ac), 0)
	var c := m.vert(_p(r, ac, zb + 0.40, lado), no, Vector2(0.5, 0.5), Vector3(0, 0, 1))
	for k in n + 1:
		var p := _oval(TAU * k / n, esc)
		var a := ac + p.y / RI
		m.vert(_p(r, a, zb + 0.40 + p.x, lado), no, Vector2(0.5 + cos(TAU * k / n) * 0.5, 0.5 + sin(TAU * k / n) * 0.5), Vector3(0, 0, 1))
	for k in n:
		m.tri(c, c + 1 + k, c + 2 + k)


## cortina de plastico abaixada (frac 0..1)
static func _persiana(m: Malha, zb: float, lado: float, frac: float) -> void:
	var ac := deg_to_rad(13.0)
	var r := RI + 0.040
	var topo := JS * 0.98
	var n := 10
	var i0 := m.v.size()
	for k in n + 1:
		var s := lerpf(topo, topo - 2.0 * JS * frac, float(k) / n)
		var a := ac + s / RI
		var no := Vector3(-cos(a) * lado, -sin(a), 0)
		for sz in [-1.0, 1.0]:
			m.vert(_p(r, a, zb + 0.40 + JZ * 1.0 * sz, lado), no, Vector2(a * r, zb + 0.4 + JZ * sz), Vector3(0, 0, 1))
	for k in n:
		_quad(m, i0 + k * 2, i0 + k * 2 + 1, i0 + k * 2 + 3, i0 + k * 2 + 2, Vector3(-cos(ac) * lado, 0, 0))
	var af := ac + (topo - 2.0 * JS * frac) / RI
	m.cx(_p(r - 0.008, af, zb + 0.40, lado), Vector3(0.016, 0.016, JZ * 1.5))


## casco de z0 ate z0+baias*0.8 (eixo Z, nariz em -Z). furo(baia, setor 0..11) -> true remove
static func casco(pai: Node3D, baias: int, z0: float, furo: Callable = Callable(), queimado: float = 0.0, persianas: bool = false, rachado: float = 0.0) -> void:
	var fora := Malha.new()
	var dentro := Malha.new()
	var rodape := Malha.new()
	var mold := Malha.new()
	var borr := Malha.new()
	var mext := Malha.new()
	var vid := Malha.new()
	var per := Malha.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19 + baias
	for b in baias:
		var zb := z0 + b * BAIA
		for lado in [1.0, -1.0]:
			for s in 6:
				var id: int = s if lado > 0.0 else 6 + s
				if furo.is_valid() and furo.call(b, id):
					continue
				var a0 := deg_to_rad(ANG[s])
				var a1 := deg_to_rad(ANG[s + 1])
				if s == 3:
					_painel_janela(fora, R, zb, lado, false, 1.04)
					_painel_janela(dentro, RI, zb, lado, true, 1.10)
					_moldura(mold, [[1.20, RI + 0.002], [1.15, RI - 0.013], [1.05, RI - 0.015], [0.99, RI - 0.004], [0.955, RI + 0.022], [0.945, RI + 0.046]], zb, lado, true)
					_moldura(borr, [[0.950, RI + 0.044], [0.915, RI + 0.043], [0.905, RI + 0.058]], zb, lado, true)
					_moldura(mext, [[1.12, R + 0.001], [1.08, R + 0.007], [0.98, R + 0.006], [0.95, R - 0.020]], zb, lado, false)
					if not (furo.is_valid() and rng.randf() < 0.45):
						_vidro(vid, RI + 0.055, zb, lado, 0.93)
					if persianas and not (b == 3 and lado > 0.0):
						var f: float = [0.0, 0.0, 0.28, 0.0, 0.55, 0.0, 1.0][(b * 3 + (2 if lado > 0 else 5)) % 7]
						if f > 0.0:
							_persiana(per, zb, lado, f)
				else:
					_painel(fora, R, a0, a1, zb, zb + BAIA, lado, false)
					_painel(rodape if s <= 2 else dentro, RI, a0, a1, zb, zb + BAIA, lado, true)
	fora.no(m_casco(queimado), pai).name = "Casco"
	dentro.no(m_forro(Color(0.50, 0.475, 0.42), 0.35 + queimado * 0.5), pai).name = "Forro"
	rodape.no(m_forro(Color(0.12, 0.13, 0.17), 0.3, 1.0, 1.0), pai)
	mold.no(m_forro(Color(0.46, 0.44, 0.39), 0.4, 0.0), pai)
	borr.no(Mat.liso(Color(0.018, 0.018, 0.02), 0.85), pai)
	mext.no(Mat.liso(Color(0.38, 0.39, 0.40), 0.32, 0.7), pai)
	if vid.v.size() > 0:
		var nv := vid.no(m_vidro(1.0 if queimado < 0.1 else 0.0, rachado), pai, false)
		nv.name = "Vidros"
		nv.add_to_group("sem_col")
	if per.v.size() > 0:
		per.no(m_forro(Color(0.52, 0.50, 0.45), 0.5, 0.0), pai)


## cavernas e longarinas (o esqueleto que aparece onde o casco rasgou)
static func esqueleto(pai: Node3D, baias: int, z0: float) -> void:
	var m := Malha.new()
	for b in baias * 2 + 1:
		var z := z0 + b * BAIA * 0.5
		var pts := []
		var rs := []
		for k in 29:
			var a := TAU * k / 28.0
			pts.append(Vector3(cos(a) * (R - 0.035), sin(a) * (R - 0.035), z))
			rs.append(0.017)
		m.tubo(pts, rs, 4, 2.0, 1.0)
	for k in 14:
		var a := TAU * k / 14.0
		if absf(fposmod(a + 0.1, PI) - 0.33) < 0.25: continue
		m.tubo([Vector3(cos(a) * (R - 0.02), sin(a) * (R - 0.02), z0), Vector3(cos(a) * (R - 0.02), sin(a) * (R - 0.02), z0 + baias * BAIA)], [0.012, 0.012], 4)
	m.no(Mat.liso(Color(0.30, 0.33, 0.26), 0.5, 0.55), pai).add_to_group("sem_col")


## beirada rasgada: lascas de chapa, espuma e fios
static func rasgo(pai: Node3D, z: float, sentido: float, semente: int, faltam: Callable = Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var ch := Malha.new()
	var es := Malha.new()
	var fi := Malha.new()
	var n := 46
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.04, 0.04)
		if faltam.is_valid() and faltam.call(a): continue
		var da := TAU / n * rng.randf_range(0.5, 0.9)
		var l := rng.randf_range(0.08, 0.55)
		var dob := rng.randf_range(-0.35, 0.40)
		var i := ch.v.size()
		var rr := R + dob * l
		var ponta := Vector3(cos(a + rng.randf_range(-da, da)) * rr, sin(a) * rr, z + sentido * l)
		var no := Vector3(cos(a), sin(a), 0)
		ch.vert(Vector3(cos(a - da) * R, sin(a - da) * R, z), no, Vector2(a * R, 0), Vector3(0, 0, 1))
		ch.vert(Vector3(cos(a + da) * R, sin(a + da) * R, z), no, Vector2(a * R + 0.1, 0), Vector3(0, 0, 1))
		ch.vert(ponta, no, Vector2(a * R, l), Vector3(0, 0, 1))
		ch.tri(i, i + 1, i + 2)
		if rng.randf() < 0.45:
			var p0 := Vector3(cos(a) * (RI + 0.04), sin(a) * (RI + 0.04), z)
			es.tubo([p0, p0 + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.22, 0.02), sentido * l * 0.8)], [0.05, 0.025], 6, 1, 1, Color(0, 0, 0.5), true)
		if rng.randf() < 0.30:
			var p0 := Vector3(cos(a) * (RI + 0.02), sin(a) * (RI + 0.02), z - sentido * 0.1)
			var p1 := p0 + Vector3(rng.randf_range(-0.2, 0.2), -rng.randf_range(0.2, 0.9), sentido * rng.randf_range(0.1, 0.5))
			fi.tubo([p0, p0.lerp(p1, 0.35) + Vector3(0, -0.05, sentido * 0.12), p1], [0.007, 0.007, 0.006], 4)
	ch.no(m_casco(0.8, 0.0), pai).add_to_group("sem_col")
	es.no(Mat.liso(Color(0.42, 0.34, 0.16), 0.95), pai).add_to_group("sem_col")
	fi.no(Mat.liso(Color(0.20, 0.03, 0.02), 0.5), pai).add_to_group("sem_col")


static func piso(pai: Node3D, comp: float, z0: float) -> void:
	var m := Malha.new()
	m.cx(Vector3(0, PISO - 0.04, z0 + comp * 0.5), Vector3(1.78, 0.08, comp), Vector3.ZERO, 1.1)
	m.no(Mat.pbr("dirty_carpet", 1.0, Color(0.20, 0.21, 0.27)), pai)
	var c := Malha.new()
	c.cx(Vector3(-0.22, PISO + 0.003, z0 + comp * 0.5), Vector3(0.40, 0.006, comp), Vector3.ZERO, 1.3)
	c.no(Mat.pbr("dirty_carpet", 1.0, Color(0.30, 0.20, 0.16)), pai).add_to_group("sem_col")
	var t := Malha.new()
	for x in [-0.45, 0.01, 0.44]:
		t.cx(Vector3(x, PISO + 0.006, z0 + comp * 0.5), Vector3(0.028, 0.012, comp))
	t.no(Mat.liso(Color(0.36, 0.36, 0.37), 0.38, 0.85), pai).add_to_group("sem_col")


## trilho de servico no teto: luz de leitura, saida de ar, aviso de cinto
static func servico(pai: Node3D, fileiras_: int, z0: float) -> Dictionary:
	var tr := Malha.new()
	var pc := Malha.new()
	var av := Malha.new()
	var avisos := []
	var lampadas := []
	var comp := fileiras_ * BAIA
	for lado in [1.0, -1.0]:
		var a := deg_to_rad(58.0)
		var c := _p(RI - 0.045, a, z0 + comp * 0.5, lado)
		tr.caixa(Transform3D(Basis(Vector3.BACK, (a - PI * 0.5) * lado), c), Vector3(0.30, 0.055, comp), 1.0)
		# calha de luz indireta
		var l := _p(RI - 0.06, deg_to_rad(74.0), z0 + comp * 0.5, lado)
		pc.caixa(Transform3D(Basis(Vector3.BACK, (deg_to_rad(74.0) - PI * 0.5) * lado), l), Vector3(0.10, 0.035, comp), 1.0)
		for f in fileiras_:
			var z := z0 + (f + 0.5) * BAIA
			var bs := Basis(Vector3.BACK, (a - PI * 0.5) * lado)
			var o := _p(RI - 0.074, a, z, lado)
			for dx in ([-0.07, 0.07] if lado > 0.0 else [0.0]):
				var p: Vector3 = o + bs.x * dx + Vector3(0, 0, 0.12)
				av.tubo([p, p - bs.y * 0.022], [0.026, 0.021], 12, 1, 1, Color(0, 0, 0.5), true)
				av.tubo([p - bs.y * 0.022, p - bs.y * 0.034], [0.012, 0.010], 10, 1, 1, Color(0, 0, 0.5), true)
				var q: Vector3 = o + bs.x * dx + Vector3(0, 0, -0.10)
				av.tubo([q, q - bs.y * 0.014], [0.030, 0.026], 12, 1, 1, Color(0, 0, 0.5), true)
				var lm := MeshInstance3D.new()
				var cy := CylinderMesh.new()
				cy.top_radius = 0.018
				cy.bottom_radius = 0.018
				cy.height = 0.004
				lm.mesh = cy
				lm.transform = Transform3D(bs, q - bs.y * 0.016)
				lm.material_override = Mat.liso(Color(0.05, 0.05, 0.05), 0.4, 0, Color(1.0, 0.86, 0.62), 0.02).duplicate()
				lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				lm.add_to_group("sem_col")
				pai.add_child(lm)
				lampadas.append([lm, q])
			var aq := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.12, 0.05)
			aq.mesh = qm
			aq.transform = Transform3D(bs * Basis(Vector3.RIGHT, PI * 0.5), o - bs.y * 0.003 + Vector3(0, 0, 0.02))
			aq.material_override = Mat.placa("placa_cinto.png", 0.0).duplicate()
			aq.add_to_group("sem_col")
			pai.add_child(aq)
			avisos.append(aq)
	tr.no(m_forro(Color(0.44, 0.42, 0.37), 0.3), pai)
	var lz := pc.no(Mat.liso(Color(0.5, 0.48, 0.42), 0.5, 0, Color(1.0, 0.84, 0.60), 0.9).duplicate(), pai, false)
	av.no(Mat.liso(Color(0.10, 0.10, 0.105), 0.4, 0.3), pai).add_to_group("sem_col")
	return {"avisos": avisos, "lampadas": lampadas, "calha": lz}


static var _polt: ArrayMesh
## partes rigidas da poltrona (o estofado vem de dados/poltrona.res)
static func _ferragem() -> ArrayMesh:
	if _polt:
		return _polt
	var m := ArrayMesh.new()
	var d := Malha.new()
	d.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 0.76, 0.345)), Vector3(0.40, 0.62, 0.03))
	d.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 0.47, 0.285)), Vector3(0.38, 0.10, 0.05))
	d.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 0.83, 0.372)), Vector3(0.36, 0.23, 0.016))
	d.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 0.965, 0.395)), Vector3(0.05, 0.022, 0.016))
	d.aplicar(m, m_forro(Color(0.20, 0.20, 0.21), 0.3, 0.0))
	var b := Malha.new()
	for sx in [-1.0, 1.0]:
		b.tubo([Vector3(0.235 * sx, 0.585, 0.19), Vector3(0.235 * sx, 0.60, 0.06), Vector3(0.235 * sx, 0.60, -0.14), Vector3(0.235 * sx, 0.585, -0.19)], [0.018, 0.026, 0.026, 0.016], 10, 1, 1, Color(0, 0, 0.5), true)
		b.caixa(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.235 * sx, 0.48, 0.16)), Vector3(0.030, 0.24, 0.05))
	b.aplicar(m, Mat.liso(Color(0.030, 0.030, 0.034), 0.55))
	var p := Malha.new()
	for sx in [-1.0, 1.0]:
		p.tubo([Vector3(0.17 * sx, 0.34, 0.16), Vector3(0.17 * sx, 0.0, 0.22)], [0.017, 0.017], 8)
		p.tubo([Vector3(0.17 * sx, 0.34, -0.14), Vector3(0.17 * sx, 0.0, -0.10)], [0.017, 0.017], 8)
		p.tubo([Vector3(0.17 * sx, 0.02, 0.24), Vector3(0.17 * sx, 0.02, -0.14)], [0.015, 0.015], 8)
	p.tubo([Vector3(-0.2, 0.33, -0.14), Vector3(0.2, 0.33, -0.14)], [0.016, 0.016], 8)
	p.tubo([Vector3(-0.2, 0.33, 0.16), Vector3(0.2, 0.33, 0.16)], [0.016, 0.016], 8)
	p.aplicar(m, Mat.liso(Color(0.42, 0.42, 0.43), 0.3, 0.9))
	var s := Malha.new()
	s.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 0.60, 0.350)), Vector3(0.34, 0.20, 0.022))
	s.aplicar(m, m_forro(Color(0.07, 0.08, 0.11), 0.2, 0.0, 1.0))
	var rv := Malha.new()
	rv.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(-0.04, 0.675, 0.352)), Vector3(0.19, 0.16, 0.006))
	rv.aplicar(m, Mat.liso(Color(0.42, 0.36, 0.26), 0.6))
	var h := Malha.new()
	h.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 1.045, 0.268)), Vector3(0.25, 0.17, 0.010))
	h.caixa(Transform3D(Basis(Vector3.RIGHT, 0.20), Vector3(0, 1.130, 0.335)), Vector3(0.25, 0.014, 0.11))
	h.aplicar(m, m_forro(Color(0.58, 0.57, 0.53), 0.35, 0.0, 0.6))
	var c := Malha.new()
	c.tubo([Vector3(-0.22, 0.47, 0.13), Vector3(-0.13, 0.515, 0.02), Vector3(0.0, 0.525, -0.01), Vector3(0.13, 0.515, 0.02), Vector3(0.22, 0.47, 0.13)], [0.020, 0.020, 0.020, 0.020, 0.020], 4)
	c.aplicar(m, m_forro(Color(0.09, 0.10, 0.13), 0.2, 0.0, 1.0))
	var fv := Malha.new()
	fv.caixa(Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.545, -0.015)), Vector3(0.065, 0.014, 0.05))
	fv.aplicar(m, Mat.liso(Color(0.55, 0.55, 0.56), 0.22, 0.95))
	_polt = m
	return m


static var _tec: StandardMaterial3D
static func m_tecido() -> StandardMaterial3D:
	if _tec:
		return _tec
	_tec = Mat.pbr("fabric_pattern_07", 1.0, Color(0.17, 0.22, 0.36)).duplicate()
	_tec.uv1_triplanar = true
	_tec.uv1_scale = Vector3(2.6, 2.6, 2.6)
	_tec.roughness = 1.0
	_tec.metallic_specular = 0.15
	return _tec


## poltrona completa: origem no piso, olhando para -Z
static func poltrona_no(pai: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	pai.add_child(n)
	n.position = pos
	n.rotation = rot
	var a := MeshInstance3D.new()
	a.mesh = load("res://dados/poltrona.res")
	a.material_override = m_tecido()
	n.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = _ferragem()
	n.add_child(b)
	return n


static func fileiras(pai: Node3D, n: int, z0: float, pular: Array = []) -> void:
	for i in n:
		for k in 3:
			if [i, k] in pular:
				continue
			poltrona_no(pai, Vector3(BANCOS[k], PISO, z0 + (i + 0.5) * BAIA))


## asa + motor
static func asa(pai: Node3D, lado: float = 1.0, quebrada: bool = false) -> Dictionary:
	var m := Malha.new()
	var pf := []
	for k in 22:
		var t := TAU * k / 22.0
		var x := cos(t)
		var esp := 0.135 * sqrt(maxf(0.0, (1.0 - x) * 0.5)) * (1.0 + x) * 0.9 + 0.004
		pf.append(Vector2(x, esp * (1.0 if sin(t) >= 0.0 else -0.62)))
	var est := []
	for i in 9:
		var f := i / 8.0
		est.append([lerpf(1.0, 9.2, f), lerpf(1.02, 0.52, f), lerpf(-0.42, 0.10, f), lerpf(0.0, 0.22, f)])
	for i in est.size() - 1:
		for k in pf.size():
			var k2 := (k + 1) % pf.size()
			var ini := m.v.size()
			for par in [[i, k], [i, k2], [i + 1, k2], [i + 1, k]]:
				var e: Array = est[par[0]]
				var q: Vector2 = pf[par[1]]
				var t2: float = TAU * par[1] / pf.size()
				var no := Vector3(0, sin(t2) + 0.15, cos(t2) * 0.35).normalized()
				m.vert(Vector3(e[0] * lado, e[2] + q.y * e[1], q.x * e[1] + e[3]), no, Vector2(e[0], q.x * e[1]), Vector3(lado, 0, 0))
			var tm := TAU * (k + 0.5) / pf.size()
			_quad(m, ini, ini + 1, ini + 2, ini + 3, Vector3(0, sin(tm) + 0.02, cos(tm) * 0.3))
	m.no(m_casco(0.75 if quebrada else 0.0, 0.0), pai)
	# motor
	var mx := 2.7 * lado
	var cy := -0.26
	var g := Malha.new()
	g.tubo([Vector3(mx, cy, -2.02), Vector3(mx, cy, -1.95), Vector3(mx, cy, -1.7), Vector3(mx, cy, -1.1), Vector3(mx, cy, -0.3), Vector3(mx, cy + 0.02, 0.5), Vector3(mx, cy + 0.05, 1.15), Vector3(mx, cy + 0.07, 1.5)], [0.20, 0.27, 0.36, 0.42, 0.42, 0.36, 0.20, 0.05], 26, 1.0, 2.6, Color(0, 0, 0.5), true)
	g.no(m_casco(0.85 if quebrada else 0.12, 0.0), pai)
	var e2 := Malha.new()
	for sx in [-1.0, 1.0]:
		e2.tubo([Vector3(mx + 0.36 * sx, cy - 0.04, -0.75), Vector3(mx + 0.47 * sx, cy - 0.03, -0.60), Vector3(mx + 0.50 * sx, cy - 0.02, -0.40)], [0.07, 0.075, 0.07], 12)
	e2.tubo([Vector3(mx, cy - 0.33, -1.78), Vector3(mx, cy - 0.34, -1.4)], [0.13, 0.10], 14)
	e2.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.32, 0.26, 0.22), 0.8, 0.6), pai)
	var helice := Node3D.new()
	helice.position = Vector3(mx, cy, -2.10)
	pai.add_child(helice)
	var h := Malha.new()
	for k in 4:
		var ra := TAU * k / 4
		for s in 7:
			var f := s / 7.0
			var y0 := 0.16 + f * 1.02
			var dobra: float = (f * f * 0.5 if quebrada and k != 1 else 0.0)
			var tr := Transform3D(Basis(Vector3.BACK, ra), Vector3.ZERO) * Transform3D(Basis(Vector3.RIGHT, dobra) * Basis(Vector3.UP, lerpf(0.95, 0.32, f)), Vector3(0, y0 * cos(dobra), y0 * sin(dobra) * 0.6))
			h.caixa(tr, Vector3(lerpf(0.15, 0.11, f) * (0.6 if s == 6 else 1.0), 0.17, 0.018))
	h.no(Mat.liso(Color(0.045, 0.045, 0.05), 0.38, 0.4), helice)
	var sp := Malha.new()
	sp.tubo([Vector3(0, 0, -0.30), Vector3(0, 0, -0.24), Vector3(0, 0, -0.10), Vector3(0, 0, 0.10)], [0.02, 0.10, 0.17, 0.20], 18, 1, 1, Color(0, 0, 0.5), true)
	sp.no(Mat.liso(Color(0.45, 0.45, 0.46), 0.22, 0.9), helice)
	return {"helice": helice, "motor": Vector3(mx, cy + 0.15, -0.7), "ponta": Vector3(9.2 * lado, 0.12, 0.22)}


static func disco_helice(pai: Node3D, pos: Vector3) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.5, 2.5)
	d.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.2, 0.9, 0.97, 1.0])
	gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.3, 0.33, 0.4, 0.05), Color(0.35, 0.38, 0.46, 0.12), Color(0.5, 0.45, 0.25, 0.2), Color(0, 0, 0, 0)])
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = g
	d.material_override = m
	d.position = pos
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(d)
	return d


static func _nariz(dz: float) -> Vector2:
	var pr := [[0.0, 0.0, 1.22], [-0.5, -0.01, 1.205], [-0.9, -0.04, 1.13], [-1.3, -0.09, 1.00], [-1.7, -0.17, 0.82], [-2.1, -0.26, 0.60], [-2.45, -0.34, 0.37], [-2.7, -0.39, 0.16], [-2.78, -0.40, 0.02]]
	for i in pr.size() - 1:
		if dz <= pr[i][0] and dz >= pr[i + 1][0]:
			var u: float = (dz - pr[i][0]) / (pr[i + 1][0] - pr[i][0])
			u = u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65
			return Vector2(lerpf(pr[i][1], pr[i + 1][1], u), lerpf(pr[i][2], pr[i + 1][2], u))
	return Vector2(-0.40, 0.02)


static func cockpit(pai: Node3D, z: float, queimado: float = 0.0, amasso: float = 0.0) -> void:
	var m := Malha.new()
	var nr := 24
	var na := 36
	for i in nr + 1:
		var dz := -2.78 * i / nr
		var q := _nariz(dz)
		for k in na + 1:
			var a := TAU * k / na
			var am := amasso * (0.5 + 0.5 * sin(a * 3.0 + dz * 5.0)) * 0.16 * clampf(-dz, 0, 1) * (1.0 if sin(a) < 0.35 else 0.25)
			var rr := maxf(0.02, q.y - am)
			m.vert(Vector3(cos(a) * rr, sin(a) * rr + q.x, z + dz + amasso * 0.10 * sin(a * 2.0) * -dz), Vector3(cos(a), sin(a), -0.3).normalized(), Vector2(a * R, z + dz), Vector3(-sin(a), cos(a), 0))
	for i in nr:
		for k in na:
			var a := i * (na + 1) + k
			_quad(m, a, a + 1, a + na + 2, a + na + 1, m.n[a])
	m.no(m_casco(queimado), pai)
	var v := Malha.new()
	var fr := Malha.new()
	var pain := [[28.0, 62.0], [64.0, 89.0], [91.0, 116.0], [118.0, 152.0]]
	for pn in pain:
		var i0 := v.v.size()
		for i in 5:
			var dz := lerpf(-0.78, -1.30, i / 4.0)
			var q := _nariz(dz)
			for k in 7:
				var a := deg_to_rad(lerpf(pn[0], pn[1], k / 6.0))
				v.vert(Vector3(cos(a) * (q.y + 0.010), sin(a) * (q.y + 0.010) + q.x, z + dz), Vector3(cos(a), sin(a), -0.5).normalized(), Vector2(k / 6.0, i / 4.0), Vector3(-sin(a), cos(a), 0))
		for i in 4:
			for k in 6:
				var a := i0 + i * 7 + k
				_quad(v, a, a + 1, a + 8, a + 7, v.n[a])
		for e in [pn[0], pn[1]]:
			var pts := []
			for i in 5:
				var dz := lerpf(-0.78, -1.30, i / 4.0)
				var q := _nariz(dz)
				var a := deg_to_rad(e)
				pts.append(Vector3(cos(a) * (q.y + 0.012), sin(a) * (q.y + 0.012) + q.x, z + dz))
			fr.tubo(pts, [0.018, 0.018, 0.018, 0.018, 0.018], 6)
		for dz in [-0.78, -1.30]:
			var q := _nariz(dz)
			var pts := []
			for k in 7:
				var a := deg_to_rad(lerpf(pn[0], pn[1], k / 6.0))
				pts.append(Vector3(cos(a) * (q.y + 0.012), sin(a) * (q.y + 0.012) + q.x, z + dz))
			fr.tubo(pts, [0.018, 0.018, 0.018, 0.018, 0.018, 0.018, 0.018], 6)
	v.no(Mat.liso(Color(0.008, 0.010, 0.013), 0.06, 0.1), pai)
	fr.no(Mat.liso(Color(0.25, 0.26, 0.27), 0.4, 0.5), pai)
