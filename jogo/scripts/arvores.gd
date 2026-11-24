class_name Arvores
extends RefCounted
## Gera as arvores por codigo. Tipos:
## 0 carvalho | 1 carvalho torto | 2 tulipeiro alto | 3 carvalho com folha seca
## 4 tsuga (conifera) | 5 abeto vermelho | 6 arvore morta | 7 arvore jovem

const ALTURAS := [21.0, 18.0, 27.0, 19.0, 21.0, 24.0, 13.0, 7.0]

static func m_casca(tipo: int) -> Material:
	match tipo:
		0, 3: return Mat.casca("bark_brown_02", Color(0.78, 0.74, 0.70), 0.75)
		1: return Mat.casca("bark_willow_02", Color(0.62, 0.60, 0.57), 0.8)
		2: return Mat.casca("bark_willow_02", Color(0.80, 0.78, 0.74), 0.45)
		4: return Mat.casca("pine_bark", Color(0.62, 0.55, 0.50), 0.6)
		5: return Mat.casca("pine_bark", Color(0.72, 0.62, 0.56), 0.5)
		6: return Mat.casca("bark_willow_02", Color(0.85, 0.84, 0.82), 0.25, 0.2)
	return Mat.casca("bark_willow_02", Color(0.7, 0.68, 0.64), 0.2)


static func m_folha(tipo: int) -> Material:
	match tipo:
		3: return Mat.folha("fol_secas.png", Color(0.85, 0.75, 0.68), 0.55, 0.4)
		4: return Mat.folha("fol_conifera.png", Color(0.82, 0.92, 0.86), 0.35, 0.4, 0.7)
		5: return Mat.folha("fol_conifera.png", Color(0.72, 0.86, 0.86), 0.3, 0.4, 0.7)
	return Mat.folha("fol_galhos.png", Color(0.95, 0.92, 0.9), 0.1, 0.34, 0.9, 1.0, 0.22)


## devolve [ArrayMesh lod0, ArrayMesh lod1]
static func gerar(tipo: int) -> Array:
	return [_monta(tipo, 0), _monta(tipo, 1)]


static func _monta(tipo: int, lod: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + tipo * 37
	var tr := Malha.new()
	var fo := Malha.new()
	match tipo:
		0: _decidua(tr, fo, rng, lod, 21.0, 0.42, 0.36, 12, 0.10, false)
		1: _decidua(tr, fo, rng, lod, 18.0, 0.36, 0.28, 11, 0.24, false)
		2: _decidua(tr, fo, rng, lod, 27.0, 0.50, 0.52, 12, 0.05, false)
		3: _decidua(tr, fo, rng, lod, 19.0, 0.40, 0.34, 11, 0.12, true)
		4: _conifera(tr, fo, rng, lod, 21.0, 0.36, 0.19, 3.5, 0.9)
		5: _conifera(tr, fo, rng, lod, 24.0, 0.40, 0.28, 2.9, 0.55)
		6: _morta(tr, fo, rng, lod)
		7: _decidua(tr, fo, rng, lod, 7.0, 0.07, 0.25, 7, 0.12, false)
	var h: float = ALTURAS[tipo]
	tr.vento(h, 1.8)
	fo.vento(h, 1.8)
	var m := ArrayMesh.new()
	tr.aplicar(m, m_casca(tipo))
	fo.aplicar(m, m_folha(tipo))
	return m


static func _tronco(tr: Malha, rng: RandomNumberGenerator, h: float, r: float, torto: float, segs: int, lados: int, ponta: float, raiz: float) -> Array:
	var pts := []
	var ra := []
	var off := Vector3.ZERO
	var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * torto * 0.3
	for i in segs + 1:
		var f := float(i) / segs
		var fy := f
		if i == 1: fy = 0.018
		elif i == 2: fy = 0.05
		pts.append(Vector3(off.x, fy * h - (0.6 if i == 0 else 0.0), off.z))
		ra.append(lerpf(r, r * ponta, pow(fy, 0.8)) * (1.25 if i == 0 else (1.12 if i == 1 else 1.0)))
		dir += Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * torto
		dir *= 0.8
		off += dir * h / segs
	tr.tubo(pts, ra, lados, 0.5, maxf(1.0, roundf(r * 6.0)), Color(0, 0, 0.5, 1), false, raiz)
	return [pts, ra]


static func _em(pts: Array, ra: Array, f: float) -> Array:
	var y: float = lerpf(0.0, (pts[-1] as Vector3).y, f)
	for i in pts.size() - 1:
		if y <= pts[i + 1].y:
			var u := clampf((y - pts[i].y) / (pts[i + 1].y - pts[i].y), 0, 1)
			return [(pts[i] as Vector3).lerp(pts[i + 1], u), lerpf(ra[i], ra[i + 1], u)]
	return [pts[-1], ra[-1]]


static func _decidua(tr: Malha, fo: Malha, rng: RandomNumberGenerator, lod: int, h: float, r: float, ini: float, nl: int, torto: float, folhas: bool) -> void:
	var t := _tronco(tr, rng, h * 0.92, r, torto, 11 if lod == 0 else 6, 12 if lod == 0 else 6, 0.16, 0.55)
	var ang := rng.randf() * TAU
	for l in nl:
		var f := ini + (0.97 - ini) * (l + rng.randf() * 0.6) / nl
		ang += 2.4 + rng.randf_range(-0.4, 0.4)
		var e := _em(t[0], t[1], f)
		var o: Vector3 = e[0]
		var comp := h * lerpf(0.27, 0.10, (f - ini) / (1.0 - ini)) * rng.randf_range(0.75, 1.15)
		var sobe := lerpf(0.35, 1.2, (f - ini) / (1.0 - ini))
		var d := Vector3(cos(ang), sobe, sin(ang)).normalized()
		var pts := [o]
		var ra := [minf(e[1] * 0.62, r * 0.42)]
		var ns := 5 if lod == 0 else 3
		var p := o
		for s in ns:
			d = (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.25, 0.75), rng.randf_range(-1, 1)) * (0.20 + torto)).normalized()
			p += d * comp / ns
			pts.append(p)
			ra.append(lerpf(ra[0], 0.018, float(s + 1) / ns))
		tr.tubo(pts, ra, 6 if lod == 0 else 3, 0.6, 1.0)
		var nc := (8 if lod == 0 else 4) + (3 if folhas and lod == 0 else 0)
		if h < 8.0:
			nc = 3 if lod == 0 else 2
		for k in nc:
			var u := lerpf(0.25, 1.0, float(k) / maxf(1.0, nc - 1))
			var q := pts_em(pts, u)
			var dd := (d * 0.8 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.9), rng.randf_range(-1, 1))).normalized()
			var lado := dd.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
			var tam := h * rng.randf_range(0.085, 0.135) * (1.0 if lod == 0 else 1.35)
			if h < 8.0: tam *= 1.5
			fo.cartao(q - dd * tam * 0.04, dd, lado, tam, tam, Vector3(0, h * 0.6, 0), 0.6, 0.5)
	var topo: Vector3 = t[0][-1]
	for k in (6 if lod == 0 else 3):
		var dd := Vector3(rng.randf_range(-0.7, 0.7), 1, rng.randf_range(-0.7, 0.7)).normalized()
		var lado := dd.cross(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))).normalized()
		fo.cartao(topo - Vector3.UP * h * 0.04, dd, lado, h * 0.13, h * 0.13, Vector3(0, h * 0.6, 0), 0.6, 0.5)


