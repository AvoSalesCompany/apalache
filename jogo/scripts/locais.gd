class_name Locais
extends Node3D
## Lugares feitos a mao: queda, passarela, cemiterio, torre. (A vila fica em vila.gd)

var fl: Floresta
var it := {}                 # id -> Interativo
var nos := {}                # id -> Node3D
var fogos := []
var portao: Node3D
var portao_col: StaticBody3D
var cabine_torre := Vector3.ZERO
var luzes_torre: Array = []
var viaturas: Array = []
var mortos: Array = []
const H_TORRE := 15.0


func construir(f: Floresta, passo: Callable) -> void:
	fl = f
	_queda()
	await passo.call("Espalhando os destrocos", 0.78)
	await _mortos(passo)
	_passarela()
	_cemiterio()
	_torre()
	_base_torre()
	for i in 2: viaturas.append(_viatura())
	colidir(self)
	await passo.call("Erguendo a torre", 0.86)


## tudo que e solido ganha colisao com o formato real da malha
func colidir(no: Node) -> void:
	for f in no.get_children():
		if String(f.name).begins_with("Forro") or f is RigidBody3D or f is StaticBody3D or f is Interativo or f.is_in_group("sem_col") or f == portao or f is Gente or f in viaturas:
			continue
		if f is MeshInstance3D and f.mesh and not (f.mesh is QuadMesh) and not (f.mesh is SphereMesh):
			var bb: AABB = f.mesh.get_aabb()
			var tam: Vector3 = bb.size * f.global_transform.basis.get_scale()
			if maxf(tam.x, maxf(tam.y, tam.z)) > 0.22 and tam.y > 0.03:
				var tris := 0
				for s in f.mesh.get_surface_count():
					if f.mesh is ArrayMesh:
						tris += maxi(f.mesh.surface_get_array_index_len(s), 3) / 3
				var forma: Shape3D = f.mesh.create_trimesh_shape() if tris < 14000 else f.mesh.create_convex_shape(true, true)
				if forma:
					var sb := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					cs.shape = forma
					sb.add_child(cs)
					f.add_child(sb)
		colidir(f)


func ocupado(x: float, z: float) -> bool:
	for q in [[Mundo.TORRE, 9.0], [Mundo.QUEDA, 4.0], [Mundo.CEMITERIO, 3.0]]:
		if absf(x - q[0].x) < q[1] and absf(z - q[0].y) < q[1]:
			return true
	return Vector2(x, z).distance_to(Mundo.VILA) < 32.0


