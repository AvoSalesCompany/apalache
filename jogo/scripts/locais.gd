class_name Locais
extends Node3D
## Lugares feitos a mao: queda, cabana, cemiterio, torre, ponte, posto.

var fl: Floresta
var it := {}                 # id -> Interativo
var nos := {}                # id -> Node3D
var fogos := []
var porta: Node3D
var porta_aberta := false
var fogao_luz: LuzFogo
var portao: Node3D
var portao_col: StaticBody3D
var caminhonete: Node3D
var cabine_torre := Vector3.ZERO
var esconderijo_torre := Vector3.ZERO
const H_TORRE := 15.0


func construir(f: Floresta, passo: Callable) -> void:
	fl = f
	_queda()
	await passo.call("Espalhando os destrocos", 0.80)
	_placa_regras()
	_cabana()
	await passo.call("Abandonando a cabana", 0.86)
	_cemiterio()
	_torre()
	await passo.call("Erguendo a torre", 0.92)
	_ponte()
	_posto()
	_caminhonete()
	colidir(self)
	await passo.call("Acendendo a cidade", 0.97)


## tudo que e solido ganha colisao com o formato real da malha
func colidir(no: Node) -> void:
	for f in no.get_children():
		if f is RigidBody3D or f is StaticBody3D or f is Interativo or f.is_in_group("sem_col") or f == porta or f == portao or f == caminhonete:
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
	for q in [[Mundo.CABANA, 5.2], [Mundo.TORRE, 4.0], [Mundo.POSTO, 17.0], [Mundo.QUEDA, 4.0], [Mundo.CEMITERIO, 3.0]]:
		if absf(x - q[0].x) < q[1] and absf(z - q[0].y) < q[1]:
			return true
	return false


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
	g.rotation.z = 0.20
	g.rotation.x = -0.05
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
	Aeronave.esqueleto(g, 9, -3.6)
	Aeronave.rasgo(g, 3.6, 1.0, 5)
	Aeronave.rasgo(g, 3.4, 1.0, 11)
	Aeronave.piso(g, 7.2, -3.6)
	Aeronave.fileiras(g, 8, -3.2, [[3, 1], [3, 2], [4, 2], [4, 1], [4, 0], [0, 0], [1, 0], [2, 0], [3, 0], [5, 0], [6, 0], [7, 1], [7, 2], [5, 2]])
	Aeronave.cockpit(g, -3.6, 0.85, 1.0)
	var cb := corpo(g)
	bx(cb, Vector3(0, Aeronave.PISO - 0.1, 0), Vector3(1.8, 0.2, 7.2))
	bx(cb, Vector3(0, 0, -3.7), Vector3(2.2, 2.2, 0.2))
	# degrau de terra para entrar pelo rombo
	bx(cb, Vector3(1.35, Aeronave.PISO - 0.28, 0.0), Vector3(1.1, 0.5, 2.3), Vector3(0, 0, -0.35))
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
	md.no(Mat.pbr("blue_metal_plate", 1.0, Color(0.6, 0.62, 0.64), 0.8, 0.3), self)
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
	# bilhete (desenho)
	var bi := Malha.new()
	bi.cx(Vector3.ZERO, Vector3(0.2, 0.004, 0.28), Vector3(0, 0.3, 0))
	var bin := bi.no(Mat.liso(Color(0.72, 0.68, 0.58), 0.9), g)
	bin.position = Vector3(Aeronave.BANCOS[1], Aeronave.PISO + 0.485, -3.2 + 2.5 * 0.8 - 0.05)
	it["desenho"] = Interativo.criar(g, bin.position, "Ler saco de papel", func(): Jogo.historia.ler_nota("desenho"), 2.2)
	# onde o jogador acorda; perto dali, uma lanterna acesa no chao
	var ac := g.to_global(Vector3(3.4, 0, 0.6))
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
	lsp.light_energy = 5.0
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


# =================================================================== PLACA
func _placa_regras() -> void:
	var p := Mundo.chaov(Mundo.PLACA_REGRAS)
	var g := grupo(p, atan2(-(-232.0 + 190.0), -(-215.0 + 112.0)) + PI)
	g.look_at_from_position(p, Vector3(-232, p.y, -195))
	g.rotation.x = 0
	var m := Malha.new()
	m.cx(Vector3(-0.42, 0.95, 0.06), Vector3(0.11, 2.1, 0.11), Vector3(0, 0, 0.04))
	m.cx(Vector3(0.42, 0.95, 0.06), Vector3(0.11, 2.0, 0.11), Vector3(0, 0, -0.03))
	m.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.6, 0.55, 0.5)), g)
	var q := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.04, 1.28, 0.05)
	q.mesh = bm
	q.position = Vector3(0, 1.45, 0)
	q.rotation.z = 0.04
	q.material_override = Mat.pbr("weathered_brown_planks", 0.8, Color(0.5, 0.45, 0.4))
	g.add_child(q)
	var pl := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.25)
	pl.mesh = qm
	pl.position = Vector3(0, 1.45, -0.03)
	pl.rotation = Vector3(0, PI, -0.04)
	pl.material_override = Mat.placa("placa_regras.png")
	g.add_child(pl)
	var b := corpo(g)
	bx(b, Vector3(0, 1.2, 0), Vector3(1.0, 2.4, 0.14))
	it["placa"] = Interativo.criar(g, Vector3(0, 1.4, -0.1), "Ler tábua entalhada", func(): Jogo.historia.ler_nota("regras"), 3.0)


