extends Node
## Fluxo do jogo: carga -> menu -> aviao -> floresta -> final.

var menu: Menu
var hud: Hud
var fl: Floresta
var av: Aviao
var jog: Jogador
var cri: Criatura
var dir: Diretor
var his: Historia
var cam_menu: Camera3D
var fase := "carga"
var _tm := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Teste.a.get("prova", "") == "gente":
		add_child(load("res://scripts/prova_gente.gd").new())
		return
	hud = Hud.new()
	add_child(hud)
	menu = Menu.new()
	add_child(menu)
	menu.novo.connect(_novo)
	menu.continuar.connect(_continuar)
	menu.voltar_menu.connect(_ao_menu)
	menu.retomar.connect(_retomar)
	menu.carregando("Acordando", 0.02)
	await get_tree().process_frame
	await get_tree().process_frame
	fl = Floresta.new()
	fl.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fl)
	Jogo.floresta = fl
	await fl.construir(_passo)
	await _passo("Reabastecendo o voo 609", 0.98)
	av = Aviao.new()
	av.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(av)
	av.construir()
	av.visible = false
	jog = Jogador.new()
	jog.process_mode = Node.PROCESS_MODE_PAUSABLE
	fl.add_child(jog)
	jog.cam.environment = fl.env
	jog.travado = true
	Jogo.jogador = jog
	cri = Criatura.new()
	fl.add_child(cri)
	Jogo.criatura = cri
	dir = Diretor.new()
	dir.process_mode = Node.PROCESS_MODE_PAUSABLE
	fl.add_child(dir)
	Jogo.diretor = dir
	var an := Anomalias.new()
	an.process_mode = Node.PROCESS_MODE_PAUSABLE
	fl.add_child(an)
	Jogo.anomalias = an
	his = Historia.new()
	his.process_mode = Node.PROCESS_MODE_PAUSABLE
	fl.add_child(his)
	his.fl = fl
	cri.pegou.connect(his.pego)
	jog.gritou.connect(dir.respondeu)
	his.acabou.connect(_final)
	cam_menu = Camera3D.new()
	cam_menu.fov = 60
	cam_menu.far = 1400
	cam_menu.environment = fl.env
	fl.add_child(cam_menu)
	await _passo("Pronto", 1.0)
	if Teste.ativo:
		_teste()
	else:
		_ao_menu()


func _passo(txt: String, p: float) -> void:
	menu.carregando(txt, p)
	await get_tree().process_frame
	await get_tree().process_frame


func _ao_menu() -> void:
	get_tree().paused = false
	if fase in ["floresta", "aviao", "final"]:
		# recomeca do zero para nao deixar nada pendurado
		Som.silencio(5.0)
		Som.abafado = 0.0
		Jogo.jogador = null
		Jogo.criatura = null
		Jogo.floresta = null
		Jogo.anomalias = null
		get_tree().reload_current_scene()
		return
	fase = "menu"
	fl.visible = true
	av.visible = false
	jog.visible = false
	_camera_menu(0.0)
	cam_menu.current = true
	fl.firmar(cam_menu.global_position)
	menu.principal()
	hud.limpar()
	hud.escurecer(1.0, 0.0)
	hud.escurecer(0.0, 3.0)
	dir.ligado = false
	Som.camada("mus_tensao", 0.16, 0.1, "Musica")


func _camera_menu(dt: float) -> void:
	_tm += dt
	var p := Mundo.chaov(Vector2(-216, -150)) + Vector3(0, 2.1, 0)
	p += Vector3(sin(_tm * 0.07) * 1.6, sin(_tm * 0.11) * 0.2, cos(_tm * 0.05) * 1.2)
	cam_menu.global_position = p
	var d := Mundo.LUA
	cam_menu.look_at(p + Vector3(d.x, 0.16, d.z).normalized().rotated(Vector3.UP, 0.10 + sin(_tm * 0.06) * 0.08))


func _process(dt: float) -> void:
	if fase == "menu":
		_camera_menu(dt)


func _novo() -> void:
	menu.esconder()
	Jogo.apagar_salvo()
	Jogo.nova_partida()
	fase = "aviao"
	hud.escurecer(1.0, 1.2)
	Som.camada("mus_tensao", 0.0, 0.3, "Musica")
	await get_tree().create_timer(1.4).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fl.visible = false
	Som.silencio(2.0)
	av.visible = true
	av.iniciar()
	av.caiu.connect(_caiu, CONNECT_ONE_SHOT)


func _caiu(protegido: bool) -> void:
	av.visible = false
	av.queue_free()
	fl.visible = true
	fase = "floresta"
	Jogo.vida_salva = 88.0 if protegido else 62.0
	if Jogo.flags.has("lanche") and not Jogo.flags.get("comeu", false): Jogo.dar("lanche")
	jog.visible = true
	jog.cam.current = true
	var a: Node3D = fl.locais.nos["acorda"]
	fl.firmar(a.global_position)
	his.comecar(true)


