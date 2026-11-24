class_name Anomalias
extends Node3D
## Coisas que observam de longe e sustos. Nada aqui machuca: so a criatura machuca.
## Regra de ritmo: construir (silencio, vulto longe) -> soltar (susto) -> respirar.

var t := 20.0
var t_forte := 90.0          # intervalo minimo entre sustos fortes
var ligado := false
var ativos: Array = []
var ultimo := ""
var _olhos: Array = []
var _t_olhos := 0.0
var _eco := 0.0
var _passos := 0.0
var cena_mascaras: Array = []


func _ready() -> void:
	for i in 14:
		var n := Node3D.new()
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color.BLACK
		mt.disable_fog = true
		var larg := randf_range(0.035, 0.065)
		for sx in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.016
			s.height = 0.032
			s.radial_segments = 8
			s.rings = 4
			e.mesh = s
			e.material_override = mt
			e.position.x = larg * sx
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(e)
		n.visible = false
		add_child(n)
		_olhos.append({"n": n, "m": mt, "k": 0.0, "livre": false, "visto": 0.0, "f": randf() * 10.0, "ob": 0.0, "tob": randf()})


func reset() -> void:
	limpar()
	t = 22.0
	t_forte = 70.0


func limpar() -> void:
	for a in ativos:
		if is_instance_valid(a):
			a.queue_free()
	ativos.clear()


func _ocupado() -> bool:
	var j = Jogo.jogador
	if j == null or j.morto or j.travado or j.so_olhar or Jogo.hud.lendo:
		return true
	var c = Jogo.criatura
	return c != null and c.estado in [Criatura.E.CACA, Criatura.E.ATAQUE, Criatura.E.TORRE]


func _process(dt: float) -> void:
	var j = Jogo.jogador
	if not ligado or j == null or not j.is_visible_in_tree():
		return
	_olhos_anda(dt, j)
	_vigias(dt, j)
	if _ocupado():
		return
	t_forte -= dt
	t -= dt
	if t <= 0.0:
		t = randf_range(26.0, 48.0) * (0.85 if Jogo.etapa >= 4 else 1.15)
		_sorteia(j)


func _sorteia(j) -> void:
	var op := []
	var e: int = Jogo.etapa
	if j.abrigado:
		op = ["sussurro", "passos_fora"]
	else:
		op = ["longe", "longe", "passos", "sussurro"]
		if e >= 2: op += ["corre", "acena", "costas", "galho"]
		if e >= 3: op += ["grupo", "poltrona", "lua"]
		if e >= 4: op += ["grupo", "corre", "lua"]
		if t_forte <= 0.0 and e >= 2 and j.lanterna.ligada: op += ["apagao", "apagao"]
	op = op.filter(func(q): return q != ultimo)
	ultimo = op[randi() % op.size()]
	fazer(ultimo)


func fazer(q: String) -> void:
	var j = Jogo.jogador
	match q:
		"longe": _por_vigia(j, randf_range(22.0, 34.0), randf_range(-0.6, 0.6), false)
		"acena": _por_vigia(j, randf_range(20.0, 30.0), randf_range(-0.5, 0.5), true)
		"grupo":
			var n := randi_range(3, 6)
			var b := randf_range(-0.4, 0.4)
			for i in n:
				_por_vigia(j, randf_range(24.0, 36.0), b + (i - n * 0.5) * 0.17, randf() < 0.2)
		"costas": _costas(j)
		"corre": _corre(j)
		"poltrona": _poltrona(j)
		"passos": _passos_atras(j)
		"sussurro":
			var s: String = ["v_sus_atras", "v_sus_cair", "v_sus_nao"][randi() % 3]
			Som.em(s, j.cam.global_position + j.cam.global_transform.basis.z * 1.3 + j.cam.global_transform.basis.x * randf_range(-0.8, 0.8), 1.0, 14, randf_range(0.9, 1.0), "Voz", 2.0)
			j.medo = maxf(j.medo, 0.4)
		"passos_fora":
			for i in 5:
				Som.em("cr_passo%d" % randi_range(1, 3), j.global_position + Vector3(5.0 - i * 2.2, 0, 5.5), -2.0, 30, 0.9)
				await get_tree().create_timer(0.75, false).timeout
				if not is_inside_tree(): return
		"galho":
			var d: Vector3 = j.cam.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(6, 10)
			Som.em("galho%d" % randi_range(1, 4), j.global_position + d, 6.0, 60)
			Som.em("arbusto", j.global_position + d, 2.0, 40)
		"lua": Jogo.floresta.cobrir_lua(randf_range(13.0, 20.0))
		"apagao": _apagao(j)


