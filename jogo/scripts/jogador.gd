class_name Jogador
extends CharacterBody3D
## Primeira pessoa: andar, correr, agachar, esconder, frio, medo, pedras, bussola.

signal gritou

const V_ANDA := 2.35
const V_CORRE := 4.9
const V_AGACHA := 1.15

var cam: Camera3D
var _col: CollisionShape3D
var _cap: CapsuleShape3D
var vida := 100.0
var frio := 0.0
var folego := 100.0
var medo := 0.0
var luz := 0.0            # luar no corpo 0..1
var ruido := 0.0          # alcance do barulho (m)
var escondido := 0.0      # 0..1
var agachado := false
var morto := false
var travado := false      # cena/leitura: sem controle
var so_olhar := false     # pode olhar, nao andar
var na_agua := false
var abrigado := false     # dentro de cabana/torre (nao perde calor)
var esconderijo := false  # escondido a forca (mesa da torre)
var alvo: Interativo = null
var _segura := 0.0
var incl := 0.0
var _olho := 1.64
var _bob := 0.0
var _bob_amp := 0.0
var _passo := 0.0
var _ant := Vector3.ZERO
var _atu := Vector3.ZERO
var _tremor := 0.0
var _fov := 72.0
var _t_luz := 0.0
var _t_cor := 0.0
var _queda := 0.0
var _mergulho := 0.0
var _moita_t := 0.0
var _cansado := false
var _ar_t := 0.0
var _bus: Node3D
var _agulha: Node3D
var _bus_v := 0.0
var _roll := 0.0
var lanterna: Lanterna
var carrega: ObjetoFisico = null
var obj_alvo: ObjetoFisico = null
var olhar_forcado := Vector3.INF
var robo := {}            # comandos do teste automatico
var robotizado := false   # no teste, teclado e mouse reais sao ignorados


func _ready() -> void:
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.30
	_cap.height = 1.76
	_col = CollisionShape3D.new()
	_col.shape = _cap
	_col.position.y = 0.88
	add_child(_col)
	floor_max_angle = deg_to_rad(56)
	floor_snap_length = 0.45
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 72
	cam.near = 0.06
	cam.far = 1400
	add_child(cam)
	lanterna = Lanterna.new()
	add_child(lanterna)
	_faz_bussola()


func _faz_bussola() -> void:
	_bus = Node3D.new()
	cam.add_child(_bus)
	_bus.position = Vector3(0.14, -0.40, -0.36)
	_bus.rotation = Vector3(0.95, -0.15, 0)
	var m := Malha.new()
	m.tubo([Vector3(0, -0.008, 0), Vector3(0, 0.0, 0), Vector3(0, 0.008, 0)], [0.050, 0.055, 0.050], 24, 1, 1, Color(0, 0, 0.5), true)
	m.no(Mat.liso(Color(0.50, 0.36, 0.14), 0.28, 0.9), _bus)
	var f := Malha.new()
	f.tubo([Vector3(0, 0.0081, 0), Vector3(0, 0.0086, 0)], [0.046, 0.046], 24, 1, 1, Color(0, 0, 0.5), true)
	f.no(Mat.liso(Color(0.72, 0.70, 0.62), 0.8, 0, Color(0.55, 0.62, 0.55), 0.05), _bus)
	_agulha = Node3D.new()
	_bus.add_child(_agulha)
	var lub := Malha.new()
	lub.cx(Vector3(0, 0.011, -0.049), Vector3(0.004, 0.004, 0.012))
	lub.no(Mat.liso(Color(0.75, 0.04, 0.03), 0.4, 0, Color(0.6, 0.03, 0.02), 0.2), _bus)
	for q in [["N", Vector3(0, 0.0095, -0.034)], ["S", Vector3(0, 0.0095, 0.034)], ["L", Vector3(0.034, 0.0095, 0)], ["O", Vector3(-0.034, 0.0095, 0)]]:
		var l := Label3D.new()
		l.text = q[0]
		l.font_size = 48
		l.pixel_size = 0.00024
		l.modulate = Color(0.1, 0.05, 0.03) if q[0] != "N" else Color(0.55, 0.04, 0.03)
		l.outline_size = 0
		l.shaded = true
		l.position = q[1]
		l.rotation.x = -PI * 0.5
		_agulha.add_child(l)
	var a := Malha.new()
	a.cx(Vector3(0, 0.010, -0.012), Vector3(0.004, 0.002, 0.024))
	a.no(Mat.liso(Color(0.65, 0.03, 0.02), 0.4, 0, Color(0.5, 0.02, 0.01), 0.15), _agulha)
	var b := Malha.new()
	b.cx(Vector3(0, 0.010, 0.012), Vector3(0.004, 0.002, 0.024))
	b.no(Mat.liso(Color(0.9, 0.9, 0.9), 0.4), _agulha)
	_bus.visible = false