func _continuar() -> void:
	if not Jogo.carregar():
		_novo()
		return
	menu.esconder()
	hud.escurecer(1.0, 1.0)
	await get_tree().create_timer(1.2).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	av.queue_free()
	fase = "floresta"
	fl.visible = true
	jog.visible = true
	jog.cam.current = true
	fl.firmar(Jogo.pos_salva)
	his.comecar(false)


func _final(qual: String) -> void:
	fase = "final"
	Som.silencio(1.0)
	dir.ligado = false
	jog.travado = true
	Jogo.apagar_salvo()
	menu.final(qual)


func _retomar() -> void:
	menu.esconder()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pausa") and fase in ["floresta", "aviao"] and not hud.lendo:
		if menu.modo == "pausa":
			_retomar()
		elif menu.modo == "":
			get_tree().paused = true
			menu.pausa()


# ------------------------------------------------------------------ testes
func _teste() -> void:
	menu.esconder()
	hud.escurecer(0.0, 0.0)
	hud.preto = 0.0
	if Teste.a.has("q"):
		Jogo.qualidade = int(Teste.a.q)
		Jogo.aplicar_opcoes()
	if Teste.a.has("lista"):
		fase = "floresta"
		Teste.album(self)
		return
	var cena: String = Teste.a.get("cena", "floresta")
	if cena == "menu":
		fase = "carga"
		_ao_menu()
		hud.preto = 0.0
		if Teste.a.has("foto"): Teste.fotografar()
		return
	if cena == "aviao":
		fase = "aviao"
		fl.visible = false
		av.visible = true
		av.iniciar()
		hud.preto = 0.0
		hud.preto_alvo = 0.0
		av.pre = false
		var alvo := Teste.num("t", 10.0)
		var passos := int(alvo / 0.05)
		for i in passos:
			av._process(0.05)
		var ol := Teste.par("olhar", Vector2(-20, 0))
		av.yaw = deg_to_rad(ol.x)
		av.pitch = deg_to_rad(ol.y)
		if Teste.a.has("foto"): Teste.fotografar()
		return

	if Teste.a.has("robo"):
		fase = "floresta"
		var r = load("res://scripts/robo.gd").new()
		r.pr = self
		add_child(r)
		return
	fase = "floresta"
	av.visible = false
	jog.visible = true
	jog.travado = true
	var p := Teste.par("pos", Vector2(-230, -200))
	var y := Mundo.altura(p.x, p.y) + Teste.num("alt", 0.1)
	jog.por_em(Vector3(p.x, y, p.y), deg_to_rad(Teste.par("olhar", Vector2(0, 0)).x))
	if Teste.a.has("alt"): jog.set_physics_process(false)
	jog.incl = deg_to_rad(Teste.par("olhar", Vector2(0, 0)).y)
	jog.cam.current = true
	fl.firmar(jog.global_position)
	if Teste.a.has("cri"):
		var c := Teste.par("cri", Vector2.ZERO)
		cri.colocar(Vector3(c.x, 0, c.y), jog.global_position)
		cri.muda(Criatura.E.OBSERVA)
		cri.em_pe_alvo = Teste.num("pe", 0.0)
		cri.em_pe = Teste.num("pe", 0.0)
		cri.set_physics_process(false)
	if Teste.a.has("foto"):
		Teste.fotografar()


