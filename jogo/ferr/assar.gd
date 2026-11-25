extends Node
## "Assa" os dados pesados uma vez so. Rodar:
##   godot --path jogo res://ferr/assar.tscn -- mundo criatura humano impostor
## (sem argumento = tudo)

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		a = PackedStringArray(["mundo", "criatura", "poltrona", "vigia", "mochila", "mapa", "impostor", "icones"])
	for q in a:
		if q.contains("="): continue
		var t0 := Time.get_ticks_msec()
		match q:
			"mundo": _mundo()
			"criatura": _criatura()
			"poltrona": _poltrona()
			"vigia": _vigia()
			"impostor": await _impostor()
			"mochila": _mochila()
			"sonda":
				Mundo.dados = load("res://dados/mundo.res")
				for k in 26:
					var pp := Vector2(-131.0, -78.8).lerp(Vector2(-104.0, -95.4), k / 25.0)
					print("sonda %.1f,%.1f h=%.2f rio=%.2f d=%.1f" % [pp.x, pp.y, Mundo.altura(pp.x, pp.y), lerpf(Mundo.RIO[5][2], Mundo.RIO[6][2], 0.2), Mundo.dist(Mundo.RIO, pp.x, pp.y)])
			"mapa": _mapa()
			"icones": await _icones()
			"gente":
				var pasta := ""
				var so := PackedStringArray()
				for k in a:
					if k.begins_with("mh="): pasta = k.substr(3).uri_decode()
					if k.begins_with("so="): so = k.substr(3).split("+")
				GenteAssar.new().rodar(pasta, so)
		print("assado: ", q, " em ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	get_tree().quit()


func _ruido(sem: int, f: float, oct: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sem
	n.frequency = f
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = oct
	return n


func _interp(l: Array, r: Array) -> float:
	return lerpf(l[r[1]][2], l[r[1] + 1][2], r[2])


func _mundo() -> void:
	var rio := Mundo.suave(Mundo.RIO, 4)
	var est := Mundo.suave(Mundo.ESTRADA, 3)
	var rod := Mundo.suave(Mundo.RODOVIA, 2)
	var tri := []
	for q in Mundo.TRILHAS:
		tri.append(Mundo.suave(q, 2))
	var skid := [[-440, -350], [-357, -294.7]]
	var n1 := _ruido(7, 0.0052, 5)
	var n2 := _ruido(19, 0.028, 4)
	var n3 := _ruido(31, 0.13, 3)
	var N := Mundo.N
	var alt := PackedFloat32Array()
	alt.resize(N * N)
	var dr := PackedFloat32Array(); dr.resize(N * N)
	var de := PackedFloat32Array(); de.resize(N * N)
	var dh := PackedFloat32Array(); dh.resize(N * N)
	var dt := PackedFloat32Array(); dt.resize(N * N)
	var ds := PackedFloat32Array(); ds.resize(N * N)
	# alturas-alvo dos lugares (terreno base + rio) sao resolvidas antes
	var base := func(x: float, z: float) -> float:
		var b := 60.0 - 0.052 * (x + z)
		b += n1.get_noise_2d(x, z) * 30.0 + n2.get_noise_2d(x, z) * 3.4 + n3.get_noise_2d(x, z) * 0.35
		var dd := Vector2(x - 172, z + 62).length()
		b += 46.0 * exp(-dd * dd / (2.0 * 78.0 * 78.0))
		var borda := maxf(absf(x), absf(z))
		b += smoothstep(410.0, 512.0, borda) * 46.0
		return b
	for iz in N:
		var z := iz * Mundo.PASSO - 512.0
		for ix in N:
			var x := ix * Mundo.PASSO - 512.0
			var i := iz * N + ix
			var h: float = base.call(x, z)
			var r := Mundo.perto(rio, x, z)
			var d: float = r[0]
			dr[i] = d
			if d < 110.0:
				var hc := _interp(rio, r)
				var vale := hc + smoothstep(2.4, 7.0, d) * 1.5 + pow(d / 75.0, 1.5) * 15.0 + n2.get_noise_2d(x, z) * 1.6 * smoothstep(5.0, 20.0, d)
				h = lerpf(vale, h, smoothstep(38.0, 105.0, d))
			# trilha
			var td := 1e9
			for q in tri:
				td = minf(td, Mundo.dist(q, x, z))
			dt[i] = td
			# estrada de servico
			var e := Mundo.perto(est, x, z)
			de[i] = e[0]
			if e[0] < 22.0:
				h = lerpf(_interp(est, e), h, smoothstep(3.2, 22.0, e[0]))
			var k := Mundo.perto(rod, x, z)
			dh[i] = k[0]
			if k[0] < 46.0:
				h = lerpf(_interp(rod, k) - 0.06, h, smoothstep(7.5, 46.0, k[0]))
			# leito do rio por cima de tudo
			if d < 13.0:
				var hc2 := _interp(rio, r)
				var leito := hc2 - 0.45 + smoothstep(1.4, 4.0, d) * 1.0 + smoothstep(4.0, 13.0, d) * 1.6
				h = minf(h, lerpf(leito, h, smoothstep(7.0, 13.0, d)))
			ds[i] = Mundo.dist(skid, x, z)
			alt[i] = h
		if iz % 64 == 0:
			print("terreno ", iz, "/", N)
	# achata os lugares
	var locais := [[Mundo.VILA, 33.0, 68.0], [Mundo.CEMITERIO, 10.0, 22.0], [Mundo.TORRE, 15.0, 54.0], [Mundo.QUEDA, 7.0, 22.0]]
	for L in locais:
		var c: Vector2 = L[0]
		var s := 0.0
		var cnt := 0
		for iz in N:
			for ix in N:
				if Vector2(ix * 2.0 - 512.0 - c.x, iz * 2.0 - 512.0 - c.y).length() < L[1]:
					s += alt[iz * N + ix]
					cnt += 1
		s /= cnt
		if L[0] == Mundo.TORRE:
			s = 127.3
		for iz in N:
			for ix in N:
				var dd := Vector2(ix * 2.0 - 512.0 - c.x, iz * 2.0 - 512.0 - c.y).length()
				if dd < L[2]:
					var w := 1.0 - smoothstep(L[1], L[2], dd)
					w *= smoothstep(7.0, 26.0, dr[iz * N + ix])
					alt[iz * N + ix] = lerpf(alt[iz * N + ix], s, w)
	# trilhas com inclinacao suave
	for q in tri:
		var pf := []
		var passos := []
		for i in q.size() - 1:
			var a0 := Vector2(q[i][0], q[i][1])
			var b0 := Vector2(q[i + 1][0], q[i + 1][1])
			var nn := maxi(1, int(a0.distance_to(b0) / 4.0))
			for k in nn:
				var pp := a0.lerp(b0, float(k) / nn)
				passos.append([pp.x, pp.y])
		for pp in passos:
			pf.append(alt[clampi(roundi((pp[1] + 512.0) / 2.0), 0, N - 1) * N + clampi(roundi((pp[0] + 512.0) / 2.0), 0, N - 1)])
		var sv := []
		for i in pf.size():
			var s0 := 0.0
			var c0 := 0
			for k in range(maxi(0, i - 7), mini(pf.size(), i + 8)):
				s0 += pf[k]
				c0 += 1
			var pw := smoothstep(0.0, 4.0, float(mini(i, pf.size() - 1 - i)))
			sv.append(lerpf(pf[i], s0 / c0, pw))
		for iz in N:
			for ix in N:
				var gi := iz * N + ix
				if dt[gi] < 16.0 and dr[gi] > 6.0 and de[gi] > 5.0:
					var r2 := Mundo.perto(passos, ix * 2.0 - 512.0, iz * 2.0 - 512.0)
					if r2[0] < 16.0:
						alt[gi] = lerpf(lerpf(sv[r2[1]], sv[r2[1] + 1], r2[2]), alt[gi], smoothstep(1.8, 16.0, r2[0]))
	# vala da queda
	for i in N * N:
		if ds[i] < 9.0:
			alt[i] += -0.9 * (1.0 - smoothstep(1.5, 4.0, ds[i])) + 0.55 * smoothstep(2.5, 4.5, ds[i]) * (1.0 - smoothstep(4.5, 8.5, ds[i]))
	# splat: campos de distancia
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var x := ix * 2.0 - 512.0
			var z := iz * 2.0 - 512.0
			var tr := minf(dt[i], de[i] - 1.2)
			var qd := minf(ds[i], Vector2(x + 365, z + 300).length() - 6.0)
			img.set_pixel(ix, iz, Color(clampf(1.0 - tr / 6.0, 0, 1), clampf(1.0 - dr[i] / 12.0, 0, 1), clampf(1.0 - dh[i] / 16.0, 0, 1), clampf(1.0 - qd / 14.0, 0, 1)))
	ResourceSaver.save(img, "res://dados/splat.res", ResourceSaver.FLAG_COMPRESS)

	var dm := DadosMundo.new()
	dm.alt = alt
	Mundo.dados = dm
	var am := func(arr: PackedFloat32Array, x: float, z: float) -> float:
		return arr[clampi(roundi((z + 512.0) / 2.0), 0, N - 1) * N + clampi(roundi((x + 512.0) / 2.0), 0, N - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var nd := _ruido(71, 0.018, 3)
	var nt := _ruido(83, 0.011, 2)
	var sitios := [[Mundo.VILA, 37.0], [Mundo.CEMITERIO, 11.0], [Mundo.TORRE, 15.0], [Mundo.QUEDA, 9.5]]
	var livre := func(x: float, z: float, folga: float) -> bool:
		if am.call(dr, x, z) < 4.8 + folga * 2.0: return false
		if am.call(de, x, z) < 3.0 + folga: return false
		if am.call(dh, x, z) < 9.0 + folga: return false
		if am.call(dt, x, z) < 1.9 + folga: return false
		if am.call(ds, x, z) < 4.0 + folga * 0.5: return false
		for S in sitios:
			if Vector2(x - S[0].x, z - S[0].y).length() < S[1] + folga: return false
		return true
	var arv := PackedFloat32Array()
	var g := 3.9
	var ng := int(1020.0 / g)
	for a in ng:
		for b in ng:
			var x := -510.0 + (a + rng.randf_range(0.08, 0.92)) * g
			var z := -510.0 + (b + rng.randf_range(0.08, 0.92)) * g
			var den := nd.get_noise_2d(x, z)
			var p := 0.50 + den * 0.60
			var drio: float = am.call(dr, x, z)
			if rng.randf() > p or not livre.call(x, z, 0.0):
				continue
			var tp := 0
			var q := nt.get_noise_2d(x, z) + rng.randf_range(-0.35, 0.35)
			var u := rng.randf()
			if drio < 50.0 and drio > 9.0 and u < 0.26:
				tp = 4
			elif q > 0.06:
				tp = 5 if rng.randf() < 0.70 else 4
			elif q > -0.08:
				tp = 2
			elif q > -0.24:
				tp = 0
			elif q > -0.40:
				tp = 1
			else:
				tp = 4
			var w := rng.randf()
			if w < 0.045: tp = 6
			elif w < 0.20: tp = 7
			# mirante: a torre enxerga a cidade
			var vt := Vector2(x - Mundo.TORRE.x, z - Mundo.TORRE.y)
			if vt.length() < 40.0:
				if rng.randf() > 0.16: continue
				tp = 7 if rng.randf() < 0.7 else 6
			elif vt.length() < 150.0 and absf(vt.angle_to(Vector2(248, 452))) < 0.55:
				if rng.randf() > 0.45: continue
				tp = 7 if rng.randf() < 0.85 else 6
			var s := rng.randf_range(0.72, 1.18)
			if rng.randf() < 0.06 and tp < 6: s *= 1.35
			var y := Mundo.altura(x, z)
			arv.append_array(PackedFloat32Array([x, y - 0.12, z, rng.randf() * TAU, s, tp]))
	dm.arv = arv
	var rd := PackedFloat32Array()
	var ne := _ruido(101, 0.030, 3)
	ng = int(1000.0 / 2.6)
	for a in ng:
		for b in ng:
			var x := -500.0 + (a + rng.randf()) * 2.6
			var z := -500.0 + (b + rng.randf()) * 2.6
			var drio: float = am.call(dr, x, z)
			var p := (ne.get_noise_2d(x, z) - 0.24) * 2.2 + 0.12 * (1.0 - smoothstep(8.0, 32.0, drio))
			if rng.randf() > p or not livre.call(x, z, 0.9):
				continue
			rd.append_array(PackedFloat32Array([x, Mundo.altura(x, z) - 0.05, z, rng.randf() * TAU, rng.randf_range(0.7, 1.35)]))
	dm.rod = rd
	var pd := PackedFloat32Array()
	ng = int(1000.0 / 5.0)
	for a in ng:
		for b in ng:
			var x := -500.0 + (a + rng.randf()) * 5.0
			var z := -500.0 + (b + rng.randf()) * 5.0
			var drio: float = am.call(dr, x, z)
			var inc := 1.0 - Mundo.normal(x, z).y
			var prob := 0.10 + inc * 1.0
			if drio < 7.0: prob = 0.85
			if rng.randf() > prob: continue
			if am.call(de, x, z) < 3.4 or am.call(dh, x, z) < 10.0 or am.call(dt, x, z) < 1.6 or am.call(ds, x, z) < 4.0: continue
			var ok := true
			for S in sitios:
				if Vector2(x - S[0].x, z - S[0].y).length() < S[1]: ok = false
			if not ok: continue
			var tp := rng.randi_range(0, 4)
			if drio > 6.0 and rng.randf() < 0.34:
				tp = rng.randi_range(5, 9)
			var s := rng.randf_range(0.6, 1.5)
			if tp < 5 and rng.randf() < 0.12: s *= 1.9
			pd.append_array(PackedFloat32Array([x, Mundo.altura(x, z), z, rng.randf() * TAU, s, tp]))
	dm.ped = pd
	ResourceSaver.save(dm, "res://dados/mundo.res", ResourceSaver.FLAG_COMPRESS)
	print("arvores ", arv.size() / 6, " rododendros ", rd.size() / 5, " pedras ", pd.size() / 6)


# ---------------------------------------------------------------- criatura
func _criatura() -> void:
	var s := Sdf.new()
	s.k = 0.055
	var pele := Color(0.25, 0, 0, 1)
	var osso := Color(0, 1, 0, 1)
	var foc := Color(0.1, 0.25, 0, 1)
	var O := Criatura.OSSOS
	var B := {}
	for i in O.size():
		B[O[i][0]] = i
	var P := {}
	for q in O:
		P[q[0]] = q[2]
	# tronco magro
	s.cap(P.bacia, P.lombo, 0.165, 0.115, B.bacia, pele)
	s.cap(P.lombo, Vector3(0, 1.31, -0.18), 0.112, 0.165, B.lombo, pele)
	s.cap(Vector3(0, 1.29, -0.18), Vector3(0, 1.22, -0.50), 0.19, 0.175, B.peito, pele)
	s.cap(Vector3(0, 1.10, -0.28), Vector3(0, 1.07, -0.48), 0.13, 0.10, B.peito, pele)
	# vertebras saltadas
	for i in 9:
		var f := i / 8.0
		var p := Vector3(0, lerpf(1.40, 1.46, sin(f * PI)), lerpf(0.52, -0.5, f))
		s.cap(p, p + Vector3(0, 0.035, 0.02), 0.026, 0.012, B.bacia if f < 0.3 else (B.lombo if f < 0.6 else B.peito), pele)
	s.cap(P.pesc1, P.pesc2, 0.095, 0.072, B.pesc1, pele)
	s.cap(P.pesc2, P.cabeca, 0.070, 0.062, B.pesc2, pele)
	# cabeca: cranio comprido de cervo, olhos para a frente
	var h: Vector3 = P.cabeca
	s.cap(h + Vector3(0, 0.03, 0.02), h + Vector3(0, 0.02, -0.12), 0.098, 0.082, B.cabeca, pele)
	s.cap(h + Vector3(0, 0.0, -0.12), h + Vector3(0, -0.07, -0.42), 0.066, 0.042, B.cabeca, foc)
	s.cap(h + Vector3(0, -0.07, -0.40), h + Vector3(0, -0.085, -0.45), 0.046, 0.034, B.cabeca, foc)
	for sx in [-1.0, 1.0]:
		s.cap(h + Vector3(0.065 * sx, 0.055, -0.12), h + Vector3(0.05 * sx, 0.015, -0.22), 0.032, 0.02, B.cabeca, pele)
		# orelhas rasgadas
		s.cap(h + Vector3(0.085 * sx, 0.07, 0.02), h + Vector3(0.22 * sx, 0.09 + 0.03 * sx, 0.07), 0.030, 0.008, B.cabeca, pele)
	s.cap(h + Vector3(0, -0.075, -0.05), h + Vector3(0, -0.145, -0.38), 0.036, 0.020, B.mandib, foc)
	# dentes
	for i in 6:
		for sx in [-1.0, 1.0]:
			var z := -0.17 - i * 0.042
			s.cap(h + Vector3(0.030 * sx, -0.06 - i * 0.008, z), h + Vector3(0.030 * sx, -0.105 - i * 0.008, z), 0.008, 0.003, B.cabeca, osso)
	# galhada torta
	for sx in [-1.0, 1.0]:
		var qb := 1.0 if sx > 0 else 0.62
		var g0: Vector3 = h + Vector3(0.06 * sx, 0.11, 0.0)
		var g1: Vector3 = h + Vector3(0.20 * sx, 0.34, 0.08)
		var g2: Vector3 = h + Vector3(0.38 * sx, 0.56, 0.02)
		var g3: Vector3 = h + Vector3(0.44 * sx, 0.80, -0.14)
		s.cap(g0, g1, 0.026, 0.022, B.cabeca, osso)
		s.cap(g1, g2, 0.022, 0.018, B.cabeca, osso)
		if qb > 0.9:
			s.cap(g2, g3, 0.018, 0.006, B.cabeca, osso)
			s.cap(g2, g2 + Vector3(0.15, 0.10, -0.14), 0.016, 0.005, B.cabeca, osso)
		s.cap(g1, g1 + Vector3(-0.02 * sx, 0.20, -0.16), 0.018, 0.005, B.cabeca, osso)
		s.cap(g1.lerp(g2, 0.6), g1.lerp(g2, 0.6) + Vector3(0.02 * sx, 0.24, -0.08), 0.016, 0.005, B.cabeca, osso)
	# membros
	for sx in [-1.0, 1.0]:
		var l := "e" if sx < 0 else "d"
		var om: Vector3 = P["ombro_" + l]
		var co: Vector3 = P["cotov_" + l]
		var pu: Vector3 = P["punho_" + l]
		s.cap(om + Vector3(-0.03 * sx, 0.06, 0.02), om, 0.10, 0.085, B["ombro_" + l], pele)
		s.cap(om, co, 0.072, 0.044, B["ombro_" + l], pele)
		s.cap(co, pu, 0.044, 0.030, B["cotov_" + l], pele)
		# mao comprida
		s.cap(pu, pu + Vector3(0, -0.12, -0.02), 0.032, 0.030, B["punho_" + l], pele)
		for d in 4:
			var ox := (d - 1.5) * 0.026
			var m0 := pu + Vector3(ox, -0.12, -0.02)
			var m1 := pu + Vector3(ox * 2.0, -0.27, -0.06 - absf(d - 1.5) * 0.01)
			var m2 := pu + Vector3(ox * 2.2, -0.41, -0.03)
			s.cap(m0, m1, 0.015, 0.012, B["punho_" + l], pele)
			s.cap(m1, m2, 0.012, 0.004, B["punho_" + l], osso if d % 2 == 0 else pele)
		var qd: Vector3 = P["coxa_" + l]
		var jo: Vector3 = P["joelho_" + l]
		var ja: Vector3 = P["jarrete_" + l]
		s.cap(qd, jo, 0.115, 0.066, B["coxa_" + l], pele)
		s.cap(jo, ja, 0.060, 0.034, B["joelho_" + l], pele)
		s.cap(ja, ja + Vector3(0, -0.34, -0.10), 0.034, 0.026, B["jarrete_" + l], pele)
		s.cap(ja + Vector3(0, -0.34, -0.10), ja + Vector3(0, -0.42, -0.16), 0.040, 0.030, B["jarrete_" + l], osso)
	s.rugas = func(p: Vector3, d: float) -> float:
		if p.z < 0.0 and p.z > -0.55 and p.y > 0.95 and p.y < 1.42 and absf(p.x) > 0.04:
			d += 0.010 * sin(p.z * 62.0 + p.y * 14.0)
		return d + 0.004 * sin(p.x * 60.0) * sin(p.y * 55.0) * sin(p.z * 58.0)
	var d := s.gerar(AABB(Vector3(-0.66, -0.06, -1.62), Vector3(1.32, 3.06, 2.6)), 0.019, O)
	print("criatura vertices ", d.v.size())
	ResourceSaver.save(Sdf.malha(d), "res://dados/criatura.res", ResourceSaver.FLAG_COMPRESS)


# poltrona estofada (tecido)
func _poltrona() -> void:
	var s := Sdf.new()
	s.k = 0.035
	s.caixa(Vector3(0, 0.40, 0.0), Vector3(0.205, 0.065, 0.225), 0.045, -0.06)
	s.caixa(Vector3(0, 0.425, -0.17), Vector3(0.195, 0.05, 0.07), 0.04, -0.05)
	# encosto inclinado com abas
	s.caixa(Vector3(0, 0.72, 0.265), Vector3(0.200, 0.30, 0.050), 0.045, 0.20)
	for sx in [-1.0, 1.0]:
		s.caixa(Vector3(0.165 * sx, 0.70, 0.235), Vector3(0.045, 0.24, 0.045), 0.04, 0.20)
		s.caixa(Vector3(0.165 * sx, 0.445, -0.02), Vector3(0.04, 0.035, 0.19), 0.03, -0.05)
		s.caixa(Vector3(0.150 * sx, 1.02, 0.300), Vector3(0.05, 0.085, 0.05), 0.04, 0.20)
	s.caixa(Vector3(0, 0.60, 0.225), Vector3(0.14, 0.05, 0.03), 0.028, 0.20)
	s.caixa(Vector3(0, 1.02, 0.325), Vector3(0.165, 0.10, 0.045), 0.042, 0.20)
	var d := s.gerar(AABB(Vector3(-0.28, 0.26, -0.32), Vector3(0.56, 0.94, 0.80)), 0.0165)
	print("poltrona vertices ", d.v.size())
	ResourceSaver.save(Sdf.malha(d), "res://dados/poltrona.res", ResourceSaver.FLAG_COMPRESS)


# os dezoito: passageiros de pe, altos demais, boca aberta demais
func _vigia() -> void:
	var pele := Color(1, 0, 0)
	var cam := Color(0, 1, 0)
	var cal := Color(0, 0, 1)
	var cab := Color(0, 0, 0)
	for modo in [0, 1, 2]:
		var s := Sdf.new()
		s.k = 0.030
		if modo < 2:
			s.cap(Vector3(0, 1.10, 0), Vector3(0, 1.34, 0.01), 0.125, 0.105, 0, cam)
			s.cap(Vector3(0, 1.34, 0.01), Vector3(0, 1.62, 0.0), 0.11, 0.14, 0, cam)
			s.cap(Vector3(-0.17, 1.69, 0.0), Vector3(0.17, 1.69, 0.0), 0.065, 0.065, 0, cam)
			# gola, pescoco comprido e cabeca caida de lado
			s.cap(Vector3(-0.07, 1.735, -0.01), Vector3(0.07, 1.735, -0.01), 0.055, 0.055, 0, cam)
			s.cap(Vector3(0, 1.70, 0), Vector3(0.02, 1.95, -0.035), 0.043, 0.037, 0, pele)
			s.cap(Vector3(0.048, 2.115, -0.035), Vector3(0.042, 2.06, -0.065), 0.088, 0.070, 0, pele)
			# queixo deslocado: boca aberta demais
			s.cap(Vector3(0.030, 1.965, -0.085), Vector3(0.018, 1.885, -0.085), 0.046, 0.036, 0, pele)
			s.cap(Vector3(0.018, 1.885, -0.085), Vector3(0.015, 1.868, -0.10), 0.034, 0.026, 0, pele)
			# nariz, orbitas fundas e cabelo
			s.cap(Vector3(0.045, 2.065, -0.135), Vector3(0.040, 2.035, -0.148), 0.013, 0.015, 0, pele)
			for ex in [-1.0, 1.0]:
				s.cap(Vector3(0.045 + 0.034 * ex, 2.078, -0.126), Vector3(0.045 + 0.036 * ex, 2.070, -0.122), 0.016, 0.015, 0, cab)
				s.cap(Vector3(0.05 + 0.080 * ex, 2.13, 0.0), Vector3(0.04 + 0.086 * ex, 2.00, 0.005), 0.040, 0.026, 0, cab)
			s.cap(Vector3(0.05, 2.165, -0.02), Vector3(0.05, 2.08, 0.04), 0.080, 0.075, 0, cab)
			s.cap(Vector3(0.0, 2.175, -0.075), Vector3(0.09, 2.18, -0.07), 0.035, 0.035, 0, cab)
			s.cap(Vector3(0.05, 2.06, 0.05), Vector3(0.04, 1.92, 0.045), 0.055, 0.030, 0, cab)
			# paleto: barra e lapelas
			s.cap(Vector3(-0.10, 1.12, 0), Vector3(0.10, 1.12, 0), 0.135, 0.135, 0, cam)
			s.cap(Vector3(-0.05, 1.66, -0.11), Vector3(-0.02, 1.40, -0.125), 0.022, 0.016, 0, cam)
			s.cap(Vector3(0.05, 1.66, -0.11), Vector3(0.02, 1.40, -0.125), 0.022, 0.016, 0, cam)
			for sx in [-1.0, 1.0]:
				if modo == 1 and sx > 0: continue
				s.cap(Vector3(0.21 * sx, 1.66, 0), Vector3(0.26 * sx, 1.28, 0.02), 0.052, 0.040, 0, cam)
				s.cap(Vector3(0.26 * sx, 1.28, 0.02), Vector3(0.25 * sx, 0.88, -0.04), 0.038, 0.026, 0, cam)
				s.cap(Vector3(0.25 * sx, 0.88, -0.04), Vector3(0.25 * sx, 0.78, -0.05), 0.028, 0.026, 0, pele)
				for dd in 4:
					var ox := (dd - 1.5) * 0.018
					s.cap(Vector3(0.25 * sx + ox, 0.77, -0.05), Vector3(0.245 * sx + ox * 1.6, 0.56, -0.07), 0.011, 0.005, 0, pele)
				s.cap(Vector3(0.085 * sx, 1.10, 0), Vector3(0.10 * sx, 0.58, -0.02), 0.088, 0.055, 0, cal)
				s.cap(Vector3(0.10 * sx, 0.58, -0.02), Vector3(0.10 * sx, 0.08, 0.02), 0.053, 0.038, 0, cal)
				s.cap(Vector3(0.10 * sx, 0.045, 0.02), Vector3(0.11 * sx, 0.03, -0.13), 0.042, 0.032, 0, cab)
			if modo == 1:
				s.cap(Vector3(0.085, 1.10, 0), Vector3(0.10, 0.58, -0.02), 0.088, 0.055, 0, cal)
				s.cap(Vector3(0.10, 0.58, -0.02), Vector3(0.10, 0.08, 0.02), 0.053, 0.038, 0, cal)
				s.cap(Vector3(0.10, 0.045, 0.02), Vector3(0.11, 0.03, -0.13), 0.042, 0.032, 0, cab)
				s.cap(Vector3(0.21, 1.66, 0), Vector3(0.24, 1.60, 0), 0.052, 0.045, 0, cam)
		else:
			# braco solto (origem no ombro), erguido
			s.cap(Vector3.ZERO, Vector3(0.16, 0.34, 0.0), 0.05, 0.038, 0, cam)
			s.cap(Vector3(0.16, 0.34, 0.0), Vector3(0.10, 0.74, -0.03), 0.037, 0.026, 0, cam)
			s.cap(Vector3(0.10, 0.74, -0.03), Vector3(0.09, 0.84, -0.03), 0.028, 0.026, 0, pele)
			for dd in 4:
				var ox := (dd - 1.5) * 0.02
				s.cap(Vector3(0.09 + ox, 0.85, -0.03), Vector3(0.085 + ox * 2.2, 1.06, -0.02), 0.011, 0.005, 0, pele)
		var d := s.gerar(AABB(Vector3(-0.42, -0.06, -0.28), Vector3(0.84, 2.40, 0.5)), 0.0150)
		print("vigia ", modo, " vertices ", d.v.size())
		ResourceSaver.save(Sdf.malha(d), "res://dados/vigia%d.res" % modo, ResourceSaver.FLAG_COMPRESS)


# ---------------------------------------------------------------- fotos das arvores distantes
func _impostor() -> void:
	var tam := Vector2i(256, 512)
	var atlas := Image.create(tam.x * 8, tam.y, false, Image.FORMAT_RGBA8)
	for tp in 8:
		var sv := SubViewport.new()
		sv.size = tam * 2
		sv.transparent_bg = true
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.ambient_light_energy = 0.85
		we.environment = env
		sv.add_child(we)
		var mi := MeshInstance3D.new()
		mi.mesh = Arvores.gerar(tp)[0]
		sv.add_child(mi)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var H: float = Arvores.ALTURAS[tp] * 1.06
		cam.size = H
		cam.position = Vector3(0, H * 0.5 - 0.3, 40)
		cam.far = 100
		sv.add_child(cam)
		cam.current = true
		for k in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := sv.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(tam.x, tam.y, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(im, Rect2i(Vector2i.ZERO, tam), Vector2i(tp * tam.x, 0))
		sv.queue_free()
	atlas.fix_alpha_edges()
	atlas.save_png("res://tex/impostores.png")


func _mochila() -> void:
	var s := Sdf.new()
	s.k = 0.03
	var c := Color(0, 1, 0)
	s.caixa(Vector3(0, 0.19, 0), Vector3(0.145, 0.185, 0.085), 0.05, 0.0, 0, c)
	s.caixa(Vector3(0, 0.375, -0.005), Vector3(0.140, 0.055, 0.095), 0.045, 0.08, 0, c)
	s.caixa(Vector3(0, 0.135, -0.105), Vector3(0.105, 0.085, 0.045), 0.03, 0.0, 0, c)
	for sx in [-1.0, 1.0]:
		s.caixa(Vector3(0.155 * sx, 0.14, 0), Vector3(0.03, 0.085, 0.055), 0.025, 0.0, 0, c)
	s.cap(Vector3(-0.15, 0.475, 0.02), Vector3(0.15, 0.475, 0.02), 0.045, 0.045, 0, c)
	var d := s.gerar(AABB(Vector3(-0.24, -0.04, -0.2), Vector3(0.48, 0.6, 0.36)), 0.0085)
	ResourceSaver.save(Sdf.malha(d), "res://dados/mochila.res", ResourceSaver.FLAG_COMPRESS)


## mapa topografico impresso: relevo sombreado, curvas de nivel, rio, trilhas
func _mapa() -> void:
	Mundo.dados = load("res://dados/mundo.res")
	var N := 1024
	var im := Image.create(N, N, false, Image.FORMAT_RGB8)
	var ru := _ruido(5, 0.02, 4)
	var rf := _ruido(9, 0.3, 2)
	for y in N:
		for x in N:
			var wx := x - 512.0 + 0.5
			var wz := y - 512.0 + 0.5
			var h := Mundo.altura(wx, wz)
			var n := Mundo.normal(wx, wz)
			var som := clampf(0.5 + (-n.x * 0.5 - n.z * 0.5) * 1.6, 0.0, 1.0)
			var c := Color(0.80, 0.75, 0.60).lerp(Color(0.60, 0.66, 0.50), 0.45 + 0.3 * ru.get_noise_2d(x, y))
			c = c.lerp(Color(0.86, 0.83, 0.74), clampf((h - 70.0) / 60.0, 0.0, 0.8))
			c = c.darkened((1.0 - som) * 0.35)
			var g := Vector2(Mundo.altura(wx + 1, wz) - h, Mundo.altura(wx, wz + 1) - h).length()
			var f: float = fposmod(h, 5.0)
			var dist: float = minf(f, 5.0 - f) / maxf(g, 0.02)
			var forte: bool = int(roundf(h / 5.0)) % 5 == 0
			if dist < (1.0 if forte else 0.6): c = c.lerp(Color(0.42, 0.28, 0.14), 0.7 if forte else 0.42)
			var dr := Mundo.dist(Mundo.RIO, wx, wz)
			if dr < 3.4: c = Color(0.24, 0.42, 0.58)
			var de := Mundo.dist(Mundo.ESTRADA, wx, wz)
			if de < 2.2: c = Color(0.55, 0.32, 0.18) if de > 1.2 else Color(0.88, 0.80, 0.62)
			for q in Mundo.TRILHAS:
				var pt := Mundo.perto(q, wx, wz)
				if pt[0] < 1.3 and int((wx + wz * 1.7) / 5.0) % 2 == 0: c = Color(0.32, 0.10, 0.06)
			c = c.lerp(Color(0.5, 0.42, 0.28), 0.10 + 0.10 * rf.get_noise_2d(x, y))
			# dobras do papel
			for dd in [256, 512, 768]:
				var k := minf(absf(x - dd), absf(y - dd))
				if k < 3.0: c = c.darkened(0.16 * (1.0 - k / 3.0))
			im.set_pixel(x, y, c)
	im.save_png("res://tex/mapa.png")


func _icones() -> void:
	for id in Itens.ORDEM:
		var sv := SubViewport.new()
		sv.size = Vector2i(384, 384)
		sv.transparent_bg = true
		sv.own_world_3d = true
		sv.msaa_3d = Viewport.MSAA_8X
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.75, 0.85)
		env.ambient_light_energy = 0.45
		we.environment = env
		sv.add_child(we)
		var l := DirectionalLight3D.new()
		l.light_energy = 1.7
		l.light_color = Color(1.0, 0.93, 0.82)
		l.rotation = Vector3(-0.8, 0.7, 0)
		sv.add_child(l)
		var l2 := DirectionalLight3D.new()
		l2.light_energy = 0.6
		l2.light_color = Color(0.6, 0.75, 1.0)
		l2.rotation = Vector3(-0.2, -2.2, 0)
		sv.add_child(l2)
		var r := Node3D.new()
		sv.add_child(r)
		Itens.modelo(r, id)
		r.rotation.y = {"rifle": PI * 0.5 + 0.25, "gasolina": 0.6, "mochila": PI + 0.5, "jaqueta": PI + 0.25, "lanche": 0.5, "municao": 0.4}.get(id, 0.25)
		var bb := AABB()
		var pri := true
		for m in r.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb()
			bb = b if pri else bb.merge(b)
			pri = false
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		sv.add_child(cam)
		var dir := Vector3(0, 0.45, 1.0).normalized()
		if id == "rifle": dir = Vector3(0, 0.08, 1.0).normalized()
		cam.size = maxf(bb.size.length() * (0.86 if id != "rifle" else 0.98), 0.05)
		cam.position = bb.get_center() + dir * 5.0
		cam.look_at(bb.get_center())
		if id == "rifle": r.rotation.z = 0.0
		cam.far = 12
		cam.current = true
		for k in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := sv.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		# enquadra
		var ub := im.get_used_rect()
		var lado := int(maxi(ub.size.x, ub.size.y) * 1.08)
		var q := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		q.blit_rect(im, ub, (Vector2i(lado, lado) - ub.size) / 2)
		q.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		q.save_png("res://tex/ic_%s.png" % id)
		sv.queue_free()
