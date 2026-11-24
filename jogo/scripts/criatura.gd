class_name Criatura
extends Node3D
## O CHAMADOR. Cervo errado de longe, coisa de pe quando caca, voz de quem morreu.
## Cerebro pequeno (este script): sentidos e corpo.
## Cerebro grande (diretor.gd): decide quando ele aparece e quando recua.

# nome, pai, posicao na pose original (quadrupede, olhando para -Z)
const OSSOS := [
	["bacia", "", Vector3(0, 1.28, 0.50)],
	["lombo", "bacia", Vector3(0, 1.32, 0.12)],
	["peito", "lombo", Vector3(0, 1.31, -0.18)],
	["pesc1", "peito", Vector3(0, 1.36, -0.55)],
	["pesc2", "pesc1", Vector3(0, 1.72, -0.80)],
	["cabeca", "pesc2", Vector3(0, 2.00, -0.94)],
	["mandib", "cabeca", Vector3(0, 1.95, -0.96)],
	["ombro_e", "peito", Vector3(-0.17, 1.22, -0.44)],
	["cotov_e", "ombro_e", Vector3(-0.20, 0.78, -0.36)],
	["punho_e", "cotov_e", Vector3(-0.19, 0.40, -0.44)],
	["ombro_d", "peito", Vector3(0.17, 1.22, -0.44)],
	["cotov_d", "ombro_d", Vector3(0.20, 0.78, -0.36)],
	["punho_d", "cotov_d", Vector3(0.19, 0.40, -0.44)],
	["coxa_e", "bacia", Vector3(-0.14, 1.22, 0.54)],
	["joelho_e", "coxa_e", Vector3(-0.18, 0.80, 0.36)],
	["jarrete_e", "joelho_e", Vector3(-0.17, 0.42, 0.74)],
	["coxa_d", "bacia", Vector3(0.14, 1.22, 0.54)],
	["joelho_d", "coxa_d", Vector3(0.18, 0.80, 0.36)],
	["jarrete_d", "joelho_d", Vector3(0.17, 0.42, 0.74)],
]

enum E { OCULTO, OBSERVA, RONDA, INVESTIGA, CACA, PROCURA, RECUA, ATAQUE, TORRE }

signal pegou
signal mudou(estado: int)

var estado: int = E.OCULTO
var esq: Skeleton3D
var corpo: MeshInstance3D
var olhos: Array = []
var mat_olho: StandardMaterial3D
var mat_pele: ShaderMaterial
var idx := {}
var desc := {}                 # posicao local de repouso

var em_pe := 0.0               # 0 cervo .. 1 de pe
var em_pe_alvo := 0.0
var vel := 0.0
var fase := 0.0
var alvo := Vector3.ZERO
var ultimo_visto := Vector3.ZERO
var deteccao := 0.0            # 0..1
var t_estado := 0.0
var t_visto := 0.0             # quanto tempo o jogador encara
var torce := 0.0
var torce_alvo := 0.0
var t_torce := 0.0
var t_passo := 0.0
var t_som := 0.0
var boca := 0.0
var agressao := 0.0            # cresce com a historia 0..1
var livre_ate := 0.0
var rumo := 0.0
var _pontos: Array = []        # pontos de ronda
var torre_t := 0.0


func _ready() -> void:
	esq = Skeleton3D.new()
	add_child(esq)
	for i in OSSOS.size():
		var o: Array = OSSOS[i]
		esq.add_bone(o[0])
		idx[o[0]] = i
		var pai: int = idx[o[1]] if o[1] != "" else -1
		var loc: Vector3 = o[2]
		if pai >= 0:
			esq.set_bone_parent(i, pai)
			loc -= OSSOS[pai][2]
		desc[o[0]] = loc
		esq.set_bone_rest(i, Transform3D(Basis.IDENTITY, loc))
	esq.reset_bone_poses()
	corpo = MeshInstance3D.new()
	corpo.mesh = load("res://dados/criatura.res")
	mat_pele = ShaderMaterial.new()
	mat_pele.shader = load("res://shaders/criatura.gdshader")
	corpo.material_override = mat_pele
	var skin := Skin.new()
	for i in OSSOS.size():
		skin.add_bind(i, Transform3D(Basis.IDENTITY, OSSOS[i][2]).affine_inverse())
	corpo.skin = skin
	esq.add_child(corpo)
	corpo.skeleton = NodePath("..")
	corpo.custom_aabb = AABB(Vector3(-2, -0.5, -2.5), Vector3(4, 4.5, 5))
	# olhos: so devolvem a luz da lua quando encaram
	mat_olho = StandardMaterial3D.new()
	mat_olho.albedo_color = Color(0.02, 0.02, 0.02)
	mat_olho.emission_enabled = true
	mat_olho.emission = Color(0.86, 0.95, 0.80)
	mat_olho.emission_energy_multiplier = 0.0
	mat_olho.roughness = 0.1
	var ba := BoneAttachment3D.new()
	ba.bone_name = "cabeca"
	esq.add_child(ba)
	for sx in [-1.0, 1.0]:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.021
		sp.height = 0.042
		m.mesh = sp
		m.material_override = mat_olho
		m.position = Vector3(0.060 * sx, 0.026, -0.228)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(m)
		olhos.append(m)
	esconder()


