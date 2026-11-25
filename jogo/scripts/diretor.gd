class_name Diretor
extends Node
## Cerebro grande. De dia nao existe. Na mata, de noite, ronda e assusta sem matar.
## No cerco da torre, ataca em ondas: aparece, golpeia, some, espera.

var tensao := 0.0            # 0..1
var alivio := 40.0           # segundos de descanso restantes
var ligado := false
var silencio := 0.0          # 0 mata viva .. 1 mata muda
var silencio_alvo := 0.0
var t_voz := 60.0
var t_fauna := 8.0
var chamando := 0.0
var pos_voz := Vector3.ZERO
var cerco := false
var t_ataque := 20.0
var _subindo := false
var _t_caca := 0.0


func _cr() -> Criatura:
	return Jogo.criatura


func reset() -> void:
	tensao = 0.0
	alivio = 30.0
	silencio = 0.0
	silencio_alvo = 0.0
	t_voz = 45.0
	chamando = 0.0
	cerco = false
	_subindo = false
	if _cr(): _cr().esconder()


func iniciar_cerco() -> void:
	cerco = true
	ligado = true
	_subindo = false
	t_ataque = 16.0
	Jogo.anomalias.ligado = true
	Jogo.anomalias.t = 40.0


func depois_do_golpe() -> void:
	t_ataque = randf_range(20.0, 30.0)
	_subindo = false


func _process(dt: float) -> void:
	var j = Jogo.jogador
	if j == null or Jogo.floresta == null or not Jogo.floresta.visible:
		return
	_sons(dt, j)
	if not ligado or j.morto or Jogo.hud.lendo:
		return
	var c := _cr()
	c.agressao = clampf(Jogo.etapa / 8.0, 0.0, 1.0)
	if j.travado and not j.so_olhar:
		return
	if Jogo.etapa < 5:
		return
	var dc := c.dist_jog() if c.visible else 99.0
	j.lanterna.falha = move_toward(j.lanterna.falha, clampf(1.0 - dc / 24.0, 0.0, 0.85), dt)
	if dc < 60.0: tensao = minf(1.0, tensao + (1.0 - dc / 60.0) * 0.06 * dt)
	else: tensao = maxf(0.0, tensao - dt * 0.018)
	if Jogo.etapa >= 6: silencio_alvo = 1.0 if dc < 48.0 or chamando > 0.0 or cerco else 0.35
	if cerco and Jogo.etapa == 7:
		_cerco(dt, j, c)
	elif Jogo.etapa == 6:
		_ronda(dt, j, c)


# ------------------------------------------------------------------ etapa 6: so medo
func _ronda(dt: float, j, c: Criatura) -> void:
	if c.estado == Criatura.E.OCULTO:
		alivio -= dt
		if alivio <= 0.0 and not j.abrigado:
			alivio = randf_range(28.0, 46.0)
			var fr: Vector3 = -j.cam.global_transform.basis.z
			fr.y = 0
			fr = fr.normalized()
			for t in 12:
				var p: Vector3 = j.global_position + fr.rotated(Vector3.UP, randf_range(-0.7, 0.7)) * randf_range(24.0, 38.0)
				if _livre(p) and Mundo.obstrucao(j.cam.global_position, Mundo.chao(p.x, p.z) + Vector3.UP * 1.6) < 0.6:
					c.colocar(p, j.global_position)
					c.muda(Criatura.E.OBSERVA)
					return
	elif c.estado in [Criatura.E.CACA, Criatura.E.PROCURA, Criatura.E.INVESTIGA] and c.t_estado > 12.0:
		c.muda(Criatura.E.RECUA)
	t_voz -= dt
	chamando = maxf(0.0, chamando - dt)
	if t_voz <= 0.0 and c.estado == Criatura.E.OCULTO and not j.abrigado:
		t_voz = randf_range(50.0, 85.0)
		chamar()


# ------------------------------------------------------------------ etapa 7: ondas
func _cerco(dt: float, j, c: Criatura) -> void:
	if c.morta or _subindo:
		return
	if c.estado == Criatura.E.OCULTO:
		t_ataque -= dt
		if t_ataque <= 0.0:
			t_ataque = 30.0
			if Jogo.historia._na_torre: _subir(j, c)
			else: emboscada(randf_range(22.0, 30.0))
	elif c.estado == Criatura.E.CACA:
		c.deteccao = 1.0
		c.ultimo_visto = j.global_position
		_t_caca += dt
		if _t_caca > 16.0 or Jogo.historia._na_torre:
			c.muda(Criatura.E.RECUA)
			t_ataque = randf_range(5.0, 10.0)
	elif c.estado in [Criatura.E.OBSERVA, Criatura.E.PROCURA, Criatura.E.RONDA, Criatura.E.INVESTIGA]:
		c.ultimo_visto = j.global_position
		c.muda(Criatura.E.CACA)
		_t_caca = 0.0