func por_em(p: Vector3, giro: float) -> void:
	global_position = p
	rotation.y = giro
	velocity = Vector3.ZERO
	_ant = p
	_atu = p
	incl = 0.0
	cam.global_position = p + Vector3.UP * _olho
	cam.rotation = Vector3(0, giro, 0)


func tremer(f: float) -> void:
	_tremor = maxf(_tremor, f)


func _ac(a: String) -> bool:
	if robo.has(a):
		return robo[a]
	return false if robotizado else Input.is_action_pressed(a)


func _eixo() -> Vector2:
	if robo.has("eixo"):
		return robo.eixo
	if robotizado:
		return Vector2.ZERO
	return Input.get_vector("esquerda", "direita", "frente", "tras")


func _unhandled_input(e: InputEvent) -> void:
	if travado or morto or robotizado:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := 0.0021 * Jogo.sens * (cam.fov / 72.0)
		rotation.y -= e.relative.x * s
		incl = clampf(incl - e.relative.y * s, -1.5, 1.5)
	if so_olhar:
		return
	if e.is_action_pressed("lanterna"):
		lanterna.alternar()
	elif e.is_action_pressed("gritar"):
		gritar()
	elif e.is_action_pressed("arremessar"):
		arremessar()
	elif e.is_action_pressed("curar"):
		curar()


func gritar() -> void:
	gritou.emit()


func curar() -> void:
	if vida > 95.0:
		Jogo.aviso.emit("Você não precisa de curativo agora")
		return
	if Jogo.gastar("curativo"):
		vida = minf(100.0, vida + 45.0)
		Som.toca("papel", -4)
		Jogo.aviso.emit("Você enfaixa o ferimento (%d restante)" % Jogo.tem("curativo"))
	else:
		Jogo.aviso.emit("Sem curativos")


func arremessar() -> void:
	if carrega:
		var c := carrega
		carrega = null
		c.gravity_scale = 1.0
		c.linear_velocity = -cam.global_transform.basis.z * clampf(11.0 - c.mass * 0.5, 4.0, 11.0) + Vector3.UP * 1.5
		c.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		Som.toca("arbusto", -16, 1.4)
		return
	if not Jogo.gastar("pedra"):
		return
	Som.toca("arbusto", -14, 1.4)
	var p := Pedra.new()
	Jogo.floresta.add_child(p)
	p.global_position = cam.global_position - cam.global_transform.basis.z * 0.4
	p.v = -cam.global_transform.basis.z * 15.0 + Vector3.UP * 2.5