static func pts_em(pts: Array, u: float) -> Vector3:
	var x := u * (pts.size() - 1)
	var i := mini(int(x), pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], x - i)


static func _conifera(tr: Malha, fo: Malha, rng: RandomNumberGenerator, lod: int, h: float, r: float, ini: float, larg: float, queda: float) -> void:
	var t := _tronco(tr, rng, h, r, 0.02, 9 if lod == 0 else 4, 10 if lod == 0 else 5, 0.06, 0.4)
	var y := h * ini
	var ang := 0.0
	# galhos secos embaixo
	if lod == 0:
		for k in 9:
			var e := _em(t[0], t[1], rng.randf_range(0.06, ini + 0.08))
			var a := rng.randf() * TAU
			var d := Vector3(cos(a), rng.randf_range(-0.25, 0.15), sin(a)).normalized()
			var cl := rng.randf_range(0.5, 1.7)
			tr.tubo([e[0], e[0] + d * cl * 0.6, e[0] + d * cl + Vector3.DOWN * 0.15], [0.03, 0.018, 0.006], 4, 1.0, 1.0)
	var passo := 0.52 if lod == 0 else 1.15
	while y < h * 0.985:
		var f := (y / h - ini) / (1.0 - ini)
		var comp := larg * pow(1.0 - f, 0.82) * (0.75 + 0.25 * minf(1.0, f * 8.0)) + 0.25
		var nb := (6 if f < 0.6 else 5) if lod == 0 else 4
		ang += 1.1
		for b in nb:
			var a := ang + TAU * b / nb + rng.randf_range(-0.22, 0.22)
			var cl := comp * rng.randf_range(0.78, 1.14)
			var incl := lerpf(-0.22, 0.55, f) + rng.randf_range(-0.12, 0.12)
			var d := Vector3(cos(a), incl, sin(a)).normalized()
			var lado := d.cross(Vector3.UP).normalized()
			lado = lado.rotated(d, rng.randf_range(-0.35, 0.35))
			var e := _em(t[0], t[1], clampf(y / h, 0, 1))
			var wl := cl * 0.56 * (1.0 if lod == 0 else 1.3)
			fo.cartao(e[0], d, lado, cl, wl, Vector3(0, y - 0.8, 0), 0.65, 0.6, Rect2(0, 0.07, 1, 0.86), true, cl * 0.16 * queda)
			if lod == 0 and f < 0.85 and b % 2 == 0:
				fo.cartao(e[0] + d * cl * 0.15, (d + Vector3.DOWN * 0.35).normalized(), lado.rotated(d, 1.1), cl * 0.72, wl * 0.8, Vector3(0, y - 0.8, 0), 0.65, 0.7, Rect2(0, 0.07, 1, 0.86), true, cl * 0.12)
		y += passo * rng.randf_range(0.85, 1.15)
	fo.cartao(Vector3(t[0][-1].x, h * 0.95, t[0][-1].z), Vector3.UP, Vector3.RIGHT, h * 0.07, h * 0.03, Vector3(0, h * 0.9, 0), 0.6, 0.6, Rect2(0, 0.07, 1, 0.86), true)