## sobe pela escada e entra pelo alcapao
func _subir(j, c: Criatura) -> void:
	_subindo = true
	var t: Node3D = Jogo.floresta.locais.nos["torre"]
	var base := t.global_position
	for i in 8:
		var y := lerpf(0.5, 14.0, i / 7.0)
		Som.em("p_metal%d" % randi_range(1, 5), base + Vector3(sin(i * 1.4), y, 0), lerpf(2.0, 8.0, i / 7.0), 50, 0.62, "Eco", 6.0)
		j.tremer(0.012 + i * 0.004)
		await get_tree().create_timer(lerpf(0.85, 0.5, i / 7.0), false).timeout
		if not is_inside_tree() or j.morto or not cerco or c.morta: return
		if not Jogo.historia._na_torre:
			_subindo = false
			t_ataque = 4.0
			return
	var p := t.to_global(Vector3(1.0, Locais.H_TORRE + 0.05, -0.6))
	c.colocar(p, j.global_position)
	c.global_position = p
	c.em_pe = 1.0
	c.muda(Criatura.E.TORRE)
	c.em_pe_alvo = 1.0
	Som.toca("stinger1", -3)
	Som.em("cr_grito2", p + Vector3.UP * 2, 8.0, 80, 0.9, "Eco", 10.0)
	var tt := 0.0
	while tt < 9.0 and is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree(): return
		if Jogo.hud.lendo: continue
		var dt := get_process_delta_time()
		tt += dt
		if c.estado != Criatura.E.TORRE or j.morto: break
		if not Jogo.historia._na_torre: break
		var d: Vector3 = j.global_position - c.global_position
		d.y = 0
		c.rumo = atan2(-d.x, -d.z)
		c.rotation.y = lerp_angle(c.rotation.y, c.rumo, minf(1.0, dt * 6.0))
		if tt > 1.5:
			c.vel = 1.5
			c.global_position += d.normalized() * minf(1.5 * dt, maxf(0.0, d.length() - 0.9))
		if d.length() < 1.45 and tt > 2.2:
			Jogo.historia.pego()
			return
	_subindo = false
	if c.estado == Criatura.E.TORRE:
		Jogo.anomalias._piscar(j, 0.3)
		c.esconder()
	t_ataque = minf(t_ataque, 14.0)


func _livre(p: Vector3) -> bool:
	if absf(p.x) > 480 or absf(p.z) > 480: return false
	for i in Mundo.arvores_perto(p, 1.5):
		return false
	return true


func emboscada(d: float) -> void:
	var j = Jogo.jogador
	var c := _cr()
	if c.estado in [Criatura.E.CACA, Criatura.E.ATAQUE, Criatura.E.TORRE] or c.morta:
		return
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	for t in 12:
		var p: Vector3 = j.global_position + fr.normalized().rotated(Vector3.UP, PI * 0.75 * (1.0 if randf() < 0.5 else -1.0) + randf_range(-0.8, 0.8)) * d
		if _livre(p) or t == 11:
			c.colocar(p, j.global_position)
			c.ultimo_visto = j.global_position
			c.livre_ate = Time.get_ticks_msec() / 1000.0 + 1.2
			c.muda(Criatura.E.CACA)
			_t_caca = 0.0
			Som.toca("stinger3", -5)
			return


## uma voz chama, fora do caminho
func chamar(qual: String = "") -> void:
	var j = Jogo.jogador
	var a := randf() * TAU
	var d := randf_range(26.0, 40.0)
	pos_voz = Mundo.chao(j.global_position.x + cos(a) * d, j.global_position.z + sin(a) * d)
	var op := ["v_alex1", "v_alex2", "v_socorro", "v_vivo", "v_cintos", "v_ruth5"]
	var v: String = qual if qual != "" else op[randi() % op.size()]
	var txt := {"v_alex1": "Alex...", "v_alex2": "Alex? Cadê você?", "v_socorro": "Socorro... me ajuda... por aqui...", "v_vivo": "Alex! Eu tô aqui! Tô vivo!", "v_cintos": "Apertem os cintos.", "v_ruth5": "Alex... sou eu, Ruth..."}
	silencio_alvo = 1.0
	chamando = 16.0
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree() or Jogo.jogador == null: return
	Som.em(v, pos_voz + Vector3.UP * 1.6, 6.0, 120, randf_range(0.97, 1.02), "Eco", 13.0)
	Jogo.falar("uma voz, entre as árvores", txt.get(v, ""), 3.5)
	j.medo = maxf(j.medo, 0.45)