func _livre(p: Vector3) -> bool:
	for i in Mundo.arvores_perto(p, 0.9):
		return false
	return Mundo.dist(Mundo.RIO, p.x, p.z) > 2.5


func _por_vigia(j, dist: float, ang: float, acena: bool) -> Vigia:
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	fr = fr.normalized()
	for k in 10:
		var p: Vector3 = j.global_position + fr.rotated(Vector3.UP, ang + randf_range(-0.2, 0.2)) * (dist + randf_range(-3, 3))
		if not _livre(p):
			continue
		if Mundo.obstrucao(j.cam.global_position, Mundo.chao(p.x, p.z) + Vector3.UP * 1.9) > 0.5 and k < 8:
			continue
		var v := Vigia.new().montar(acena)
		Jogo.floresta.add_child(v)
		v.por(p, j.global_position)
		ativos.append(v)
		return v
	return null


## somem quando encarados, iluminados de perto ou quando voce chega perto
func _vigias(dt: float, j) -> void:
	for v in ativos.duplicate():
		if not is_instance_valid(v):
			ativos.erase(v)
			continue
		if v.has_meta("cena"):
			continue
		var d: float = v.global_position.distance_to(j.global_position)
		if v.na_vista():
			v.visto += dt
			j.medo = maxf(j.medo, 0.34)
			if v.visto > 0.12 and not v.has_meta("ouviu"):
				v.set_meta("ouviu", true)
				Jogo.diretor.silencio = maxf(Jogo.diretor.silencio, 0.65)
				Som.toca("sub", -15)
		var lim := 2.6 if j.lanterna.ilumina(v.global_position + Vector3.UP * 1.8) > 0.2 else 4.5
		if v.visto > lim or d < 11.0 or (v.vida > 28.0 and not v.na_vista(0.7)) or d > 75.0:
			if v.na_vista(0.7):
				_piscar(j, 0.16)
				Som.em("arbusto", v.global_position, -2.0, 50)
			ativos.erase(v)
			v.queue_free()


func _piscar(j, s: float) -> void:
	j.lanterna.apagao = maxf(j.lanterna.apagao, s)
	Jogo.hud.piscar(s)


## alguem parado de costas, encostado numa arvore
func _costas(j) -> void:
	var v := _por_vigia(j, randf_range(13.0, 18.0), randf_range(-0.5, 0.5), false)
	if v == null:
		return
	v.modo = "costas"
	v.rotation.y += PI
	v.set_meta("cena", true)
	Som.em("v_coro", v.global_position + Vector3.UP * 1.8, -8.0, 22, 1.0, "Voz", 3.0)
	var espera := 0.0
	while is_instance_valid(v) and espera < 45.0:
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(v): return
		var dt := get_process_delta_time()
		if Jogo.hud.lendo: continue
		espera += dt
		if v.na_vista(0.9): v.visto += dt
		var d: float = v.global_position.distance_to(j.global_position)
		if d < 6.5 or v.visto > 5.0:
			# a cabeca estala para tras
			Som.em("cr_estalos", v.global_position + Vector3.UP * 2.0, 6.0, 30)
			v.rotation.y = atan2(-(j.global_position.x - v.global_position.x), -(j.global_position.z - v.global_position.z))
			v.modo = ""
			susto(0.9)
			await get_tree().create_timer(0.42, false).timeout
			_piscar(j, 0.5)
			break
	if is_instance_valid(v):
		ativos.erase(v)
		v.queue_free()


