class_name Historia
extends Node
## Roteiro: etapas, itens, conversas, gatilhos por lugar, ataque, cerco e final.
## Etapas: 0 acordar | 1 destrocos | 2 rumo a vila (dia) | 3 vila (tarde) | 4 noite na casa
##         5 fuga para a torre | 6 chave + gasolina | 7 cerco (ele pode matar) | 8 amanhecer | 9 fim

signal acabou(final: String)

const NOTAS := {
	"igreja": ["Aviso na porta da igreja", "Pregado com um prego só, o papel já amarelo:\n\nAO PÔR DO SOL, PORTA TRANCADA.\nNÃO GRITE.\nNÃO RESPONDA SE CHAMAREM O SEU NOME.\nNÃO SIGA AS LUZES.\nSE O MATO CALAR, CALE TAMBÉM.\n\nE embaixo, a lápis, em letra de criança:\n\nela só sabe o que você contar"],
	"bilhete": ["Bilhete na grade da torre", "Pra quem vier me render,\n\nperdi a chave da torre na privada. De novo. Não enfio mais a mão lá nem morto.\n\nO gerador secou. Sem ele não tem luz nem rádio. O Amos, da vila, guarda um galão de gasolina no galpão.\n\nO rifle está lá em cima, na parede. Espero que você não precise.\n\nWalt — guarda florestal, Torre 4"],
	"lapides": ["Lápides", "Sobrenomes diferentes. Séculos diferentes.\n\nA mesma data de morte em todas:\n\n24 DE JANEIRO."],
	"torre": ["Livro da Torre 4", "Registro de ocorrências.\n\n24/01/1931 — bimotor do correio. Nenhum corpo.\n24/01/1959 — teco-teco. Nenhum corpo.\n24/01/1987 —\n\nA linha de hoje já está preenchida, com a tinta ainda molhada:\n\nVoo 609. Dezenove a bordo.\nFalta um."],
}

const FALAS := {
	"caleb": [["v_caleb1", "Parado aí. Você veio do avião? Nós ouvimos a queda de madrugada. Achei que não tinha sobrado ninguém."],
		["v_caleb2", "A estrada fechou com a neve e o telefone morreu faz uma semana. Rádio, só na Torre 4, e ninguém sobe lá com o sol baixo."],
		["v_caleb3", "Você não pode ficar do lado de fora depois que escurecer. Procure a Ruth, na casa grande, depois da fogueira. E fale com o velho Elias antes da noite."]],
	"elias": [["v_elias1", "Chega perto do fogo. Você tem cara de quem ouviu alguém chamar, lá em cima."],
		["v_elias2", "Estes montes são mais velhos que os ossos. Mais velhos que as árvores, mais velhos que o mar. Quando meus avós chegaram, já tinha alguma coisa morando aqui."],
		["v_elias3", "Ela não tem voz. Então pega a dos outros. Quem vivia aqui antes de nós não dizia o nome dela depois do pôr do sol. Nós também não dizemos."],
		["v_elias4", "Primeiro os pássaros vão embora. Depois os cachorros calam. Depois ela te chama, com a voz de alguém que você perdeu. Se você responde, ela sabe onde você está."],
		["v_elias5", "Cinquenta e seis anos atrás caiu um avião do correio, nesta mesma noite. Ela veio buscar quem sobrou. E levou nove de nós junto. Reza para eu estar errado."]],
	"hannah": [["v_hannah1", "Você é do avião? Meu Deus, que frio. Fica perto da fogueira."],
		["v_hannah2", "Hoje de manhã todos os pássaros voaram para o sul. Todos. Minha mãe dizia que isso só aconteceu uma vez."]],
	"amos": [["v_amos1", "Guardo a gasolina aí dentro, para o gerador da torre. Se a luz da torre acender, a guarda florestal enxerga lá do vale."],
		["v_amos2", "Mas hoje ninguém sobe. Hoje é dia vinte e quatro."]],
	"ruth": [["v_ruth1", "Minha nossa, que frio você deve estar passando. Entra, entra. Tem sopa na mesa e uma cama no quarto. Aqui ninguém paga por abrigo."]],
}
const NOMES := {"caleb": "Caleb", "elias": "Elias", "hannah": "Hannah", "amos": "Amos", "ruth": "Ruth"}

var fl: Floresta
var _t := 0.0
var _na_torre := false
var em_dialogo := false
var pula := false
var _som_gerador: AudioStreamPlayer3D
var cerco_t := 0.0
var _atq := false
var _susto_fora := 0.0
var _vt := 0.0
var _vil_pol: Array = []


func _ready() -> void:
	Jogo.historia = self


func _j() -> Jogador:
	return Jogo.jogador