func _rot(nome: String, e: Vector3) -> void:
	esq.set_bone_pose_rotation(idx[nome], Quaternion.from_euler(e))


func esconder() -> void:
	estado = E.OCULTO
	visible = false
	vel = 0.0
	deteccao = 0.0
	mudou.emit(estado)


func muda(e: int) -> void:
	if estado == e:
		return
	estado = e
	t_estado = 0.0
	t_visto = 0.0
	visible = e != E.OCULTO
	match e:
		E.OBSERVA:
			em_pe_alvo = 0.0
			vel = 0.0
		E.RONDA:
			em_pe_alvo = 0.0 if randf() < 0.5 else 1.0
			_pontos.clear()
		E.INVESTIGA:
			em_pe_alvo = 1.0
		E.CACA:
			em_pe_alvo = 0.0
			deteccao = 1.0
			Som.em("cr_grito%d" % randi_range(1, 2), global_position + Vector3.UP * 2, 8.0, 160, randf_range(0.9, 1.05), "Eco", 14.0)
		E.PROCURA:
			em_pe_alvo = 1.0
			_pontos.clear()
		E.RECUA:
			em_pe_alvo = 0.0
			deteccao = 0.0
	mudou.emit(e)


func colocar(p: Vector3, olhar: Vector3) -> void:
	global_position = Mundo.chao(p.x, p.z)
	var d := olhar - p
	rumo = atan2(-d.x, -d.z)
	rotation.y = rumo
	mat_pele.set_shader_parameter("dissolve", 0.0)
	reset_physics_interpolation()


func dist_jog() -> float:
	return global_position.distance_to(Jogo.jogador.global_position) if Jogo.jogador else 999.0


## o jogador esta olhando para ele, com visada limpa?
func sendo_visto() -> bool:
	var j = Jogo.jogador
	if j == null or not visible:
		return false
	var cam: Camera3D = j.cam
	var c := global_position + Vector3.UP * 1.6
	var d := (c - cam.global_position)
	var l := d.length()
	if l > 95.0:
		return false
	if -cam.global_transform.basis.z.dot(d / l) < 0.80:
		return false
	return Mundo.obstrucao(cam.global_position, c) < 0.9


# ------------------------------------------------------------------ sentidos
func _sentir(dt: float) -> void:
	var j = Jogo.jogador
	if j == null or j.morto or j.travado:
		return
	var p: Vector3 = j.global_position
	var d := dist_jog()
	var ganho := 0.0
	# visao
	var ate := (p - global_position)
	ate.y = 0
	var frente := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	var ang := rad_to_deg(frente.angle_to(ate.normalized())) if d > 0.1 else 0.0
	var alc := lerpf(13.0, 34.0, j.luz)
	if j.agachado: alc *= 0.55
	alc *= lerpf(1.0, 0.16, j.escondido)
	if estado == E.CACA: alc *= 1.9
	if j.lanterna.luz.visible and j.escondido < 0.6:
		alc = maxf(alc * 1.25, 30.0 if j.lanterna.ilumina(global_position + Vector3.UP * 1.5) < 0.05 else 44.0)
	if d < alc and ang < 72.0:
		var ob := Mundo.obstrucao(global_position + Vector3.UP * 2.0, p + Vector3.UP * (0.9 if j.agachado else 1.5))
		var vis := (1.0 - d / alc) * clampf(1.2 - ob, 0.0, 1.0)
		if vis > 0.0:
			ganho += 0.25 + vis * 1.7
			ultimo_visto = p
	if d < 2.2 and j.escondido < 0.6:
		ganho += 3.0
		ultimo_visto = p
	# audicao
	if j.ruido > 0.5 and d < j.ruido:
		var f: float = 1.0 - d / j.ruido
		ganho += f * 0.9
		if f > 0.25 or randf() < 0.3:
			ultimo_visto = p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * d * 0.22
	if ganho > 0.0:
		deteccao = minf(1.0, deteccao + ganho * dt * lerpf(0.55, 1.0, agressao))
	else:
		deteccao = maxf(0.0, deteccao - dt * (0.12 if estado == E.CACA else 0.16))