func _physics_process(dt: float) -> void:
	_ant = _atu
	if morto:
		return
	var eixo := _eixo() if not (travado or so_olhar) else Vector2.ZERO
	var quer_ag := _ac("agachar") and not travado
	if quer_ag != agachado:
		if quer_ag or not test_move(global_transform.translated(Vector3.UP * 0.05), Vector3.UP * 0.75):
			agachado = quer_ag
			_cap.height = 1.0 if agachado else 1.76
			_col.position.y = _cap.height * 0.5
	var corre := _ac("correr") and eixo.y < -0.2 and not agachado and not _cansado and folego > 0.0
	var v := V_AGACHA if agachado else (V_CORRE if corre else V_ANDA)
	if frio > 75.0: v *= 0.88
	if vida < 35.0: v *= 0.86
	if na_agua: v *= 0.62
	var b := Basis(Vector3.UP, rotation.y)
	var d := b * Vector3(eixo.x, 0, eixo.y)
	if eixo.y > 0.1: v *= 0.75
	var chao := is_on_floor()
	var alvo_v := d * v
	var ac := 12.0 if chao else 2.0
	# mato fechado segura o passo
	if _moita_t > 0.25 and not agachado:
		alvo_v *= lerpf(1.0, 0.55, _moita_t)
	velocity.x = move_toward(velocity.x, alvo_v.x, ac * dt * maxf(1.0, v * 0.5))
	velocity.z = move_toward(velocity.z, alvo_v.z, ac * dt * maxf(1.0, v * 0.5))
	if chao:
		if _queda > 6.0:
			tremer(0.02 * _queda)
			Som.toca("queda_corpo", -2)
			if _queda > 11.0:
				ferir((_queda - 10.0) * 7.0)
		_queda = 0.0
		velocity.y = -0.5
		if _ac("pular") and not (travado or so_olhar) and not agachado and folego > 12.0:
			velocity.y = 4.1
			folego -= 8.0
			robo.erase("pular")
	else:
		velocity.y -= 13.0 * dt
		_queda = maxf(_queda, -velocity.y)
	move_and_slide()
	for k in get_slide_collision_count():
		var col := get_slide_collision(k)
		var rb = col.get_collider()
		if rb is RigidBody3D and col.get_normal().y < 0.6:
			var emp: Vector3 = -col.get_normal()
			emp.y = 0.0
			emp = emp.normalized()
			# leve acompanha o passo; pesado arrasta devagar
			var quer := v * clampf(7.0 / rb.mass, 0.22, 0.95)
			var ja: float = rb.linear_velocity.dot(emp)
			if ja < quer:
				rb.sleeping = false
				rb.apply_central_impulse((emp + Vector3.UP * 0.10) * (quer - ja) * rb.mass * 0.8)
				rb.apply_torque_impulse(Vector3.UP * randf_range(-0.05, 0.05) * rb.mass)
	_carregar(dt)
	# rede de seguranca: nunca atravessar o terreno
	var ty := Mundo.altura(global_position.x, global_position.z)
	if global_position.y < ty - 1.2:
		global_position.y = ty + 0.1
		velocity.y = 0.0
	global_position.x = clampf(global_position.x, -495, 495)
	global_position.z = clampf(global_position.z, -495, 495)
	_atu = global_position
	_corpo(dt, corre, chao)
	_sentidos(dt)
	_procura_alvo(dt)


func _carregar(dt: float) -> void:
	if carrega == null:
		return
	if not is_instance_valid(carrega) or morto or travado:
		if is_instance_valid(carrega): carrega.gravity_scale = 1.0
		carrega = null
		return
	var alvo_p := cam.global_position - cam.global_transform.basis.z * 1.25 - cam.global_transform.basis.y * 0.18
	var d := alvo_p - carrega.global_position
	if d.length() > 2.4:
		carrega.gravity_scale = 1.0
		carrega = null
		return
	carrega.linear_velocity = d * 11.0
	carrega.angular_velocity *= 0.86
	carrega.sleeping = false


