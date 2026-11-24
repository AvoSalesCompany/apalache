class_name Historia
extends Node
## Roteiro: etapas, itens, notas, gatilhos por lugar, mortes e finais.
## Etapas: 0 acordar | 1 destrocos | 2 seguir o rio | 3 cabana | 4 ir a torre
##         5 torre aberta | 6 estrada | 7 ponte/perseguicao | 8 rodovia | 9 fim

signal acabou(final: String)

const NOTAS := {
	"desenho": ["Saco de papel, poltrona 4B", "Desenho de criança, em giz de cera.\n\nO avião. A lua. E na asa, de pé, um bicho de chifres mais alto que a janela.\n\nEmbaixo, em letra torta:\n\n\"ELE ESTÁ ACENANDO.\""],
	"regras": ["Tábua entalhada", "Entalhado à faca, há muitos anos:\n\nNÃO GRITE.\nNÃO RESPONDA.\nNÃO SIGA AS LUZES.\nSE O MATO CALAR, CALE TAMBÉM.\n\nE mais embaixo, recente, ainda com lascas claras:\n\nELE SÓ SABE O QUE VOCÊ CONTAR."],
	"diario": ["Caderno do guarda", "12 de outubro. Os cães não passam mais do riacho.\n\n15 de outubro. Minha avó dizia que tem coisa nestes montes mais velha que os montes. Que ela não tem voz, então pega a dos outros. Primeiro chama de longe, pra ver se você responde. Se responder, ela fica sabendo onde você está. Se disser seu nome, ela fica sabendo quem você é.\n\n19 de outubro. Vi um cervo parado na clareira. Os olhos eram na frente da cara. Quando percebeu que eu tinha visto, ele se levantou.\n\n23 de outubro. Vou até a Torre 4 chamar pelo rádio. A chave fica no prego. Se os grilos pararem eu me enfio no rododendro, agacho e não respiro.\n\n24 de outubro. Alguém bateu na porta com a minha voz."],
	"lapides": ["Lápides", "Sobrenomes diferentes. Séculos diferentes.\n\nA mesma data de morte em todas:\n\n24 DE OUTUBRO."],
	"torre": ["Livro da Torre 4", "Registro de ocorrências.\n\n24/10/1931 — bimotor do correio. Nenhum corpo.\n24/10/1959 — teco-teco. Nenhum corpo.\n24/10/1987 —\n\nA linha de hoje já está preenchida, com a tinta ainda molhada:\n\nVoo 609. Dezenove a bordo.\nFalta um."],
}

var fl: Floresta
var _t := 0.0
var _radio_ok := false
var _na_torre := false
var _moeda := 0.0
var _cam_t := -1.0


func _ready() -> void:
	Jogo.historia = self


func _j() -> Jogador:
	return Jogo.jogador


