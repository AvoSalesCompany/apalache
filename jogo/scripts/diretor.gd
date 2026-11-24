class_name Diretor
extends Node
## Cerebro grande. Mede a tensao, abre e fecha o cerco, cala os grilos,
## chama o jogador pelo nome. Nunca conta a posicao exata para a criatura.

var tensao := 0.0            # 0..1
var alivio := 40.0           # segundos de descanso restantes
var ligado := false
var silencio := 0.0          # 0 mata viva .. 1 mata muda
var silencio_alvo := 0.0
var t_voz := 60.0
var t_fauna := 8.0
var t_luzes := 0.0
var chamando := 0.0          # janela em que responder e fatal
var pos_voz := Vector3.ZERO
var agressao := 0.0
var _luzes := []
var _t_est := 0.0


func _cr() -> Criatura:
	return Jogo.criatura


func _ready() -> void:
	_faz_luzes()


func reset() -> void:
	tensao = 0.0
	alivio = 35.0
	silencio = 0.0
	silencio_alvo = 0.0
	t_voz = 45.0
	chamando = 0.0
	if _cr(): _cr().esconder()


func _process(dt: float) -> void:
	var j = Jogo.jogador
	if j == null or Jogo.floresta == null or not Jogo.floresta.visible:
		return
	_sons(dt, j)
	if not ligado or j.morto:
		return
	_luzes_anda(dt, j)
	var c := _cr()
	agressao = clampf(Jogo.etapa / 8.0 + Jogo.chamados * 0.06, 0.0, 1.0)
	c.agressao = agressao
	if j.travado and not j.so_olhar:
		return
	# tensao
	var ganho := 0.0
	if c.visible:
		var d := c.dist_jog()
		ganho = clampf(1.0 - d / 60.0, 0.0, 1.0) * 0.05
		if c.estado == Criatura.E.CACA: ganho += 0.06
	if ganho > 0.0: tensao = minf(1.0, tensao + ganho * dt)
	else: tensao = maxf(0.0, tensao - dt * 0.018)
	# silencio: a mata cala quando ele esta perto
	var perto := c.visible and c.dist_jog() < 48.0
	silencio_alvo = 1.0 if perto or chamando > 0.0 else 0.0
	_t_est -= dt
	if c.estado == Criatura.E.OCULTO:
		alivio -= dt
		if alivio <= 0.0:
			_abrir(j, c)
	elif c.estado in [Criatura.E.RONDA, Criatura.E.PROCURA, Criatura.E.INVESTIGA]:
		# ja apertou demais: manda embora
		if tensao > 0.85 or c.t_estado > 55.0:
			tensao *= 0.6
			alivio = lerpf(75.0, 38.0, agressao)
			c.muda(Criatura.E.RECUA)
	if c.estado == Criatura.E.RECUA:
		alivio = maxf(alivio, lerpf(50.0, 26.0, agressao))
	# voz
	t_voz -= dt
	chamando = maxf(0.0, chamando - dt)
	if chamando > 0.0 and Vector2(j.global_position.x - pos_voz.x, j.global_position.z - pos_voz.z).length() < 9.0:
		chamando = 0.0
		Jogo.falar("", "Não tem ninguém aqui.", 2.5)
		emboscada(16.0)
	if t_voz <= 0.0 and c.estado in [Criatura.E.OCULTO, Criatura.E.OBSERVA] and not j.abrigado and Jogo.etapa >= 2:
		t_voz = randf_range(70.0, 130.0) * lerpf(1.1, 0.7, agressao)
		chamar()