func _corpo(dt: float, corre: bool, chao: bool) -> void:
	var vh := Vector2(velocity.x, velocity.z).length()
	# folego
	if corre and vh > 2.5:
		folego = maxf(0.0, folego - dt * (9.5 if frio < 70 else 14.0))
		if folego <= 0.0: _cansado = true
	else:
		folego = minf(100.0, folego + dt * (11.0 if vh < 0.3 else 7.0) * (0.6 if frio > 70 else 1.0))
		if folego > 32.0: _cansado = false
	# frio
	var ta: float = 0.085 * (0.45 if Jogo.tem("jaqueta") > 0 else 1.0)
	if na_agua: ta += 0.9
	if corre: ta -= 0.06
	if abrigado: ta = -0.15
	if not travado and Jogo.flags.get("vivo", false):
		frio = clampf(frio + ta * dt, 0.0, 100.0)
	if frio >= 99.0:
		ferir(dt * 0.9, true)
	# agua
	var dr := Mundo.dist(Mundo.RIO, global_position.x, global_position.z) if absf(global_position.y - Mundo.altura(global_position.x, global_position.z)) < 0.6 else 99.0
	na_agua = dr < 3.2 and _nivel_rio() > global_position.y + 0.08
	# passos
	_bob_amp = lerpf(_bob_amp, clampf(vh / V_CORRE, 0.0, 1.0) if chao else 0.0, minf(1.0, dt * 8.0))
	_bob += vh * dt * (1.75 if not agachado else 2.1)
	_passo += vh * dt
	var comp := 1.05 if agachado else (1.95 if corre else 1.45)
	if chao and _passo > comp and vh > 0.4:
		_passo = 0.0
		_som_passo(corre)
	# barulho que a criatura escuta
	var r := 0.0
	if vh > 0.4:
		r = 3.5 if agachado else (25.0 if corre else 10.0)
		if na_agua: r += 6.0
		if _sup() == "p_madeira" or _sup() == "p_metal": r *= 1.15
	if _cansado: r = maxf(r, 8.0)
	ruido = lerpf(ruido, r, minf(1.0, dt * 5.0))


func _nivel_rio() -> float:
	var q := Mundo.perto(Mundo.RIO, global_position.x, global_position.z)
	return lerpf(Mundo.RIO[q[1]][2], Mundo.RIO[q[1] + 1][2], q[2])


func _sup() -> String:
	var ty := Mundo.altura(global_position.x, global_position.z)
	if global_position.y > ty + 0.22:
		if Vector2(global_position.x, global_position.z).distance_to(Mundo.TORRE) < 5.0:
			return "p_madeira" if global_position.y > ty + 14.0 else "p_metal"
		if Vector2(global_position.x, global_position.z).distance_to(Mundo.POSTO) > 25.0:
			return "p_madeira"
	if na_agua: return "p_agua"
	if Mundo.dist(Mundo.RODOVIA, global_position.x, global_position.z) < 4.3: return "p_asfalto"
	if Vector2(global_position.x, global_position.z).distance_to(Mundo.POSTO) < 16.0: return "p_asfalto"
	return "p_folha"


func _som_passo(corre: bool) -> void:
	var db := -17.0 if agachado else (-5.0 if corre else -10.0)
	Som.varia(_sup(), 5, db, 0.10)
	if corre and _sup() == "p_folha" and randf() < 0.05:
		Som.varia("galho", 4, -8.0)
		if Jogo.criatura: Jogo.criatura.ouvir(global_position, 38.0)
	if _sup() == "p_madeira" and randf() < 0.12:
		Som.varia("madeira_range", 2, -12.0)


func _sentidos(dt: float) -> void:
	_t_luz -= dt
	if _t_luz <= 0.0:
		_t_luz = 0.25
		_t_cor = Mundo.luar(global_position + Vector3.UP * 1.2)
		if abrigado: _t_cor *= 0.3
		var mt := Mundo.moita(global_position)
		_moita_t = mt
		if mt > 0.3 and Vector2(velocity.x, velocity.z).length() > 0.8 and randf() < 0.35:
			Som.toca("arbusto", -18, randf_range(0.9, 1.2))
			ruido = maxf(ruido, 13.0 if not agachado else 5.0)
		_mergulho = mt if agachado else mt * 0.25
		if esconderijo and agachado: _mergulho = 1.0
	luz = lerpf(luz, _t_cor, minf(1.0, dt * 2.0))
	escondido = lerpf(escondido, _mergulho, minf(1.0, dt * 3.0))
	# medo
	var m := 0.0
	var cr = Jogo.criatura
	if cr and cr.visible:
		var d: float = cr.dist_jog()
		m = clampf(1.0 - d / 42.0, 0.0, 1.0) * 0.75
		if cr.estado == Criatura.E.CACA: m = maxf(m, 0.75)
		if cr.sendo_visto(): m = maxf(m, 0.55)
	if luz < 0.25: m = maxf(m, 0.14)
	medo = move_toward(medo, m, dt * (0.35 if m > medo else 0.11))