func esperar(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


# =============================================================== inicio
func comecar(novo: bool) -> void:
	var j := _j()
	var loc := fl.locais
	Jogo.flags["vivo"] = true
	if novo:
		var a: Node3D = loc.nos["acorda"]
		j.por_em(a.global_position + Vector3.UP * 0.1, 0.0)
		var d := Vector2(Mundo.QUEDA.x - a.global_position.x, Mundo.QUEDA.y - a.global_position.z)
		j.rotation.y = atan2(-d.x, -d.y) + 0.5
		j.vida = Jogo.vida_salva
		j.frio = 8.0
		await _acordar()
	else:
		j.por_em(Jogo.pos_salva + Vector3.UP * 0.1, Jogo.giro_salvo)
		j.vida = Jogo.vida_salva
		j.frio = Jogo.frio_salvo
		_restaura()
		Jogo.hud.escurecer(0.0, 2.0)
		Jogo.definir_objetivo(Jogo.objetivo)
	j.morto = false
	j.travado = false
	j.so_olhar = false
	Jogo.diretor.reset()
	Jogo.diretor.ligado = true


func _restaura() -> void:
	var loc := fl.locais
	for k in ["jaqueta", "kit", "bussola", "chave", "curativo2"]:
		if Jogo.flags.get("pegou_" + k, false):
			loc.it[k].ativo = false
			loc.nos[k].visible = false
	if Jogo.flags.get("portao", false):
		loc.abrir_portao()
	if Jogo.flags.get("fogao", false):
		_luz_fogao()
	if Jogo.flags.get("radio", false):
		loc.it["radio"].ativo = false
	for f in loc.fogos:
		f.visible = Jogo.etapa < 4


func _acordar() -> void:
	var j := _j()
	var h: Hud = Jogo.hud
	h.escurecer(1.0, 0.0)
	h.tonto = 1.0
	Som.abafado = 1.0
	Som.toca("zumbido", -6, 1.0, "UI")
	j.travado = true
	j.incl = 0.9
	await esperar(2.0)
	j.agachado = true
	j._olho = 0.35
	h.escurecer(0.15, 3.0)
	var t := create_tween()
	t.tween_property(j, "incl", 0.15, 5.0).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(h, "tonto", 0.0, 9.0)
	t.parallel().tween_property(Som, "abafado", 0.0, 8.0)
	await esperar(2.2)
	h.escurecer(0.85, 0.5)
	await esperar(0.8)
	h.escurecer(0.0, 2.2)
	h.capitulo("HOLLER", "em algum lugar dos montes Apalaches — 24 de outubro, 2h17", 3.5)
	await esperar(3.5)
	j.so_olhar = true
	j.travado = false
	Jogo.falar("você", "...Ei? Alguém?", 3.0)
	await esperar(3.6)
	Jogo.falar("", "As poltronas estão vazias. Os cintos continuam afivelados.", 4.5)
	await esperar(2.0)
	j.so_olhar = false
	Jogo.etapa = 1
	Jogo.definir_objetivo("Reviste os destroços  (0/3)")
	Jogo.aviso.emit("WASD andar  ·  Mouse olhar  ·  E usar  ·  Shift correr  ·  Ctrl agachar")
	Jogo.salvar()


# =============================================================== itens e notas
func pegar(id: String) -> void:
	var loc := fl.locais
	loc.it[id].ativo = false
	loc.nos[id].visible = false
	Jogo.flags["pegou_" + id] = true
	Som.toca("pegar", -4)
	match id:
		"jaqueta":
			Jogo.dar("jaqueta")
			Jogo.aviso.emit("Jaqueta de lona — você perde calor mais devagar")
		"kit":
			Jogo.dar("curativo", 2)
			Jogo.aviso.emit("Curativos ×2  —  [H] para usar")
		"curativo2":
			Jogo.dar("curativo")
			Jogo.aviso.emit("Curativo  —  [H] para usar")
		"bussola":
			Jogo.dar("bussola")
			Jogo.aviso.emit("Bússola  —  segure [C]")
		"chave":
			Jogo.dar("chave")
			Som.toca("chave", -4)
			Jogo.aviso.emit("Chave — Torre 4")
			_batidas()
	if id in ["jaqueta", "kit", "bussola"]:
		var n := 0
		for k in ["jaqueta", "kit", "bussola"]:
			if Jogo.flags.get("pegou_" + k, false): n += 1
		if n < 3 and Jogo.etapa == 1:
			Jogo.definir_objetivo("Reviste os destroços  (%d/3)" % n)
		elif Jogo.etapa == 1:
			_sair_dos_destrocos()


func _sair_dos_destrocos() -> void:
	Jogo.etapa = 2
	Jogo.salvar()
	await esperar(2.0)
	Jogo.falar("você", "Água desce. E água sempre acaba em gente.", 4.0)
	Jogo.definir_objetivo("Ache o riacho a leste e siga a correnteza")
	await esperar(5.0)
	Som.em("assobio", _j().global_position + Vector3(-40, 4, -36), 3.0, 180, 1.0, "Eco", 16.0)
	Jogo.diretor.silencio_alvo = 1.0
	Jogo.diretor.silencio = 0.7
	await esperar(3.5)
	Jogo.falar("", "Alguém assobiou. Na direção de onde o avião veio.", 4.0)


func ler_nota(id: String) -> void:
	if id == "regras":
		Jogo.flags["regras"] = true
	Jogo.ler(NOTAS[id][0], NOTAS[id][1])
	if id == "regras" and not Jogo.flags.get("viu_regras", false):
		Jogo.flags["viu_regras"] = true
		await Jogo.hud.leitura_fechou
		await esperar(1.0)
		if Jogo.etapa == 2:
			# primeira aparicao: do outro lado do riacho
			var c: Criatura = Jogo.criatura
			c.colocar(Vector3(-196, 0, -143), _j().global_position)
			c.muda(Criatura.E.OBSERVA)
			Jogo.diretor.silencio_alvo = 1.0
	if id == "torre":
		await Jogo.hud.leitura_fechou
		await esperar(1.2)
		Som.em("v_sus_atras", _j().global_position + _j().cam.global_transform.basis.z * 1.2, 4.0, 20, 1.0, "Voz", 2.0)


# =============================================================== cabana
func _batidas() -> void:
	var j := _j()
	var loc := fl.locais
	if Jogo.etapa < 3: Jogo.etapa = 3
	await esperar(2.4)
	Jogo.diretor.alivio = 60.0
	Jogo.diretor.silencio_alvo = 1.0
	Jogo.diretor.chamando = 26.0
	Jogo.diretor.pos_voz = Vector3(9999, 0, 9999)
	if loc.porta_aberta:
		loc.mover_porta(false, true)
		Som.em("batida_metal", loc.porta.global_position, -6.0, 40, 0.7)
		await esperar(1.6)
	for i in 3:
		Som.em("p_madeira%d" % (i + 1), loc.porta.global_position + Vector3.UP, 10.0, 40, 0.7, "Eco", 5.0)
		j.tremer(0.03)
		await esperar(0.75)
	await esperar(1.6)
	Som.em("v_socorro", loc.porta.global_position + Vector3.UP * 1.6, 5.0, 40, 1.0, "Voz", 4.0)
	Jogo.falar("do outro lado da porta", "Socorro... me ajuda...", 4.0)
	j.medo = maxf(j.medo, 0.6)
	await esperar(6.0)
	Som.em("v_cintos", loc.porta.global_position + Vector3.UP * 1.6, 5.0, 40, 1.0, "Voz", 4.0)
	Jogo.falar("do outro lado da porta", "Apertem... os cintos...", 4.0)
	await esperar(5.0)
	Som.em("cr_estalos", loc.porta.global_position, 2.0, 30)
	await esperar(2.0)
	Som.em("cr_passo1", loc.porta.global_position + Vector3(0, 0, 3), 2.0, 60)
	await esperar(1.0)
	Som.em("cr_passo2", loc.porta.global_position + Vector3(0, 0, 8), 0.0, 60)
	await esperar(2.5)
	Jogo.diretor.chamando = 0.0
	Jogo.diretor.silencio_alvo = 0.0
	Jogo.etapa = maxi(Jogo.etapa, 4)
	Jogo.definir_objetivo("Siga a trilha para leste até a Torre 4")
	for f in fl.locais.fogos: f.visible = false
	Jogo.salvar()


func acender_fogao() -> void:
	Jogo.flags["fogao"] = true
	Som.toca("fosforo", -4)
	_luz_fogao()
	Jogo.aviso.emit("O calor volta devagar aos seus dedos")


func _luz_fogao() -> void:
	var loc := fl.locais
	loc.it["fogao"].ativo = false
	loc.fogao_luz.visible = true
	create_tween().tween_property(loc.fogao_luz, "base", 2.0, 3.0)
	Som.loop3d("fogo", loc.fogao_luz, Vector3.ZERO, -10.0, 14.0, 2.0)


# =============================================================== cemiterio
func cova() -> void:
	if Jogo.flags.get("cova", false):
		return
	Jogo.flags["cova"] = true
	fl.locais.it["cova"].ativo = false
	var j := _j()
	j.travado = true
	j.olhar_forcado = fl.locais.nos["cova"].global_position + Vector3.UP * 0.9
	Som.toca("stinger2", -2)
	Jogo.falar("", "A madeira é nova. A terra ainda está molhada.", 3.5)
	await esperar(3.4)
	Jogo.falar("você", "...É o meu nome.", 2.6)
	j.medo = maxf(j.medo, 0.7)
	await esperar(2.2)
	j.olhar_forcado = Vector3.INF
	j.travado = false
	Som.em("v_alex1", j.global_position + j.cam.global_transform.basis.z * 5.0, 5.0, 60, 0.92, "Eco", 8.0)
	Jogo.falar("atrás de você", "Alex...", 3.0)
	Jogo.diretor.chamando = 10.0
	Jogo.diretor.pos_voz = Vector3(9999, 0, 9999)
	Jogo.diretor.silencio_alvo = 1.0
	await esperar(3.0)
	var c: Criatura = Jogo.criatura
	if c.estado == Criatura.E.OCULTO and not j.morto:
		var p := Mundo.CEMITERIO + Vector2(-16, 12)
		c.colocar(Vector3(p.x, 0, p.y), j.global_position)
		c.muda(Criatura.E.OBSERVA)


# =============================================================== torre
func portao() -> void:
	if Jogo.tem("chave") <= 0:
		Som.em("batida_metal", fl.locais.portao.global_position, -8.0, 40)
		Jogo.aviso.emit("Cadeado. A plaquinha diz: CHAVE COM O GUARDA")
		if Jogo.etapa < 4:
			Jogo.definir_objetivo("Ache a chave: a cabana do guarda, perto do riacho")
		return
	Som.toca("chave", -2)
	Jogo.flags["portao"] = true
	fl.locais.abrir_portao()
	Jogo.etapa = maxi(Jogo.etapa, 5)
	Jogo.definir_objetivo("Suba e use o rádio")
	Jogo.salvar()


func radio() -> void:
	if Jogo.flags.get("radio", false):
		return
	Jogo.flags["radio"] = true
	fl.locais.it["radio"].ativo = false
	var j := _j()
	j.so_olhar = true
	var pr: Vector3 = fl.locais.it["radio"].global_position
	Som.toca("radio_clique", -2)
	Jogo.diretor.alivio = 200.0
	Jogo.diretor.ligado = false
	Jogo.criatura.esconder()
	var est := Som.loop3d("radio_estatica", fl.locais, fl.locais.to_local(pr), -6.0, 20.0, 3.0)
	await esperar(2.5)
	Jogo.falar("você", "Alguém na escuta? Torre 4. O avião caiu. Alguém na escuta?", 4.0)
	await esperar(5.0)
	est.volume_db = -14
	var v := Som.em("v_guarda1", pr, 4.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Torre 4, aqui é a guarda florestal de Cold Holler. Estou te ouvindo. Escuta com atenção.", 6.0)
	await esperar(6.2)
	Jogo.falar("rádio", "Não fica aí. Desce pela estrada de serviço, atravessa a ponte e segue para leste, até as luzes da cidade.", 8.0)
	await esperar(maxf(2.0, v.stream.get_length() - 6.2 + 0.4) if is_instance_valid(v) else 8.0)
	var v2 := Som.em("v_guarda2", pr, 4.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "E não responde pra ninguém. Ninguém que você encontrar aí vai saber o seu nome.", 6.0)
	await esperar(7.0)
	est.volume_db = -2
	await esperar(2.4)
	est.volume_db = -20
	await esperar(1.2)
	var v3 := Som.em("v_falsa", pr, 6.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Torre 4... aqui é a comandante. Fique onde está.", 4.6)
	j.medo = 0.7
	await esperar(5.2)
	Jogo.falar("rádio", "Eu estou subindo.", 3.0)
	await esperar(3.0)
	est.stop()
	Som.toca("stinger2", -4)
	j.so_olhar = false
	Jogo.definir_objetivo("Esconda-se! Agache no canto da chapa, atrás da mesa caída")
	await _subida()


func _subida() -> void:
	var j := _j()
	var c: Criatura = Jogo.criatura
	var t: Node3D = fl.locais.nos["torre"]
	var base := t.global_position
	# passos no metal, subindo
	for i in 10:
		var y := lerpf(0.5, 14.0, i / 9.0)
		Som.em("p_metal%d" % randi_range(1, 5), base + Vector3(sin(i * 1.4), y, 0), lerpf(0.0, 7.0, i / 9.0), 50, 0.62, "Eco", 6.0)
		if i in [3, 6, 8]: Som.em("metal%d" % randi_range(1, 2), base + Vector3.UP * y, -2.0, 60)
		j.tremer(0.012 + i * 0.004)
		await esperar(lerpf(1.35, 0.8, i / 9.0))
		if j.morto: return
	# aparece pelo alcapao
	var p1 := t.to_global(Vector3(2.0, Locais.H_TORRE + 0.05, -0.6))
	var p2 := t.to_global(Vector3(0.6, Locais.H_TORRE + 0.05, 1.1))
	c.estado = Criatura.E.OCULTO
	c.colocar(p1, j.global_position)
	c.global_position = p1
	c.em_pe = 1.0
	c.muda(Criatura.E.TORRE)
	c.em_pe_alvo = 1.0
	c.scale = Vector3.ONE * 0.86
	Som.em("cr_respira", p1 + Vector3.UP * 2, 4.0, 30, 0.8)
	var tempo := 0.0
	var fase := 0
	while tempo < 13.0:
		var dt := get_process_delta_time()
		await get_tree().process_frame
		if not is_inside_tree(): return
		tempo += dt
		var alvo := p2 if tempo < 7.5 else p1
		if tempo > 1.5:
			var d := alvo - c.global_position
			if d.length() > 0.2:
				c.global_position += d.normalized() * minf(d.length(), 0.75 * dt)
				c.vel = 0.75
				c.rumo = atan2(-d.x, -d.z)
			else:
				c.vel = 0.0
				c.rumo += sin(tempo * 1.3) * dt * 0.9
			c.rotation.y = lerp_angle(c.rotation.y, c.rumo, dt * 2.5)
		if fase == 0 and tempo > 3.5:
			fase = 1
			Som.em("v_alex2", c.global_position + Vector3.UP * 2.2, 4.0, 30, 0.9, "Voz", 4.0)
			Jogo.falar("", "Alex? Cadê você?", 3.0)
		if fase == 1 and tempo > 7.0:
			fase = 2
			Som.em("cr_estalos", c.global_position + Vector3.UP * 2, 4.0, 30)
			c.torce_alvo = 1.0
		var safo: bool = j.esconderijo and j.agachado and j.ruido < 5.0
		if tempo > 1.2 and not safo:
			c.scale = Vector3.ONE
			pego()
			return
	# vai embora
	Som.em("cr_passo1", p1, 2.0, 40)
	c.esconder()
	c.scale = Vector3.ONE
	for i in 6:
		Som.em("p_metal%d" % randi_range(1, 5), base + Vector3.UP * lerpf(13, 1, i / 5.0), lerpf(3.0, -6.0, i / 5.0), 50, 0.62)
		await esperar(0.6)
	Som.em("cr_grito1", base + Vector3(60, 4, -50), 8.0, 260, 0.9, "Eco", 22.0)
	Jogo.etapa = 6
	Jogo.definir_objetivo("Desça a torre e siga a estrada de serviço para o sul, até a ponte")
	Jogo.diretor.ligado = true
	Jogo.diretor.alivio = 30.0
	Jogo.salvar()


# =============================================================== morte
func pego() -> void:
	var j := _j()
	var c: Criatura = Jogo.criatura
	if j.morto: return
	if j.vida > 60.0 and not Jogo.flags.get("torre_agora", false) and c.estado != Criatura.E.TORRE:
		# primeiro golpe: fere e solta
		j.ferir(52.0)
		j.tremer(0.9)
		Jogo.hud.dano = 1.0
		j.medo = 1.0
		Som.toca("cr_ataque", 2)
		Som.toca("queda_corpo", 2)
		var d: Vector3 = (j.global_position - c.global_position)
		d.y = 0
		j.velocity = d.normalized() * 7.0 + Vector3.UP * 3.0
		c.livre_ate = Time.get_ticks_msec() / 1000.0 + 5.0
		Jogo.diretor.alivio = 30.0
		Jogo.diretor.tensao = 0.4
		await esperar(0.25)
		c.muda(Criatura.E.RECUA)
		Jogo.falar("", "Ele soltou. Ele quis soltar.", 3.5)
		return
	morrer("pego")


func morrer(causa: String) -> void:
	var j := _j()
	if j.morto: return
	var c: Criatura = Jogo.criatura
	j.travado = true
	Jogo.mortes += 1
	Jogo.diretor.ligado = false
	if causa == "pego":
		c.muda(Criatura.E.ATAQUE)
		c.em_pe = 1.0
		c.em_pe_alvo = 1.0
		var f: Vector3 = c.global_position - j.global_position
		f.y = 0
		if f.length() < 0.1: f = Vector3.FORWARD
		c.global_position = j.global_position + f.normalized() * 1.25
		c.rumo = atan2(f.x, f.z)
		c.rotation.y = c.rumo
		Som.toca("cr_ataque", 4)
		Som.toca("stinger1", 0)
		j.medo = 1.0
		j.tremer(1.0)
		for i in 36:
			j.olhar_forcado = c.altura_cabeca()
			j.tremer(0.5)
			await get_tree().process_frame
			if not is_inside_tree(): return
		Jogo.hud.dano = 1.0
		Jogo.hud.escurecer(1.0, 0.12)
		Som.toca("queda_corpo", 4)
		Som.toca("galho2", 2, 0.6)
	else:
		Jogo.hud.escurecer(1.0, 3.0)
		create_tween().tween_property(Som, "abafado", 1.0, 2.5)
		await esperar(3.0)
	j.morto = true
	Som.abafado = 0.6
	await esperar(1.6)
	var fr := {"pego": ["Agora ele tem a sua voz.", "Na próxima vez, ele vai chamar alguém com ela.", "Falta nenhum."], "frio": ["O frio foi gentil."], "ferida": ["A serra fica com o que cai nela."]}
	var l: Array = fr[causa]
	Jogo.hud.capitulo(l[Jogo.mortes % l.size()], "", 2.2)
	if causa == "pego": Som.toca("v_alex1", -4, 0.95, "UI")
	await esperar(5.2)
	if not is_inside_tree(): return
	renascer()


func renascer() -> void:
	var j := _j()
	if Jogo.carregar():
		pass
	Som.abafado = 0.0
	Jogo.hud.limpar()
	Jogo.criatura.esconder()
	Jogo.criatura.scale = Vector3.ONE
	j.olhar_forcado = Vector3.INF
	j.medo = 0.0
	j.folego = 100.0
	j.esconderijo = false
	# a cena do radio recomeca se ele morreu nela
	if Jogo.etapa == 5:
		Jogo.flags["radio"] = false
		fl.locais.it["radio"].ativo = true
	if Jogo.etapa < 7:
		Jogo.flags.erase("ponte")
	fl.firmar(Jogo.pos_salva)
	j.morto = false
	comecar(false)


# =============================================================== gatilhos por lugar
func _process(dt: float) -> void:
	var j := _j()
	if j == null or j.morto or fl == null or not fl.visible or Jogo.etapa == 0 or Jogo.etapa >= 9:
		return
	Jogo.tempo += dt
	_t -= dt
	_calor(dt, j)
	if _t > 0.0:
		return
	_t = 0.2
	var p := Vector2(j.global_position.x, j.global_position.z)
	# abrigo
	var cab: Node3D = fl.locais.nos["cabana"]
	var lc := cab.to_local(j.global_position)
	var na_cab := absf(lc.x) < 2.9 and absf(lc.z) < 2.3 and lc.y < 3.0
	var tor: Node3D = fl.locais.nos["torre"]
	var lt := tor.to_local(j.global_position)
	_na_torre = absf(lt.x) < 2.6 and absf(lt.z) < 2.6 and lt.y > Locais.H_TORRE - 0.5
	j.abrigado = na_cab
	j.esconderijo = _na_torre and lt.distance_to(Vector3(1.9, Locais.H_TORRE, 2.0)) < 1.05
	match Jogo.etapa:
		1:
			if p.distance_to(Mundo.QUEDA) > 70.0:
				_sair_dos_destrocos()
		2:
			if not Jogo.flags.get("rio", false) and Mundo.dist(Mundo.RIO, p.x, p.y) < 7.0:
				Jogo.flags["rio"] = true
				Jogo.definir_objetivo("Siga o riacho correnteza abaixo")
				Jogo.aviso.emit("Olhe para a água e aperte E para pegar pedras. Água gelada rouba calor.")
				Jogo.salvar()
			if not Jogo.flags.get("susto1", false) and p.distance_to(Vector2(-232, -215)) < 24.0:
				Jogo.flags["susto1"] = true
				Som.em("raposa", j.global_position + Vector3(-18, 2, 22), 4.0, 120)
				j.medo = maxf(j.medo, 0.4)
			if not Jogo.flags.get("perto_placa", false) and p.distance_to(Mundo.PLACA_REGRAS) < 26.0:
				Jogo.flags["perto_placa"] = true
				Jogo.definir_objetivo("Há uma trilha e uma tábua na margem")
			if p.distance_to(Mundo.CABANA) < 30.0:
				Jogo.etapa = 3
				Jogo.definir_objetivo("Uma cabana. Procure algo que ajude")
				Jogo.salvar()
		4:
			if not Jogo.flags.get("cemit", false) and p.distance_to(Mundo.CEMITERIO) < 13.0:
				Jogo.flags["cemit"] = true
				Som.em("v_sus_cair", j.global_position + j.cam.global_transform.basis.z * 2.0, 2.0, 20, 1.0, "Voz", 3.0)
			if not Jogo.flags.get("viu_torre", false) and p.distance_to(Mundo.TORRE) < 30.0:
				Jogo.flags["viu_torre"] = true
				Jogo.definir_objetivo("Abra o portão da torre")
				Jogo.salvar()
		6:
			if not Jogo.flags.get("vista", false) and p.distance_to(Vector2(248, 45)) < 22.0:
				Jogo.flags["vista"] = true
				Jogo.salvar()
			if not Jogo.flags.get("luz_dica", false) and p.distance_to(Mundo.LUZES) < 62.0:
				Jogo.flags["luz_dica"] = true
				Jogo.falar("", "Luzes entre as árvores, fora da estrada. Parecem lanternas.", 4.0)
				Som.em("v_vivo", Mundo.chaov(Mundo.LUZES) + Vector3.UP * 2, 5.0, 130, 1.0, "Eco", 14.0)
			if p.distance_to(Vector2(303, 268)) < 12.0 and not Jogo.flags.get("ponte", false):
				Jogo.flags["ponte"] = true
				Jogo.etapa = 7
				Jogo.definir_objetivo("Atravesse a ponte")
				Jogo.salvar()
		7:
			if not Jogo.flags.get("corre", false) and p.distance_to(Mundo.PONTE) < 6.0:
				Jogo.flags["corre"] = true
				_perseguicao()
			if Mundo.dist(Mundo.RODOVIA, p.x, p.y) < 5.5:
				_na_rodovia()
		8:
			if p.x > 408.0 and Mundo.dist(Mundo.RODOVIA, p.x, p.y) < 40.0:
				_final_bom()
			elif not Jogo.flags.get("camin", false) and p.x > 296.0:
				Jogo.flags["camin"] = true
				_caminhonete()
	_anda_caminhonete(0.2)


func _calor(dt: float, j: Jogador) -> void:
	for f in fl.locais.fogos:
		if f.visible and f.global_position.distance_to(j.global_position) < 5.0:
			j.frio = maxf(0.0, j.frio - dt * 4.0)
	if j.abrigado and Jogo.flags.get("fogao", false):
		j.frio = maxf(0.0, j.frio - dt * 5.0)


# =============================================================== ponte e fim
func _perseguicao() -> void:
	var j := _j()
	var c: Criatura = Jogo.criatura
	Jogo.diretor.silencio = 1.0
	Jogo.diretor.ligado = true
	c.esconder()
	Som.em("metal1", j.global_position, -2.0, 40)
	await esperar(0.8)
	Som.em("cr_grito1", j.global_position + Vector3(8, 2, -30), 12.0, 260, 0.85, "Eco", 26.0)
	Som.toca("stinger1", -2)
	Jogo.definir_objetivo("CORRA")
	await esperar(0.9)
	if j.morto: return
	c.colocar(Vector3(309, 0, 250), j.global_position)
	c.ultimo_visto = j.global_position
	c.livre_ate = Time.get_ticks_msec() / 1000.0 + 2.0
	c.muda(Criatura.E.CACA)
	c.agressao = 1.0


func _na_rodovia() -> void:
	Jogo.etapa = 8
	var c: Criatura = Jogo.criatura
	if c.visible:
		c.muda(Criatura.E.RECUA)
		Som.em("cr_grito2", c.global_position, 8.0, 200, 0.8, "Eco", 20.0)
	Jogo.diretor.ligado = false
	Jogo.diretor.silencio = 1.0
	Jogo.definir_objetivo("Asfalto. Siga para leste, até as luzes")
	Jogo.falar("", "Ele parou onde o asfalto começa.", 4.0)
	Jogo.salvar()


func _caminhonete() -> void:
	var g := fl.locais.caminhonete
	g.visible = true
	_cam_t = 0.0
	g.set_meta("x", 150.0)
	Som.loop3d("caminhao", g, Vector3.ZERO, 2.0, 120.0, 9.0)
	Jogo.falar("", "Faróis.", 2.0)


func _anda_caminhonete(_d: float) -> void:
	pass


func _physics_process(dt: float) -> void:
	if _cam_t < 0.0 or fl == null:
		return
	var j := _j()
	var g := fl.locais.caminhonete
	_cam_t += dt
	var x: float = g.get_meta("x")
	var alvo := minf(j.global_position.x - 5.0, 385.0)
	if not Jogo.flags.get("parou", false):
		var v := clampf((alvo - x) * 0.55, 0.0, 15.0)
		x += v * dt
		g.set_meta("x", x)
		if alvo - x < 1.5:
			Jogo.flags["parou"] = true
			_motorista()
	var l := fl.locais
	var z := l._z_rod(x) - 1.7
	var z2 := l._z_rod(x + 2.0) - 1.7
	g.global_position = Vector3(x, Mundo.altura(x, z) + 0.12, z)
	g.rotation.y = atan2(-2.0, -(z2 - z))


func _motorista() -> void:
	var j := _j()
	var g := fl.locais.caminhonete
	var pos := g.global_position + Vector3.UP * 1.4
	Som.em("buzina", pos, -4.0, 60)
	await esperar(1.4)
	Som.em("v_motorista1", pos, 5.0, 40, 1.0, "Voz", 6.0)
	Jogo.falar("motorista", "Ei! Meu Deus. Você tá bem? Entra aí, eu te levo pra cidade.", 5.0)
	fl.locais.it["carona"].ativo = true
	await esperar(8.0)
	if Jogo.etapa != 8: return
	Som.em("v_motorista2", pos, 5.0, 40, 1.0, "Voz", 6.0)
	Jogo.falar("motorista", "Entra logo.", 2.2)
	await esperar(2.4)
	if Jogo.etapa != 8: return
	Jogo.falar("motorista", "Alex.", 3.0)
	Jogo.diretor.silencio = 1.0
	j.medo = maxf(j.medo, 0.55)
	Jogo.definir_objetivo("As luzes da cidade estão perto")


func entrar_caminhonete() -> void:
	if Jogo.etapa != 8: return
	Jogo.etapa = 9
	var j := _j()
	j.travado = true
	Som.toca("batida_metal", -4, 0.8)
	Jogo.hud.escurecer(1.0, 1.4)
	await esperar(2.4)
	Som.toca("v_cintos", 0, 0.95, "UI")
	Jogo.falar("motorista", "Aperte o cinto.", 4.0)
	await esperar(4.6)
	Som.toca("cr_ataque", 0, 0.9, "UI")
	await esperar(2.2)
	acabou.emit("carona")


func _final_bom() -> void:
	if Jogo.etapa != 8: return
	Jogo.etapa = 9
	var j := _j()
	j.so_olhar = true
	_cam_t = -1.0
	Jogo.definir_objetivo("")
	Jogo.falar("você", "Luz. Luz de gente.", 3.0)
	Jogo.diretor.silencio_alvo = 0.0
	await esperar(3.2)
	Jogo.hud.escurecer(1.0, 4.0)
	await esperar(4.4)
	acabou.emit("civilizacao")