static func _morta(tr: Malha, fo: Malha, rng: RandomNumberGenerator, lod: int) -> void:
	var t := _tronco(tr, rng, 13.0, 0.32, 0.12, 9 if lod == 0 else 5, 9 if lod == 0 else 5, 0.35, 0.6)
	for k in (9 if lod == 0 else 6):
		var f := rng.randf_range(0.3, 0.97)
		var e := _em(t[0], t[1], f)
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), rng.randf_range(-0.1, 0.9), sin(a)).normalized()
		var p: Vector3 = e[0]
		var pts := [p]
		var cl := rng.randf_range(0.8, 3.2)
		for s in 3:
			d = (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.35).normalized()
			p += d * cl / 3.0
			pts.append(p)
		tr.tubo(pts, [0.09, 0.06, 0.035, 0.008], 5 if lod == 0 else 3, 0.8, 1.0)
		if cl > 1.8:
			var lado := d.cross(Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1))).normalized()
			fo.cartao(pts[2], d, lado, cl * 0.6, cl * 0.5, Vector3(0, 8, 0), 0.5, 0.3)
	# lasca no topo
	var topo: Vector3 = t[0][-1]
	for k in 4:
		tr.tubo([topo, topo + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.4, 1.0), rng.randf_range(-0.15, 0.15))], [0.07, 0.005], 4, 1.0, 1.0)


## Rododendro: o "inferno de louro" dos Apalaches
static func rododendro(semente: int, lod: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 50 + semente
	var tr := Malha.new()
	var fo := Malha.new()
	var ns := 8 if lod == 0 else 5
	for i in ns:
		var a := TAU * i / ns + rng.randf_range(-0.4, 0.4)
		var alcance := rng.randf_range(0.5, 1.35)
		var alt := rng.randf_range(1.3, 2.7)
		var p0 := Vector3(cos(a) * 0.15, -0.15, sin(a) * 0.15)
		var p1 := Vector3(cos(a) * alcance * 0.35, alt * 0.45, sin(a) * alcance * 0.35) + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		var p2 := Vector3(cos(a) * alcance, alt, sin(a) * alcance)
		tr.tubo([p0, p0.lerp(p1, 0.55) + Vector3(0.05, 0, 0.04), p1, p1.lerp(p2, 0.5) + Vector3(-0.05, 0.06, 0), p2], [0.05, 0.045, 0.036, 0.026, 0.012], 5 if lod == 0 else 3, 1.2, 1.0)
		for k in (7 if lod == 0 else 3):
			var u := rng.randf_range(0.35, 1.05)
			var q := p1.lerp(p2, u) + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.4))
			var nd := Vector3(rng.randf_range(-0.8, 0.8) + cos(a) * 0.6, rng.randf_range(0.35, 1.2), rng.randf_range(-0.8, 0.8) + sin(a) * 0.6).normalized()
			var d := nd.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
			var l := nd.cross(d).normalized()
			var tam := rng.randf_range(0.75, 1.15) * (1.0 if lod == 0 else 1.5)
			fo.cartao(q - d * tam * 0.5, d, l, tam, tam, Vector3(0, 0.6, 0), 0.6, 0.35)
	tr.vento(3.0, 1.5, 0.12)
	fo.vento(3.0, 1.5, 0.12)
	var m := ArrayMesh.new()
	tr.aplicar(m, Mat.casca("bark_willow_02", Color(0.55, 0.5, 0.46), 0.3))
	fo.aplicar(m, Mat.folha("fol_rododendro.png", Color(0.95, 1.0, 0.95), 0.4, 0.4, 0.42))
	return m


static func capim(semente: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var fo := Malha.new()
	for k in 4:
		var a := PI * k / 4 + rng.randf_range(-0.2, 0.2)
		var l := Vector3(cos(a), 0, sin(a))
		fo.cartao(Vector3(rng.randf_range(-0.1, 0.1), -0.03, rng.randf_range(-0.1, 0.1)), (Vector3.UP + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))).normalized(), l, rng.randf_range(0.35, 0.6), 0.55, Vector3(0, -0.6, 0), 0.85, 1.4)
	var m := ArrayMesh.new()
	fo.aplicar(m, Mat.folha("fol_capim.png", Color(0.8, 0.8, 0.72), 0.5, 0.4))
	return m
