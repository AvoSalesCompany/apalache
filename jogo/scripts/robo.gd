extends Node
## Teste automatico: joga a partida inteira andando de verdade e relata cada passo.
## Uso: godot --path jogo -- robo=1 [vel=3] [final=bom|carona] [morte=1]

var pr
var j: Jogador
var loc: Locais
var falhas := 0
var agacha := false
var t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(960, 540)
	Engine.time_scale = Teste.num("vel", 3.0)
	Engine.max_physics_steps_per_frame = 24
	t0 = Time.get_ticks_msec()
	j = pr.jog
	j.robotizado = true
	loc = pr.fl.locais
	pr.his.acabou.connect(func(q): diz("FINAL: " + q))
	roda()


func diz(s: String) -> void:
	print("PASSO [%5.1fs] etapa=%d vida=%.0f frio=%.0f alt=%.1f vy=%.1f chao=%s  %s" % [(Time.get_ticks_msec() - t0) / 1000.0, Jogo.etapa, j.vida, j.frio, j.global_position.y - Mundo.altura(j.global_position.x, j.global_position.z), j.velocity.y, j.is_on_floor(), s])


func seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func ate(f: Callable, lim: float, nome: String) -> bool:
	var t := 0.0
	while not f.call():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if pr.hud.lendo: pr.hud.fechar_nota()
		if t > lim:
			falhas += 1
			diz("FALHA: esperou demais por " + nome)
			return false
	return true


func mira(p: Vector3) -> void:
	var d := p - j.cam.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	j.incl = atan2(d.y, Vector2(d.x, d.z).length())


## anda ate (x,z). y opcional para lugares com andar
func vai(p: Vector3, perto: float = 1.6, lim: float = 60.0, correr: bool = true) -> bool:
	var t := 0.0
	var parado := 0.0
	var melhor := 1e9
	while true:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		if pr.hud.lendo: pr.hud.fechar_nota()
		if pr.fase == "final":
			j.robo = {}
			return true
		if j.morto:
			j.robo = {}
			diz("morreu no caminho")
			return false
		var d := Vector2(p.x - j.global_position.x, p.z - j.global_position.z)
		var l := d.length()
		if l < perto:
			j.robo = {}
			return true
		if j.travado or j.so_olhar:
			continue
		t += dt
		if l < melhor - 0.15:
			melhor = l
			parado = 0.0
		else:
			parado += dt
		j.rotation.y = atan2(-d.x, -d.y)
		var lado := 0.0
		if parado > 0.9:
			lado = 1.0 if fmod(parado, 2.4) < 1.2 else -1.0
		j.robo = {"eixo": Vector2(lado, -1.0).normalized(), "agachar": agacha, "correr": correr and parado < 0.5, "pular": parado > 0.6 and fmod(parado, 0.8) < 0.05}
		if parado > 9.0 or t > lim:
			falhas += 1
			diz("FALHA: preso em (%.1f, %.1f, %.1f) indo para (%.1f, %.1f)" % [j.global_position.x, j.global_position.y, j.global_position.z, p.x, p.z])
			j.por_em(Vector3(p.x, maxf(Mundo.altura(p.x, p.z) + 0.1, p.y if p.y > 0.0 else -999.0), p.z), j.rotation.y)
			j.robo = {}
			return false
	return false


func xz(x: float, z: float) -> Vector3:
	return Vector3(x, -1.0, z)


func usa(id: String, anda: bool = true) -> void:
	var i: Interativo = loc.it[id]
	if anda:
		var q := i.global_position
		await vai(Vector3(q.x, q.y, q.z), 1.35, 25.0, false)
	var t := 0.0
	while t < 6.0:
		await get_tree().physics_frame
		if pr.hud.lendo:
			pr.hud.fechar_nota()
			j.robo = {}
			diz("leu: " + id)
			return
		mira(i.global_position)
		t += get_physics_process_delta_time()
		j.robo = {"usar": true} if i == j.alvo else {}
		if not i.ativo:
			j.robo = {}
			diz("usou: " + id)
			return
		if Jogo.etapa >= 9:
			j.robo = {}
			return
		if i == j.alvo and i.segurar <= 0.0:
			await get_tree().physics_frame
			await get_tree().physics_frame
			j.robo = {}
			if pr.hud.lendo: pr.hud.fechar_nota()
			diz("usou: " + id)
			return
	falhas += 1
	j.robo = {}
	diz("FALHA: nao conseguiu usar %s (dist %.2f, alvo=%s, ativo=%s)" % [id, j.cam.global_position.distance_to(i.global_position), j.alvo, i.ativo])


