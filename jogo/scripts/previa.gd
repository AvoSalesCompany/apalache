extends Node
## Grava a previa do jogo:  godot --path jogo --write-movie previa.avi --fixed-fps 30 -- previa=1
## So roda com esse argumento.

var pr
var j: Jogador
var _anda := Vector3.ZERO
var _giro := 0.0
var _incl := 0.0
var _livre := true
var _t := 0.0
var _bob := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	j = pr.jog
	j.robotizado = true
	roda()


func _process(dt: float) -> void:
	_t += dt
	if _livre:
		return
	var v := _anda.length()
	_bob += v * dt * 1.8
	var b := Basis(Vector3.UP, j.rotation.y)
	var p := j.global_position + b * _anda * dt
	p.y = Mundo.altura(p.x, p.z) + 0.02
	j.global_position = p
	j._ant = p
	j._atu = p
	j._bob = _bob
	j._bob_amp = clampf(v / 4.0, 0.0, 0.6)
	j.rotation.y += deg_to_rad(_giro) * dt
	j.incl += deg_to_rad(_incl) * dt


func seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func corte() -> void:
	pr.hud.escurecer(1.0, 0.0)
	pr.hud.preto = 1.0
	await seg(0.18)
	pr.hud.limpar()
	pr.hud.escurecer(0.0, 0.35)


func em(x: float, z: float, giro: float, incl: float = 0.0) -> void:
	j.por_em(Mundo.chao(x, z) + Vector3.UP * 0.02, deg_to_rad(giro))
	j.incl = deg_to_rad(incl)
	pr.fl.firmar(j.global_position)


func voo(t: float, yaw: float, pitch: float) -> void:
	var av: Aviao = pr.av
	while av.t < t:
		av._process(0.05)
	av.yaw = deg_to_rad(yaw)
	av.pitch = deg_to_rad(pitch)


func olha(yaw: float, pitch: float, s: float) -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(pr.av, "yaw", deg_to_rad(yaw), s)
	t.tween_property(pr.av, "pitch", deg_to_rad(pitch), s)


func roda() -> void:
	pr.fase = "aviao"
	pr.hud.preto = 1.0
	pr.fl.visible = false
	pr.av.visible = true
	pr.av.iniciar()
	voo(8.6, 12, -6)
	pr.hud._cap.modulate.a = 0
	olha(-30, -3, 4.5)
	await seg(5.0)
	voo(40.5, -60, -4)
	olha(-84, -3, 2.0)
	await seg(3.2)
	voo(52.2, -20, -2)
	olha(16, -2, 2.2)
	await seg(5.6)
	voo(64.0, -74, 0)
	await seg(1.4)
	voo(78.6, 4, -4)
	await seg(4.2)
	# ---------------------------------------------------- chao
	pr.av.rodando = false
	pr.av.visible = false
	Som.silencio(4.0)
	Som.abafado = 0.0
	pr.fl.visible = true
	j.visible = true
	j.cam.current = true
	j.set_physics_process(false)
	_livre = false
	pr.dir.ligado = false
	Jogo.flags["vivo"] = true
	Jogo.itens = {"lanterna": 1, "bussola": 1}
	Jogo.etapa = 3
	j.lanterna.bateria = 100.0
	j.lanterna.ligada = true
	pr.hud.limpar()
	em(-371.5, -291.0, -42, -3)
	corte()
	_anda = Vector3(0.1, 0, -0.9)
	_giro = 5.0
	await seg(5.0)
	em(-264, -246, -140, -3)
	corte()
	_anda = Vector3(0, 0, -1.7)
	_giro = -1.5
	await seg(5.0)
	# vigia no facho
	em(-232.5, -209.5, -158, 0)
	corte()
	_anda = Vector3(0, 0, -0.5)
	_giro = 4.0
	var a := Vigia.new().montar(false)
	pr.fl.add_child(a)
	a.set_meta("cena", true)
	a.por(Vector3(-228.6, 0, -200.6), j.global_position)
	await seg(2.6)
	Som.toca("stinger2", -2)
	for k in 5:
		j.lanterna.apagao = 0.10
		await seg(0.24)
	j.lanterna.apagao = 0.8
	await seg(0.4)
	a.queue_free()
	await seg(0.9)
	# alguem acenando perto da cabana
	em(-101, -99, -82, 0)
	corte()
	_anda = Vector3(0, 0, -1.2)
	_giro = 0.5
	for q in [[-89, -101, 1], [-84, -96.5, 0], [-86, -106, 0], [-80, -101, 0]]:
		var v := Vigia.new().montar(q[2] > 0)
		pr.fl.add_child(v)
		v.set_meta("cena", true)
		v.por(Vector3(q[0], 0, q[1]), j.global_position)
	Som.em("v_alex1", Mundo.chao(-86, -101) + Vector3.UP * 2, 6.0, 120, 0.95, "Eco", 13.0)
	await seg(4.2)
	# a criatura se levanta
	em(-206, -158, -150, 0)
	corte()
	j.lanterna.ligada = false
	_anda = Vector3.ZERO
	_giro = 0.0
	pr.cri.colocar(Vector3(-202, 0, -150.5), j.global_position)
	pr.cri.muda(Criatura.E.OBSERVA)
	pr.cri.em_pe = 0.0
	pr.cri.em_pe_alvo = 0.0
	await seg(1.4)
	pr.cri.em_pe_alvo = 1.0
	Som.em("cr_estalos", pr.cri.global_position + Vector3.UP * 2, 6.0, 40)
	await seg(3.4)
	Som.toca("cr_grito1", -2)
	pr.cri.esconder()
	# caminhonete
	em(323, 396.2, 90, 1)
	corte()
	var g: Node3D = pr.fl.locais.caminhonete
	g.visible = true
	for k in 110:
		var x := lerpf(262.0, 306.0, 1.0 - pow(1.0 - k / 110.0, 2.0))
		var z: float = pr.fl.locais._z_rod(x) - 1.7
		g.global_position = Vector3(x, Mundo.altura(x, z) + 0.12, z)
		g.rotation.y = -PI * 0.5
		await get_tree().process_frame
	pr.hud.escurecer(1.0, 0.5)
	await seg(0.9)
	Som.toca("v_alex1", 0, 0.95, "UI")
	pr.hud.capitulo("HOLLER", "não responda", 2.2)
	await seg(4.6)
	get_tree().quit()
