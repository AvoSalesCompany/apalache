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
			for k in j.get_slide_collision_count():
				var sc := j.get_slide_collision(k)
				var o: Node = sc.get_collider()
				diz("  toca %s/%s n=%s p=%s tam=%s" % [o.get_parent().name, o.name, sc.get_normal().snapped(Vector3.ONE * 0.1), loc.nos["fuselagem"].to_local(sc.get_position()).snapped(Vector3.ONE * 0.01), o.get_parent().mesh.get_aabb().size.snapped(Vector3.ONE * 0.01) if o.get_parent() is MeshInstance3D else ""])
			diz("FALHA: preso em (%.1f, %.1f, %.1f) indo para (%.1f, %.1f)" % [j.global_position.x, j.global_position.y, j.global_position.z, p.x, p.z])
			j.por_em(Vector3(p.x, maxf(Mundo.altura(p.x, p.z) + 0.1, p.y if p.y > 0.0 else -999.0), p.z), j.rotation.y)
			j.robo = {}
			return false
	return false


func xz(x: float, z: float) -> Vector3:
	return Vector3(x, -1.0, z)


func usa(id: String, anda: bool = true) -> void:
	var i: Interativo = loc.it[id] if loc.it.has(id) else pr.fl.vila.it[id]
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
		j.vida = maxf(j.vida, 90.0)
		j.frio = minf(j.frio, 60.0)



func roda() -> void:
	if Teste.a.has("voo"):
		pr.fase = "menu"
		pr._novo()
		await ate(func(): return pr.fase == "aviao" and pr.av.rodando, 20, "decolar")
		diz("voando")
		await ate(func(): return pr.av._fase_com == 2, 90, "comissaria chegar")
		diz("comissaria chegou em tp=%.1f" % pr.av.tp)
		await ate(func(): return pr.av.lanche != "", 30, "escolher lanche")
		diz("lanche: " + pr.av.lanche)
		await ate(func(): return not pr.av.pre, 60, "fim da parte calma")
		diz("comecaram os acontecimentos em tp=%.1f" % pr.av.tp)
		await ate(func(): return pr.fase == "floresta", 130, "cair")
		diz("caiu; vida_salva=%.0f itens=%s" % [Jogo.vida_salva, Jogo.itens])
		await ate(func(): return Jogo.etapa >= 1 and not j.travado and not j.so_olhar, 60, "acordar")
		diz("acordou depois do voo em %s hora=%.2f" % [j.global_position, pr.fl.clima.hora])
		j.por_em(Mundo.chao(-289, -272), 0.0)
		Jogo.etapa = 2
		pr.his.salvar()
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
		pr.hud.inv.abre("itens")
		await seg(0.3)
		pr.hud.inv.mostra("mapa")
		await seg(0.3)
		pr.hud.inv.fecha()
		diz("inventario abriu e fechou; travado=%s" % j.travado)
		diz("VOO ok falhas=%d" % falhas)
		get_tree().quit()
		return
	Jogo.nova_partida()
	Jogo.vida_salva = 88.0
	pr.av.visible = false
	j.visible = true
	j.cam.current = true
	pr.fl.firmar(loc.nos["acorda"].global_position)
	imortal()
	var v: Vila = pr.fl.vila
	if Teste.a.has("pula"):
		await _pula(int(Teste.a.pula))
	else:
		await _dia(v)
	if int(Teste.a.get("pula", 0)) < 5: await _noite(v)
	if int(Teste.a.get("pula", 0)) < 7: await _torre(v)
	await _cerco()