func imortal() -> void:
	while is_inside_tree():
		await seg(0.5)
		if not Teste.a.has("morte"):
			j.vida = maxf(j.vida, 90.0)
			j.frio = minf(j.frio, 60.0)
			pr.cri.livre_ate = 1e12


func roda() -> void:
	if Teste.a.has("voo"):
		pr.fase = "menu"
		pr._novo()
		await ate(func(): return pr.fase == "aviao" and pr.av.rodando, 20, "decolar")
		diz("voando")
		await ate(func(): return pr.fase == "floresta", 130, "cair")
		diz("caiu; vida_salva=%.0f" % Jogo.vida_salva)
		await ate(func(): return Jogo.etapa >= 1 and not j.travado and not j.so_olhar, 60, "acordar")
		diz("acordou depois do voo em %s" % j.global_position)
		j.por_em(Mundo.chao(-289, -272), 0.0)
		Jogo.etapa = 2
		Jogo.salvar()
		j.por_em(Mundo.chao(0, 0), 0.0)
		j.vida = 20.0
		pr.his.renascer()
		await ate(func(): return not j.travado, 10, "continuar")
		diz("continuou em %s" % j.global_position)
		pr._unhandled_input(_tecla(KEY_ESCAPE))
		await get_tree().process_frame
		diz("pausado=%s menu=%s" % [get_tree().paused, pr.menu.modo])
		pr.menu.opcoes("pausa")
		await get_tree().process_frame
		pr.menu.pausa()
		pr._retomar()
		diz("retomou pausado=%s" % get_tree().paused)
		get_tree().quit()
		return
	Jogo.nova_partida()
	Jogo.vida_salva = 88.0
	pr.av.visible = false
	j.visible = true
	j.cam.current = true
	pr.fl.firmar(loc.nos["acorda"].global_position)
	imortal()
	pr.his.comecar(true)
	await ate(func(): return Jogo.etapa >= 1 and not j.travado and not j.so_olhar, 60, "acordar")
	diz("acordou")
	var nf := 0
	var afund := 0
	for o in pr.fl.locais.find_children("*", "RigidBody3D", true, false):
		nf += 1
		if o.global_position.y < Mundo.altura(o.global_position.x, o.global_position.z) - 0.25: afund += 1
	diz("objetos fisicos=%d afundados=%d" % [nf, afund])
	await usa("lanterna")
	await usa("jaqueta")
	await usa("kit")
	await usa("desenho")
	await usa("bussola")
	await ate(func(): return Jogo.etapa >= 2, 10, "etapa 2")
	diz("saiu dos destrocos; itens=" + str(Jogo.itens))
	if Teste.a.has("anom"):
		await _anomalias()
		return
	if Teste.a.has("morte"):
		pr.dir.emboscada(8.0)
		await ate(func(): return Jogo.mortes > 0 or j.vida < 60.0, 60, "ataque")
		diz("foi atacado")
		await seg(6.0)
		j.vida = 30.0
		pr.cri.livre_ate = 0.0
		pr.dir.emboscada(8.0)
		await ate(func(): return Jogo.mortes > 0, 60, "morte")
		diz("morreu")
		await ate(func(): return not j.morto and not j.travado, 40, "renascer")
		diz("renasceu em %s" % j.global_position)
		Teste.a.erase("morte")
		if Teste.a.has("so"):
			get_tree().quit()
			return
	for q in [[-310, -292], [-289, -272], [-262, -243], [-232, -208], [-222, -186], [-212, -160], [-200, -136]]:
		await vai(xz(q[0], q[1]), 3.0)
	diz("desceu o riacho")
	await usa("placa")
	await seg(3.0)
	diz("criatura: estado=%d visivel=%s dist=%.0f" % [pr.cri.estado, pr.cri.visible, pr.cri.dist_jog()])
	for q in Mundo.TRILHAS[0]:
		await vai(xz(q[0], q[1]), 2.5)
	await ate(func(): return Jogo.etapa >= 3, 5, "etapa 3 (cabana)")
	var cab: Node3D = loc.nos["cabana"]
	await vai(cab.to_global(Vector3(0, 0, 6.2)), 1.2)
	await vai(cab.to_global(Vector3(0, 0, 3.4)), 0.8, 20, false)
	await usa("porta", false)
	await seg(1.5)
	await vai(cab.to_global(Vector3(0, 0, 0.6)), 0.5, 20, false)
	diz("dentro da cabana, abrigado=%s" % j.abrigado)
	await usa("diario")
	await vai(cab.to_global(Vector3(-0.6, 0, 0.4)), 0.5, 20, false)
	await usa("fogao")
	await vai(cab.to_global(Vector3(0.4, 0, 0.4)), 0.5, 20, false)
	await usa("curativo2")
	await vai(cab.to_global(Vector3(-0.4, 0, 0.8)), 0.5, 20, false)
	await usa("chave", false)
	await ate(func(): return Jogo.etapa >= 4, 60, "batidas na porta")
	diz("batidas terminaram; porta aberta=%s" % loc.porta_aberta)
	if not loc.porta_aberta:
		await vai(cab.to_global(Vector3(0.1, 0, 1.1)), 0.5, 20, false)
		await usa("porta", false)
		await seg(1.5)
	await vai(cab.to_global(Vector3(0, 0, 5.8)), 0.9, 25, false)
	for q in Mundo.TRILHAS[1].slice(0, 4):
		await vai(xz(q[0], q[1]), 2.5)
	await vai(Vector3(Mundo.CEMITERIO.x + 4.0, 0, Mundo.CEMITERIO.y + 7.4), 1.2)
	await usa("cova")
	await ate(func(): return not j.travado, 20, "fim da cena da cova")
	for q in Mundo.TRILHAS[1].slice(4):
		await vai(xz(q[0], q[1]), 2.5)
	var tor: Node3D = loc.nos["torre"]
	await vai(tor.to_global(Vector3(-4.4, 0, -0.6)), 1.0)
	diz("pe da torre")
	await vai(tor.to_global(Vector3(-3.1, 0, -0.6)), 0.5, 20, false)
	await usa("portao", false)
	await seg(1.8)
	await sobe(tor)
	diz("topo da torre y=%.1f (piso %.1f) na_torre=%s" % [j.global_position.y, tor.global_position.y + Locais.H_TORRE, pr.his._na_torre])
	await usa("livro")
	await usa("radio")
	await ate(func(): return j.so_olhar, 5, "radio comecar")
	await ate(func(): return not j.so_olhar, 90, "conversa do radio")
	diz("radio terminou, escondendo")
	await vai(tor.to_global(Vector3(1.0, Locais.H_TORRE, 0.9)), 0.4, 20, false)
	agacha = true
	await vai(tor.to_global(Vector3(1.9, Locais.H_TORRE, 1.7)), 0.45, 20, false)
	agacha = false
	j.robo = {"agachar": true}
	await seg(1.0)
	diz("esconderijo=%s agachado=%s" % [j.esconderijo, j.agachado])
	await ate(func(): return Jogo.etapa >= 6 or j.morto, 90, "criatura na torre")
	diz("sobreviveu a torre")
	j.robo = {}
	await seg(1.0)
	await desce(tor)
	for q in Mundo.ESTRADA.slice(1, 8):
		await vai(xz(q[0], q[1]), 3.0)
	diz("chegou a ponte")
	await vai(xz(303, 268), 2.0)
	await vai(xz(296, 284), 2.0)
	await vai(xz(288, 300), 2.5)
	diz("atravessou a ponte")
	for q in Mundo.ESTRADA.slice(8):
		await vai(xz(q[0], q[1]), 3.0)
	await vai(xz(262, 399), 2.0)
	await ate(func(): return Jogo.etapa >= 8, 6, "rodovia")
	diz("rodovia")
	await vai(xz(300, 398), 2.5, 60, false)
	await vai(xz(322, 396.8), 2.5, 60, false)
	await ate(func(): return Jogo.flags.get("parou", false), 40, "caminhonete parar")
	diz("caminhonete parou em x=%.0f" % loc.caminhonete.global_position.x)
	if Teste.a.get("final", "bom") == "carona":
		await ate(func(): return loc.it["carona"].ativo, 10, "motorista")
		await usa("carona")
	else:
		await seg(10.0)
		for x in [345, 370, 395, 412]:
			await vai(xz(x, 393 + (395 - x) * 0.04), 3.0)
	await ate(func(): return pr.fase == "final", 30, "tela final")
	diz("TERMINOU falhas=%d tempo_de_jogo=%.1f min mortes=%d" % [falhas, Jogo.tempo / 60.0, Jogo.mortes])
	if Teste.a.has("foto"):
		await seg(1.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Teste.a.foto)
	get_tree().quit()