# =================================================================== CABANA
func _cabana() -> void:
	var p := Mundo.chaov(Mundo.CABANA)
	var g := grupo(p + Vector3(0, 0.35, 0), 0.5)
	nos["cabana"] = g
	var W := 3.0       # metade x
	var D := 2.4       # metade z
	var H := 2.5
	var tr := Malha.new()
	var r := 0.135
	var n := int(H / (r * 1.75))
	for i in n:
		var y := r + i * r * 1.75
		var jit := sin(i * 12.9) * 0.02
		# parede -x e +x (janela em +x)
		for sx in [-1.0, 1.0]:
			if sx > 0 and y > 0.95 and y < 1.75:
				tr.tubo([Vector3(W * sx + jit, y, -D - 0.25), Vector3(W * sx, y, -0.5)], [r, r * 0.95], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
				tr.tubo([Vector3(W * sx, y, 0.5), Vector3(W * sx + jit, y, D + 0.25)], [r * 0.95, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
			else:
				tr.tubo([Vector3(W * sx + jit, y, -D - 0.25), Vector3(W * sx, y, 0), Vector3(W * sx + jit, y, D + 0.25)], [r, r * 1.05, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
		# fundo (-z) com janela
		if y > 0.95 and y < 1.75:
			tr.tubo([Vector3(-W - 0.25, y + r * 0.8, -D), Vector3(0.2, y + r * 0.8, -D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
			tr.tubo([Vector3(1.2, y + r * 0.8, -D), Vector3(W + 0.25, y + r * 0.8, -D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
		else:
			tr.tubo([Vector3(-W - 0.25, y + r * 0.8, -D), Vector3(W + 0.25, y + r * 0.8, -D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
		# frente (+z) com porta
		if y < 2.05:
			tr.tubo([Vector3(-W - 0.25, y + r * 0.8, D), Vector3(-0.5, y + r * 0.8, D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
			tr.tubo([Vector3(0.5, y + r * 0.8, D), Vector3(W + 0.25, y + r * 0.8, D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
		else:
			tr.tubo([Vector3(-W - 0.25, y + r * 0.8, D), Vector3(W + 0.25, y + r * 0.8, D)], [r, r], 8, 0.6, 2.0, Color(0, 0, 0.5), true)
	tr.no(Mat.casca("bark_brown_02", Color(0.72, 0.66, 0.60), 0.35, 0.0), g)
	var md := Malha.new()
	# assoalho
	for i in 17:
		md.cx(Vector3(-W + 0.18 + i * 0.35, -0.04, 0), Vector3(0.335, 0.06, D * 2.0), Vector3(0, 0, sin(i * 7.0) * 0.008), 0.5, true)
	# varanda
	for i in 12:
		md.cx(Vector3(-W + 0.25 + i * 0.5, -0.06, D + 0.95), Vector3(0.48, 0.06, 1.9), Vector3(sin(i * 5.0) * 0.015, 0, 0), 0.5, true)
	for sx in [-1.0, 0.0, 1.0]:
		md.cx(Vector3((W - 0.1) * sx if sx != 0.0 else 0.9, 1.1, D + 1.8), Vector3(0.14, 2.3, 0.14))
	# batentes, moldura das janelas, cumeeira
	md.cx(Vector3(-0.52, 1.02, D + 0.02), Vector3(0.1, 2.1, 0.32))
	md.cx(Vector3(0.52, 1.02, D + 0.02), Vector3(0.1, 2.1, 0.32))
	md.cx(Vector3(0, 2.10, D + 0.02), Vector3(1.14, 0.1, 0.32))
	for y in [0.92, 1.84]:
		md.cx(Vector3(W, y, 0), Vector3(0.34, 0.07, 1.1))
		md.cx(Vector3(0.7, y + 0.1, -D), Vector3(1.1, 0.07, 0.34))
	md.cx(Vector3(W, 1.38, 0), Vector3(0.05, 0.9, 0.05))
	md.cx(Vector3(0.7, 1.48, -D), Vector3(0.05, 0.9, 0.05))
	md.viga(Vector3(-W - 0.5, 3.75, 0), Vector3(W + 0.5, 3.75, 0), 0.16)
	for i in 5:
		var x := -W + i * (W * 2 / 4.0)
		for sz in [-1.0, 1.0]:
			md.viga(Vector3(x, 3.72, 0), Vector3(x, 2.45, (D + 0.55) * sz), 0.11)
	md.viga(Vector3(-W, 2.3, 0.0), Vector3(W, 2.3, 0.0), 0.14)
	# oitao
	for sx in [-1.0, 1.0]:
		for i in 12:
			var z := -D + 0.2 + i * (D * 2 / 12.0)
			var alt := 1.25 * (1.0 - absf(z) / D)
			if alt > 0.05:
				md.cx(Vector3(W * sx, 2.45 + alt * 0.5, z), Vector3(0.04, alt, 0.38), Vector3.ZERO, 0.5)
	md.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.62, 0.56, 0.50)), g)
	# telhado de zinco com buraco (entra luar)
	var tl := Malha.new()
	var incl := atan2(1.30, D + 0.55)
	var comp := Vector2(1.30, D + 0.55).length()
	for sz in [-1.0, 1.0]:
		for i in 8:
			for j in 3:
				if sz > 0 and (i == 4 or i == 5) and j == 0: continue
				if sz > 0 and i == 5 and j == 1: continue
				var x := -W - 0.5 + (i + 0.5) * ((W * 2 + 1.0) / 8.0)
				var f := (j + 0.5) / 3.0
				var pz = (D + 0.55) * f * sz
				var py := 3.83 - 1.30 * f + 0.02 * sin(i * 9.0 + j * 4.0)
				tl.caixa(Transform3D(Basis(Vector3.RIGHT, incl * sz), Vector3(x, py, pz)), Vector3(0.90, 0.02, comp / 3.0 + 0.06), 0.5)
	for i in 8:
		tl.caixa(Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(-W - 0.5 + (i + 0.5) * 0.875, 2.36, D + 1.15)), Vector3(0.9, 0.02, 1.75), 0.5)
	tl.no(Mat.pbr("rusty_corrugated_iron", 1.0, Color(0.7, 0.65, 0.62)), g)
	# chamine
	var ch := Malha.new()
	ch.cx(Vector3(-W - 0.4, 2.0, -0.6), Vector3(0.8, 4.6, 1.0), Vector3.ZERO, 0.5)
	ch.no(Mat.pbr("mossy_rock", 0.7, Color(0.75, 0.75, 0.72)), g)
	# colisao
	var b := corpo(g)
	bx(b, Vector3(0, -0.2, 0.9), Vector3(W * 2, 0.3, D * 2 + 1.9))
	bx(b, Vector3(0, -0.28, D + 2.2), Vector3(W * 2, 0.5, 0.9), Vector3(0.45, 0, 0))
	bx(b, Vector3(-W, 1.2, 0), Vector3(0.3, 2.6, D * 2))
	bx(b, Vector3(W, 1.2, 0), Vector3(0.3, 2.6, D * 2))
	bx(b, Vector3(0, 1.2, -D), Vector3(W * 2, 2.6, 0.3))
	bx(b, Vector3(-W * 0.5 - 0.25, 1.2, D), Vector3(W - 0.5, 2.6, 0.3))
	bx(b, Vector3(W * 0.5 + 0.25, 1.2, D), Vector3(W - 0.5, 2.6, 0.3))
	bx(b, Vector3(-W - 0.4, 1.5, -0.6), Vector3(0.8, 3.6, 1.0))
	# degraus da varanda
	# moveis
	prop(g, "WoodenTable_01", Vector3(1.6, 0, -1.3), 0.0, 0.78)
	ObjetoFisico.movel(g, "WoodenChair_01", Vector3(1.0, 0.02, -0.75), 2.2, 0.9, 5.0, "cadeira")
	for k in 4:
		ObjetoFisico.lata(g, Vector3(1.9 + k * 0.09, 0.90, -1.1 + 0.05 * (k % 2)), [Color(0.4, 0.1, 0.06), Color(0.15, 0.25, 0.12), Color(0.45, 0.36, 0.12), Color(0.3, 0.3, 0.32)][k])
	ObjetoFisico.movel(g, "wooden_crate_01", Vector3(-0.4, 0.02, -1.9), 0.3, 0.42, 6.0, "caixote")
	_pilhas("pilha2", g, Vector3(2.35, 1.51, 1.62))
	prop(g, "old_bed_frame", Vector3(-2.0, 0, -1.2), 0.0, 1.0)
	prop(g, "barrel_stove", Vector3(-2.35, 0, 0.75), PI * 0.5, 1.0)
	prop(g, "painted_wooden_cabinet", Vector3(2.45, 0, 1.4), -PI * 0.5, 1.5)
	ObjetoFisico.movel(g, "wooden_lantern_01", Vector3(1.55, 0.80, -1.5), 0.3, 0.34, 1.6, "lampião")
	prop(g, "Rockingchair_01", Vector3(-1.9, -0.02, D + 0.9), 0.4, 1.05)
	prop(g, "wooden_axe", Vector3(2.75, 0.02, 0.5), 0.0, 0.0, "y", Vector3(0.0, 0, 0.2))
	bx(b, Vector3(1.6, 0.76, -1.3), Vector3(1.3, 0.05, 0.7))
	bx(b, Vector3(-2.0, 0.3, -1.2), Vector3(1.0, 0.6, 1.9))
	bx(b, Vector3(-2.35, 0.5, 0.75), Vector3(0.7, 1.0, 0.9))
	bx(b, Vector3(2.5, 0.8, 1.4), Vector3(0.5, 1.6, 1.0))
	# porta
	porta = Node3D.new()
	g.add_child(porta)
	porta.position = Vector3(-0.46, 0, D)
	var pm := Malha.new()
	for i in 5:
		pm.cx(Vector3(0.095 + i * 0.184, 1.02, 0), Vector3(0.178, 2.0, 0.045), Vector3.ZERO, 0.6)
	pm.cx(Vector3(0.46, 0.5, 0.03), Vector3(0.88, 0.12, 0.03), Vector3.ZERO, 0.6)
	pm.cx(Vector3(0.46, 1.6, 0.03), Vector3(0.88, 0.12, 0.03), Vector3.ZERO, 0.6)
	pm.no(Mat.pbr("weathered_planks", 1.0, Color(0.55, 0.5, 0.46)), porta)
	var pb := corpo(porta)
	bx(pb, Vector3(0.46, 1.0, 0), Vector3(0.92, 2.0, 0.08))
	it["porta"] = Interativo.criar(porta, Vector3(0.8, 1.05, 0), "Abrir porta", _usa_porta, 2.2)
	# chave da torre, diario, curativo, fosforos
	var ck := Malha.new()
	ck.tubo([Vector3(0, 0, 0), Vector3(0, -0.07, 0)], [0.006, 0.006], 5)
	ck.cx(Vector3(0, -0.11, 0), Vector3(0.05, 0.08, 0.01))
	var ckn := ck.no(Mat.liso(Color(0.65, 0.5, 0.2), 0.3, 0.9), g)
	ckn.position = Vector3(-0.75, 1.55, D - 0.17)
	nos["chave"] = ckn
	it["chave"] = Interativo.criar(g, ckn.position, "Pegar chave: TORRE 4", func(): Jogo.historia.pegar("chave"), 2.2)
	var dm := Malha.new()
	dm.cx(Vector3.ZERO, Vector3(0.2, 0.03, 0.28), Vector3(0, 0.3, 0))
	var dn := dm.no(Mat.liso(Color(0.20, 0.10, 0.05), 0.7), g)
	dn.position = Vector3(1.35, 0.80, -1.25)
	it["diario"] = Interativo.criar(g, dn.position, "Ler caderno do guarda", func(): Jogo.historia.ler_nota("diario"), 2.2)
	var cm := Malha.new()
	cm.tubo([Vector3.ZERO, Vector3(0, 0.07, 0)], [0.05, 0.05], 12, 1, 1, Color(0, 0, 0.5), true)
	var cn := cm.no(Mat.liso(Color(0.8, 0.78, 0.72), 0.9), g)
	cn.position = Vector3(2.45, 1.5, 1.25)
	nos["curativo2"] = cn
	it["curativo2"] = Interativo.criar(g, cn.position, "Pegar curativo", func(): Jogo.historia.pegar("curativo2"), 2.2)
	it["fogao"] = Interativo.criar(g, Vector3(-2.2, 0.8, 0.75), "Acender o fogão", func(): Jogo.historia.acender_fogao(), 2.2, 1.6)
	fogao_luz = LuzFogo.new()
	fogao_luz.base = 0.0
	fogao_luz.light_color = Color(1.0, 0.64, 0.36)
	fogao_luz.omni_range = 7.5
	fogao_luz.position = Vector3(-1.75, 0.5, 0.75)
	fogao_luz.shadow_enabled = true
	fogao_luz.visible = false
	g.add_child(fogao_luz)


func _usa_porta() -> void:
	mover_porta(not porta_aberta)


func mover_porta(abre: bool, rapido: bool = false) -> void:
	porta_aberta = abre
	it["porta"].texto = "Fechar porta" if abre else "Abrir porta"
	Som.em("porta", porta.global_position, 0.0, 40)
	var t := create_tween()
	t.tween_property(porta, "rotation:y", -1.75 if abre else 0.0, 0.25 if rapido else 1.1).set_trans(Tween.TRANS_SINE)


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
	m.no(Mat.pbr("concrete_moss", 1.0, Color(0.72, 0.74, 0.72)), self)
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
	ce.no(Mat.pbr("weathered_planks", 1.0, Color(0.6, 0.58, 0.55)), self)
	# cova fresca: cruz com o nome
	var p := Mundo.chaov(c + Vector2(4.4, 3.4))
	var g := grupo(p, 0.3)
	nos["cova"] = g
	var mo := Malha.new()
	for i in 26:
		mo.tubo([Vector3(rng.randf_range(-0.35, 0.35), -0.1, rng.randf_range(-0.85, 0.85)), Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.14, 0.30), rng.randf_range(-0.6, 0.6))], [0.26, 0.12], 7, 0.6, 1.0, Color(0, 0, 0.5), true)
	mo.no(Mat.pbr("brown_mud_leaves_01", 0.8, Color(0.85, 0.75, 0.66)), g)
	var cz := Malha.new()
	cz.cx(Vector3(0, 0.62, -1.15), Vector3(0.11, 1.4, 0.06), Vector3(0.04, 0, 0.05), 0.7)
	cz.cx(Vector3(0, 0.95, -1.15), Vector3(0.78, 0.15, 0.05), Vector3(0, 0, 0.05), 0.7, true)
	cz.no(Mat.pbr("weathered_planks", 1.0, Color(0.72, 0.64, 0.52)), g)
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
	m.no(Mat.pbr("rusty_metal_02", 0.8, Color(0.55, 0.5, 0.46), 0.9, 0.3), g)
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
	es.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.5, 0.47, 0.44), 0.85, 0.35), g).add_to_group("sem_col")
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
	tl.no(Mat.pbr("rusty_corrugated_iron", 1.0, Color(0.6, 0.55, 0.52)), g)
	# mesa e radio
	prop(g, "WoodenTable_01", Vector3(-1.75, H + 0.05, 1.9), 0.0, 0.80)
	prop(g, "vintage_radio_transceiver", Vector3(-1.75, H + 0.86, 1.9), PI, 0.34)
	ObjetoFisico.movel(g, "WoodenChair_01", Vector3(-1.1, H + 0.07, 1.1), 2.8, 0.9, 5.0, "cadeira")
	for k in 3:
		ObjetoFisico.lata(g, Vector3(-1.2 - k * 0.1, H + 0.95, 2.05))
	_pilhas("pilha3", g, Vector3(-2.15, H + 0.87, 1.75))
	bx(b, Vector3(-1.75, H + 0.80, 1.9), Vector3(1.3, 0.1, 0.8))
	it["radio"] = Interativo.criar(g, Vector3(-1.75, H + 1.0, 1.75), "Ligar o rádio", func(): Jogo.historia.radio(), 2.2, 1.2)
	var bi := Malha.new()
	bi.cx(Vector3.ZERO, Vector3(0.2, 0.004, 0.28), Vector3(0, 0.3, 0))
	var bn := bi.no(Mat.liso(Color(0.7, 0.66, 0.55), 0.9), g)
	bn.position = Vector3(-1.3, H + 0.87, 1.85)
	it["livro"] = Interativo.criar(g, bn.position, "Ler livro da torre", func(): Jogo.historia.ler_nota("torre"), 2.0)
	# esconderijo: armario caido / lona no canto
	var lo := Malha.new()
	lo.cx(Vector3(1.9, H + 1.22, 2.0), Vector3(1.25, 0.05, 1.05), Vector3(0, 0, 0.03))
	lo.cx(Vector3(1.28, H + 0.62, 2.22), Vector3(0.05, 1.2, 0.62), Vector3(0, 0, 0.02))
	lo.no(Mat.pbr("green_metal_rust", 1.0, Color(0.5, 0.55, 0.5)), g)
	esconderijo_torre = g.to_global(Vector3(1.9, H + 0.05, 2.0))
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


# =================================================================== PONTE
func _ponte() -> void:
	var a := Vector2(303.2, 268.6)
	var b := Vector2(288.8, 299.4)
	var d := (b - a).normalized()
	a -= d * 3.0
	b += d * 3.0
	var pa := Mundo.chaov(a)
	var pb := Mundo.chaov(b)
	pa.y = maxf(pa.y, 23.4) + 0.32
	pb.y = maxf(pb.y, 23.0) + 0.32
	var g := grupo(Vector3.ZERO)
	var m := Malha.new()
	var comp := pa.distance_to(pb)
	var dir := (pb - pa).normalized()
	var lado := Vector3(-dir.z, 0, dir.x).normalized()
	var n := int(comp / 0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		if rng.randf() < 0.07 and i > 6 and i < n - 6: continue
		var p := pa + dir * (i + 0.5) * comp / n
		var bs := Basis(lado, Vector3.UP, dir).rotated(dir, rng.randf_range(-0.012, 0.012)).rotated(Vector3.UP, rng.randf_range(-0.02, 0.02))
		m.caixa(Transform3D(bs, p - Vector3.UP * 0.04), Vector3(3.5 + rng.randf_range(-0.12, 0.12), 0.08, 0.31), 0.5)
	for s in [-1.0, 1.0]:
		m.viga(pa + lado * 1.45 * s - Vector3.UP * 0.28, pb + lado * 1.45 * s - Vector3.UP * 0.28, 0.24, 0.5, 0.36)
		m.viga(pa + lado * 1.68 * s + Vector3.UP * 0.95, pb + lado * 1.68 * s + Vector3.UP * 0.95, 0.09, 0.5, 0.14)
		for i in 14:
			var p = pa.lerp(pb, i / 13.0) + lado * 1.68 * s
			m.viga(p - Vector3.UP * 0.4, p + Vector3.UP * 1.0, 0.11, 0.5)
		for q in [0.3, 0.7]:
			var p = pa.lerp(pb, q) + lado * 1.3 * s
			m.viga(p - Vector3.UP * 0.3, Vector3(p.x, Mundo.altura(p.x, p.z) - 0.5, p.z) + lado * 0.3 * s, 0.26, 0.5)
	m.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.62, 0.57, 0.52)), g).add_to_group("sem_col")
	var c := corpo(g)
	var sh := CollisionShape3D.new()
	var bxs := BoxShape3D.new()
	bxs.size = Vector3(3.5, 0.3, comp + 0.6)
	sh.shape = bxs
	c.add_child(sh)
	sh.transform = Transform3D(Basis(lado, dir.cross(lado).normalized() * 1.0, dir).orthonormalized(), (pa + pb) * 0.5 - Vector3.UP * 0.15)
	for s in [-1.0, 1.0]:
		var s2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(0.12, 1.4, comp)
		s2.shape = b2
		c.add_child(s2)
		s2.transform = Transform3D(sh.transform.basis, (pa + pb) * 0.5 + lado * 1.7 * s + Vector3.UP * 0.6)
	nos["ponte_a"] = grupo(pa)
	nos["ponte_b"] = grupo(pb)
	# placa
	var pp := Mundo.chaov(Vector2(311, 246))
	var gp := grupo(pp)
	var pm := Malha.new()
	pm.cx(Vector3(0, 0.9, -0.06), Vector3(0.08, 2.2, 0.08))
	pm.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.5, 0.5, 0.5)), gp)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 0.6)
	q.mesh = qm
	q.position = Vector3(0, 1.75, 0)
	q.material_override = Mat.placa("placa_ponte.png")
	gp.add_child(q)
	gp.look_at_from_position(pp, Vector3(318, pp.y, 220))
	gp.rotate_y(PI)


# =================================================================== POSTO E CIDADE
func _posto() -> void:
	var p := Mundo.chaov(Mundo.POSTO)
	p.y = Mundo.altura(Mundo.POSTO.x, Mundo.POSTO.y)
	var g := grupo(p, -0.03)
	nos["posto"] = g
	# patio
	var pt := Malha.new()
	pt.cx(Vector3(0, 0.02, 2.5), Vector3(30, 0.12, 17), Vector3.ZERO, 0.3)
	pt.no(Mat.pbr("concrete_moss", 1.0, Color(0.5, 0.5, 0.5)), g)
	# loja
	var lj := Malha.new()
	lj.cx(Vector3(0, 1.7, -7.2), Vector3(12, 3.4, 0.2), Vector3.ZERO, 0.4)
	lj.cx(Vector3(-6, 1.7, -4.7), Vector3(0.2, 3.4, 5), Vector3.ZERO, 0.4)
	lj.cx(Vector3(6, 1.7, -4.7), Vector3(0.2, 3.4, 5), Vector3.ZERO, 0.4)
	lj.cx(Vector3(0, 3.45, -4.7), Vector3(12.6, 0.25, 5.6), Vector3.ZERO, 0.4)
	lj.cx(Vector3(0, 0.35, -2.2), Vector3(12, 0.7, 0.2), Vector3.ZERO, 0.4)
	lj.cx(Vector3(0, 3.0, -2.2), Vector3(12, 0.8, 0.2), Vector3.ZERO, 0.4)
	for x in [-6.0, -3.0, -0.7, 0.7, 3.0, 6.0]:
		lj.cx(Vector3(x, 1.7, -2.2), Vector3(0.2, 3.4, 0.22), Vector3.ZERO, 0.4)
	lj.no(Mat.pbr("concrete_moss", 1.0, Color(0.78, 0.74, 0.68)), g)
	var lu := Malha.new()
	for x in [-4.0, 0.0, 4.0]:
		lu.cx(Vector3(x, 3.28, -4.7), Vector3(1.8, 0.05, 0.2))
	lu.no(Mat.liso(Color.WHITE, 0.5, 0, Color(0.9, 1.0, 0.92), 5.0), g)
	for x in [-3.5, 3.5]:
		var o := OmniLight3D.new()
		o.light_color = Color(0.86, 1.0, 0.90)
		o.light_energy = 2.2
		o.omni_range = 11
		o.position = Vector3(x, 2.9, -4.4)
		o.shadow_enabled = true
		o.distance_fade_enabled = true
		o.distance_fade_begin = 130
		g.add_child(o)
	# prateleiras
	var pr := Malha.new()
	for x in [-4.0, -1.6, 2.2, 4.4]:
		for y in [0.4, 0.9, 1.4]:
			pr.cx(Vector3(x, y, -5.0), Vector3(1.6, 0.05, 0.5))
			for k in 5:
				pr.cx(Vector3(x - 0.6 + k * 0.3, y + 0.15, -5.0), Vector3(0.18, 0.26, 0.2))
	pr.no(Mat.liso(Color(0.35, 0.22, 0.15), 0.7), g)
	# cobertura
	var co := Malha.new()
	co.cx(Vector3(0, 4.6, 4.5), Vector3(14, 0.6, 7))
	co.no(Mat.liso(Color(0.75, 0.72, 0.68), 0.6), g)
	var fx := Malha.new()
	fx.cx(Vector3(0, 4.6, 8.03), Vector3(14.02, 0.3, 0.04))
	fx.cx(Vector3(0, 4.6, 0.97), Vector3(14.02, 0.3, 0.04))
	fx.no(Mat.liso(Color(0.6, 0.04, 0.03), 0.5, 0, Color(0.9, 0.06, 0.04), 1.5), g)
	var cl := Malha.new()
	for x in [-5.5, 5.5]:
		cl.tubo([Vector3(x, 0, 4.5), Vector3(x, 4.4, 4.5)], [0.16, 0.16], 10)
	cl.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.7, 0.7, 0.7)), g)
	var lm := Malha.new()
	for x in [-4.0, 0.0, 4.0]:
		lm.cx(Vector3(x, 4.28, 4.5), Vector3(1.3, 0.05, 0.6))
		var s := SpotLight3D.new()
		s.position = Vector3(x, 4.2, 4.5)
		s.rotation.x = -PI * 0.5
		s.light_color = Color(0.88, 1.0, 0.92)
		s.light_energy = 7.0
		s.spot_range = 12
		s.spot_angle = 62
		s.light_volumetric_fog_energy = 2.0
		s.shadow_enabled = x == 0.0
		s.distance_fade_enabled = true
		s.distance_fade_begin = 170
		g.add_child(s)
	lm.no(Mat.liso(Color.WHITE, 0.5, 0, Color(0.9, 1.0, 0.93), 7.0), g)
	Som.loop3d("neon", g, Vector3(0, 4, 4.5), -14.0, 40, 5.0)
	# bombas
	for x in [-2.6, 2.6]:
		var bb := Malha.new()
		bb.cx(Vector3(x, 0.85, 4.5), Vector3(0.7, 1.5, 0.45))
		bb.no(Mat.liso(Color(0.5, 0.06, 0.05), 0.4), g)
		var bb2 := Malha.new()
		bb2.cx(Vector3(x, 1.25, 4.74), Vector3(0.5, 0.4, 0.02))
		bb2.no(Mat.liso(Color(0.8, 0.8, 0.75), 0.4, 0, Color(0.8, 0.9, 0.8), 0.6), g)
	# letreiro
	var le := Malha.new()
	le.tubo([Vector3(11, 0, 8), Vector3(11, 7.4, 8)], [0.18, 0.15], 10)
	le.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.6, 0.6, 0.6)), g)
	for sy in [0.0, PI]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(4.4, 1.1)
		q.mesh = qm
		q.position = Vector3(11, 7.6, 8)
		q.rotation.y = -PI * 0.5 + sy
		q.position += q.basis.z * 0.06
		q.material_override = Mat.placa("placa_posto.png", 1.9)
		g.add_child(q)
	var b := corpo(g)
	bx(b, Vector3(0, 1.7, -4.7), Vector3(12, 3.4, 5.2))
	bx(b, Vector3(0, 0.0, 2.5), Vector3(30, 0.16, 17))
	for x in [-5.5, -2.6, 2.6, 5.5]:
		bx(b, Vector3(x, 1.0, 4.5), Vector3(0.7, 2.2, 0.5))
	# postes pela rodovia
	for i in 7:
		var x := 352.0 + i * 24.0
		var z := _z_rod(x) + (5.6 if i % 2 == 0 else -5.6)
		if absf(x - 428) < 16 and i % 2 == 1: continue
		var pp := Mundo.chaov(Vector2(x, z))
		var gp := grupo(pp, 0.0 if i % 2 == 0 else PI)
		prop(gp, "street_lamp_01", Vector3.ZERO, 0.0, 5.2)
		var s := SpotLight3D.new()
		s.position = Vector3(0, 5.0, -0.6)
		s.rotation.x = -PI * 0.5
		s.light_color = Color(1.0, 0.72, 0.40)
		s.light_energy = 6.0
		s.spot_range = 13
		s.spot_angle = 58
		s.light_volumetric_fog_energy = 3.0
		s.distance_fade_enabled = true
		s.distance_fade_begin = 190
		s.distance_fade_length = 40
		s.shadow_enabled = i < 4
		gp.add_child(s)
		var bl := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.14
		sp.height = 0.28
		bl.mesh = sp
		bl.position = Vector3(0, 5.0, -0.5)
		bl.material_override = Mat.liso(Color.WHITE, 0.5, 0, Color(1.0, 0.75, 0.42), 9.0)
		gp.add_child(bl)
	# placa da cidade
	var pz := Mundo.chaov(Vector2(344, _z_rod(344) + 6.4))
	var gz := grupo(pz)
	var zm := Malha.new()
	for x in [-0.9, 0.9]:
		zm.cx(Vector3(x, 1.0, 0.05), Vector3(0.1, 2.6, 0.1))
	zm.no(Mat.pbr("weathered_planks", 1.0), gz)
	var zq := MeshInstance3D.new()
	var zqm := QuadMesh.new()
	zqm.size = Vector2(2.4, 1.2)
	zq.mesh = zqm
	zq.position = Vector3(0, 1.8, 0)
	zq.material_override = Mat.placa("placa_cidade.png", 0.05)
	gz.add_child(zq)
	gz.rotation.y = -PI * 0.5 - 0.35
	# casas ao longe
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cs := Malha.new()
	var jn := Malha.new()
	for i in 9:
		var x := 455.0 + rng.randf_range(0, 45)
		var z := _z_rod(x) + (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(15, 34)
		var q := Mundo.chaov(Vector2(x, z))
		var w := rng.randf_range(6, 9)
		var h := rng.randf_range(3, 5)
		cs.cx(q + Vector3(0, h * 0.5 - 0.5, 0), Vector3(w, h + 1.0, 6.5), Vector3.ZERO, 0.4)
		for s in [-1.0, 1.0]:
			cs.caixa(Transform3D(Basis(Vector3.RIGHT, 0.62 * s), q + Vector3(0, h + 1.0, 1.7 * s)), Vector3(w + 0.6, 0.15, 4.4), 0.4)
		for k in 2:
			if rng.randf() < 0.75:
				jn.cx(q + Vector3(-w * 0.25 + k * w * 0.5, h * 0.55, -3.27 if z > 388 else 3.27), Vector3(0.9, 1.0, 0.03))
				jn.cx(q + Vector3(-w * 0.5 - 0.02, h * 0.55, -1.5 + k * 3.0), Vector3(0.03, 1.0, 0.9))
	cs.no(Mat.pbr("weathered_planks", 1.0, Color(0.6, 0.6, 0.6)), self)
	jn.no(Mat.liso(Color(0.2, 0.12, 0.05), 0.5, 0, Color(1.0, 0.66, 0.28), 4.0), self)
	# luzes da cidade vistas da torre (bem longe)
	var lt := Malha.new()
	for i in 80:
		var x := 400.0 + rng.randf_range(0, 110)
		var z := 388.0 + rng.randf_range(-70, 60)
		var y := Mundo.altura(x, z) + (rng.randf_range(5, 14) if i % 2 == 0 else rng.randf_range(20, 36))
		lt.cx(Vector3(x, y, z), Vector3.ONE * rng.randf_range(0.8, 1.5))
	var mlz := Mat.liso(Color.BLACK, 0.5, 0, Color(1.0, 0.72, 0.38), 12.0).duplicate() as StandardMaterial3D
	mlz.disable_fog = true
	mlz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mlz.albedo_color = Color(2.4, 1.6, 0.8)
	var ln := lt.no(mlz, self, false)
	ln.visibility_range_begin = 220.0


func _z_rod(x: float) -> float:
	var l := Mundo.RODOVIA
	for i in l.size() - 1:
		if x >= l[i][0] and x <= l[i + 1][0]:
			return lerpf(l[i][1], l[i + 1][1], (x - l[i][0]) / (l[i + 1][0] - l[i][0]))
	return 400.0


# =================================================================== CAMINHONETE
func _caminhonete() -> void:
	var g := grupo(Vector3(0, -300, 0))
	caminhonete = g
	var m := Malha.new()
	m.cx(Vector3(0, 0.85, 0.3), Vector3(1.9, 0.6, 5.0))
	m.cx(Vector3(0, 0.95, -2.0), Vector3(1.85, 0.5, 1.3), Vector3(-0.05, 0, 0))
	m.cx(Vector3(0, 1.75, -0.35), Vector3(1.7, 0.10, 1.5))
	for sx in [-1.0, 1.0]:
		m.viga(Vector3(0.82 * sx, 1.15, -1.35), Vector3(0.78 * sx, 1.75, -1.0), 0.07)
		m.viga(Vector3(0.82 * sx, 1.15, 0.45), Vector3(0.78 * sx, 1.75, 0.35), 0.10)
		m.cx(Vector3(0.94 * sx, 1.25, 1.7), Vector3(0.06, 0.4, 2.2))
	m.cx(Vector3(0, 1.25, 2.8), Vector3(1.9, 0.4, 0.06))
	m.cx(Vector3(0, 1.45, 0.48), Vector3(1.7, 0.6, 0.05))
	m.no(Mat.pbr("green_metal_rust", 1.0, Color(0.36, 0.22, 0.18), 0.7, 0.4), g)
	var v := Malha.new()
	v.cx(Vector3(0, 1.45, -1.18), Vector3(1.55, 0.62, 0.02), Vector3(-0.55, 0, 0))
	for sx in [-1.0, 1.0]:
		v.cx(Vector3(0.82 * sx, 1.45, -0.4), Vector3(0.02, 0.5, 1.3))
	v.no(Mat.liso(Color(0.004, 0.004, 0.005), 0.06, 0.1), g)
	var r := Malha.new()
	for sx in [-1.0, 1.0]:
		for z in [-1.6, 1.8]:
			r.tubo([Vector3(0.80 * sx, 0.40, z), Vector3(0.98 * sx, 0.40, z)], [0.40, 0.40], 16, 1, 1, Color(0, 0, 0.5), true)
	r.cx(Vector3(0, 0.6, -2.68), Vector3(1.95, 0.18, 0.12))
	r.no(Mat.liso(Color(0.02, 0.02, 0.02), 0.8), g)
	var f := Malha.new()
	for sx in [-1.0, 1.0]:
		f.tubo([Vector3(0.68 * sx, 0.95, -2.62), Vector3(0.68 * sx, 0.95, -2.68)], [0.14, 0.14], 14, 1, 1, Color(0, 0, 0.5), true)
		var s := SpotLight3D.new()
		s.position = Vector3(0.68 * sx, 0.95, -2.75)
		s.light_color = Color(1.0, 0.86, 0.62)
		s.light_energy = 8.0
		s.spot_range = 55
		s.spot_angle = 24
		s.light_volumetric_fog_energy = 0.45
		s.shadow_enabled = true
		g.add_child(s)
	f.no(Mat.liso(Color.WHITE, 0.3, 0, Color(1.0, 0.9, 0.7), 14.0), g)
	var tr := Malha.new()
	for sx in [-1.0, 1.0]:
		tr.cx(Vector3(0.8 * sx, 1.0, 2.84), Vector3(0.16, 0.2, 0.02))
	tr.no(Mat.liso(Color(0.3, 0, 0), 0.4, 0, Color(1, 0.05, 0.03), 4.0), g)
	var b := corpo(g)
	bx(b, Vector3(0, 0.9, 0.2), Vector3(1.9, 1.6, 5.4))
	it["carona"] = Interativo.criar(g, Vector3(1.1, 1.2, -0.4), "Entrar na caminhonete", func(): Jogo.historia.entrar_caminhonete(), 2.6, 1.5)
	it["carona"].ativo = false
	g.visible = false