## comeca direto numa etapa
func _pula(e: int) -> void:
	Jogo.flags = {"vivo": true, "pegou_mochila": true, "pegou_jaqueta": true, "pegou_lanterna": true, "falou_caleb": true, "falou_elias": true, "falou_ruth": true, "sopa": true}
	Jogo.itens = {"mochila": 1, "mapa": 1, "lanterna": 1, "jaqueta": 1, "curativo": 2}
	Jogo.etapa = e
	var v: Vila = pr.fl.vila
	if e == 3:
		j.por_em((v.casas.ruth as Node3D).to_global(Vector3(2.0, 0.1, 0.5)), 0.0)
		pr.fl.clima.por(18.2)
	if e >= 6:
		var tor: Node3D = loc.nos["torre"]
		j.por_em(tor.to_global(Vector3(-6, 0.2, -0.6)), 0.0)
		Jogo.flags["hora"] = 3.2
		Jogo.flags["saiu_vila"] = true
	if e >= 7:
		var tor: Node3D = loc.nos["torre"]
		var p := tor.to_global(Vector3(0.4, Locais.H_TORRE + 0.1, 1.2)) if not Teste.a.has("chao") else tor.to_global(Vector3(-7, 0.2, -3))
		j.por_em(p, 0.0)
		Jogo.itens["rifle"] = 1
		Jogo.itens["municao"] = 20
		for k in ["gerador", "portao", "radio", "pegou_rifle", "pegou_chave"]: Jogo.flags[k] = true
	pr.his.salvar()
	pr.his.comecar(false)
	if e >= 7: j.rifle.pegar()
	await seg(1.0)


func _dia(v: Vila) -> void:
	pr.his.comecar(true)
	await ate(func(): return Jogo.etapa >= 1 and not j.travado and not j.so_olhar, 60, "acordar")
	diz("acordou hora=%.2f" % pr.fl.clima.hora)
	var nf := 0
	var afund := 0
	for o in pr.fl.locais.find_children("*", "RigidBody3D", true, false):
		nf += 1
		if o.global_position.y < Mundo.altura(o.global_position.x, o.global_position.z) - 0.25: afund += 1
	diz("objetos fisicos=%d afundados=%d mortos=%d" % [nf, afund, loc.mortos.size()])
	await usa("lanterna")
	await usa("mochila")
	await usa("bussola")
	await vai(loc.nos["fuselagem"].to_global(Vector3(2.6, 0, 0.2)), 1.0, 20, false)
	await vai(loc.nos["fuselagem"].to_global(Vector3(0.4, 0, 0.2)), 0.7, 20, false)
	await usa("jaqueta")
	await usa("kit")
	await vai(loc.nos["fuselagem"].to_global(Vector3(2.8, 0, 0.0)), 0.9, 20, false)
	await ate(func(): return Jogo.etapa >= 2, 10, "etapa 2")
	diz("saiu dos destrocos; itens=" + str(Jogo.itens))
	for q in Mundo.TRILHAS[0].slice(0, 8):
		await vai(xz(q[0], q[1]), 3.0)
	await vai(xz(-129.4, -79.8), 0.6)
	await vai(xz(-118, -86.75), 0.6)
	await vai(xz(-106.2, -94.0), 0.8)
	diz("trilha feita hora=%.1f cri_visivel=%s vigias=%d" % [pr.fl.clima.hora, pr.cri.visible, Jogo.anomalias.ativos.size()])
	await vai(xz(-92, -102), 3.0)
	await ate(func(): return Jogo.etapa >= 3, 6, "etapa 3 (vila)")
	diz("chegou na vila hora=%.1f" % pr.fl.clima.hora)
	await usa("fala_caleb")
	await fala()
	await usa("fala_elias")
	await fala()
	diz("ouviu Elias hora=%.1f" % pr.fl.clima.hora)
	var cr: Node3D = v.casas.ruth
	await vai(cr.to_global(Vector3(-0.9, 0, 8.0)), 1.2)
	await vai(cr.to_global(Vector3(-1.3, 0, 5.2)), 0.8, 20, false)
	await usa("fala_ruth", false)
	await fala()
	await seg(6.0)
	await vai(cr.to_global(Vector3(-1.5, 0, 4.1)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(-1.4, 0, 1.6)), 0.6, 20, false)
	diz("dentro da casa abrigado=%s hora=%.1f" % [j.abrigado, pr.fl.clima.hora])
	await vai(cr.to_global(Vector3(-0.6, 0, 0.75)), 0.4, 20, false)
	await usa("sopa", false)
	await seg(3.0)
	await fala()
	await vai(cr.to_global(Vector3(0.5, 0, 1.15)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(2.1, 0, 1.1)), 0.5, 20, false)


func fala() -> void:
	await seg(0.4)
	await ate(func(): return not pr.his.em_dialogo, 60, "fim da conversa")