func _abrir(j, c: Criatura) -> void:
	if j.abrigado:
		alivio = 12.0
		return
	if Jogo.etapa < 2:
		alivio = 20.0
		return
	# observa de longe ou ronda
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	fr = fr.normalized()
	if randf() < lerpf(0.75, 0.30, agressao):
		for t in 12:
			var a := randf_range(-0.75, 0.75)
			var d := randf_range(24.0, 38.0)
			var p: Vector3 = j.global_position + fr.rotated(Vector3.UP, a) * d
			if _livre(p) and Mundo.obstrucao(j.cam.global_position, Mundo.chao(p.x, p.z) + Vector3.UP * 1.6) < 0.5:
				c.colocar(p, j.global_position)
				c.muda(Criatura.E.OBSERVA)
				alivio = 45.0
				return
	var a2 := PI + randf_range(-1.0, 1.0)
	var p2: Vector3 = j.global_position + fr.rotated(Vector3.UP, a2) * randf_range(38.0, 52.0)
	if _livre(p2):
		c.colocar(p2, j.global_position)
		c.muda(Criatura.E.RONDA)
	else:
		alivio = 4.0


func _livre(p: Vector3) -> bool:
	if absf(p.x) > 480 or absf(p.z) > 480: return false
	if Mundo.dist(Mundo.RODOVIA, p.x, p.z) < 12.0: return false
	for i in Mundo.arvores_perto(p, 1.5):
		return false
	return true


func emboscada(d: float) -> void:
	var j = Jogo.jogador
	var c := _cr()
	if c.estado in [Criatura.E.CACA, Criatura.E.ATAQUE, Criatura.E.TORRE]:
		return
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	for t in 10:
		var p: Vector3 = j.global_position + fr.normalized().rotated(Vector3.UP, PI + randf_range(-0.9, 0.9)) * d
		if _livre(p) or t == 9:
			c.colocar(p, j.global_position)
			c.ultimo_visto = j.global_position
			c.livre_ate = Time.get_ticks_msec() / 1000.0 + 1.5
			c.muda(Criatura.E.CACA)
			Som.toca("stinger1", -3)
			return


## uma voz chama, fora do caminho
func chamar(qual: String = "") -> void:
	var j = Jogo.jogador
	var a := randf() * TAU
	var d := randf_range(26.0, 40.0)
	pos_voz = Mundo.chao(j.global_position.x + cos(a) * d, j.global_position.z + sin(a) * d)
	var op := ["v_alex1", "v_alex2", "v_socorro"]
	if Jogo.etapa >= 4: op += ["v_vivo", "v_cintos"]
	if Jogo.etapa >= 6: op += ["v_impacto"]
	var v: String = qual if qual != "" else op[randi() % op.size()]
	var txt := {"v_alex1": "Alex...", "v_alex2": "Alex? Cadê você?", "v_socorro": "Socorro... me ajuda... por aqui...", "v_vivo": "Alex! Eu tô aqui! Tô vivo!", "v_cintos": "Apertem os cintos.", "v_impacto": "Posição... de impacto."}
	silencio_alvo = 1.0
	chamando = 16.0
	await get_tree().create_timer(2.2).timeout
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
	if not ligado:
		return
	if chamando > 0.0 or (c.visible and c.dist_jog() < 60.0) or Jogo.chamados >= 2:
		var era := chamando > 0.0
		chamando = 0.0
		await get_tree().create_timer(1.8).timeout
		if Jogo.jogador == null or j.morto: return
		if c.visible and c.dist_jog() < 60.0 and c.estado != Criatura.E.TORRE:
			c.ultimo_visto = j.global_position
			c.muda(Criatura.E.CACA)
		else:
			if era: Som.em("v_alex1", j.global_position - j.cam.global_transform.basis.z * -7.0, 4.0, 60, 0.8)
			await get_tree().create_timer(1.2).timeout
			if Jogo.jogador == null or j.morto: return
			emboscada(24.0)
	else:
		await get_tree().create_timer(2.6).timeout
		if Jogo.jogador == null: return
		var d: Vector3 = -j.cam.global_transform.basis.z * 60.0
		Som.em("v_alex1", j.global_position + d, 4.0, 160, 0.9, "Eco", 16.0)
		Jogo.falar("muito longe", "Alex...", 3.0)
		j.medo = maxf(j.medo, 0.5)
		alivio = minf(alivio, 14.0)