## o jogador gritou (Q)
func respondeu() -> void:
	var j = Jogo.jogador
	var c := _cr()
	Jogo.chamados += 1
	Jogo.falar("você", ["Tem alguém aí?!", "Ei! Aqui! Socorro!", "Quem tá aí?!"][randi() % 3], 2.2)
	j.ruido = 70.0
	if Jogo.etapa < 5:
		if Jogo.etapa == 2 and randf() < 0.6:
			await get_tree().create_timer(2.4, false).timeout
			if Jogo.jogador: Passaros.revoada(Jogo.floresta, j.global_position + Vector3(randf_range(-40, 40), 16, randf_range(-40, 40)), 14, Vector3(0.2, 0.3, 1.0))
		return
	chamando = 0.0
	await get_tree().create_timer(2.0, false).timeout
	if Jogo.jogador == null or j.morto: return
	if Jogo.etapa == 7:
		t_ataque = minf(t_ataque, 2.0)
	else:
		Som.em("v_alex1", j.global_position + j.cam.global_transform.basis.z * 7.0, 5.0, 60, 0.85, "Eco", 8.0)
		Jogo.falar("atrás de você", "Alex...", 2.5)
		j.medo = maxf(j.medo, 0.7)
		if c.estado == Criatura.E.OCULTO: alivio = minf(alivio, 3.0)


# ------------------------------------------------------------------ paisagem sonora
func _sons(dt: float, j) -> void:
	silencio = move_toward(silencio, silencio_alvo if ligado else 0.0, dt * (0.55 if silencio_alvo > silencio else 0.10))
	var vivo := 1.0 - silencio
	var cl: Clima = Jogo.floresta.clima
	var dentro := 0.35 if j.abrigado else 1.0
	var dia: float = cl.dia
	Som.camada("amb_vento", (0.34 + 0.10 * sin(Time.get_ticks_msec() * 0.0002) + 0.16 * cl.neve) * dentro * lerpf(0.5, 1.0, vivo), 0.2)
	Som.camada("amb_dia", 0.30 * dia * vivo * dentro if Jogo.etapa < 4 or Jogo.etapa >= 8 else 0.0, 0.3)
	Som.camada("amb_drone", (0.10 + 0.36 * silencio) * (1.0 - dia * 0.85) + 0.2 * j.medo, 0.15, "Musica")
	Som.camada("mus_tensao", clampf(tensao * 0.4 + silencio * 0.14, 0.0, 0.42) * (1.0 - dia * 0.8), 0.10, "Musica")
	var c := _cr()
	var ca: bool = c != null and (c.estado == Criatura.E.CACA or _subindo) and not j.morto
	if Jogo.etapa >= 6: Som.camada("mus_caca", 0.62 if ca else 0.0, 0.8 if ca else 0.22, "Musica")
	var cor: float = clampf((j.medo - 0.6) * 0.6, 0.0, 0.22)
	Som.camada("v_coro", cor if Jogo.etapa >= 5 else 0.0, 0.1)
	t_fauna -= dt
	if t_fauna <= 0.0:
		t_fauna = randf_range(9.0, 24.0)
		if not Jogo.flags.get("vivo", false): return
		var a := randf() * TAU
		var p: Vector3 = j.global_position + Vector3(cos(a), 0.3, sin(a)) * randf_range(28, 60)
		if dia > 0.5 and vivo > 0.6:
			var q: String = ["corvo1", "corvo2", "corvo3", "galho1", "galho3"][randi() % 5]
			Som.em(q, p + Vector3.UP * 8.0, -5.0, 130, randf_range(0.93, 1.05), "Eco", 12.0)
		elif dia < 0.3 and vivo > 0.5:
			var q: String = ["coruja", "coruja2", "galho1", "galho3", "raposa"][randi() % 5]
			Som.em(q, p, -3.0 if q != "raposa" else -7.0, 130, randf_range(0.93, 1.05), "Eco", 12.0)
		elif silencio > 0.8 and randf() < 0.5:
			Som.em("galho%d" % randi_range(1, 4), j.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(10, 20), -6.0, 60)