func _noite(v: Vila) -> void:
	var cr: Node3D = v.casas.ruth
	await vai(cr.to_global(Vector3(2.3, 0, -0.5)), 0.5, 20, false)
	await ate(func(): return v.it["cama"].ativo, 10, "cama liberada")
	await usa("cama", false)
	if Jogo.etapa == 3 and v.it["cama"].ativo:
		diz("ainda claro: hora=%.1f" % pr.fl.clima.hora)
		await ate(func(): return pr.fl.clima.hora >= 17.7, 120, "escurecer")
		await usa("cama", false)
	await ate(func(): return Jogo.etapa == 4, 30, "noite")
	diz("noite hora=%.2f" % pr.fl.clima.hora)
	await ate(func(): return Jogo.etapa == 5, 90, "ataque")
	diz("ataque comecou; porta=%s cri=%d" % [v.porta_aberta, pr.cri.estado])
	await vai(cr.to_global(Vector3(2.0, 0, 1.1)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(0.6, 0, 1.15)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(-1.5, 0, 1.9)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(-1.5, 0, 4.3)), 0.5, 20, false)
	await vai(cr.to_global(Vector3(-1.5, 0, 7.2)), 0.9, 20)
	diz("saiu da casa")
	if Teste.a.has("foto"):
		for k in 4:
			mira(pr.fl.vila.mundo(-6, 2) + Vector3.UP * 1.2)
			await seg(1.6)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg("%s%d.jpg" % [Teste.a.foto, k], 0.92)
	await seg(6.0)
	diz("praca: cri=%d visivel=%s caleb_morto=%s" % [pr.cri.estado, pr.cri.visible, v.gente.caleb.morto])
	for q in Mundo.TRILHAS[1].slice(1):
		await vai(xz(q[0], q[1]), 3.0)
	await ate(func(): return Jogo.etapa >= 6, 8, "chegar na torre")
	diz("torre; vila destruida=%s mortes=%d" % [v.destruida, Jogo.mortes])


func _torre(v: Vila) -> void:
	var tor: Node3D = loc.nos["torre"]
	await vai(tor.to_global(Vector3(-4.4, 0, -0.6)), 1.0)
	await vai(tor.to_global(Vector3(-3.1, 0, -0.5)), 0.5, 20, false)
	await usa("portao", false)
	await usa("bilhete", false)
	await vai(tor.to_global(Vector3(-4.6, 0, 0.4)), 0.7, 20, false)
	var ob: Node3D = loc.nos["banheiro"]
	await vai(ob.to_global(Vector3(0.3, 0, 2.6)), 0.6, 30, false)
	await vai(ob.to_global(Vector3(0.2, 0, 1.9)), 0.4, 20, false)
	await usa("porta_banheiro", false)
	await seg(1.6)
	await vai(ob.to_global(Vector3(0.2, 0, 0.35)), 0.35, 20, false)
	await usa("privada", false)
	diz("chave=%d" % Jogo.tem("chave"))
	await seg(8.0)
	await vai(ob.to_global(Vector3(0.2, 0, 2.6)), 0.6, 20, false)
	await vai(loc.nos["gerador"].to_global(Vector3(0.0, 0, 1.6)), 0.7, 40)
	await usa("gerador", false)
	diz("gerador seco: " + Jogo.objetivo)
	# volta para a vila
	for k in range(Mundo.TRILHAS[1].size() - 1, 0, -1):
		await vai(xz(Mundo.TRILHAS[1][k][0], Mundo.TRILHAS[1][k][1]), 3.0)
	var ga: Node3D = v.casas.galpao
	await vai(xz(Mundo.VILA.x + 3, Mundo.VILA.y - 3), 2.0)
	await vai(xz(Mundo.VILA.x + 5, Mundo.VILA.y + 12), 2.0)
	await vai(ga.to_global(Vector3(-0.6, 0, 7.0)), 1.0)
	await vai(ga.to_global(Vector3(-0.7, 0, 4.4)), 0.7, 25, false)
	await vai(ga.to_global(Vector3(-1.2, 0, -1.0)), 0.8, 25, false)
	await vai(ga.to_global(Vector3(-1.7, 0, -3.2)), 0.5, 25, false)
	await usa("gasolina", false)
	diz("gasolina=%d" % Jogo.tem("gasolina"))
	await seg(6.0)
	diz("susto no galpao; cri=%d vida=%.0f" % [pr.cri.estado, j.vida])
	await vai(ga.to_global(Vector3(-0.8, 0, 3.0)), 0.8, 25, false)
	await vai(ga.to_global(Vector3(-0.6, 0, 7.4)), 1.0, 25)
	await vai(xz(Mundo.VILA.x + 14, Mundo.VILA.y - 2), 2.0)
	for q in Mundo.TRILHAS[1].slice(1):
		await vai(xz(q[0], q[1]), 3.0)
	await vai(loc.nos["gerador"].to_global(Vector3(0.0, 0, 1.6)), 0.7, 40)
	await usa("gerador", false)
	await seg(7.0)
	diz("luz da torre=%.1f" % loc.luzes_torre[1][0].light_energy)
	await vai(tor.to_global(Vector3(2.0, 0, -5.0)), 1.0, 20)
	await vai(tor.to_global(Vector3(-4.6, 0, -4.2)), 1.0, 20)
	await vai(tor.to_global(Vector3(-4.4, 0, -0.6)), 0.8, 20, false)
	await vai(tor.to_global(Vector3(-3.1, 0, -0.6)), 0.5, 20, false)
	await usa("portao", false)
	await seg(1.8)
	await sobe(tor)
	diz("topo da torre na_torre=%s" % pr.his._na_torre)
	await usa("rifle", false)
	await usa("municao", false)
	await vai(tor.to_global(Vector3(0.4, Locais.H_TORRE, 1.2)), 0.5, 15, false)
	await usa("livro")
	await usa("radio")
	await ate(func(): return Jogo.etapa == 7, 90, "radio")
	diz("chamou ajuda; itens=" + str(Jogo.itens))