## dispara cada susto e confere a leitura protegida e a fisica
func _anomalias() -> void:
	var an: Anomalias = Jogo.anomalias
	if Teste.a.anom != "2": await vai(xz(-289, -272), 2.0)
	j.lanterna.ligada = true
	Jogo.etapa = 3
	for q in (["longe", "acena", "grupo", "corre", "passos", "sussurro", "galho", "lua", "poltrona", "costas", "apagao"] if Teste.a.anom != "2" else []):
		an.t = 999.0
		an.fazer(q)
		await seg(3.0)
		var n := 0
		for v in an.ativos:
			if is_instance_valid(v): n += 1
		diz("anomalia %s: ativos=%d medo=%.2f lua=%.2f" % [q, n, j.medo, pr.fl.lua_fator])
	# chega perto da poltrona / de quem esta de costas
	for v in an.ativos.duplicate():
		if is_instance_valid(v) and v.has_meta("cena"):
			j.por_em(v.global_position + Vector3(2.5, 0.2, 2.5), 0.0)
			await seg(4.0)
	diz("depois de chegar perto: ativos=%d" % an.ativos.size())
	# leitura protegida: a criatura congela
	Jogo.etapa = 5
	j.por_em(Mundo.chao(-289, -272), 0.0)
	pr.cri.colocar(j.global_position + Vector3(9, 0, 0), j.global_position)
	pr.cri.ultimo_visto = j.global_position
	pr.cri.muda(Criatura.E.CACA)
	pr.hud.abrir_nota("teste", "texto")
	var p0: Vector3 = pr.cri.global_position
	for k in 6:
		await seg(0.5)
		diz("   leitura: lendo=%s estado=%d andou=%.2f vis=%s" % [pr.hud.lendo, pr.cri.estado, pr.cri.global_position.distance_to(p0), pr.cri.visible])
	diz("lendo com a criatura a 9 m: ela andou %.2f m, vida=%.0f" % [pr.cri.global_position.distance_to(p0), j.vida])
	pr.hud.fechar_nota()
	pr.cri.esconder()
	# empurrar uma mala andando contra ela
	var cont := 0
	for m in pr.fl.locais.find_children("*", "RigidBody3D", true, false):
		if not (m.nome in ["mala", "caixote", "poltrona", "lata"]) or cont >= 9: continue
		cont += 1
		var m0: Vector3 = m.global_position
		j.por_em(m0 + Vector3(0.4, 0.3, 1.7), 0.0)
		await seg(0.5)
		j.robo = {"eixo": Vector2(0, -1)}
		var tocou := {}
		for k in 90:
			var d: Vector3 = m.global_position - j.global_position
			j.rotation.y = atan2(-d.x, -d.z)
			await get_tree().physics_frame
			for c in j.get_slide_collision_count():
				var col: Node = j.get_slide_collision(c).get_collider()
				var nm: String = col.nome if col is ObjetoFisico else (str(col.get_parent().name) + "/" + col.get_class())
				tocou["%s ny=%.1f" % [nm, j.get_slide_collision(c).get_normal().y]] = true
		j.robo = {}
		diz("empurrei %s (%.0f kg): moveu %.2f m, dist=%.2f tocou=%s" % [m.nome, m.mass, m.global_position.distance_to(m0), Vector2(m.global_position.x - j.global_position.x, m.global_position.z - j.global_position.z).length(), tocou.keys().slice(0, 5)])
	diz("ANOMALIAS ok")
	get_tree().quit()