## barulho pontual (pedra, grito, galho)
func ouvir(p: Vector3, alcance: float, forte: bool = false) -> void:
	if estado in [E.OCULTO, E.CACA, E.ATAQUE, E.RECUA, E.TORRE] or Jogo.etapa < 4:
		return
	if global_position.distance_to(p) < alcance:
		ultimo_visto = p
		if forte:
			deteccao = maxf(deteccao, 0.6)
		muda(E.INVESTIGA)


func _physics_process(dt: float) -> void:
	if estado == E.OCULTO or Jogo.jogador == null or (Jogo.hud and Jogo.hud.lendo):
		return
	t_estado += dt
	match estado:
		E.OBSERVA: _observa(dt)
		E.RONDA: _ronda(dt)
		E.INVESTIGA: _investiga(dt)
		E.CACA: _caca(dt)
		E.PROCURA: _procura(dt)
		E.RECUA: _recua(dt)
		E.ATAQUE: vel = 0.0
		E.TORRE: pass
	if estado in [E.RONDA, E.INVESTIGA, E.CACA, E.PROCURA]:
		_sentir(dt)
	if estado != E.TORRE:
		global_position.y = lerpf(global_position.y, Mundo.altura(global_position.x, global_position.z), minf(1.0, dt * 10.0))
	rotation.y = lerp_angle(rotation.y, rumo, minf(1.0, dt * (5.0 if estado == E.CACA else 2.6)))
	_sons(dt)


func _ir(p: Vector3, v: float, dt: float) -> float:
	var d := p - global_position
	d.y = 0
	var l := d.length()
	if l < 0.4:
		vel = move_toward(vel, 0.0, dt * 8.0)
		return l
	d /= l
	# desvia de troncos
	var des := Vector3.ZERO
	for i in Mundo.arvores_perto(global_position + d * 1.4, 2.6):
		var t := Vector3(Mundo.dados.arv[i * 6], 0, Mundo.dados.arv[i * 6 + 2])
		var r := Vector3(global_position.x, 0, global_position.z) - t
		var rl := maxf(r.length() - Mundo.raio_tronco(i), 0.15)
		if rl < 1.9:
			var lado := Vector3(-d.z, 0, d.x)
			if lado.dot(r) < 0: lado = -lado
			des += (r.normalized() * 0.5 + lado * 0.8) * (1.9 - rl) / 1.9
	d = (d + des * 1.1).normalized()
	vel = move_toward(vel, v, dt * 9.0)
	global_position += d * vel * dt
	rumo = atan2(-d.x, -d.z)
	return l


func _encara() -> void:
	var d: Vector3 = Jogo.jogador.global_position - global_position
	rumo = atan2(-d.x, -d.z)


func _observa(dt: float) -> void:
	vel = move_toward(vel, 0.0, dt * 6.0)
	_encara()
	if sendo_visto():
		t_visto += dt
	var d := dist_jog()
	if t_visto > 2.2:
		em_pe_alvo = 1.0          # levanta, devagar, sem tirar os olhos
	if t_visto > 4.4 or d < (13.0 if Jogo.etapa >= 4 else 24.0) or t_estado > 40.0:
		if d < 11.0 and Jogo.etapa >= 4:
			ultimo_visto = Jogo.jogador.global_position
			muda(E.CACA)
		else:
			muda(E.RECUA)


func _ronda(dt: float) -> void:
	var jp: Vector3 = Jogo.jogador.global_position
	if _pontos.is_empty():
		for i in 3:
			var a := randf() * TAU
			var r := randf_range(14, 34)
			_pontos.append(jp + Vector3(cos(a) * r, 0, sin(a) * r))
	if _ir(_pontos[0], lerpf(1.5, 2.1, agressao), dt) < 1.5:
		_pontos.pop_front()
		if randf() < 0.4: em_pe_alvo = 1.0 - em_pe_alvo
	if deteccao > 0.45:
		muda(E.INVESTIGA)
	if deteccao >= 1.0:
		muda(E.CACA)