func _cerco() -> void:
	var tor: Node3D = loc.nos["torre"]
	if Teste.a.has("morte"):
		pr.dir.t_ataque = 2.0
		await ate(func(): return Jogo.mortes > 0, 260, "tres golpes")
		diz("morreu com danos=%d" % j.danos)
		await ate(func(): return not j.morto and not j.travado and Jogo.etapa == 7, 60, "renascer")
		diz("renasceu em %s etapa=%d danos=%d" % [j.global_position, Jogo.etapa, j.danos])
		Teste.a.erase("morte")
	if Teste.a.has("espera"):
		await ate(func():
			j.danos = 0
			return Jogo.etapa >= 8, 330, "amanhecer sem matar")
		diz("sobreviveu sem matar")
	else:
		var tiros := 0
		var t := 0.0
		while not pr.cri.morta and t < 400.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			j.danos = 0
			var c: Criatura = pr.cri
			if c.visible and c.estado in [Criatura.E.CACA, Criatura.E.TORRE]:
				mira(c.altura_cabeca() - Vector3.UP * 0.35)
				j.robo = {"foco": true}
				if c.dist_jog() < 18.0 and j.rifle._t <= 0.0 and j.rifle._recarrega <= 0.0 and c.vidas > 0:
					await get_tree().process_frame
					var antes := c.vidas
					j.rifle.atirar(j)
					tiros += 1
					diz("tiro %d a %.1f m: vidas %d -> %d" % [tiros, c.dist_jog(), antes, c.vidas])
			else:
				j.robo = {}
				if j.rifle.pente < 3: j.rifle.recarregar()
			if tiros == 1 and pr.his._na_torre and t > 60.0: t += 0.0
		diz("matou=%s tiros=%d em %.0f s" % [pr.cri.morta, tiros, t])
	await ate(func(): return Jogo.etapa == 8, 60, "etapa 8")
	await ate(func(): return Jogo.flags.get("policia", false), 90, "policia")
	diz("policia chegou hora=%.2f" % pr.fl.clima.hora)
	if pr.his._na_torre or j.global_position.y > tor.global_position.y + 2.0:
		await desce(tor)
	await seg(3.0)
	var pp: Vector3 = pr.his._vil_pol[0].global_position
	await vai(Vector3(pp.x, 0, pp.z), 5.0, 60)
	await ate(func(): return pr.fase == "final", 60, "tela final")
	diz("TERMINOU falhas=%d tempo_de_jogo=%.1f min mortes=%d final=%s" % [falhas, Jogo.tempo / 60.0, Jogo.mortes, pr.menu._titulo.text])
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