func teste_cena(q: Dictionary) -> void:
	hud.preto = 0.0
	hud.preto_alvo = 0.0
	if q.has("t"):
		if not av.rodando:
			fl.visible = false
			av.visible = true
			av.iniciar()
		if float(q.t) >= 0.0:
			av.pre = false
			while av.t < float(q.t):
				av._process(0.05)
		else:
			av.pre = true
			while av.tp < -float(q.t):
				av._process(0.05)
				av.com._process(0.05)
				for g in av._passag: g._process(0.05)
			if q.has("serve"):
				av._chegou_com()
				av.com.giro_alvo = -PI * 0.5 - 0.25
				for k in 60: av.com._process(0.05)
				av.bandeja.visible = true
				Itens.lanche(av.prato, "sanduiche")
		av.yaw = deg_to_rad(float(q.olhar[0]))
		av.pitch = deg_to_rad(float(q.olhar[1]))
		return
	if is_instance_valid(av) and av.visible:
		av.visible = false
		av.rodando = false
		Som.silencio(5.0)
	fl.visible = true
	jog.visible = true
	jog.travado = not q.has("hud")
	if q.has("itens"):
		for k in q.itens: Jogo.dar(k)
	if q.has("etapa"): Jogo.etapa = int(q.etapa)
	if q.has("lanterna"):
		Jogo.itens["lanterna"] = 1
		jog.lanterna.ligada = float(q.lanterna) > 0
		jog.lanterna.bateria = 100.0
	for v in Jogo.anomalias.ativos:
		if is_instance_valid(v): v.queue_free()
	Jogo.anomalias.ativos.clear()
	if q.has("vigias"):
		for pv in q.vigias:
			var vg := Vigia.new().montar(pv.size() > 2 and float(pv[2]) > 0)
			fl.add_child(vg)
			vg.por(Vector3(float(pv[0]), 0, float(pv[1])), jog.global_position)
			Jogo.anomalias.ativos.append(vg)
	fl.clima.por(float(q.get("hora", 12.0)))
	fl.clima.neve = float(q.get("neve", 0.3))
	fl.clima.neve_alvo = fl.clima.neve
	for k in q.get("desliga", []):
		match k:
			"sombra": fl.lua.shadow_enabled = false
			"ang": fl.clima.set_meta("ang0", true)
			"d60": fl.lua.directional_shadow_max_distance = 60.0
			"s2": fl.lua.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			"atlas": RenderingServer.directional_shadow_atlas_set_size(2048, true)
			"lod1":
				for g in fl.find_children("*", "MultiMeshInstance3D", true, false):
					if g.has_meta("nv") and g.get_meta("nv") == 1: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"vol": fl.env.volumetric_fog_enabled = false
			"ssao": fl.env.ssao_enabled = false
			"glow": fl.env.glow_enabled = false
			"raios": fl.raios.visible = false
			"gente":
				for g in fl.find_children("*", "Skeleton3D", true, false): g.visible = false
			"veg":
				for g in fl.find_children("*", "MultiMeshInstance3D", true, false): g.visible = false
			"neve": fl.ar.visible = false
			"luzes":
				for g in fl.find_children("*", "OmniLight3D", true, false): g.visible = false
				for g in fl.find_children("*", "SpotLight3D", true, false): g.visible = false
			"terreno":
				for g in fl.get_children():
					if g is MeshInstance3D and g != fl.raios: g.visible = false
	if q.has("destruir"): fl.vila.destruir()
	if q.has("torre"): his._liga_torre(true)
	if q.has("inv"): hud.inv.abre(q.inv)
	elif hud.inv.visible: hud.inv.fecha()
	if q.has("rifle"):
		Jogo.itens["rifle"] = 1
		jog.rifle.pegar()
		jog.travado = false
	if q.has("abre"):
		(fl.locais.nos["porta_banheiro"] as Node3D).rotation.y = -1.9
		fl.locais.portao.rotation.y = -1.7
		fl.vila.porta_ruth.rotation.y = 1.9
	if q.has("revoada"): Passaros.revoada(fl, Vector3(float(q.revoada[0]), float(q.revoada[1]), float(q.revoada[2])), 30, Vector3(0.3, 0.3, 1.0))
	if q.has("viatura"):
		for k in 2:
			var vv: Node3D = fl.locais.viaturas[k]
			vv.visible = true
			vv.global_position = Mundo.chao(183 + k * 5.0, -47 + k * 9.0)
			vv.rotation.y = 0.7
	if q.has("em"):
		# posicao relativa a um lugar: [no, x, y, z] e olhar para [x, y, z] do mesmo no
		var base: Node3D = {"fuselagem": fl.locais.nos["fuselagem"], "torre": fl.locais.nos["torre"], "banheiro": fl.locais.nos["banheiro"], "gerador": fl.locais.nos["gerador"], "casa": fl.vila.casas.ruth, "galpao": fl.vila.casas.galpao, "vila": fl.vila}.get(q.em[0], fl.vila)
		if q.em[0] in fl.vila.gente: base = fl.vila.gente[q.em[0]]
		var w := base.to_global(Vector3(float(q.em[1]), float(q.em[2]), float(q.em[3])))
		var a := base.to_global(Vector3(float(q.para[0]), float(q.para[1]), float(q.para[2])))
		var d := a - (w + Vector3.UP * 1.64)
		q["pos"] = [w.x, w.z]
		q["y"] = w.y
		q["olhar"] = [rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))]
	var x := float(q.pos[0])
	var z := float(q.pos[1])
	var y: float = float(q.y) if q.has("y") else Mundo.altura(x, z) + float(q.get("alt", 0.1))
	jog.por_em(Vector3(x, y, z), deg_to_rad(float(q.olhar[0])))
	jog.set_physics_process(not (q.has("alt") or q.has("y")))
	jog.incl = deg_to_rad(float(q.olhar[1]))
	jog.robo = {"bussola": q.has("bussola"), "foco": q.has("foco")}
	jog.cam.current = true
	fl.firmar(jog.global_position)
	cri.esconder()
	if q.has("cri"):
		cri.colocar(Vector3(float(q.cri[0]), 0, float(q.cri[1])), jog.global_position)
		cri.muda(Criatura.E.OBSERVA)
		cri.em_pe_alvo = float(q.get("pe", 0))
		cri.em_pe = cri.em_pe_alvo
		cri.set_physics_process(false)
		if q.has("criy"): cri.global_position.y = float(q.criy)
	if q.has("lamp"):
		var lp := OmniLight3D.new()
		lp.light_energy = float(q.lamp)
		lp.omni_range = 14
		fl.add_child(lp)
		lp.global_position = jog.cam.global_position + Vector3(0.6, 0.5, 0)
		get_tree().create_timer(1.6).timeout.connect(lp.queue_free)
	pass