func grupo(p: Vector3, rot: float = 0.0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = p
	n.rotation.y = rot
	return n


func corpo(pai: Node3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	pai.add_child(b)
	return b


func bx(b: StaticBody3D, pos: Vector3, tam: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tam
	c.shape = s
	c.position = pos
	c.rotation = rot
	b.add_child(c)


func prop(pai: Node3D, id: String, pos: Vector3, ry: float = 0.0, alvo: float = 0.0, eixo: String = "y", extra: Vector3 = Vector3.ZERO) -> Node3D:
	var m := Mat.modelo(id)
	pai.add_child(m)
	var bb := AABB()
	var pri := true
	for q in Mat.malhas_de(id):
		var b: AABB = (q[1] as Transform3D) * (q[0] as Mesh).get_aabb()
		bb = b if pri else bb.merge(b)
		pri = false
	var e := 1.0
	if alvo > 0.0:
		e = alvo / (bb.size.y if eixo == "y" else maxf(bb.size.x, bb.size.z))
	m.scale = Vector3.ONE * e
	m.rotation = Vector3(extra.x, ry, extra.z)
	m.position = pos - Vector3(0, bb.position.y * e, 0) if extra == Vector3.ZERO else pos
	return m


# =================================================================== QUEDA
func _queda() -> void:
	var c := Mundo.chaov(Mundo.QUEDA)
	var dir := atan2(-(72.0), -(48.0))      # vale da queda: noroeste -> sudeste
	# fuselagem principal (8 fileiras) tombada
	var g := grupo(c + Vector3(0, 0.72, 0), dir)
	g.rotation.z = 0.12
	# acompanha a encosta e assenta o piso logo acima do chao
	var bz := Vector3(sin(dir), 0, cos(dir))
	var hf := Mundo.altura(c.x - bz.x * 3.2, c.z - bz.z * 3.2)
	var ht := Mundo.altura(c.x + bz.x * 3.2, c.z + bz.z * 3.2)
	g.rotation.x = clampf(atan2(hf - ht, 6.4), -0.16, 0.16)
	var falta := -9.0
	for iz in 15:
		for ix in 5:
			var lp := Vector3(-0.8 + ix * 0.4, Aeronave.PISO - 0.10, -3.5 + iz * 0.5)
			var w := g.to_global(lp)
			falta = maxf(falta, Mundo.altura(w.x, w.z) - w.y)
	g.position.y += falta + 0.03
	nos["fuselagem"] = g
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var falhas := {}
	for b in 9:
		for s in 12:
			var pr := 0.05
			if b >= 7: pr = 0.16
			if b >= 8: pr = 0.40
			falhas[b * 100 + s] = rng.randf() < pr and not (s in [0, 6])
	# rombo lateral por onde se entra (lado direito)
	for b in [3, 4, 5]:
		for s in [1, 2, 3, 4]:
			falhas[b * 100 + s] = not (b == 5 and s == 4)
	var fr := func(b, s): return falhas.get(b * 100 + s, false)
	Aeronave.casco(g, 9, -3.6, fr, 0.75, false, 1.0)
	var antes := g.get_child_count()
	Aeronave.esqueleto(g, 9, -3.6)
	for k in range(antes, g.get_child_count()): g.get_child(k).add_to_group("sem_col")
	Aeronave.rasgo(g, 3.6, 1.0, 5)
	Aeronave.rasgo(g, 3.4, 1.0, 11)
	Aeronave.piso(g, 7.2, -3.6)
	Aeronave.fileiras(g, 8, -3.2, [[3, 1], [3, 2], [4, 2], [4, 1], [4, 0], [0, 0], [1, 0], [2, 0], [3, 0], [5, 0], [6, 0], [7, 1], [7, 2], [5, 2]])
	Aeronave.cockpit(g, -3.6, 0.85, 1.0)
	var cb := corpo(g)
	bx(cb, Vector3(0, Aeronave.PISO - 0.1, 0), Vector3(1.8, 0.2, 7.2))
	bx(cb, Vector3(0, 0, -3.7), Vector3(2.2, 2.2, 0.2))
	# chapa arrancada que virou rampa para entrar pelo rombo
	var rp0 := Vector3(0.72, Aeronave.PISO + 0.01, 0.0)
	var wr := g.to_global(Vector3(3.1, 0, 0))
	var rp1 := g.to_local(Vector3(wr.x, Mundo.altura(wr.x, wr.z) - 0.04, wr.z))
	rp1.z = 0.0
	var rd := rp1 - rp0
	var ra := atan2(rd.y, rd.x)
	bx(cb, (rp0 + rp1) * 0.5 - Vector3(0, 0.10, 0), Vector3(rd.length() + 0.2, 0.20, 1.7), Vector3(0, 0, ra))
	var rm := Malha.new()
	rm.cx((rp0 + rp1) * 0.5, Vector3(rd.length() + 0.1, 0.03, 1.5), Vector3(0.02, 0, ra))
	for k in 4: rm.cx(rp0.lerp(rp1, (k + 0.5) / 4.0) - Vector3(0, 0.04, 0), Vector3(0.05, 0.06, 1.5), Vector3(0, 0, ra))
	rm.no(Mat.pbrn("blue_metal_plate", 1.0, Color(0.62, 0.64, 0.66), 0.8, 0.3, 0.35), g).add_to_group("sem_col")
	# mascaras penduradas
	for k in 10:
		var m := Malha.new()
		var p := Vector3(rng.randf_range(-0.5, 0.5), 0.80, -2.6 + k * 0.55)
		var q := p + Vector3(rng.randf_range(-0.15, 0.05), -rng.randf_range(0.4, 0.75), rng.randf_range(-0.1, 0.1))
		m.tubo([p, p.lerp(q, 0.5) + Vector3(0.04, 0, 0.03), q], [0.006, 0.006, 0.006], 4)
		m.tubo([q, q + Vector3(0, -0.07, 0)], [0.03, 0.045], 8)
		m.no(Mat.liso(Color(0.75, 0.58, 0.10), 0.6, 0, Color.BLACK, 0, true), g)
	# cauda, 26 m atras
	var dv := Vector2(-72, -48).normalized()
	var pc := Mundo.chaov(Mundo.QUEDA + dv * 27.0 + Vector2(dv.y, -dv.x) * 3.0)
	var t := grupo(pc + Vector3(0, 0.9, 0), dir + 0.6)
	t.rotation.z = -0.5
	t.rotation.x = 0.12
	Aeronave.casco(t, 4, -1.2, func(b, s): return b == 0 and s in [3, 4, 5, 9], 0.8, false, 1.0)
	Aeronave.esqueleto(t, 4, -1.2)
	Aeronave.rasgo(t, -1.2, -1.0, 21)
	Aeronave.rasgo(t, -1.0, -1.0, 22)
	Aeronave.piso(t, 2.6, -0.8)
	var ct := Malha.new()
	ct.tubo([Vector3(0, 0, 2.0), Vector3(0, 0.03, 2.8), Vector3(0, 0.15, 3.8), Vector3(0, 0.33, 4.9), Vector3(0, 0.45, 5.6)], [1.22, 1.12, 0.82, 0.42, 0.12], 30, 1.0, 7.6, Color(0, 0, 0.5), true)
	ct.no(Aeronave.m_casco(0.7, 0.6), t)
	var ep := Malha.new()
	for q in 9:
		var f := q / 8.0
		ep.cx(Vector3(0, 0.55 + f * 2.6, 4.35 + f * 1.05), Vector3(0.15 - f * 0.07, 0.36, 1.75 - f * 0.75))
	for sx in [-1.0, 1.0]:
		for q in 8:
			var f := q / 7.0
			if sx > 0 and q > 4: continue
			ep.cx(Vector3((0.15 + f * 2.1) * sx, 3.02 + 0.02 * q, 5.2 + f * 0.25), Vector3(0.34, 0.11 - f * 0.05, 0.95 - f * 0.35))
	ep.no(Aeronave.m_casco(0.45, 0.0), t)
	var tb := corpo(t)
	bx(tb, Vector3(0, 0, 4.6), Vector3(1.0, 1.0, 2.0))
	# asa arrancada
	var pa := Mundo.chaov(Mundo.QUEDA + dv * 11.0 + Vector2(dv.y, -dv.x) * -9.0)
	var a := grupo(pa + Vector3(0, 1.0, 0), dir + 1.15)
	a.rotation.z = 0.34
	var asa_q := Aeronave.asa(a, 1.0, true)
	var ab := corpo(a)
	bx(ab, Vector3(5.0, -0.15, 0.1), Vector3(8, 0.2, 1.4), Vector3(0, 0, 0.06))
	# fogo: motor + chao + cauda
	fogos.append(Fx.fogo(self, a.to_global(Vector3(2.7, 0.15, -0.6)), 1.35, 6.5, 26.0))
	fogos.append(Fx.fogo(self, Mundo.chaov(Mundo.QUEDA + Vector2(6.5, 4.0)) + Vector3.UP * 0.1, 0.6, 2.6, 12.0, false))
	fogos.append(Fx.fogo(self, Mundo.chaov(Mundo.QUEDA + dv * 22.0) + Vector3.UP * 0.1, 0.8, 3.0, 14.0, false))
	Fx.fumaca(self, c + Vector3(0, 2.2, 0), 1.4, 20)
	# troncos quebrados ao longo da vala
	var mq := Malha.new()
	for i in 16:
		var f := rng.randf_range(4, 62)
		var lado := (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(3.6, 6.5)
		var p := Mundo.chaov(Mundo.QUEDA + dv * f + Vector2(dv.y, -dv.x) * lado)
		var alt := rng.randf_range(1.0, 4.5)
		var r := rng.randf_range(0.18, 0.40)
		var inc := Vector3(rng.randf_range(-0.2, 0.2) - dv.x * 0.2, 1, rng.randf_range(-0.2, 0.2) - dv.y * 0.2).normalized()
		mq.tubo([p - inc * 0.4, p + inc * 0.3, p + inc * alt], [r * 1.25, r, r * 0.9], 9, 0.5, 2.0, Color(0, 0, 0.5), true, 0.4)
		for k in 5:
			var an := TAU * k / 5
			var o := p + inc * (alt - 0.1) + Vector3(cos(an), 0, sin(an)) * r * 0.6
			mq.tubo([o, o + inc * rng.randf_range(0.3, 0.9) + Vector3(cos(an), 0, sin(an)) * 0.08], [r * 0.28, 0.01], 5, 1.0, 1.0)
		if rng.randf() < 0.55:
			var d2 := Vector3(-dv.x + rng.randf_range(-0.5, 0.5), 0.05, -dv.y + rng.randf_range(-0.5, 0.5)).normalized()
			var l := rng.randf_range(5, 11)
			var ini := p + Vector3.UP * r + d2 * 0.8
			var fim := ini + d2 * l
			fim.y = Mundo.altura(fim.x, fim.z) + r * 0.7
			mq.tubo([ini, ini.lerp(fim, 0.5) + Vector3.UP * 0.15, fim], [r, r * 0.8, r * 0.55], 8, 0.5, 2.0, Color(0, 0, 0.5), true)
	mq.no(Mat.casca("bark_brown_02", Color(0.8, 0.76, 0.72), 0.2, 0.0), self)
	# destrocos soltos
	var md := Malha.new()
	for i in 46:
		var p := Mundo.chaov(Mundo.QUEDA + dv * rng.randf_range(-12, 40) + Vector2(dv.y, -dv.x) * rng.randf_range(-11, 11))
		md.caixa(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))), p + Vector3.UP * 0.06), Vector3(rng.randf_range(0.2, 1.3), 0.02, rng.randf_range(0.2, 0.9)))
	md.no(Mat.pbrn("blue_metal_plate", 1.0, Color(0.6, 0.62, 0.64), 0.8, 0.3, 0.30), self)
	for i in 9:
		var p := Mundo.chaov(Mundo.QUEDA + dv * rng.randf_range(-9, 26) + Vector2(dv.y, -dv.x) * rng.randf_range(-9, 9))
		var tm := Vector3(rng.randf_range(0.45, 0.7), rng.randf_range(0.16, 0.24), rng.randf_range(0.32, 0.45))
		ObjetoFisico.mala(self, p + Vector3.UP * 0.5, tm, rng.randf() * TAU, [Color(0.18, 0.08, 0.05), Color(0.05, 0.07, 0.12), Color(0.12, 0.12, 0.10)][i % 3])
	for i in 5:
		var p := Mundo.chaov(Mundo.QUEDA + dv * rng.randf_range(2, 24) + Vector2(dv.y, -dv.x) * rng.randf_range(-8, 8))
		var s := ObjetoFisico.poltrona(self, p + Vector3.UP * 0.7, Vector3(rng.randf_range(-1.7, 0.2), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))

	# ---- itens
	var jq := Malha.new()
	for i in 4:
		jq.tubo([Vector3(-0.2 + i * 0.04, 0.02 + i * 0.035, 0.14), Vector3(0, 0.05 + i * 0.035, 0.0), Vector3(0.2 - i * 0.03, 0.02 + i * 0.03, -0.12)], [0.06, 0.08, 0.05], 7, 1, 1, Color(0, 0, 0.5), true)
	var jn := jq.no(Mat.pbr("fabric_pattern_07", 2.0, Color(0.42, 0.24, 0.10)), g)
	jn.position = Vector3(Aeronave.BANCOS[1], Aeronave.PISO + 0.50, -3.2 + 5.5 * 0.8 - 0.05)
	nos["jaqueta"] = jn
	it["jaqueta"] = Interativo.criar(g, jn.position + Vector3(0, 0.15, 0), "Pegar jaqueta", func(): Jogo.historia.pegar("jaqueta"), 2.2)
	# kit de primeiros socorros
	var kt := Node3D.new()
	g.add_child(kt)
	kt.position = Vector3(-0.5, Aeronave.PISO + 0.12, 1.3)
	var km := Malha.new()
	km.cx(Vector3.ZERO, Vector3(0.36, 0.2, 0.26), Vector3(0, 0.4, 0))
	km.no(Mat.liso(Color(0.55, 0.05, 0.04), 0.5), kt)
	var kc := Malha.new()
	kc.cx(Vector3(0, 0.102, 0), Vector3(0.16, 0.004, 0.05), Vector3(0, 0.4, 0))
	kc.cx(Vector3(0, 0.102, 0), Vector3(0.05, 0.004, 0.16), Vector3(0, 0.4, 0))
	kc.no(Mat.liso(Color(0.85, 0.85, 0.82), 0.6), kt)
	nos["kit"] = kt
	it["kit"] = Interativo.criar(g, kt.position, "Pegar kit de curativos", func(): Jogo.historia.pegar("kit"), 2.2)
	# bussola no painel do cockpit
	var pb_g := g.to_global(Vector3(5.6, 0, -1.2))
	var pb_m := Vector2(pb_g.x, pb_g.z)
	var cx_ := prop(self, "wooden_crate_01", Mundo.chaov(pb_m), 0.4, 0.42)
	cx_.rotation = Vector3(0.05, 0.5, 0)
	var bu := Malha.new()
	bu.tubo([Vector3.ZERO, Vector3(0, 0.03, 0)], [0.05, 0.05], 16, 1, 1, Color(0, 0, 0.5), true)
	var bn := bu.no(Mat.liso(Color(0.55, 0.42, 0.16), 0.3, 0.9), self)
	bn.position = Mundo.chaov(pb_m) + Vector3.UP * 0.44
	nos["bussola"] = bn
	it["bussola"] = Interativo.criar(self, bn.position, "Pegar bússola", func(): Jogo.historia.pegar("bussola"), 2.4)
	# mochila de alguem, com um mapa dentro
	var mp := g.to_global(Vector3(6.2, 0, 4.4))
	var moc := grupo(Vector3(mp.x, Mundo.altura(mp.x, mp.z) + 0.10, mp.z))
	moc.rotation = Vector3(-1.15, 2.2, 0.25)
	Itens.mochila(moc)
	nos["mochila"] = moc
	it["mochila"] = Interativo.criar(self, moc.position + Vector3.UP * 0.15, "Abrir mochila", func(): Jogo.historia.pegar("mochila"), 2.4, 1.2)
	# onde o jogador acorda; perto dali, uma lanterna acesa no chao
	var ac := g.to_global(Vector3(3.6, 0, 0.6))
	nos["acorda"] = grupo(Vector3(ac.x, Mundo.altura(ac.x, ac.z), ac.z))
	var lp2 := g.to_global(Vector3(4.7, 0, -1.5))
	var ln := grupo(Vector3(lp2.x, Mundo.altura(lp2.x, lp2.z) + 0.045, lp2.z))
	var longe := g.to_global(Vector3(13.0, 0, -15.0))
	ln.look_at(Vector3(longe.x, Mundo.altura(longe.x, longe.z) + 1.5, longe.z))
	nos["lanterna"] = ln
	var lmat := Lanterna.modelo(ln)
	lmat.emission_energy_multiplier = 9.0
	var lsp := Lanterna.spot(ln)
	lsp.position = Vector3(0, 0, -0.15)
	lsp.light_energy = 3.0
	nos["lanterna_luz"] = lsp
	it["lanterna"] = Interativo.criar(self, ln.position + Vector3.UP * 0.05, "Pegar lanterna", func(): Jogo.historia.pegar("lanterna"), 2.4)
	# pilhas
	_pilhas("pilha1", self, t.to_global(Vector3(0.3, Aeronave.PISO + 0.12, 0.4)))
	# caixotes soltos
	for q in [Vector3(6.4, 0, 2.2), Vector3(6.9, 0, 1.3), Vector3(-4.6, 0, 3.0)]:
		var cp := g.to_global(q)
		ObjetoFisico.movel(self, "wooden_crate_01", Mundo.chao(cp.x, cp.z) + Vector3.UP * 0.1, rng.randf() * TAU, 0.45, 7.0, "caixote")
	for k in 6:
		var lt := Mundo.chaov(Mundo.QUEDA + dv * rng.randf_range(-6, 14) + Vector2(dv.y, -dv.x) * rng.randf_range(-7, 7))
		ObjetoFisico.lata(self, lt + Vector3.UP * 0.4)
	# fagulhas nos fios rasgados
	for q in [Vector3(0.6, 0.7, 3.7), Vector3(-0.9, 0.2, 3.6)]:
		_fagulha(g, q)