func _investiga(dt: float) -> void:
	var l := _ir(ultimo_visto, lerpf(2.2, 2.9, agressao), dt)
	if deteccao >= 1.0:
		muda(E.CACA)
	elif l < 2.0 or t_estado > 14.0:
		muda(E.PROCURA)


func _caca(dt: float) -> void:
	var j = Jogo.jogador
	var v := lerpf(4.7, 5.5, agressao)
	var d := dist_jog()
	if j.escondido > 0.7 and d > 5.0 and deteccao < 0.7:
		v = 2.6
	_ir(ultimo_visto if deteccao < 0.35 else j.global_position, v, dt)
	if deteccao > 0.35:
		ultimo_visto = j.global_position
	if d < 1.75 and not j.morto and not j.travado and Time.get_ticks_msec() / 1000.0 > livre_ate:
		muda(E.ATAQUE)
		pegou.emit()
		return
	if deteccao <= 0.12 and global_position.distance_to(ultimo_visto) < 3.0:
		muda(E.PROCURA)
	if t_estado > 34.0:
		muda(E.RECUA)


func _procura(dt: float) -> void:
	if _pontos.is_empty():
		for i in 3:
			var a := randf() * TAU
			_pontos.append(ultimo_visto + Vector3(cos(a), 0, sin(a)) * randf_range(4, 11))
	if _ir(_pontos[0], 1.7, dt) < 1.2:
		_pontos.pop_front()
	if deteccao >= 0.9:
		muda(E.CACA)
	elif t_estado > lerpf(13.0, 20.0, agressao):
		muda(E.RECUA)


func _recua(dt: float) -> void:
	var f: Vector3 = global_position - Jogo.jogador.global_position
	f.y = 0
	_ir(global_position + f.normalized() * 20.0, 6.5, dt)
	if t_estado > 1.2:
		mat_pele.set_shader_parameter("dissolve", clampf((t_estado - 1.2) / 1.6, 0.0, 1.0) * 0.9)
	if t_estado > 3.0 or f.length() > 90.0:
		esconder()


func _sons(dt: float) -> void:
	var d := dist_jog()
	t_passo -= dt * vel
	if t_passo <= 0.0 and vel > 0.4:
		t_passo = 1.5 if em_pe > 0.5 else 1.1
		Som.em("cr_passo%d" % randi_range(1, 3), global_position, 1.0 if vel > 3.0 else -5.0, 70, randf_range(0.85, 1.1), "Eco", 7.0)
		if randf() < 0.13:
			Som.em("galho%d" % randi_range(1, 4), global_position, -2.0, 80)
	t_som -= dt
	if t_som <= 0.0:
		t_som = randf_range(2.6, 6.0)
		var q: String = ["cr_estalos", "cr_rosna1", "cr_respira", "cr_rosna2"][randi_range(0, 3)]
		if estado == E.CACA:
			q = "cr_rosna1"
			t_som = 1.6
		if estado != E.OBSERVA and d < 45.0:
			Som.em(q, global_position + Vector3.UP * 2.0, -3.0, 45, randf_range(0.8, 1.0), "Eco", 5.0)
			if q.begins_with("cr_estalos"):
				torce_alvo = randf_range(-1.0, 1.0)