func esperar(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func vila() -> Vila:
	return fl.vila


func salvar() -> void:
	Jogo.flags["hora"] = fl.clima.hora
	Jogo.salvar()


# =============================================================== inicio
func comecar(novo: bool) -> void:
	var j := _j()
	var loc := fl.locais
	Jogo.flags["vivo"] = true
	em_dialogo = false
	j.danos = int(Jogo.flags.get("danos", 0))
	if novo:
		var a: Node3D = loc.nos["acorda"]
		fl.clima.por(6.35)
		fl.clima.ir(7.1, 0.012)
		fl.clima.neve = 0.25
		fl.clima.neve_alvo = 0.25
		j.por_em(a.global_position + Vector3.UP * 0.1, -PI * 0.5 + 0.25)
		j.vida = Jogo.vida_salva
		j.frio = 18.0
		await _acordar()
	else:
		fl.clima.por(float(Jogo.flags.get("hora", 8.0)))
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
	Jogo.anomalias.reset()
	Jogo.anomalias.ligado = Jogo.etapa >= 5 and Jogo.etapa < 8
	if not novo:
		match Jogo.etapa:
			4: _ataque()
			7: _cerco()
			8: _policia()


func _restaura() -> void:
	var loc := fl.locais
	var v := vila()
	_j().lanterna.bateria = float(Jogo.flags.get("bateria", 100.0))
	for k in loc.nos:
		if Jogo.flags.get("pegou_" + k, false) and loc.it.has(k):
			loc.it[k].ativo = false
			loc.nos[k].visible = false
	if Jogo.flags.get("portao", false): loc.abrir_portao()
	if Jogo.flags.get("pegou_chave", false): loc.it["privada"].ativo = false
	if Jogo.flags.get("gerador", false): _liga_torre(true)
	for f in loc.fogos: f.visible = Jogo.etapa < 3
	if Jogo.etapa == 3:
		_estado_vila()
		if Jogo.flags.get("falou_ruth", false):
			var cr: Node3D = v.casas.ruth
			var g: Gente = v.gente.ruth
			g.position = v.to_local(cr.to_global(Vector3(-2.0, 0.02, 1.5)))
			g.giro_alvo = cr.rotation.y + PI * 0.9
			v.porta_aberta = true
			v.porta_ruth.rotation.y = 1.9
	if Jogo.etapa >= 5: v.destruir()
	fl.clima.neve_alvo = _neve_da_etapa()
	fl.clima.neve = fl.clima.neve_alvo


func _neve_da_etapa() -> float:
	return [0.25, 0.25, 0.35, 0.55, 0.75, 0.75, 0.7, 0.8, 0.2, 0.2][clampi(Jogo.etapa, 0, 9)]


func _acordar() -> void:
	var j := _j()
	var h: Hud = Jogo.hud
	h.escurecer(1.0, 0.0)
	h.tonto = 1.0
	Som.abafado = 1.0
	Som.toca("zumbido", -6, 1.0, "UI")
	j.travado = true
	j.incl = 0.95
	await esperar(2.0)
	j.agachado = true
	j._olho = 0.35
	h.escurecer(0.15, 3.0)
	var t := create_tween()
	t.tween_property(j, "incl", 0.06, 5.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(h, "tonto", 0.0, 9.0)
	t.parallel().tween_property(Som, "abafado", 0.0, 8.0)
	await esperar(2.2)
	h.escurecer(0.85, 0.5)
	await esperar(0.8)
	h.escurecer(0.0, 2.2)
	h.capitulo("HOLLER", "em algum lugar dos montes Apalaches — 24 de janeiro, amanhecer", 3.5)
	await esperar(4.0)
	j.so_olhar = true
	j.travado = false
	Jogo.falar("você", "...Ei? Alguém?", 3.0)
	await esperar(4.2)
	Jogo.falar("", "Ninguém responde. Só o fogo estalando e a neve.", 4.0)
	await esperar(2.0)
	j.so_olhar = false
	Jogo.etapa = 1
	Jogo.definir_objetivo("Reviste os destroços: uma mochila e algo quente")
	Jogo.aviso.emit("WASD andar  ·  Mouse olhar  ·  E usar  ·  Shift correr  ·  Tab inventário")
	salvar()
	await esperar(9.0)
	if Jogo.etapa == 1: Passaros.revoada(fl, j.global_position + Vector3(38, 14, -22), 16, Vector3(0.5, 0.25, 1.0))


# =============================================================== itens e notas
func pegar(id: String) -> void:
	var loc := fl.locais
	loc.it[id].ativo = false
	if id != "mochila": loc.nos[id].visible = false
	Jogo.flags["pegou_" + id] = true
	Som.toca("pegar", -4)
	match id:
		"mochila":
			loc.nos[id].visible = false
			Som.toca("arbusto", -8, 1.3)
			_ganha("mochila")
			await esperar(0.9)
			_ganha("mapa")
			Jogo.aviso.emit("Um mapa da serra — aperte [M]")
			Som.toca("papel", -4)
		"lanterna":
			_ganha("lanterna")
			_j().lanterna.bateria = 100.0
			Jogo.aviso.emit("Lanterna  —  [F] liga e desliga")
			loc.nos["lanterna_luz"].visible = false
		"pilha1", "pilha2", "pilha3":
			_ganha("pilha")
		"jaqueta":
			_ganha("jaqueta")
			Jogo.aviso.emit("Casaco de lona — você perde calor bem mais devagar")
		"kit":
			_ganha("curativo", 2)
			Jogo.aviso.emit("Curativos ×2  —  [H] para usar")
		"curativo3":
			_ganha("curativo")
		"bussola":
			_ganha("bussola")
			Jogo.aviso.emit("Bússola  —  segure [C]")
		"gasolina":
			_ganha("gasolina")
			_pegou_gasolina()
		"rifle":
			_ganha("rifle")
			_j().rifle.pegar()
			Jogo.aviso.emit("Rifle  —  [2] empunhar  ·  botão direito mira  ·  clique atira  ·  [R] recarrega")
		"municao":
			_ganha("municao", 12)
	if Jogo.etapa == 1 and id in ["mochila", "jaqueta", "lanterna", "kit", "bussola"]:
		_confere_destrocos()


func _ganha(id: String, n: int = 1) -> void:
	Jogo.dar(id, n)
	Jogo.hud.mostrar_item(id, n)


func _confere_destrocos() -> void:
	var m: bool = Jogo.flags.get("pegou_mochila", false)
	var q: bool = Jogo.flags.get("pegou_jaqueta", false)
	if m and q:
		Jogo.etapa = 2
		salvar()
		await esperar(2.6)
		Jogo.falar("você", "Cold Holler. Alguém circulou essa vila no mapa. Tenho que chegar lá antes de escurecer.", 5.0)
		Jogo.definir_objetivo("Siga a trilha do riacho até COLD HOLLER antes de escurecer")
	elif m:
		Jogo.definir_objetivo("Ache algo quente: procure dentro do avião")
	elif q:
		Jogo.definir_objetivo("Ache uma mochila perto dos destroços")


func ler_nota(id: String) -> void:
	Jogo.ler(NOTAS[id][0], NOTAS[id][1])
	if id == "igreja": Jogo.flags["regras"] = true
	if id == "bilhete" and not Jogo.flags.get("bilhete", false):
		Jogo.flags["bilhete"] = true
		_objetivo_torre()
	if id == "torre":
		await Jogo.hud.leitura_fechou
		await esperar(1.2)
		Som.em("v_sus_atras", _j().global_position + _j().cam.global_transform.basis.z * 1.2, 4.0, 20, 1.0, "Voz", 2.0)


# =============================================================== conversas
## linhas: [som, texto]
func dialogo(g: Gente, quem: String, linhas: Array) -> void:
	var j := _j()
	em_dialogo = true
	j.so_olhar = true
	g.olhar = j.cam
	for q in linhas:
		var dur := maxf(2.2, q[1].length() * 0.062 + 0.8)
		var st = Som.fluxo(q[0]) if q[0] != "" else null
		if st: dur = maxf(st.get_length() + 0.5, 1.6)
		if Teste.a.has("robo"): dur = 0.4
		g.dizer(q[0], quem, q[1], dur)
		var t := 0.0
		pula = false
		while t < dur:
			await get_tree().process_frame
			if not is_inside_tree(): return
			t += get_process_delta_time()
			if t > 0.7 and pula: break
	pula = false
	j.so_olhar = false
	em_dialogo = false
	g.olhar_fim(j)


func _unhandled_input(e: InputEvent) -> void:
	if em_dialogo and e.is_action_pressed("usar"):
		pula = true


func falar_com(id: String) -> void:
	if em_dialogo: return
	var g: Gente = vila().gente[id]
	var pri: bool = not Jogo.flags.get("falou_" + id, false)
	if id == "ruth":
		await _ruth(g, pri)
		return
	if pri:
		if id == "elias":
			g.giro_alvo = null
			fl.clima.ir(maxf(fl.clima.hora, 16.9), 0.045)
		await dialogo(g, NOMES[id], FALAS[id])
		Jogo.flags["falou_" + id] = true
		if id == "elias": _elias_fim()
		_objetivo_vila()
		salvar()
	else:
		var rep := {"caleb": ["", "Anda. O sol não espera ninguém."], "elias": ["", "Não responde. Por mais que doa."], "hannah": ["", "Entra em alguma casa antes de escurecer."], "amos": ["", "Amanhã eu abro o galpão. Hoje não."]}
		await dialogo(g, NOMES[id], [rep[id]])


func _elias_fim() -> void:
	await esperar(1.5)
	Passaros.revoada(fl, vila().mundo(14, 30) + Vector3.UP * 16.0, 30, Vector3(-0.2, 0.25, 1.0))
	Jogo.falar("", "Os últimos pássaros atravessam a vila, altos, todos para o mesmo lado.", 4.0)


func _ruth(g: Gente, pri: bool) -> void:
	var v := vila()
	if pri:
		await dialogo(g, "Ruth", FALAS.ruth)
		Jogo.flags["falou_ruth"] = true
		if not v.porta_aberta: v.mover_porta(true)
		var cr: Node3D = v.casas.ruth
		var pts := [v.to_local(cr.to_global(Vector3(-1.5, 0.02, 4.1))), v.to_local(cr.to_global(Vector3(-1.5, 0.02, 2.2))), v.to_local(cr.to_global(Vector3(-2.0, 0.02, 1.5)))]
		g.ir(pts, 0.9, func(): g.giro_alvo = cr.rotation.y + PI * 0.9)
		_estado_vila()
		_objetivo_vila()
		salvar()
		return
	if not Jogo.flags.get("sopa", false):
		await dialogo(g, "Ruth", [["", "Toma a sopa enquanto está quente."]])
	elif not Jogo.flags.get("falou_elias", false):
		await dialogo(g, "Ruth", [["", "Antes de deitar, vá ouvir o Elias, na fogueira. É importante."]])
	else:
		await dialogo(g, "Ruth", [["v_ruth2", "Quando o sol sumir, tranca a porta e não abre para ninguém. Nem se for a minha voz."]])


func _estado_vila() -> void:
	var v := vila()
	if Jogo.flags.get("falou_ruth", false):
		v.it["sopa"].ativo = not Jogo.flags.get("sopa", false)
		v.it["cama"].ativo = Jogo.flags.get("sopa", false) and Jogo.flags.get("falou_elias", false)


func sopa() -> void:
	var v := vila()
	Jogo.flags["sopa"] = true
	v.it["sopa"].ativo = false
	Som.toca("talher", -6)
	_j().frio = 0.0
	_j().vida = minf(100.0, _j().vida + 25.0)
	Jogo.aviso.emit("A sopa desce quente até os pés")
	fl.clima.ir(maxf(fl.clima.hora, 17.6), 0.045)
	await esperar(2.5)
	var g: Gente = v.gente.ruth
	if not em_dialogo:
		await dialogo(g, "Ruth", [["v_ruth2", "Quando o sol sumir, tranca a porta e não abre para ninguém. Nem se for a minha voz."]])
	_estado_vila()
	_objetivo_vila()
	salvar()


func _objetivo_vila() -> void:
	if Jogo.etapa != 3: return
	var f := Jogo.flags
	_estado_vila()
	if not f.get("falou_caleb", false) and not f.get("falou_ruth", false):
		Jogo.definir_objetivo("Fale com o homem na entrada da vila")
	elif not f.get("falou_elias", false):
		Jogo.definir_objetivo("Ouça o velho Elias, na fogueira")
	elif not f.get("falou_ruth", false):
		Jogo.definir_objetivo("Procure a Ruth, na casa grande, antes de escurecer")
	elif not f.get("sopa", false):
		Jogo.definir_objetivo("Entre e tome a sopa da Ruth")
	else:
		Jogo.definir_objetivo("A cama fica no quarto. Durma um pouco")
		fl.clima.ir(maxf(fl.clima.hora, 18.3), 0.05)


func bater(id: String) -> void:
	Som.em("p_madeira%d" % randi_range(1, 5), _j().cam.global_position - _j().cam.global_transform.basis.z, 4.0, 30, 0.8)
	await esperar(0.9)
	Jogo.falar("", {"galpao": "Trancado por dentro. Pela fresta: barris, ferramentas e um galão.", "velha": "Alguém apaga a luz lá dentro.", "caleb": "Ninguém em casa.", "hannah": "Ninguém em casa.", "elias": "Ninguém em casa."}.get(id, "Trancada."), 3.0)


# =============================================================== noite e ataque
func dormir() -> void:
	if fl.clima.hora < 17.6:
		fl.clima.ir(18.4, 0.09)
		Jogo.aviso.emit("Ainda está claro. Espere escurecer")
		return
	var j := _j()
	var v := vila()
	v.it["cama"].ativo = false
	j.travado = true
	Jogo.hud.escurecer(1.0, 2.2)
	Som.silencio(0.6)
	await esperar(3.0)
	Jogo.hud.capitulo("Duas e quarenta e sete", "", 2.0)
	await esperar(4.2)
	Jogo.etapa = 4
	fl.clima.por(2.78)
	fl.clima.neve_alvo = 0.75
	var cr: Node3D = v.casas.ruth
	var p := cr.to_global(Vector3(2.2, 0.1, -0.6))
	j.por_em(p, cr.rotation.y + PI * 0.75)
	salvar()
	_ataque()


func _ataque() -> void:
	if _atq: return
	_atq = true
	var j := _j()
	var v := vila()
	var cr: Node3D = v.casas.ruth
	var c: Criatura = Jogo.criatura
	j.travado = true
	Jogo.diretor.ligado = true
	Jogo.diretor.silencio = 0.4
	Jogo.diretor.silencio_alvo = 0.4
	Jogo.hud.escurecer(1.0, 0.0)
	v.porta_ruth.rotation.y = 0.0
	v.porta_aberta = false
	v.it["porta"].ativo = false
	v.luz_mesa.light_energy = 0.0
	v.fogao.base = 0.8
	(cr.get_meta("luz_quarto") as OmniLight3D).light_energy = 0.15
	var ruth: Gente = v.gente.ruth
	ruth.caminho.clear()
	ruth.visible = true
	ruth.position = v.to_local(cr.to_global(Vector3(0.2, 0.02, 1.2)))
	ruth.rotation.y = cr.rotation.y + PI
	ruth.giro_alvo = null
	ruth.pose = "panico"
	ruth.medo = 0.9
	ruth.olhar = j.cam
	v.esconder_moradores(["elias", "hannah", "amos", "caleb"])
	var cao := Som.em("cachorros", v.mundo(22, 14) + Vector3.UP, 4.0, 160, 1.0, "Eco", 16.0)
	await esperar(2.5)
	Jogo.hud.escurecer(0.0, 2.5)
	await esperar(3.5)
	if is_instance_valid(cao): cao.stop()
	Som.em("galho2", v.mundo(22, 14) + Vector3.UP, 8.0, 160, 0.7, "Eco", 14.0)
	j.travado = false
	Jogo.diretor.silencio_alvo = 1.0
	Jogo.diretor.silencio = 1.0
	await esperar(2.2)
	Jogo.falar("", "Os cachorros calaram. Todos ao mesmo tempo.", 3.2)
	await esperar(4.0)
	Som.em("v_alex1", cr.to_global(Vector3(-7, 1.5, 4)), 5.0, 60, 0.95, "Eco", 10.0)
	Jogo.falar("lá fora", "Alex...", 2.6)
	j.medo = maxf(j.medo, 0.5)
	await esperar(3.0)
	ruth.dizer("v_ruth3", "Ruth", "Não responde. Não faz barulho.", 3.0)
	await esperar(4.2)
	# passos no telhado
	for i in 7:
		var p := cr.to_global(Vector3(-3.5 + i * 1.1, 3.6, 0.6))
		Som.em("cr_passo%d" % randi_range(1, 3), p, 4.0, 30, 0.8, "Mundo", 5.0)
		Som.em("madeira_range%d" % randi_range(1, 2), p, 0.0, 25, 0.8)
		j.tremer(0.025)
		await esperar(0.85)
	await esperar(1.6)
	Som.em("cr_respira", cr.to_global(Vector3(3.0, 2.8, 0.6)), 6.0, 20, 0.8)
	await esperar(2.6)
	Som.em("grito_gente", v.mundo(15, -12) + Vector3.UP * 1.5, 8.0, 180, 1.0, "Eco", 18.0)
	Som.toca("stinger2", -2)
	j.medo = 1.0
	await esperar(1.0)
	Som.em("explosao", v.mundo(15, -19), 6.0, 220, 0.9, "Eco", 24.0)
	Jogo.hud.branco = 0.25
	j.tremer(0.5)
	v.queimar("elias")
	await esperar(0.9)
	Som.em("cr_grito1", v.mundo(4, 4) + Vector3.UP * 2, 12.0, 240, 0.85, "Eco", 26.0)
	await esperar(0.8)
	v.mover_porta(true, true)
	v.it["porta"].ativo = false
	Som.em("batida_metal", v.porta_ruth.global_position, 6.0, 60, 0.5)
	v.queimar("hannah")
	ruth.dizer("v_ruth4", "Ruth", "Ela entrou na vila! Corre para a torre, a leste, depois do cemitério! Chama ajuda no rádio! Vai! Vai!", 6.5)
	Jogo.etapa = 5
	Jogo.definir_objetivo("CORRA — siga a trilha a leste até a torre")
	Som.toca("stinger1", -4)
	Som.camada("mus_caca", 0.6, 0.5, "Musica")
	salvar_em_fuga()
	_panico_na_vila()


func salvar_em_fuga() -> void:
	# quem morre ou sai daqui recomeca na cama
	Jogo.etapa = 4
	salvar()
	Jogo.etapa = 5


func _panico_na_vila() -> void:
	var v := vila()
	var j := _j()
	var c: Criatura = Jogo.criatura
	var mostra := func(id: String, x: float, z: float) -> Gente:
		var g: Gente = v.gente[id]
		g.visible = true
		g.position = v.ch(x, z)
		g.medo = 1.0
		g.olhar = null
		g.pose = "corre"
		return g
	var am: Gente = mostra.call("amos", 9.0, 17.0)
	am.ir([v.ch(5, 8), v.ch(0, -8), v.ch(-1, -22)], 3.6, func(): am.visible = false)
	var ha: Gente = mostra.call("hannah", 4.0, -4.0)
	ha.ir([v.ch(10, 3), v.ch(20, 14), v.ch(34, 24)], 3.6, func(): ha.visible = false)
	var ca: Gente = mostra.call("caleb", -9.0, 5.0)
	ca.pose = "arma"
	ca.medo = 0.7
	ca.rotation.y = atan2(-18.0, -2.0)
	# a criatura atravessa a praca e pega Caleb
	for i in 2:
		await esperar(1.6)
		if j.morto: return
		Som.em("tiro", ca.cabeca(), 8.0, 260, 1.0, "Eco", 26.0)
		_clarao(ca.cabeca() + ca.global_transform.basis.z * -1.0)
	var ini := v.mundo(14, -2)
	c.colocar(ini, ca.global_position)
	c.muda(Criatura.E.TORRE)
	c.em_pe = 0.0
	c.em_pe_alvo = 0.0
	Som.em("cr_grito2", ini + Vector3.UP * 2, 10.0, 240, 0.9, "Eco", 24.0)
	var t := 0.0
	while t < 4.0 and is_inside_tree():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var d := ca.global_position - c.global_position
		d.y = 0
		if d.length() < 1.6: break
		c.vel = 7.0
		c.global_position += d.normalized() * 7.0 * dt
		c.global_position.y = Mundo.altura(c.global_position.x, c.global_position.z)
		c.rumo = atan2(-d.x, -d.z)
		c.rotation.y = c.rumo
	if not is_inside_tree(): return
	c.vel = 0.0
	c.em_pe_alvo = 1.0
	Som.em("cr_ataque", c.global_position + Vector3.UP, 8.0, 120)
	Som.em("grito_gente", ca.cabeca(), 8.0, 160, 0.82, "Eco", 14.0)
	Fx.sangue(v, ca.global_position, 2.4)
	ca.morrer(7, 0.1, 0.9)
	ca.basis = Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, PI * 0.5)
	ca.position.y += 0.08
	await esperar(2.2)
	if not is_inside_tree(): return
	# vira para voce
	c.muda(Criatura.E.OBSERVA)
	c.em_pe_alvo = 1.0
	Som.em("cr_estalos", c.global_position + Vector3.UP * 2, 8.0, 60)
	await esperar(2.5)
	if c.estado == Criatura.E.OBSERVA: c.muda(Criatura.E.RECUA)
	# ficar parado na vila rende um susto
	var parado := 0.0
	while is_inside_tree() and Jogo.etapa == 5 and not Jogo.flags.get("saiu_vila", false):
		await esperar(0.5)
		if j.morto: return
		parado += 0.5
		if parado > 22.0:
			parado = 8.0
			Jogo.definir_objetivo("CORRA — siga a trilha a leste até a torre")
			susto_dela()


func _clarao(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 6.0
	l.omni_range = 9.0
	fl.add_child(l)
	l.global_position = p
	await esperar(0.07)
	if is_instance_valid(l): l.queue_free()


## cara na sua cara, sem machucar: ela so quer que voce corra
func susto_dela() -> void:
	var j := _j()
	var c: Criatura = Jogo.criatura
	if j.morto or j.travado or c.estado == Criatura.E.ATAQUE: return
	var fr: Vector3 = -j.cam.global_transform.basis.z
	fr.y = 0
	c.colocar(j.global_position + fr.normalized() * 2.2, j.global_position)
	c.muda(Criatura.E.TORRE)
	c.em_pe = 1.0
	c.em_pe_alvo = 1.0
	Jogo.anomalias.susto(1.0)
	Som.toca("cr_ataque", 2)
	j.tremer(0.6)
	await esperar(0.55)
	Jogo.anomalias._piscar(j, 0.45)
	c.esconder()


func _saiu_da_vila() -> void:
	Jogo.flags["saiu_vila"] = true
	var v := vila()
	Som.em("grito_gente", v.mundo(-12, -8) + Vector3.UP * 1.5, 10.0, 260, 1.12, "Eco", 26.0)
	Jogo.criatura.esconder()
	v.destruir()
	Jogo.anomalias.ligado = true
	Jogo.anomalias.t = 14.0
	Jogo.diretor.silencio_alvo = 1.0
	salvar()
	await esperar(5.0)
	Jogo.falar("", "Atrás de você, a vila para de gritar.", 4.0)


# =============================================================== cemiterio
func cova() -> void:
	if Jogo.flags.get("cova", false): return
	Jogo.flags["cova"] = true
	fl.locais.it["cova"].ativo = false
	var j := _j()
	j.travado = true
	j.olhar_forcado = fl.locais.nos["cova"].global_position + Vector3.UP * 0.9
	Som.toca("stinger2", -2)
	Jogo.falar("", "A madeira é nova. A terra ainda está solta.", 3.5)
	await esperar(3.4)
	Jogo.falar("você", "...É o meu nome.", 2.6)
	j.medo = maxf(j.medo, 0.7)
	await esperar(2.2)
	j.olhar_forcado = Vector3.INF
	j.travado = false
	if Jogo.etapa >= 5:
		Som.em("v_alex1", j.global_position + j.cam.global_transform.basis.z * 5.0, 5.0, 60, 0.92, "Eco", 8.0)
		Jogo.falar("atrás de você", "Alex...", 3.0)


# =============================================================== torre
func _objetivo_torre() -> void:
	if Jogo.etapa != 6: return
	var f := Jogo.flags
	if f.get("gerador", false) and f.get("portao", false):
		Jogo.definir_objetivo("Suba a torre e chame ajuda pelo rádio")
	elif f.get("gerador", false):
		Jogo.definir_objetivo("A luz acendeu. Ache a chave da torre: olhe no banheiro")
	elif Jogo.tem("gasolina") > 0:
		Jogo.definir_objetivo("Leve a gasolina até o gerador, ao pé da torre")
	elif f.get("bilhete", false) or f.get("viu_gerador", false):
		if f.get("pegou_chave", false): Jogo.definir_objetivo("Volte à vila e pegue a gasolina no galpão do Amos")
		else: Jogo.definir_objetivo("A chave está na privada. A gasolina, no galpão da vila")
	else:
		Jogo.definir_objetivo("Ache um jeito de entrar na torre")


func portao() -> void:
	var loc := fl.locais
	if Jogo.tem("chave") <= 0:
		Som.em("batida_metal", loc.portao.global_position, -8.0, 40)
		Jogo.aviso.emit("Cadeado. Tem um bilhete preso na grade")
		return
	Som.toca("chave", -2)
	Jogo.flags["portao"] = true
	loc.abrir_portao()
	_objetivo_torre()
	salvar()


func privada() -> void:
	var loc := fl.locais
	var j := _j()
	loc.it["privada"].ativo = false
	Jogo.flags["pegou_chave"] = true
	Som.toca("nojo", 0)
	_ganha("chave")
	Jogo.falar("você", "Eu não quero saber o que é isso. Eu não quero saber o que é isso.", 4.0)
	_objetivo_torre()
	salvar()
	await esperar(4.5)
	# alguem anda em volta do banheiro
	var b: Node3D = loc.nos["banheiro"]
	Jogo.diretor.silencio_alvo = 1.0
	for i in 6:
		var a := i * 0.7
		Som.em("p_neve%d" % randi_range(1, 5), b.to_global(Vector3(cos(a) * 1.6, 0.2, -sin(a) * 1.6)), 6.0, 20, 0.75)
		await esperar(0.62)
	var d: Vector3 = b.global_position - j.global_position
	if d.length() < 3.0 and not j.morto:
		for i in 3:
			Som.em("p_madeira%d" % (i + 1), b.to_global(Vector3(0, 1.2, -0.8)), 12.0, 30, 0.65)
			j.tremer(0.05)
			await esperar(0.4)
		j.medo = maxf(j.medo, 0.8)
		await esperar(0.9)
		Som.em("v_sus_atras", j.cam.global_position + j.cam.global_transform.basis.z * 0.8, 4.0, 12, 1.0, "Voz", 2.0)


func gerador() -> void:
	var loc := fl.locais
	if Jogo.flags.get("gerador", false): return
	if Jogo.tem("gasolina") <= 0:
		Jogo.flags["viu_gerador"] = true
		Jogo.aviso.emit("Tanque seco. Na lataria, a giz: GASOLINA COM O AMOS, NA VILA")
		_objetivo_torre()
		return
	Jogo.gastar("gasolina")
	Jogo.flags["gerador"] = true
	loc.it["gerador"].ativo = false
	Som.em("despeja", loc.nos["gerador"].global_position, 2.0, 20)
	await esperar(2.6)
	for i in 2:
		Som.em("partida", loc.nos["gerador"].global_position, 2.0, 60)
		await esperar(1.1)
	_liga_torre(false)
	_objetivo_torre()
	salvar()
	await esperar(2.0)
	Som.em("cr_grito1", Mundo.chaov(Mundo.TORRE + Vector2(-70, 40)) + Vector3.UP * 3, 10.0, 300, 0.85, "Eco", 28.0)
	Jogo.falar("", "Ela viu a luz.", 2.8)


func _liga_torre(ja: bool) -> void:
	var loc := fl.locais
	loc.it["gerador"].ativo = false
	if _som_gerador == null:
		_som_gerador = Som.loop3d("motor", loc.nos["gerador"], Vector3(0, 0.6, 0), -4.0, 70.0, 5.0)
	for q in loc.luzes_torre:
		if ja: q[0].light_energy = q[1]
		else:
			var t := create_tween()
			t.tween_property(q[0], "light_energy", q[1] * 0.4, 0.1)
			t.tween_property(q[0], "light_energy", 0.0, 0.12)
			t.tween_interval(0.25)
			t.tween_property(q[0], "light_energy", q[1], 0.5)


func radio() -> void:
	if Jogo.flags.get("radio", false): return
	if not Jogo.flags.get("gerador", false):
		Som.toca("radio_clique", -2)
		Jogo.aviso.emit("Sem energia. O gerador fica ao pé da torre")
		Jogo.flags["viu_gerador"] = true
		_objetivo_torre()
		return
	Jogo.flags["radio"] = true
	var loc := fl.locais
	loc.it["radio"].ativo = false
	var j := _j()
	j.so_olhar = true
	var pr: Vector3 = loc.it["radio"].global_position
	Som.toca("radio_clique", -2)
	Jogo.anomalias.limpar()
	Jogo.anomalias.ligado = false
	Jogo.diretor.ligado = false
	Jogo.criatura.esconder()
	var k := 0.12 if Teste.a.has("robo") else 1.0
	var est := Som.loop3d("radio_estatica", loc, loc.to_local(pr), -6.0, 20.0, 3.0)
	await esperar(2.5 * k)
	Jogo.falar("você", "Alguém na escuta? Torre 4. O avião caiu. A vila foi atacada. Alguém na escuta?", 4.5)
	await esperar(5.0 * k)
	est.volume_db = -14
	Som.em("v_radio1", pr, 5.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Torre 4, aqui é a guarda florestal do condado. Estamos vendo a sua luz. Quem fala?", 5.0)
	await esperar(5.6 * k)
	Jogo.falar("você", "Alex. Só sobrou eu. Tem uma coisa aqui fora.", 3.5)
	await esperar(4.0 * k)
	Som.em("v_radio2", pr, 5.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Escuta. A polícia já está subindo, mas a estrada é só neve. Eles chegam ao amanhecer. Aguenta até lá.", 7.0)
	await esperar(7.4 * k)
	Som.em("v_radio3", pr, 5.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Pega o rifle do Walt. E não abre para ninguém.", 4.0)
	await esperar(4.6 * k)
	est.volume_db = -2
	await esperar(2.0 * k)
	est.volume_db = -20
	await esperar(0.8 * k)
	Som.em("v_falsa", pr, 6.0, 20, 1.0, "Voz", 4.0)
	Jogo.falar("rádio", "Torre 4... aqui é a comandante. Fique onde está.", 4.6)
	j.medo = 0.7
	await esperar(5.2 * k)
	Jogo.falar("rádio", "Eu estou subindo.", 3.0)
	await esperar(3.0 * k)
	est.stop()
	Som.toca("stinger2", -4)
	j.so_olhar = false
	Jogo.etapa = 7
	Jogo.flags["danos"] = 0
	j.danos = 0
	fl.clima.por(maxf(fl.clima.hora, 4.5))
	salvar()
	_cerco()


# =============================================================== cerco: agora ela pode matar
func _cerco() -> void:
	cerco_t = 0.0
	var c: Criatura = Jogo.criatura
	c.vidas = 3
	c.morta = false
	_j().danos = 0
	fl.clima.hora = 4.5
	fl.clima.ir(5.95, 1.45 / 230.0)
	Jogo.definir_objetivo("Aguente até o amanhecer — ou mate a coisa")
	Jogo.aviso.emit("Três golpes matam você. Três tiros matam ela.")
	Jogo.diretor.iniciar_cerco()


func _process_cerco(dt: float) -> void:
	var j := _j()
	if j.morto: return
	cerco_t += dt
	var c: Criatura = Jogo.criatura
	if c.morta:
		if cerco_t < 9990.0:
			cerco_t = 10000.0
			_venceu(true)
	elif cerco_t > 230.0 and cerco_t < 9990.0 and not (c.estado in [Criatura.E.CACA, Criatura.E.ATAQUE]):
		cerco_t = 10000.0
		_venceu(false)


func _venceu(matou: bool) -> void:
	Jogo.flags["matou"] = matou
	Jogo.diretor.ligado = false
	Jogo.etapa = 8
	if not matou:
		var c: Criatura = Jogo.criatura
		if c.visible: c.muda(Criatura.E.RECUA)
		Som.em("cr_grito2", _j().global_position + Vector3(50, 4, 40), 8.0, 300, 0.75, "Eco", 26.0)
		Jogo.falar("", "O céu clareia. Ela recua para a mata, sem pressa.", 4.0)
	else:
		Jogo.falar("", "A mata inteira solta o ar.", 4.0)
	await esperar(4.0)
	salvar()
	_policia()


func _policia() -> void:
	var loc := fl.locais
	fl.clima.ir(6.78, maxf(0.015, (6.7 - fl.clima.hora) / 36.0))
	fl.clima.neve_alvo = 0.15
	Jogo.diretor.silencio_alvo = 0.0
	await esperar(4.0)
	Som.em("sirene", Mundo.chaov(Vector2(300, 165)) + Vector3.UP * 2, 10.0, 400, 1.0, "Eco", 40.0)
	Jogo.falar("", "Sirenes. Subindo pela estrada de serviço.", 4.0)
	Jogo.definir_objetivo("Desça e vá até as luzes da polícia")
	var pts := []
	for i in range(5, 0, -1): pts.append(Vector2(Mundo.ESTRADA[i][0], Mundo.ESTRADA[i][1]))
	pts.append(Vector2(183, -47))
	var cv := Curve2D.new()
	for p in pts: cv.add_point(p)
	for k in 2: loc.viaturas[k].visible = true
	var L := cv.get_baked_length()
	var s := 20.0
	if Teste.a.has("robo"): s = L - 60.0
	var sir := Som.loop3d("sirene", loc.viaturas[0], Vector3(0, 2, 0), -2.0, 220.0, 14.0)
	while is_inside_tree() and s < L - 0.5:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		s = minf(L - 0.4, s + minf(11.0, maxf(2.0, (L - s) * 0.5)) * dt)
		for k in 2:
			var g: Node3D = loc.viaturas[k]
			var sk := maxf(1.0, s - k * 9.0)
			var a := cv.sample_baked(sk)
			var b := cv.sample_baked(maxf(0.0, sk - 2.0))
			var d := a - b
			var pa := Mundo.chaov(a)
			var pb := Mundo.chaov(b)
			g.global_position = (pa + pb) * 0.5 + Vector3.UP * 0.06
			if d.length() > 0.1:
				g.look_at(g.global_position + (pa - pb), Vector3.UP)
	if not is_inside_tree(): return
	sir.stop()
	Jogo.flags["policia"] = true
	var v0: Node3D = loc.viaturas[0]
	for q in [["pol1", -1.5, -1.2], ["pol2", 1.6, -0.6]]:
		var w := v0.to_global(Vector3(q[1], 0, q[2]))
		var g := Gente.criar(fl, q[0], Mundo.chao(w.x, w.z), v0.rotation.y)
		g.set_meta("chao", 0.0)
		g.pose = "arma" if q[0] == "pol1" else "pe"
		_vil_pol.append(g)
		var alvo := v0.to_global(Vector3(q[1] * 1.4, 0, -5.5))
		g.ir([Mundo.chao(alvo.x, alvo.z)], 1.4)
		var lt := Lanterna.spot(g)
		lt.position = Vector3(0.15, 1.3, -0.3)
		lt.light_energy = 4.0
		lt.shadow_enabled = q[0] == "pol1"
	await esperar(1.0)
	_vil_pol[0].dizer("v_pol1", "policial", "Polícia! Tem alguém aí em cima?", 3.5)


func _fim() -> void:
	if Jogo.etapa != 8: return
	Jogo.etapa = 9
	var j := _j()
	j.so_olhar = true
	Jogo.definir_objetivo("")
	var a: Gente = _vil_pol[0]
	var b: Gente = _vil_pol[1]
	a.pose = "pe"
	a.olhar = j.cam
	b.olhar = j.cam
	a.dizer("v_pol2", "policial", "Aqui! Achei uma pessoa viva!", 3.0)
	await esperar(3.4)
	b.dizer("v_pol3", "policial", "Calma. Acabou. Você está a salvo. Vamos tirar você daqui.", 5.0)
	await esperar(5.4)
	Jogo.falar("você", "E os outros?", 2.2)
	await esperar(2.8)
	a.dizer("", "policial", "Que outros? Não tem vila nenhuma nesta serra desde 1931.", 4.5)
	await esperar(4.8)
	Jogo.hud.escurecer(1.0, 4.5)
	await esperar(5.0)
	acabou.emit("matou" if Jogo.flags.get("matou", false) else "vivo")


# =============================================================== golpes e morte
## a criatura alcancou o jogador
func pego() -> void:
	var j := _j()
	var c: Criatura = Jogo.criatura
	if j.morto: return
	if Jogo.etapa != 7:
		c.estado = Criatura.E.OCULTO
		susto_dela()
		return
	j.danos += 1
	Jogo.flags["danos"] = j.danos
	if j.danos >= 3:
		morrer("pego")
		return
	# golpe: cara na cara, sangue, e ela some
	c.muda(Criatura.E.ATAQUE)
	c.em_pe = 1.0
	c.em_pe_alvo = 1.0
	var f: Vector3 = c.global_position - j.global_position
	f.y = 0
	if f.length() < 0.1: f = Vector3.FORWARD
	c.global_position = j.global_position + f.normalized() * 1.35
	c.rumo = atan2(f.x, f.z)
	c.rotation.y = c.rumo
	Som.toca("cr_ataque", 4)
	Som.toca("stinger1", -2)
	Som.toca("queda_corpo", 3)
	Jogo.hud.dano = 1.0
	j.medo = 1.0
	j.tremer(1.0)
	var t := 0.0
	while t < 0.55:
		j.olhar_forcado = c.altura_cabeca()
		await get_tree().process_frame
		if not is_inside_tree(): return
		t += get_process_delta_time()
	j.olhar_forcado = Vector3.INF
	j.velocity = -f.normalized() * 6.0 + Vector3.UP * 2.5
	Jogo.anomalias._piscar(j, 0.5)
	c.esconder()
	Jogo.diretor.depois_do_golpe()
	Jogo.falar("", ["", "Um golpe. Ela sumiu. Quis que doesse.", "Dois. Você não aguenta outro."][j.danos], 3.5)


func morrer(causa: String) -> void:
	var j := _j()
	if j.morto: return
	var c: Criatura = Jogo.criatura
	j.travado = true
	Jogo.mortes += 1
	Jogo.diretor.ligado = false
	Jogo.anomalias.limpar()
	Jogo.anomalias.ligado = false
	j.lanterna.apagao = 0.0
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
	var fr := {"pego": ["Agora ela tem a sua voz.", "Na próxima vez, ela vai chamar alguém com ela.", "Falta nenhum."], "frio": ["O frio foi gentil."], "ferida": ["A serra fica com o que cai nela."]}
	var l: Array = fr[causa]
	Jogo.hud.capitulo(l[Jogo.mortes % l.size()], "", 2.2)
	if causa == "pego": Som.toca("v_alex1", -4, 0.95, "UI")
	await esperar(5.2)
	if not is_inside_tree(): return
	renascer()


func renascer() -> void:
	var j := _j()
	var mortes := Jogo.mortes
	var tempo := Jogo.tempo
	Jogo.carregar()
	Jogo.mortes = mortes
	Jogo.tempo = tempo
	Som.abafado = 0.0
	Jogo.hud.limpar()
	var c: Criatura = Jogo.criatura
	c.esconder()
	c.scale = Vector3.ONE
	j.olhar_forcado = Vector3.INF
	j.medo = 0.0
	j.folego = 100.0
	j.danos = 0
	Jogo.flags["danos"] = 0
	_atq = false
	fl.firmar(Jogo.pos_salva)
	j.morto = false
	comecar(false)


# =============================================================== gatilhos por lugar
func _process(dt: float) -> void:
	var j := _j()
	if j == null or fl == null or not fl.visible:
		return
	_vt += dt
	fl.locais.girar_luzes(_vt)
	if j.morto or Jogo.etapa == 0 or Jogo.etapa >= 9:
		return
	Jogo.tempo += dt
	_calor(dt, j)
	if Jogo.etapa == 7: _process_cerco(dt)
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	var p := Vector2(j.global_position.x, j.global_position.z)
	var loc := fl.locais
	var v := vila()
	var lt: Vector3 = (loc.nos["torre"] as Node3D).to_local(j.global_position)
	_na_torre = absf(lt.x) < 2.6 and absf(lt.z) < 2.6 and lt.y > Locais.H_TORRE - 0.5
	j.abrigado = v.dentro_ruth(j.global_position) or v.dentro_galpao(j.global_position)
	fl.clima.neve_alvo = _neve_da_etapa()
	match Jogo.etapa:
		1:
			if p.distance_to(Mundo.QUEDA) > 60.0 and not Jogo.flags.get("longe", false):
				Jogo.flags["longe"] = true
				Jogo.falar("você", "Sem um mapa e um casaco eu não duro uma hora.", 3.5)
		2:
			var prog := clampf((p.x + 365.0) / 275.0, 0.0, 1.0)
			fl.clima.ir(maxf(fl.clima.hora_alvo, lerpf(7.1, 15.4, prog)), 0.035)
			_dia(p, j)
			if p.distance_to(Mundo.VILA) < 38.0:
				Jogo.etapa = 3
				fl.clima.ir(maxf(fl.clima.hora_alvo, 15.6), 0.05)
				for f in loc.fogos: f.visible = false
				_objetivo_vila()
				salvar()
				Jogo.falar("você", "Fumaça. Gente. Graças a Deus.", 3.5)
		3:
			for id in v.gente:
				var g: Gente = v.gente[id]
				if not em_dialogo and g.visible:
					g.olhar = j.cam if g.global_position.distance_to(j.global_position) < 6.0 else null
		5:
			_fuga(p, j)
			if not Jogo.flags.get("saiu_vila", false) and p.distance_to(Mundo.VILA) > 44.0:
				_saiu_da_vila()
			if p.distance_to(Mundo.TORRE) < 24.0:
				Jogo.etapa = 6
				Som.camada("mus_caca", 0.0, 0.3, "Musica")
				_objetivo_torre()
				salvar()
		6:
			_volta(p, j)
		8:
			if Jogo.flags.get("policia", false) and _vil_pol.size() > 0 and j.global_position.distance_to(_vil_pol[0].global_position) < 7.0:
				_fim()


## de dia: so passaros, longe, com pressa
func _dia(p: Vector2, j: Jogador) -> void:
	for q in [["rev1", Vector2(-300, -272), 26, Vector3(24, 13, 18)], ["rev2", Vector2(-232, -186), 40, Vector3(-10, 15, 34)], ["rev3", Vector2(-176, -108), 22, Vector3(30, 16, -6)]]:
		if not Jogo.flags.get(q[0], false) and p.distance_to(q[1]) < 16.0:
			Jogo.flags[q[0]] = true
			Passaros.revoada(fl, j.global_position + q[3], q[2], Vector3(0.3, 0.3, 1.0))
			j.medo = maxf(j.medo, 0.45)
			j.tremer(0.02)
			if q[0] == "rev2":
				await esperar(5.0)
				Jogo.falar("", "Voaram todos para o sul. Todos de uma vez.", 3.5)
	if not Jogo.flags.get("vau", false) and p.distance_to(Mundo.VAU) < 14.0:
		Jogo.flags["vau"] = true
		Jogo.aviso.emit("A água gelada rouba calor. Use a passarela")
		salvar()


func _fuga(p: Vector2, j: Jogador) -> void:
	_susto_fora -= 0.2
	if not Jogo.flags.get("saiu_vila", false): return
	if _susto_fora <= 0.0:
		_susto_fora = randf_range(7.0, 11.0)
		var lado: Vector3 = j.cam.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
		var tras: Vector3 = j.cam.global_transform.basis.z
		Som.em("cr_grito%d" % randi_range(1, 2), j.global_position + tras * 26.0 + lado * 8.0 + Vector3.UP * 2, 6.0, 160, randf_range(0.85, 1.0), "Eco", 16.0)
		for i in 3: Som.em("galho%d" % randi_range(1, 4), j.global_position + lado * randf_range(6, 12) + tras * randf_range(0, 8), 4.0, 60)
		if randf() < 0.6: Jogo.anomalias.fazer("corre")
	if not Jogo.flags.get("cemit", false) and p.distance_to(Mundo.CEMITERIO) < 15.0:
		Jogo.flags["cemit"] = true
		Som.em("v_sus_cair", j.global_position + j.cam.global_transform.basis.z * 2.0, 4.0, 20, 1.0, "Voz", 3.0)
		for i in 6:
			var a := TAU * i / 6.0
			var w := Vector3(Mundo.CEMITERIO.x + cos(a) * 8.0, 0, Mundo.CEMITERIO.y + sin(a) * 8.0)
			var vg := Vigia.new().montar(i % 3 == 0)
			fl.add_child(vg)
			vg.por(w, j.global_position)
			Jogo.anomalias.ativos.append(vg)


## voltar a vila destruida
func _volta(p: Vector2, j: Jogador) -> void:
	var f := Jogo.flags
	var v := vila()
	if not f.get("volta1", false) and p.distance_to(Mundo.VILA) < 46.0:
		f["volta1"] = true
		Jogo.falar("", "Não sobrou ninguém de pé.", 3.0)
		salvar()
	if not f.get("volta2", false) and p.distance_to(Mundo.VILA) < 24.0:
		f["volta2"] = true
		var cr: Node3D = v.casas.ruth
		Som.em("v_ruth5", cr.to_global(Vector3(2.5, 1.2, -1.0)), 6.0, 60, 0.95, "Eco", 9.0)
		Jogo.falar("de dentro da casa da Ruth", "Alex... sou eu, Ruth... me ajuda aqui dentro...", 4.5)
		j.medo = maxf(j.medo, 0.6)
		var vg := Vigia.new().montar(true)
		fl.add_child(vg)
		var w := cr.to_global(Vector3(-1.5, 0, 2.6))
		vg.por(w, j.global_position)
		vg.global_position.y = cr.global_position.y
		Jogo.anomalias.ativos.append(vg)
	if f.get("volta2", false) and not f.get("ruth_susto", false) and v.dentro_ruth(j.global_position):
		f["ruth_susto"] = true
		await esperar(1.2)
		susto_dela()
	if f.get("pegou_gasolina", false) and not f.get("volta3", false) and p.distance_to(Mundo.CEMITERIO) < 22.0:
		f["volta3"] = true
		Jogo.anomalias.fazer("grupo")
		await esperar(2.0)
		Som.em("v_alex2", j.global_position + j.cam.global_transform.basis.z * 6.0, 5.0, 60, 0.92, "Eco", 8.0)
		Jogo.falar("atrás de você", "Alex? Cadê você?", 3.0)


func _pegou_gasolina() -> void:
	_objetivo_torre()
	salvar()
	var j := _j()
	var v := vila()
	var g: Node3D = v.casas.galpao
	await esperar(1.4)
	(g.get_meta("luz") as OmniLight3D).light_energy = 0.0
	Som.em("madeira_range1", g.to_global(Vector3(1.5, 1.5, 4.8)), 6.0, 30, 0.7)
	j.lanterna.apagao = maxf(j.lanterna.apagao, 2.2)
	Jogo.diretor.silencio = 1.0
	await esperar(1.0)
	Som.em("cr_respira", g.to_global(Vector3(0, 2.0, 3.5)), 6.0, 20, 0.8)
	await esperar(1.3)
	if j.morto or not v.dentro_galpao(j.global_position): return
	# parada na porta
	var c: Criatura = Jogo.criatura
	c.colocar(g.to_global(Vector3(0, 0, 4.6)), j.global_position)
	c.muda(Criatura.E.TORRE)
	c.em_pe = 1.0
	c.em_pe_alvo = 1.0
	j.olhar_forcado = c.altura_cabeca()
	Jogo.anomalias.susto(0.9)
	await esperar(0.9)
	j.olhar_forcado = Vector3.INF
	Jogo.anomalias._piscar(j, 0.6)
	c.esconder()


func _calor(dt: float, j: Jogador) -> void:
	for f in fl.locais.fogos:
		if f.visible and f.global_position.distance_to(j.global_position) < 5.0:
			j.frio = maxf(0.0, j.frio - dt * 4.0)
	var v := vila()
	if v.fogueira.visible and v.fogueira.global_position.distance_to(j.global_position) < 5.0:
		j.frio = maxf(0.0, j.frio - dt * 5.0)
	if not v.destruida and v.dentro_ruth(j.global_position):
		j.frio = maxf(0.0, j.frio - dt * 4.0)