func _pilhas(id: String, pai: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	pai.add_child(n)
	n.position = pos
	var m := Malha.new()
	var m2 := Malha.new()
	for i in 2:
		var o := Vector3(i * 0.045, 0.017, i * 0.02)
		m.tubo([o, o + Vector3(0.01, 0, 0.042)], [0.0165, 0.0165], 14, 1, 1, Color(0, 0, 0.5), true)
		m2.tubo([o + Vector3(0.01, 0, 0.042), o + Vector3(0.014, 0, 0.060)], [0.0168, 0.0168], 14, 1, 1, Color(0, 0, 0.5), true)
	m.no(Mat.liso(Color(0.02, 0.02, 0.02), 0.35), n)
	m2.no(Mat.liso(Color(0.62, 0.40, 0.12), 0.25, 0.9), n)
	n.add_to_group("sem_col")
	nos[id] = n
	it[id] = Interativo.criar(pai, pos + Vector3.UP * 0.05, "Pegar pilhas", func(): Jogo.historia.pegar(id), 2.2)


func _fagulha(pai: Node3D, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 0.85
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.3, 1)
	m.spread = 70
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 2.8
	m.gravity = Vector3(0, -6, 0)
	m.scale_min = 0.008
	m.scale_max = 0.020
	m.color_ramp = Fx._rampa([[0, Color(0.8, 0.9, 1, 1)], [0.4, Color(1, 0.7, 0.3, 1)], [1, Color(1, 0.2, 0.0, 0)]])
	p.process_material = m
	var q := QuadMesh.new()
	q.material = Mat.sprite(Color(1, 1, 1), 8.0, true)
	p.draw_pass_1 = q
	p.position = pos
	p.lifetime = 0.8
	p.randomness = 1.0
	p.speed_scale = 0.7
	pai.add_child(p)


# =================================================================== CEMITERIO
func _cemiterio() -> void:
	var c := Mundo.CEMITERIO
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var m := Malha.new()
	var k := 0
	for i in 4:
		for j in 4:
			if i == 3 and j >= 2: continue
			var p := Mundo.chaov(c + Vector2(-4.2 + i * 2.7 + rng.randf_range(-0.3, 0.3), -4.2 + j * 2.7 + rng.randf_range(-0.3, 0.3)))
			var w := rng.randf_range(0.5, 0.7)
			var h := rng.randf_range(0.6, 1.0)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), 0.3 + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.16, 0.16)))
			var t := Transform3D(b, p)
			m.caixa(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5 - 0.1, 0)), Vector3(w, h + 0.2, 0.13), 0.8)
			# topo arredondado
			for q in 7:
				var a0 := PI * q / 7.0
				var a1 := PI * (q + 1) / 7.0
				var am := (a0 + a1) * 0.5
				m.caixa(t * Transform3D(Basis(Vector3.BACK, am - PI * 0.5), Vector3(cos(am) * w * 0.24, h + sin(am) * w * 0.24, 0)), Vector3(w * 0.26, w * 0.5, 0.13), 0.8)
			k += 1
	m.no(Mat.pbrn("concrete_moss", 1.0, Color(0.72, 0.74, 0.76)), self)
	# cerca torta
	var ce := Malha.new()
	for s in 4:
		for i in 10:
			if s == 0 and i in [4, 5]: continue
			var f := -6.6 + i * 1.45
			var q: Vector2 = [Vector2(f, 6.6), Vector2(f, -6.6), Vector2(6.6, f), Vector2(-6.6, f)][s]
			var p := Mundo.chaov(c + q)
			ce.cx(p + Vector3.UP * 0.5, Vector3(0.08, 1.2, 0.08), Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)))
			if i < 9 and rng.randf() < 0.75 and not (s == 0 and i in [3, 4]):
				var q2: Vector2 = [Vector2(f + 1.45, 6.6), Vector2(f + 1.45, -6.6), Vector2(6.6, f + 1.45), Vector2(-6.6, f + 1.45)][s]
				var p2 := Mundo.chaov(c + q2)
				ce.viga(p + Vector3.UP * rng.randf_range(0.6, 0.9), p2 + Vector3.UP * rng.randf_range(0.5, 0.9), 0.05, 1.0, 0.09)
	ce.no(Mat.pbrn("weathered_planks", 1.0, Color(0.6, 0.58, 0.55)), self)
	# cova fresca: cruz com o nome
	var p := Mundo.chaov(c + Vector2(4.4, 3.4))
	var g := grupo(p, 0.3)
	nos["cova"] = g
	var mo := Malha.new()
	for i in 26:
		mo.tubo([Vector3(rng.randf_range(-0.35, 0.35), -0.1, rng.randf_range(-0.85, 0.85)), Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.14, 0.30), rng.randf_range(-0.6, 0.6))], [0.26, 0.12], 7, 0.6, 1.0, Color(0, 0, 0.5), true)
	mo.no(Mat.pbrn("brown_mud_leaves_01", 0.8, Color(0.85, 0.75, 0.66), 1.0, 0.0, 0.25), g)
	var cz := Malha.new()
	cz.cx(Vector3(0, 0.62, -1.15), Vector3(0.11, 1.4, 0.06), Vector3(0.04, 0, 0.05), 0.7)
	cz.cx(Vector3(0, 0.95, -1.15), Vector3(0.78, 0.15, 0.05), Vector3(0, 0, 0.05), 0.7, true)
	cz.no(Mat.pbrn("weathered_planks", 1.0, Color(0.72, 0.64, 0.52)), g)
	var l3 := Label3D.new()
	l3.text = "A L E X"
	l3.font_size = 90
	l3.pixel_size = 0.0016
	l3.modulate = Color(0.06, 0.03, 0.02)
	l3.shaded = true
	l3.outline_size = 0
	l3.position = Vector3(0, 0.95, -1.118)
	l3.rotation.z = 0.05
	g.add_child(l3)
	it["cova"] = Interativo.criar(g, Vector3(0, 0.9, -1.1), "Olhar a cruz", func(): Jogo.historia.cova(), 2.8)
	Interativo.criar(self, Mundo.chaov(c + Vector2(-1.5, -1.5)) + Vector3.UP * 0.7, "Ler lápides", func(): Jogo.historia.ler_nota("lapides"), 3.0)