## atravessa a sua frente correndo
func _corre(j) -> void:
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	fr = fr.normalized()
	var lado := fr.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	var c: Vector3 = j.global_position + fr * randf_range(9.0, 14.0)
	var v := Vigia.new().montar(false)
	v.set_meta("cena", true)
	Jogo.floresta.add_child(v)
	ativos.append(v)
	var a := c - lado * 9.0
	var b := c + lado * 9.0
	v.por(a, b)
	v.modo = "costas"
	Som.em("arbusto", a, 8.0, 50)
	j.medo = maxf(j.medo, 0.55)
	var s := 0.0
	var passo := 0.0
	while s < 1.0:
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(v): return
		var dt := get_process_delta_time()
		s += dt / 1.15
		passo -= dt
		var p := a.lerp(b, s)
		p += lado.cross(Vector3.UP) * sin(s * 9.0) * 0.25
		v.global_position = Vector3(p.x, Mundo.altura(p.x, p.z) + absf(sin(s * 26.0)) * 0.10, p.z)
		v.rotation.x = -0.42
		v.corpo.rotation.z = sin(s * 26.0) * 0.16
		if passo <= 0.0:
			passo = 0.13
			Som.em("p_folha%d" % randi_range(1, 5), v.global_position, 6.0, 40, 0.8)
	if t_forte < 30.0:
		Som.toca("stinger3", -14)
	ativos.erase(v)
	v.queue_free()


## poltrona do aviao no meio da mata, com alguem sentado de costas
func _poltrona(j) -> void:
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	fr = fr.normalized()
	var p: Vector3
	var ok := false
	for k in 10:
		p = j.global_position + fr.rotated(Vector3.UP, randf_range(-0.35, 0.35)) * randf_range(17, 24)
		if _livre(p) and Mundo.obstrucao(j.cam.global_position, Mundo.chao(p.x, p.z) + Vector3.UP) < 0.5:
			ok = true
			break
	if not ok:
		return
	var r := Node3D.new()
	r.set_meta("cena", true)
	Jogo.floresta.add_child(r)
	ativos.append(r)
	r.global_position = Mundo.chao(p.x, p.z) - Vector3.UP * 0.05
	var d: Vector3 = j.global_position - r.global_position
	r.rotation = Vector3(randf_range(-0.06, 0.06), atan2(d.x, d.z), randf_range(-0.08, 0.08))
	Aeronave.poltrona_no(r, Vector3.ZERO)
	var h := MeshInstance3D.new()
	h.mesh = load("res://dados/humano.res")
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/humano.gdshader")
	m.set_shader_parameter("camisa", Color(0.18, 0.16, 0.14))
	m.set_shader_parameter("pele", Color(0.21, 0.195, 0.18))
	h.material_override = m
	h.position = Vector3(0, 0.44, 0.05)
	r.add_child(h)
	Som.em("av_chime", r.global_position + Vector3.UP, -4.0, 45, 0.7)
	var espera := 0.0
	while is_instance_valid(r) and espera < 60.0:
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(r): return
		if Jogo.hud.lendo: continue
		espera += get_process_delta_time()
		var dist: float = r.global_position.distance_to(j.global_position)
		if dist > 60.0: break
		if dist < 5.5:
			j.medo = 0.7
			Som.em("cr_estalos", r.global_position + Vector3.UP, 5.0, 25)
			await get_tree().create_timer(0.7, false).timeout
			if not is_instance_valid(h): return
			h.rotation.y = PI
			susto(0.8)
			await get_tree().create_timer(0.38, false).timeout
			_piscar(j, 0.7)
			h.queue_free()
			Jogo.falar("", "O cinto continua afivelado.", 3.0)
			break
	ativos.erase(r)
	if is_instance_valid(r):
		get_tree().create_timer(60.0, false).timeout.connect(func(): if is_instance_valid(r): r.queue_free())


## passos que copiam os seus e param um instante depois
func _passos_atras(j) -> void:
	var dur := 9.0
	var andava := false
	while dur > 0.0:
		await get_tree().create_timer(0.52, false).timeout
		if not is_inside_tree() or Jogo.jogador == null: return
		dur -= 0.52
		var v := Vector2(j.velocity.x, j.velocity.z).length()
		var tras: Vector3 = j.global_position + j.global_transform.basis.z * 5.0
		if v > 0.8:
			andava = true
			Som.em("p_folha%d" % randi_range(1, 5), tras, 1.0, 22, 0.82)
		elif andava:
			andava = false
			Som.em("p_folha%d" % randi_range(1, 5), tras, 3.0, 22, 0.78)
			j.medo = maxf(j.medo, 0.45)
			dur -= 2.0