# ------------------------------------------------------------------ animacao
func _process(dt: float) -> void:
	if not visible:
		return
	em_pe = move_toward(em_pe, em_pe_alvo, dt * (0.55 if estado == E.OBSERVA else 1.6))
	var p := smoothstep(0.0, 1.0, em_pe)
	fase += dt * (vel * lerpf(2.1, 1.75, p) + 0.0001)
	var amp := clampf(vel / 3.2, 0.0, 1.25)
	var corre := clampf((vel - 3.2) / 2.0, 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var resp := sin(t * 1.7) * 0.02
	t_torce -= dt
	if t_torce <= 0.0:
		t_torce = randf_range(0.7, 3.5)
		if randf() < 0.6: torce_alvo = randf_range(-0.5, 0.5)
	torce = lerpf(torce, torce_alvo, minf(1.0, dt * 14.0))
	var s := sin(fase)
	var c := cos(fase)
	var s2 := sin(fase * 2.0)

	# bacia: quadrupede -> de pe
	var alt_bacia := lerpf(0.0, 0.16, p) + absf(s) * 0.05 * amp - corre * 0.08 * (1.0 - p)
	esq.set_bone_pose_position(idx.bacia, desc.bacia + Vector3(0, alt_bacia, lerpf(0.0, -0.42, p)))
	_rot("bacia", Vector3(lerpf(corre * 0.10 * s, 1.12, p), s * 0.10 * amp, c * 0.06 * amp))
	_rot("lombo", Vector3(lerpf(-corre * 0.16 * s, 0.10, p) + resp, -s * 0.10 * amp, torce * 0.10))
	_rot("peito", Vector3(lerpf(resp, -0.28, p) + s2 * 0.03 * amp, -s * 0.12 * amp * p, -torce * 0.08))
	# pescoco e cabeca seguem o jogador
	var gy := 0.0
	var gx := 0.0
	if Jogo.jogador and Jogo.jogador.is_inside_tree():
		var loc: Vector3 = to_local(Jogo.jogador.global_position + Vector3.UP * 1.4)
		gy = clampf(atan2(-loc.x, -loc.z), -1.2, 1.2)
		gx = clampf(atan2(loc.y - lerpf(2.0, 2.5, p), Vector2(loc.x, loc.z).length()), -0.7, 0.5)
	_rot("pesc1", Vector3(lerpf(-0.05 + s2 * 0.05 * amp - corre * 0.35, -0.55, p), gy * 0.35, torce * 0.25 * p))
	_rot("pesc2", Vector3(lerpf(0.0, -0.45, p), gy * 0.30, torce * 0.35))
	_rot("cabeca", Vector3(lerpf(gx - 0.05, gx + 0.10, p) + randf_range(-0.01, 0.01), gy * 0.35, torce * (0.5 + 0.7 * p)))
	boca = move_toward(boca, 0.75 if estado in [E.CACA, E.ATAQUE] else 0.06 + 0.05 * sin(t * 0.7), dt * 3.0)
	_rot("mandib", Vector3(-boca, 0, torce * 0.08))
	# patas dianteiras / bracos
	for l in ["e", "d"]:
		var sg := -1.0 if l == "e" else 1.0
		var f := s * sg
		var g := maxf(0.0, c * sg)
		var ga := f * (0.62 + corre * 0.35) * amp
		# quadrupede
		var om := Vector3(ga, 0, 0)
		var co := Vector3(-g * 0.9 * amp, 0, 0)
		var pu := Vector3(g * 0.9 * amp, 0, 0)
		# de pe: bracos compridos pendurados para a frente
		var om2 := Vector3(-0.85 + ga * 0.45 + resp * 2.0, 0.0, sg * 0.20)
		var co2 := Vector3(0.45 - 0.2 * amp, 0, -sg * 0.10)
		var pu2 := Vector3(0.30 + 0.12 * sin(t * 2.3 + sg), 0, 0)
		if estado == E.ATAQUE:
			om2 = Vector3(0.9, 0, sg * 0.5)
			co2 = Vector3(0.5, 0, 0)
		_rot("ombro_" + l, om.lerp(om2, p))
		_rot("cotov_" + l, co.lerp(co2, p))
		_rot("punho_" + l, pu.lerp(pu2, p))
		# patas traseiras
		var f2 := -s * sg if p < 0.5 else s * sg
		var g2 := maxf(0.0, -c * sg) if p < 0.5 else maxf(0.0, c * sg)
		var ga2 := f2 * (0.55 + corre * 0.35) * amp
		_rot("coxa_" + l, Vector3(ga2 + lerpf(0.0, -0.72, p), 0, sg * 0.05 * p))
		_rot("joelho_" + l, Vector3(-g2 * 0.7 * amp + lerpf(0.0, -0.55, p), 0, 0))
		_rot("jarrete_" + l, Vector3(g2 * 0.8 * amp + lerpf(0.0, 0.42, p), 0, 0))
	# brilho dos olhos: so quando encara a camera
	var brilho := 0.0
	if Jogo.jogador:
		var cam: Camera3D = Jogo.jogador.cam
		var ba: Transform3D = esq.global_transform * esq.get_bone_global_pose(idx.cabeca)
		var d := (cam.global_position - ba.origin).normalized()
		brilho = pow(clampf(-ba.basis.z.dot(d), 0.0, 1.0), 3.0)
	mat_olho.emission_energy_multiplier = brilho * (5.0 if fmod(t, 5.3) > 0.12 else 0.0)


func altura_cabeca() -> Vector3:
	return (esq.global_transform * esq.get_bone_global_pose(idx.cabeca)).origin