# =================================================================== TORRE
func _torre() -> void:
	var p := Mundo.chaov(Mundo.TORRE)
	var g := grupo(p, 0.35)
	nos["torre"] = g
	var H := H_TORRE
	var m := Malha.new()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.viga(Vector3(3.3 * sx, -0.6, 3.3 * sz), Vector3(2.5 * sx, H, 2.5 * sz), 0.2)
	for i in 5:
		var y0 := i * 3.0
		var y1 := y0 + 3.0
		var w0 := lerpf(3.3, 2.5, y0 / H)
		var w1 := lerpf(3.3, 2.5, y1 / H)
		for s in [[Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(1, 0, -1), Vector3(-1, 0, -1)], [Vector3(1, 0, 1), Vector3(1, 0, -1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
			m.viga(s[0] * w1 + Vector3.UP * y1, s[1] * w1 + Vector3.UP * y1, 0.11)
			if i == 0 and s[0].x == -1 and s[1].x == -1: continue
			m.viga(s[0] * w0 + Vector3.UP * y0, s[1] * w1 + Vector3.UP * y1, 0.07)
			m.viga(s[1] * w0 + Vector3.UP * y0, s[0] * w1 + Vector3.UP * y1, 0.07)
	m.no(Mat.pbrn("rusty_metal_02", 0.8, Color(0.55, 0.5, 0.46), 0.9, 0.3, 0.7), g)
	# escada em zigue-zague
	var es := Malha.new()
	var b := corpo(g)
	for i in 5:
		var y0 := i * 3.0
		var par := i % 2 == 0
		var z := -0.62 if par else 0.62
		var x0 := -1.6 if par else 1.6
		var x1 := -x0
		for d in 14:
			var f := (d + 0.5) / 14.0
			es.cx(Vector3(lerpf(x0, x1, f), y0 + 3.0 * f + 0.06, z), Vector3(0.26, 0.035, 0.98), Vector3.ZERO, 1.0)
		for lz in [-0.52, 0.52]:
			es.viga(Vector3(x0, y0 - 0.05, z + lz), Vector3(x1, y0 + 2.95, z + lz), 0.04, 1.0, 0.18)
			es.viga(Vector3(x0, y0 + 0.95, z + lz), Vector3(x1, y0 + 3.95, z + lz), 0.035)
		var inc := atan2(3.0, 3.2)
		bx(b, Vector3(0, y0 + 1.5 - 0.06, z), Vector3(4.42, 0.12, 1.0), Vector3(0, 0, inc if par else -inc))
		for lz in [-0.56, 0.56]:
			bx(b, Vector3(0, y0 + 2.1, z + lz), Vector3(3.1, 1.1, 0.05), Vector3(0, 0, inc if par else -inc))
		# patamar
		var lx := 2.0 * signf(x1)
		es.cx(Vector3(lx, y0 + 2.97, 0), Vector3(0.86, 0.06, 2.3), Vector3.ZERO, 1.0)
		bx(b, Vector3(lx, y0 + 2.94, 0), Vector3(0.9, 0.12, 2.3))
		if i < 4:
			es.viga(Vector3(lx + 0.42 * signf(x1), y0 + 4.0, -1.1), Vector3(lx + 0.42 * signf(x1), y0 + 4.0, 1.1), 0.035)
			es.viga(Vector3(lx - 0.4, y0 + 4.0, -1.12 if not par else 1.12), Vector3(lx + 0.4, y0 + 4.0, -1.12 if not par else 1.12), 0.035)
			bx(b, Vector3(lx + 0.46 * signf(x1), y0 + 3.6, 0), Vector3(0.06, 1.3, 2.3))
			bx(b, Vector3(lx, y0 + 3.6, 1.16), Vector3(0.9, 1.3, 0.06))
			bx(b, Vector3(lx, y0 + 3.6, -1.16), Vector3(0.9, 1.3, 0.06))
	es.no(Mat.pbrn("rusty_metal_02", 1.0, Color(0.5, 0.47, 0.44), 0.85, 0.35, 0.55), g).add_to_group("sem_col")
	# cabine: piso com alcapao sobre o ultimo lance
	var cb := Malha.new()
	var pisos := [[Vector3(0, H, 1.35), Vector3(5.4, 0.1, 2.7)], [Vector3(0, H, -1.92), Vector3(5.4, 0.1, 1.56)], [Vector3(-1.95, H, -0.57), Vector3(1.5, 0.1, 1.14)], [Vector3(2.15, H, -0.57), Vector3(1.1, 0.1, 1.14)]]
	for q in pisos:
		cb.cx(q[0], q[1], Vector3.ZERO, 0.6)
		bx(b, q[0], q[1])
	var W := 2.6
	for s in 4:
		var ang := s * PI * 0.5
		var bs := Basis(Vector3.UP, ang)
		cb.caixa(Transform3D(bs, bs * Vector3(0, H + 0.5, W)), Vector3(W * 2, 1.0, 0.08), 0.5)
		cb.caixa(Transform3D(bs, bs * Vector3(0, H + 2.2, W)), Vector3(W * 2, 0.16, 0.12), 0.5)
		for k in 5:
			cb.caixa(Transform3D(bs, bs * Vector3(-W + k * W * 0.5, H + 1.6, W)), Vector3(0.08, 1.2, 0.08), 0.5)
		bx(b, bs * Vector3(0, H + 0.9, W), Vector3(W * 2, 1.9, 0.1), Vector3(0, ang, 0))
	for lz in [-1.14]:
		cb.viga(Vector3(-1.1, H + 0.95, lz), Vector3(1.5, H + 0.95, lz), 0.05)
	cb.viga(Vector3(-1.1, H + 0.95, 0.0), Vector3(1.5, H + 0.95, 0.0), 0.05)
	for x in [-1.1, 0.2, 1.5]:
		cb.cx(Vector3(x, H + 0.5, 0.0), Vector3(0.05, 0.95, 0.05))
		cb.cx(Vector3(x, H + 0.5, -1.14), Vector3(0.05, 0.95, 0.05))
	bx(b, Vector3(0.2, H + 0.5, 0.02), Vector3(2.7, 1.0, 0.06))
	bx(b, Vector3(0.2, H + 0.5, -1.16), Vector3(2.7, 1.0, 0.06))
	bx(b, Vector3(-1.15, H + 0.5, -0.57), Vector3(0.06, 1.0, 1.1))
	cb.no(Mat.pbr("weathered_planks", 1.0, Color(0.6, 0.55, 0.5)), g)
	var tl := Malha.new()
	for s in 4:
		var bs := Basis(Vector3.UP, s * PI * 0.5)
		tl.caixa(Transform3D(bs * Basis(Vector3.RIGHT, 0.42), bs * Vector3(0, H + 2.85, 1.55)), Vector3(6.2, 0.03, 3.4), 0.5)
	tl.no(Mat.pbrn("rusty_corrugated_iron", 1.0, Color(0.6, 0.55, 0.52)), g)
	# mesa e radio
	prop(g, "WoodenTable_01", Vector3(-1.75, H + 0.05, 1.9), 0.0, 0.80)
	prop(g, "vintage_radio_transceiver", Vector3(-1.75, H + 0.86, 1.9), PI, 0.34)
	ObjetoFisico.movel(g, "WoodenChair_01", Vector3(-1.1, H + 0.07, 1.1), 2.8, 0.9, 5.0, "cadeira")
	for k in 3:
		ObjetoFisico.lata(g, Vector3(-1.2 - k * 0.1, H + 0.95, 2.05))
	_pilhas("pilha3", g, Vector3(-2.15, H + 0.87, 1.75))
	var cur := Malha.new()
	cur.tubo([Vector3.ZERO, Vector3(0, 0.07, 0)], [0.05, 0.05], 12, 1, 1, Color(0, 0, 0.5), true)
	var curn := cur.no(Mat.liso(Color(0.8, 0.78, 0.72), 0.9), g)
	curn.position = Vector3(-1.55, H + 0.86, 1.55)
	nos["curativo3"] = curn
	it["curativo3"] = Interativo.criar(g, curn.position, "Pegar curativo", func(): Jogo.historia.pegar("curativo3"), 2.0)
	bx(b, Vector3(-1.75, H + 0.80, 1.9), Vector3(1.3, 0.1, 0.8))
	it["radio"] = Interativo.criar(g, Vector3(-1.75, H + 1.0, 1.75), "Chamar ajuda pelo rádio", func(): Jogo.historia.radio(), 2.2, 1.0)
	var bi := Malha.new()
	bi.cx(Vector3.ZERO, Vector3(0.2, 0.004, 0.28), Vector3(0, 0.3, 0))
	var bn := bi.no(Mat.liso(Color(0.7, 0.66, 0.55), 0.9), g)
	bn.position = Vector3(-1.3, H + 0.87, 1.85)
	it["livro"] = Interativo.criar(g, bn.position, "Ler livro da torre", func(): Jogo.historia.ler_nota("torre"), 2.0)
	# rifle na parede e caixa de municao
	var sup := Malha.new()
	for x in [1.45, 2.05]:
		sup.cx(Vector3(x, H + 0.66, 2.50), Vector3(0.05, 0.05, 0.16))
		sup.cx(Vector3(x, H + 0.70, 2.43), Vector3(0.05, 0.06, 0.03))
	sup.no(Mat.pbr("weathered_planks", 1.0, Color(0.5, 0.45, 0.4)), g)
	var rf := Node3D.new()
	g.add_child(rf)
	rf.position = Vector3(1.75, H + 0.74, 2.46)
	Itens.rifle(rf)
	rf.rotation = Vector3(0, PI * 0.5, 0)
	rf.add_to_group("sem_col")
	nos["rifle"] = rf
	it["rifle"] = Interativo.criar(g, rf.position, "Pegar rifle", func(): Jogo.historia.pegar("rifle"), 2.4)
	var cxm := Node3D.new()
	g.add_child(cxm)
	cxm.position = Vector3(1.7, H + 0.07, 1.75)
	prop(cxm, "wooden_crate_01", Vector3.ZERO, 0.2, 0.36)
	var mun := Node3D.new()
	g.add_child(mun)
	mun.position = Vector3(1.7, H + 0.44, 1.75)
	Itens.municao(mun)
	mun.add_to_group("sem_col")
	nos["municao"] = mun
	it["municao"] = Interativo.criar(g, mun.position, "Pegar munição", func(): Jogo.historia.pegar("municao"), 2.4)
	# luz da cabine e holofote, apagados ate o gerador ligar
	var lam := Malha.new()
	lam.tubo([Vector3(0, H + 2.25, 0.4), Vector3(0, H + 2.05, 0.4)], [0.01, 0.01], 6)
	lam.tubo([Vector3(0, H + 2.05, 0.4), Vector3(0, H + 1.95, 0.4)], [0.05, 0.16], 14)
	lam.no(Mat.liso(Color(0.08, 0.10, 0.08), 0.5, 0.4), g)
	var lb := OmniLight3D.new()
	lb.light_color = Color(1.0, 0.80, 0.52)
	lb.light_energy = 0.0
	lb.omni_range = 7.0
	lb.shadow_enabled = true
	lb.position = Vector3(0, H + 1.85, 0.4)
	g.add_child(lb)
	luzes_torre.append([lb, 2.2])
	for q in [[Vector3(-3.0, H + 0.2, 0), Vector3(-9, 0, 2)], [Vector3(0, H + 0.2, -3.0), Vector3(2, 0, -10)], [Vector3(3.0, H + 0.2, 0), Vector3(10, 0, 3)]]:
		var hs := SpotLight3D.new()
		hs.light_color = Color(0.92, 0.96, 1.0)
		hs.light_energy = 0.0
		hs.spot_range = 46.0
		hs.spot_angle = 34.0
		hs.light_volumetric_fog_energy = 2.0
		hs.shadow_enabled = true
		g.add_child(hs)
		hs.position = q[0]
		hs.look_at_from_position(g.to_global(q[0]), g.to_global(q[1]))
		luzes_torre.append([hs, 9.0])
		var hm := Malha.new()
		hm.tubo([q[0], q[0] + (q[1] - q[0]).normalized() * 0.18], [0.08, 0.13], 12)
		hm.no(Mat.liso(Color(0.1, 0.1, 0.1), 0.5, 0.6), g)
	cabine_torre = g.to_global(Vector3(0, H + 0.1, 1.2))
	# portao embaixo
	portao = Node3D.new()
	g.add_child(portao)
	portao.position = Vector3(-1.75, 0, -1.14)
	var pm := Malha.new()
	for i in 7:
		pm.cx(Vector3(0, 0.95, 0.05 + i * 0.16), Vector3(0.03, 1.9, 0.03))
	for y in [0.1, 1.0, 1.85]:
		pm.cx(Vector3(0, y, 0.52), Vector3(0.035, 0.04, 1.04))
	pm.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.5, 0.46, 0.42), 0.9, 0.3), portao)
	portao_col = corpo(portao)
	bx(portao_col, Vector3(0, 1.0, 0.52), Vector3(0.1, 2.2, 1.06))
	# grades laterais para nao contornar
	var gr := Malha.new()
	for q in [[Vector3(-1.75, 1.0, 0.62), Vector3(0.06, 2.0, 1.2)], [Vector3(0.0, 1.0, -1.2), Vector3(3.5, 2.0, 0.06)], [Vector3(0.0, 1.0, 1.2), Vector3(3.5, 2.0, 0.06)], [Vector3(2.45, 1.0, 0), Vector3(0.06, 2.0, 2.4)]]:
		bx(b, q[0], q[1])
		var sz: Vector3 = q[1]
		var L := maxf(sz.x, sz.z)
		for i in int(L / 0.16) + 1:
			var o := -L * 0.5 + i * 0.16
			gr.cx(q[0] + (Vector3(o, 0, 0) if sz.x > sz.z else Vector3(0, 0, o)), Vector3(0.025, 2.0, 0.025))
	gr.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.45, 0.42, 0.4), 0.9, 0.3), g)
	it["portao"] = Interativo.criar(g, Vector3(-1.85, 1.1, -0.6), "Abrir portão", func(): Jogo.historia.portao(), 2.6)
	var pl := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.45)
	pl.mesh = qm
	pl.position = Vector3(-1.80, 1.55, 0.62)
	pl.rotation.y = -PI * 0.5
	pl.material_override = Mat.placa("placa_torre.png")
	g.add_child(pl)