## a lanterna morre; quando volta, tem alguem
func _apagao(j) -> void:
	t_forte = randf_range(150.0, 220.0)
	Jogo.diretor.silencio = 1.0
	for i in 5:
		j.lanterna.apagao = 0.07
		await get_tree().create_timer(randf_range(0.16, 0.34), false).timeout
		if not is_inside_tree(): return
	j.lanterna.apagao = 2.6
	Som.toca("radio_clique", -6, 0.7)
	await get_tree().create_timer(0.9, false).timeout
	Som.em("cr_respira", j.cam.global_position - j.cam.global_transform.basis.z * 2.0, 4.0, 14, 0.85, "Voz", 2.0)
	await get_tree().create_timer(1.45, false).timeout
	if not is_inside_tree() or _ocupado(): return
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	var p: Vector3 = j.global_position + fr.normalized() * 3.4
	var v := Vigia.new().montar(false)
	v.set_meta("cena", true)
	Jogo.floresta.add_child(v)
	v.por(p, j.global_position)
	j.lanterna.apagao = 0.0
	susto(1.0)
	await get_tree().create_timer(0.45, false).timeout
	_piscar(j, 0.9)
	if is_instance_valid(v): v.queue_free()


func susto(f: float) -> void:
	var j = Jogo.jogador
	Som.toca("stinger1", lerpf(-8.0, 1.0, f))
	if f > 0.7: Som.toca("cr_grito2", -10, 1.25)
	j.medo = 1.0
	j.tremer(0.22 * f)
	j._fov -= 16.0 * f
	Jogo.hud.pulso = 1.0
	Jogo.diretor.tensao = maxf(0.0, Jogo.diretor.tensao - 0.3)
	t = maxf(t, 35.0)
	t_forte = maxf(t_forte, 100.0)


# ------------------------------------------------------------------ olhos na mata
func _olhos_anda(dt: float, j) -> void:
	var quantos: int = [0, 2, 6, 8, 9, 10, 12, 14, 6, 0][clampi(Jogo.etapa, 0, 9)]
	if j.abrigado: quantos = 0
	for i in _olhos.size():
		var q: Dictionary = _olhos[i]
		var n: Node3D = q.n
		q.f += dt
		if not q.livre:
			if i < quantos and randf() < dt * 0.5:
				_por_olho(q, j)
			continue
		var d: float = n.global_position.distance_to(j.global_position)
		if d > 52.0 or i >= quantos:
			q.livre = false
			n.visible = false
			continue
		q.tob -= dt
		if q.tob <= 0.0:
			q.tob = 0.35 + randf() * 0.2
			q.ob = Mundo.obstrucao(j.cam.global_position, n.global_position)
		n.look_at(j.cam.global_position)
		var il: float = j.lanterna.ilumina(n.global_position)
		var alvo := il * 2.2 + 0.015
		if q.ob > 0.8 or fmod(q.f, 5.3) < 0.10: alvo = 0.0
		if il > 0.25: q.visto += dt
		if q.visto > 2.2 + fmod(q.f, 2.0) or d < 9.0:
			# fecha os olhos e vai embora
			q.livre = false
			n.visible = false
			q.visto = 0.0
			if d < 22.0 and randf() < 0.6: Som.em("arbusto", n.global_position, -6.0, 35)
			continue
		q.k = move_toward(q.k, alvo, dt * 6.0)
		q.m.albedo_color = Color(0.80, 1.0, 0.72) * q.k
		n.visible = q.k > 0.008


func _por_olho(q: Dictionary, j) -> void:
	for k in 4:
		var a := randf() * TAU
		var r := randf_range(17.0, 34.0)
		var p: Vector3 = j.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		if Mundo.dist(Mundo.RODOVIA, p.x, p.z) < 12.0 or not _livre(p):
			continue
		q.n.global_position = Mundo.chao(p.x, p.z) + Vector3.UP * [0.45, 0.9, 1.5, 2.1][randi() % 4]
		q.livre = true
		q.visto = 0.0
		q.k = 0.0
		return