func ferir(q: float, calado: bool = false) -> void:
	if morto: return
	vida -= q
	if not calado:
		tremer(0.35)
	if vida <= 0.0:
		vida = 0.0
		Jogo.historia.morrer("frio" if calado else "ferida")


func _procura_alvo(dt: float) -> void:
	var antes := alvo
	alvo = null
	if travado or so_olhar:
		_segura = 0.0
		return
	var fr := -cam.global_transform.basis.z
	var melhor := 0.80
	for i in get_tree().get_nodes_in_group("interativo"):
		if not i.ativo or not i.is_visible_in_tree():
			continue
		var d: Vector3 = i.global_position - cam.global_position
		var l := d.length()
		if l < i.raio:
			var k := fr.dot(d / maxf(l, 0.01)) if l > 0.5 else 0.95
			if k > melhor:
				melhor = k
				alvo = i
	if alvo != antes:
		_segura = 0.0
	obj_alvo = null
	if carrega:
		if Input.is_action_just_pressed("usar") and not robotizado:
			carrega.gravity_scale = 1.0
			carrega = null
		return
	if alvo == null:
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + fr * 2.3)
		q.exclude = [get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if not h.is_empty() and h.collider is ObjetoFisico:
			obj_alvo = h.collider
			if Input.is_action_just_pressed("usar") and not robotizado:
				if obj_alvo.pesado:
					Jogo.aviso.emit("Pesado demais para carregar")
					obj_alvo.apply_impulse(fr * obj_alvo.mass * 0.8, h.position - obj_alvo.global_position)
				else:
					carrega = obj_alvo
					carrega.gravity_scale = 0.0
					Som.toca("pegar", -10)
			return
	if alvo:
		var usa: bool = robo.get("usar", false if robotizado else Input.is_action_pressed("usar"))
		if alvo.segurar > 0.0:
			if usa:
				_segura += dt
				if _segura >= alvo.segurar:
					_segura = -99.0
					robo.erase("usar")
					alvo.usar()
			else:
				_segura = 0.0
		elif (Input.is_action_just_pressed("usar") and not robotizado) or robo.get("usar", false):
			robo.erase("usar")
			alvo.usar()
	elif Jogo.tem("pedra") < 5 and Mundo.dist(Mundo.RIO, global_position.x, global_position.z) < 5.0 and incl < -0.35:
		if Input.is_action_just_pressed("usar"):
			Jogo.dar("pedra")
			Som.toca("pedra", -8)
			Jogo.aviso.emit("Pedra do rio (%d/5) — arremesse para distrair" % Jogo.tem("pedra"))


func dica() -> String:
	if carrega:
		return "[E] Soltar    [clique] Arremessar"
	if obj_alvo and not alvo:
		return "[E] Empurrar %s" % obj_alvo.nome if obj_alvo.pesado else "[E] Pegar %s" % obj_alvo.nome
	if alvo:
		return ("[E] %s" if alvo.segurar <= 0.0 else "[segure E] %s") % alvo.texto
	if not travado and Jogo.tem("pedra") < 5 and incl < -0.35 and Mundo.dist(Mundo.RIO, global_position.x, global_position.z) < 5.0:
		return "[E] Pegar pedra"
	return ""


func prog_segurar() -> float:
	return clampf(_segura / alvo.segurar, 0.0, 1.0) if alvo and alvo.segurar > 0.0 else 0.0


func _process(dt: float) -> void:
	if morto and olhar_forcado == Vector3.INF:
		return
	var f := Engine.get_physics_interpolation_fraction()
	var p := _ant.lerp(_atu, f)
	_olho = lerpf(_olho, 0.86 if agachado else 1.64, minf(1.0, dt * 9.0))
	var t := Time.get_ticks_msec() / 1000.0
	var by := sin(_bob * 2.0) * 0.040 * _bob_amp
	var bx := cos(_bob) * 0.030 * _bob_amp
	var resp := sin(t * lerpf(1.3, 3.4, maxf(medo, 1.0 - folego / 100.0))) * lerpf(0.004, 0.014, maxf(medo, 1.0 - folego / 100.0))
	_tremor = move_toward(_tremor, 0.0, dt * 0.9)
	var fr := frio / 100.0
	var tr := _tremor + maxf(0.0, fr - 0.6) * 0.012 + medo * 0.004
	var ch := Vector3(sin(t * 37.0) + sin(t * 61.0), sin(t * 43.0) + sin(t * 71.0), sin(t * 29.0)) * tr * 0.5
	var b := Basis(Vector3.UP, rotation.y)
	cam.global_position = p + Vector3.UP * (_olho + by + resp) + b * Vector3(bx, 0, 0) + b * ch * 0.14
	var lat := b.inverse() * Vector3(velocity.x, 0, velocity.z)
	_roll = lerpf(_roll, -lat.x * 0.006, minf(1.0, dt * 5.0))
	if olhar_forcado != Vector3.INF:
		var d := (olhar_forcado - cam.global_position).normalized()
		var ry := atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, ry, minf(1.0, dt * 7.0))
		incl = lerp_angle(incl, asin(clampf(d.y, -1, 1)), minf(1.0, dt * 7.0))
	cam.rotation = Vector3(incl + ch.y * 0.10 + sin(_bob * 2.0) * 0.0022 * _bob_amp, rotation.y + ch.x * 0.10, _roll + cos(_bob) * 0.0028 * _bob_amp + ch.z * 0.08)
	var alvo_f := 72.0
	if _ac("foco") and not travado: alvo_f = 46.0
	elif Vector2(velocity.x, velocity.z).length() > 3.6: alvo_f = 78.0
	_fov = lerpf(_fov, alvo_f - medo * 4.0, minf(1.0, dt * 6.0))
	cam.fov = _fov
	lanterna.atualiza(dt, cam, _bob * _bob_amp)
	# bussola
	var quer := _ac("bussola") and Jogo.tem("bussola") > 0 and not travado
	_bus_v = move_toward(_bus_v, 1.0 if quer else 0.0, dt * 4.0)
	_bus.visible = _bus_v > 0.01
	if _bus.visible:
		_bus.position = Vector3(0.10, lerpf(-0.42, -0.155, smoothstep(0, 1, _bus_v)) + by * 0.3, -0.34)
		var desvio := 0.0
		if Jogo.criatura and Jogo.criatura.visible:
			desvio = clampf(1.0 - Jogo.criatura.dist_jog() / 40.0, 0.0, 1.0) * sin(t * 9.0) * 2.4   # enlouquece perto dele
		_agulha.rotation.y = lerp_angle(_agulha.rotation.y, -rotation.y + desvio + sin(t * 2.1) * 0.04, minf(1.0, dt * 4.0))
	# camadas do corpo
	Som.camada("resp_cansada", clampf((55.0 - folego) / 55.0, 0.0, 1.0) * 0.5, 0.8)
	Som.camada("resp_medo", clampf((medo - 0.4) * 1.4, 0.0, 0.55), 0.6)
	_ar_t -= dt
	if medo > 0.28 and _ar_t <= 0.0 and not morto:
		_ar_t = lerpf(1.15, 0.48, clampf((medo - 0.28) / 0.6, 0, 1))
		Som.toca("coracao", lerpf(-16.0, 0.0, medo), 1.0, "UI")
		if Jogo.hud: Jogo.hud.pulso = 1.0