func abrir_portao() -> void:
	it["portao"].ativo = false
	Som.em("metal2", portao.global_position, 0.0, 50)
	var t := create_tween()
	t.tween_property(portao, "rotation:y", -1.7, 1.4).set_trans(Tween.TRANS_SINE)


# =================================================================== MORTOS
## quem estava no voo
func _mortos(passo: Callable) -> void:
	var g: Node3D = nos["fuselagem"]
	var k := 0
	for q in [[0, 2, "p01"], [1, 1, "p05"], [1, 2, "p04"], [2, 2, "p07"], [6, 2, "p08"], [2, 1, "viz"]]:
		var p := Vector3(Aeronave.BANCOS[q[1]], Aeronave.PISO + 0.52, -3.2 + (q[0] + 0.5) * 0.8 - 0.02)
		var n := Gente.criar(g, q[2], p, 0.0, true)
		n.morrer(11 + k * 7, 0.45 if q[0] > 0 else 0.6, 0.55)
		mortos.append(n)
		k += 1
	await passo.call("Contando os passageiros", 0.80)
	for q in [[-0.42, "com2"], [0.42, "pil"]]:
		var n := Gente.criar(g, "pil" if q[1] == "pil" else "p06", Vector3(q[0], -0.30, -3.6 - 0.62), 0.0, true)
		n.morrer(40 + int(q[0] * 10.0), 0.35, 0.75)
		mortos.append(n)
	# caidos na neve: [x, z locais, quem, giro, de brucos]
	for q in [[5.0, -3.4, "com", 0.6, false], [7.8, 1.6, "p02", 2.4, true], [-4.8, -1.2, "p03", -0.8, false], [1.2, 8.6, "p06", 1.9, true]]:
		var w := g.to_global(Vector3(q[0], 0, q[1]))
		var n := Gente.criar(self, q[2], Vector3(w.x, Mundo.altura(w.x, w.z) + (0.07 if not q[4] else 0.10), w.z))
		n.morrer(60 + k * 3, 0.85, 0.5)
		n.basis = Basis(Vector3.UP, q[3]) * Basis(Vector3.RIGHT, -PI * 0.5 if q[4] else PI * 0.5)
		var nm := Mundo.normal(w.x, w.z)
		n.basis = Basis(Quaternion(Vector3.UP, nm)) * n.basis
		mortos.append(n)
		var c := n.to_global(Vector3(0, 1.1, 0))
		Fx.sangue(self, Vector3(c.x, Mundo.altura(c.x, c.z), c.z), randf_range(1.2, 1.9))
		k += 1
	for q in [[2.2, 1.0, 1.3], [3.4, -1.2, 0.8], [0.4, 6.0, 1.4]]:
		var w := g.to_global(Vector3(q[0], 0, q[1]))
		Fx.sangue(self, Mundo.chao(w.x, w.z), q[2])
	for n in mortos: n.add_to_group("sem_col")