func sobe(tor: Node3D) -> void:
	await vai(tor.to_global(Vector3(-2.6, 0, -0.62)), 0.4, 20, false)
	await vai(tor.to_global(Vector3(-1.75, 0, -0.62)), 0.4, 20, false)
	for i in 5:
		var par := i % 2 == 0
		var z := -0.62 if par else 0.62
		var x1 := 2.0 if par else -2.0
		await vai(tor.to_global(Vector3(x1, (i + 1) * 3.0, z)), 0.45, 25, false)
		if i < 4:
			await vai(tor.to_global(Vector3(x1, (i + 1) * 3.0, -z)), 0.4, 15, false)
	await vai(tor.to_global(Vector3(2.0, Locais.H_TORRE, 0.9)), 0.5, 15, false)


func desce(tor: Node3D) -> void:
	await vai(tor.to_global(Vector3(2.0, Locais.H_TORRE, 0.6)), 0.5, 15, false)
	await vai(tor.to_global(Vector3(2.05, Locais.H_TORRE, -0.62)), 0.4, 15, false)
	for i in range(4, -1, -1):
		var par := i % 2 == 0
		var z := -0.62 if par else 0.62
		var x0 := -2.0 if par else 2.0
		await vai(tor.to_global(Vector3(x0, i * 3.0, z)), 0.45, 25, false)
		if i > 0:
			await vai(tor.to_global(Vector3(x0, i * 3.0, -z)), 0.4, 15, false)
	await vai(tor.to_global(Vector3(-4.6, 0, -0.6)), 0.8, 20, false)
	diz("desceu a torre")


func _tecla(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e