# ------------------------------------------------------------------ luzes falsas
func _faz_luzes() -> void:
	for i in 4:
		var n := Node3D.new()
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.11
		s.height = 0.22
		m.mesh = s
		m.material_override = Mat.liso(Color.BLACK, 0.5, 0, Color(1.0, 0.62, 0.25), 8.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(m)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 0.9
		l.omni_range = 8.0
		l.light_volumetric_fog_energy = 5.0
		n.add_child(l)
		n.visible = false
		add_child(n)
		_luzes.append({"n": n, "f": randf() * TAU, "l": l, "m": m})


func _luzes_anda(dt: float, j) -> void:
	var c2 := Mundo.LUZES
	var dj := Vector2(j.global_position.x, j.global_position.z).distance_to(c2)
	var on: bool = Jogo.etapa >= 6 and dj < 110.0 and not Jogo.flags.get("luzes_fim", false)
	t_luzes += dt
	for i in _luzes.size():
		var q: Dictionary = _luzes[i]
		q.n.visible = on
		if not on: continue
		var a: float = q.f + t_luzes * (0.14 + i * 0.03)
		var p := Vector3(c2.x + cos(a) * (6.0 + i * 3.0), 0, c2.y + sin(a * 0.8) * (6.0 + i * 3.0))
		p.y = Mundo.altura(p.x, p.z) + 1.7 + sin(t_luzes * 0.9 + q.f) * 0.5
		q.n.global_position = p
		q.l.light_energy = 0.9 + 0.35 * sin(t_luzes * 3.1 + q.f * 5.0)
	if on and dj < 13.0:
		Jogo.flags["luzes_fim"] = true
		Som.toca("stinger3", -4)
		for q in _luzes: q.n.visible = false
		Jogo.falar("", "As luzes se apagam todas ao mesmo tempo.", 3.0)
		j.frio = minf(95.0, j.frio + 18.0)
		get_tree().create_timer(1.6).timeout.connect(func(): emboscada(11.0))


# ------------------------------------------------------------------ paisagem sonora
func _sons(dt: float, j) -> void:
	silencio = move_toward(silencio, silencio_alvo if ligado else 0.0, dt * (0.55 if silencio_alvo > silencio else 0.10))
	var vivo := 1.0 - silencio
	var dentro := 0.45 if j.abrigado else 1.0
	Som.camada("amb_vento", (0.30 + 0.10 * sin(Time.get_ticks_msec() * 0.0002)) * dentro * lerpf(0.45, 1.0, vivo), 0.2)
	Som.camada("amb_insetos", 0.22 * vivo * dentro, 0.3)
	Som.camada("amb_drone", 0.10 + 0.36 * silencio + 0.2 * j.medo, 0.15, "Musica")
	Som.camada("mus_tensao", clampf(tensao * 0.4 + silencio * 0.14, 0.0, 0.42), 0.10, "Musica")
	var c := _cr()
	var ca = c != null and c.estado == Criatura.E.CACA and not j.morto
	Som.camada("mus_caca", 0.62 if ca else 0.0, 0.8 if ca else 0.22, "Musica")
	var cor: float = clampf((j.medo - 0.6) * 0.6, 0.0, 0.22)
	Som.camada("v_coro", cor if Jogo.etapa >= 4 else 0.0, 0.1)
	t_fauna -= dt
	if t_fauna <= 0.0:
		t_fauna = randf_range(9.0, 26.0)
		if vivo > 0.7 and Jogo.flags.get("vivo", false):
			var a := randf() * TAU
			var p: Vector3 = j.global_position + Vector3(cos(a), 0.3, sin(a)) * randf_range(28, 60)
			var q: String = ["coruja", "coruja2", "galho1", "galho3", "arbusto", "raposa", "coruja"][randi() % 7]
			Som.em(q, p, -3.0 if q != "raposa" else -7.0, 130, randf_range(0.93, 1.05), "Eco", 12.0)
		elif silencio > 0.8 and randf() < 0.5:
			var a := randf() * TAU
			Som.em("galho%d" % randi_range(1, 4), j.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(10, 20), -6.0, 60)