# =================================================================== PASSARELA
func _passarela() -> void:
	var a := Vector2(-129.0, -80.0)
	var b := Vector2(-106.5, -93.8)
	var pa := Mundo.chaov(a) + Vector3.UP * 0.12
	var pb := Mundo.chaov(b) + Vector3.UP * 0.12
	var dir := (pb - pa).normalized()
	var lado := Vector3(-dir.z, 0, dir.x).normalized()
	var comp := pa.distance_to(pb)
	var m := Malha.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var n := int(comp / 0.30)
	for i in n:
		if rng.randf() < 0.05 and i > 4 and i < n - 5: continue
		var p := pa + dir * (i + 0.5) * comp / n
		m.caixa(Transform3D(Basis(lado, Vector3.UP, dir).rotated(Vector3.UP, rng.randf_range(-0.03, 0.03)), p - Vector3.UP * 0.03), Vector3(1.5 + rng.randf_range(-0.08, 0.08), 0.06, 0.26), 0.6)
	for s in [-1.0, 1.0]:
		m.viga(pa + lado * 0.6 * s - Vector3.UP * 0.18, pb + lado * 0.6 * s - Vector3.UP * 0.18, 0.18, 0.5, 0.26)
		m.viga(pa + lado * 0.74 * s + Vector3.UP * 0.92, pb + lado * 0.74 * s + Vector3.UP * 0.92, 0.07)
		for i in 10:
			var p = pa.lerp(pb, i / 9.0) + lado * 0.74 * s
			m.viga(p - Vector3.UP * 0.3, p + Vector3.UP * 0.95, 0.09)
			if i in [3, 6]: m.viga(p - Vector3.UP * 0.2, Vector3(p.x, Mundo.altura(p.x, p.z) - 0.6, p.z), 0.2)
	m.no(Mat.pbrn("weathered_brown_planks", 1.0, Color(0.6, 0.56, 0.52), 1.0, 0.0, 0.85), self).add_to_group("sem_col")
	var c := corpo(self)
	var bs := Basis(lado, dir.cross(lado).normalized(), dir).orthonormalized()
	if bs.determinant() < 0.0: bs.y = -bs.y
	for q in [[Vector3.ZERO, Vector3(1.5, 0.2, comp + 1.2)], [lado * 0.78 + Vector3.UP * 0.5, Vector3(0.08, 1.2, comp)], [lado * -0.78 + Vector3.UP * 0.5, Vector3(0.08, 1.2, comp)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = q[1]
		cs.shape = sh
		c.add_child(cs)
		cs.transform = Transform3D(bs, (pa + pb) * 0.5 - Vector3.UP * 0.10 + q[0])


# =================================================================== BASE DA TORRE
func _base_torre() -> void:
	var g: Node3D = nos["torre"]
	# ---- banheiro de fora
	var ob := Node3D.new()
	g.add_child(ob)
	ob.position = Vector3(-8.2, 0.02, 5.2)
	ob.rotation.y = atan2(-8.2, 5.2) + PI * 0.5
	nos["banheiro"] = ob
	var m := Malha.new()
	for i in 8:
		var x := -0.70 + i * 0.20
		m.cx(Vector3(x, 1.08, -0.75), Vector3(0.19, 2.2, 0.04), Vector3(0, 0, sin(i * 9.0) * 0.01), 0.7)
		for sx in [-1.0, 1.0]:
			m.cx(Vector3(0.75 * sx, 1.08, -0.70 + i * 0.20), Vector3(0.04, 2.2, 0.19), Vector3(sin(i * 7.0 + sx) * 0.01, 0, 0), 0.7)
	for sx in [-1.0, 1.0]:
		m.cx(Vector3(0.66 * sx, 1.08, 0.75), Vector3(0.20, 2.2, 0.05))
		for sz in [-1.0, 1.0]: m.cx(Vector3(0.72 * sx, 1.1, 0.72 * sz), Vector3(0.09, 2.3, 0.09))
	m.cx(Vector3(0, 2.10, 0.75), Vector3(1.5, 0.22, 0.05))
	m.cx(Vector3(0, 0.02, 0), Vector3(1.5, 0.06, 1.5), Vector3.ZERO, 0.6)
	m.no(Mat.pbr("weathered_planks", 1.0, Color(0.52, 0.48, 0.44)), ob)
	var rt := Malha.new()
	rt.cx(Vector3(0, 2.34, 0), Vector3(1.9, 0.05, 2.0), Vector3(0.14, 0, 0))
	rt.no(Mat.pbrn("rusty_corrugated_iron", 1.0, Color(0.6, 0.55, 0.52)), ob)
	var nv := Malha.new()
	nv.cx(Vector3(0, 2.43, -0.02), Vector3(1.86, 0.13, 1.94), Vector3(0.14, 0, 0))
	nv.no(Mat.neve_lisa(), ob)
	# porta com lua recortada
	var pt := Node3D.new()
	ob.add_child(pt)
	pt.position = Vector3(-0.55, 0.05, 0.76)
	var pm := Malha.new()
	for i in 5: pm.cx(Vector3(0.11 + i * 0.22, 0.98, 0), Vector3(0.21, 1.94, 0.04), Vector3.ZERO, 0.8)
	for y in [0.4, 1.6]: pm.cx(Vector3(0.55, y, -0.03), Vector3(1.05, 0.12, 0.03), Vector3.ZERO, 0.8)
	pm.no(Mat.pbr("weathered_planks", 1.0, Color(0.56, 0.50, 0.46)), pt)
	var lu := Malha.new()
	lu.tubo([Vector3(0.55, 1.55, 0.021), Vector3(0.55, 1.55, 0.024)], [0.09, 0.09], 20, 1, 1, Color(0, 0, 0.5), true)
	lu.no(Mat.liso(Color(0.01, 0.01, 0.012), 1.0), pt)
	var pb := corpo(pt)
	bx(pb, Vector3(0.55, 1.0, 0), Vector3(1.08, 1.95, 0.06))
	pt.add_to_group("sem_col")
	nos["porta_banheiro"] = pt
	it["porta_banheiro"] = Interativo.criar(pt, Vector3(0.9, 1.0, 0.05), "Abrir", func():
		it["porta_banheiro"].ativo = false
		Som.em("porta", pt.global_position, 2.0, 40, 0.8)
		create_tween().tween_property(pt, "rotation:y", -1.9, 1.3).set_trans(Tween.TRANS_SINE), 2.4)
	# privada
	var pv := Node3D.new()
	ob.add_child(pv)
	pv.position = Vector3(0, 0.05, -0.28)
	var lou := Aeronave.m_forro(Color(0.46, 0.43, 0.36), 0.95, 0.0, 0.0)
	var lo := Malha.new()
	lo.tubo([Vector3(0, 0, 0.0), Vector3(0, 0.04, 0.0), Vector3(0, 0.16, 0.01), Vector3(0, 0.28, 0.03), Vector3(0, 0.38, 0.04), Vector3(0, 0.40, 0.04)], [0.145, 0.15, 0.115, 0.17, 0.205, 0.195], 26)
	var ab := []
	for q in [[0.40, 0.195], [0.385, 0.160], [0.33, 0.135], [0.26, 0.10], [0.22, 0.04]]: ab.append(q)
	lo.tubo([Vector3(0, 0.40, 0.04), Vector3(0, 0.385, 0.04), Vector3(0, 0.33, 0.04), Vector3(0, 0.26, 0.04), Vector3(0, 0.22, 0.04)], [0.195, 0.160, 0.135, 0.10, 0.04], 26)
	lo.cx(Vector3(0, 0.56, -0.27), Vector3(0.42, 0.36, 0.17))
	lo.cx(Vector3(0, 0.755, -0.27), Vector3(0.45, 0.035, 0.20))
	var lon := lo.no(lou, pv)
	for i in lon.mesh.get_surface_count():
		pass
	var assento := Malha.new()
	var pas := []
	var ras := []
	for i in 29:
		var a := -2.55 + 5.1 * i / 28.0
		pas.append(Vector3(sin(a) * 0.178, 0.415, 0.04 + cos(a) * 0.200))
		ras.append(0.030)
	assento.tubo(pas, ras, 10)
	for i in assento.v.size(): assento.v[i].y = 0.415 + (assento.v[i].y - 0.415) * 0.45
	assento.no(Aeronave.m_forro(Color(0.20, 0.15, 0.10), 0.9, 0.0, 0.0), pv)
	var suj := Malha.new()
	suj.tubo([Vector3(0, 0.335, 0.04), Vector3(0, 0.3351, 0.04)], [0.13, 0.13], 22, 1, 1, Color(0, 0, 0.5), true)
	for i in 5:
		var a := i * 1.3
		suj.tubo([Vector3(cos(a) * 0.05, 0.31, 0.04 + sin(a) * 0.05), Vector3(cos(a) * 0.055, 0.345, 0.04 + sin(a) * 0.05), Vector3(cos(a) * 0.03, 0.352, 0.04 + sin(a) * 0.03)], [0.035, 0.028, 0.006], 9)
	suj.no(Mat.liso(Color(0.055, 0.034, 0.012), 0.22), pv)
	var man := Malha.new()
	for i in 12:
		var a := i * 2.399
		var r := 0.25 + 0.03 * i
		man.tubo([Vector3(cos(a) * r, 0.006, sin(a) * r * 0.8), Vector3(cos(a) * r, 0.010, sin(a) * r * 0.8)], [0.03 + 0.02 * sin(i * 3.0), 0.02], 10, 1, 1, Color(0, 0, 0.5), true)
	man.no(Mat.liso(Color(0.06, 0.04, 0.02), 0.35), pv)
	pv.add_to_group("sem_col")
	var bb := corpo(ob)
	bx(bb, Vector3(0, 0.35, -0.35), Vector3(0.5, 0.7, 0.6))
	it["privada"] = Interativo.criar(ob, Vector3(0, 0.45, -0.24), "Enfiar a mão na privada", func(): Jogo.historia.privada(), 2.3, 3.2)
	Som.loop3d("moscas", ob, Vector3(0, 0.8, -0.3), -16.0, 6.0, 1.0)
	# ---- gerador sob um telheiro
	var ge := Node3D.new()
	g.add_child(ge)
	ge.position = Vector3(6.6, 0, -4.6)
	ge.rotation.y = 0.5
	var tm := Malha.new()
	for sx in [-1.0, 1.0]:
		tm.viga(Vector3(1.0 * sx, -0.3, -0.8), Vector3(1.0 * sx, 1.7, -0.8), 0.10)
		tm.viga(Vector3(1.0 * sx, -0.3, 0.8), Vector3(1.0 * sx, 2.0, 0.8), 0.10)
	tm.no(Mat.pbrn("weathered_brown_planks", 1.0, Color(0.5, 0.46, 0.42)), ge)
	var tt := Malha.new()
	tt.cx(Vector3(0, 1.92, 0), Vector3(2.5, 0.05, 2.2), Vector3(-0.18, 0, 0))
	tt.no(Mat.pbrn("rusty_corrugated_iron", 1.0, Color(0.6, 0.55, 0.5)), ge)
	var tn := Malha.new()
	tn.cx(Vector3(0, 2.01, 0), Vector3(2.46, 0.12, 2.16), Vector3(-0.18, 0, 0))
	tn.no(Mat.neve_lisa(), ge)
	var gm := prop(ge, "portable_generator", Vector3(0, 0.02, 0), 0.0, 0.72)
	nos["gerador"] = ge
	it["gerador"] = Interativo.criar(ge, Vector3(0, 0.6, 0.1), "Abastecer o gerador", func(): Jogo.historia.gerador(), 2.6, 2.5)
	prop(ge, "Barrel_01", Vector3(-0.75, 0.0, -0.4), 0.3, 0.9)
	# bilhete no portao
	var bi := Malha.new()
	bi.cx(Vector3.ZERO, Vector3(0.005, 0.24, 0.18), Vector3(0.1, 0, 0))
	var bn := bi.no(Mat.liso(Color(0.74, 0.70, 0.58), 0.9), g)
	bn.position = Vector3(-1.83, 1.25, 0.25)
	it["bilhete"] = Interativo.criar(g, bn.position + Vector3(-0.05, 0, 0), "Ler bilhete", func(): Jogo.historia.ler_nota("bilhete"), 2.2)
	# marcas de que alguem vivia aqui
	prop(g, "tree_stump_01", Vector3(4.5, -0.1, 5.2), 0.4, 0.5)
	prop(g, "wooden_axe", Vector3(4.5, 0.42, 5.2), 0.3, 0.0, "y", Vector3(0.0, 0, 0.9))


# =================================================================== VIATURA
func _viatura() -> Node3D:
	var g := grupo(Vector3(0, -300, 0))
	var br := Malha.new()
	var pr := Malha.new()
	pr.cx(Vector3(0, 0.80, 0.2), Vector3(1.9, 0.55, 4.9))
	pr.cx(Vector3(0, 0.98, -1.85), Vector3(1.82, 0.36, 1.45), Vector3(-0.03, 0, 0))
	br.cx(Vector3(0, 1.62, 0.55), Vector3(1.62, 0.10, 2.7))
	br.cx(Vector3(0, 1.10, 2.1), Vector3(1.84, 0.5, 1.0))
	for sx in [-1.0, 1.0]:
		pr.viga(Vector3(0.82 * sx, 1.10, -1.15), Vector3(0.76 * sx, 1.62, -0.75), 0.07)
		pr.viga(Vector3(0.84 * sx, 1.10, 0.35), Vector3(0.78 * sx, 1.62, 0.35), 0.10)
		pr.viga(Vector3(0.84 * sx, 1.10, 1.9), Vector3(0.78 * sx, 1.62, 1.85), 0.12)
		br.cx(Vector3(0.955 * sx, 0.92, 0.15), Vector3(0.02, 0.34, 1.7))
	pr.no(Mat.liso(Color(0.035, 0.032, 0.030), 0.25, 0.3), g)
	br.no(Mat.liso(Color(0.72, 0.70, 0.64), 0.28, 0.2), g)
	var v := Malha.new()
	v.cx(Vector3(0, 1.36, -0.96), Vector3(1.5, 0.60, 0.02), Vector3(-0.65, 0, 0))
	v.cx(Vector3(0, 1.36, 1.92), Vector3(1.5, 0.48, 0.02), Vector3(0.12, 0, 0))
	for sx in [-1.0, 1.0]:
		v.cx(Vector3(0.80 * sx, 1.36, -0.25), Vector3(0.02, 0.46, 1.1))
		v.cx(Vector3(0.80 * sx, 1.36, 1.1), Vector3(0.02, 0.46, 1.4))
	v.no(Mat.liso(Color(0.004, 0.004, 0.005), 0.06, 0.1), g)
	var r := Malha.new()
	for sx in [-1.0, 1.0]:
		for z in [-1.6, 1.7]:
			r.tubo([Vector3(0.78 * sx, 0.38, z), Vector3(0.98 * sx, 0.38, z)], [0.38, 0.38], 18, 1, 1, Color(0, 0, 0.5), true)
	r.cx(Vector3(0, 0.58, -2.62), Vector3(1.95, 0.18, 0.12))
	r.cx(Vector3(0, 0.58, 2.68), Vector3(1.95, 0.18, 0.12))
	r.no(Mat.liso(Color(0.02, 0.02, 0.02), 0.7), g)
	var f := Malha.new()
	for sx in [-1.0, 1.0]:
		f.tubo([Vector3(0.68 * sx, 0.92, -2.56), Vector3(0.68 * sx, 0.92, -2.62)], [0.13, 0.13], 14, 1, 1, Color(0, 0, 0.5), true)
		var s := SpotLight3D.new()
		s.position = Vector3(0.68 * sx, 0.92, -2.7)
		s.light_color = Color(1.0, 0.90, 0.72)
		s.light_energy = 7.0
		s.spot_range = 48
		s.spot_angle = 24
		s.light_volumetric_fog_energy = 0.8
		s.shadow_enabled = sx > 0
		g.add_child(s)
	f.no(Mat.liso(Color.WHITE, 0.3, 0, Color(1.0, 0.92, 0.76), 14.0), g)
	# giroflex
	for sx in [-1.0, 1.0]:
		var c := Color(1.0, 0.04, 0.03) if sx < 0 else Color(0.05, 0.16, 1.0)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.50, 0.13, 0.24)
		b.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = c * 0.3
		mt.emission_enabled = true
		mt.emission = c
		mt.emission_energy_multiplier = 0.0
		b.material_override = mt
		b.position = Vector3(0.33 * sx, 1.75, 0.1)
		g.add_child(b)
		var o := OmniLight3D.new()
		o.light_color = c
		o.omni_range = 26.0
		o.light_energy = 0.0
		o.light_volumetric_fog_energy = 2.0
		o.position = Vector3(0.33 * sx, 2.1, 0.1)
		g.add_child(o)
		g.set_meta("giro_a" if sx < 0 else "giro_b", [mt, o])
	var cb := corpo(g)
	bx(cb, Vector3(0, 0.9, 0.1), Vector3(1.9, 1.5, 5.2))
	g.visible = false
	return g


func girar_luzes(t: float) -> void:
	for i in viaturas.size():
		var g: Node3D = viaturas[i]
		if not g.visible: continue
		for k in [-1, 1]:
			var q: Array = g.get_meta("giro_a" if k < 0 else "giro_b")
			var on := 1.0 if sin(t * 9.0 + i * 1.3 + (PI if k > 0 else 0.0)) > 0.1 else 0.0
			q[0].emission_energy_multiplier = 9.0 * on
			q[1].light_energy = 4.5 * on