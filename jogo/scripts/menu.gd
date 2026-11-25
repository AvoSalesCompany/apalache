class_name Menu
extends CanvasLayer
## Menu principal, pausa, opcoes, carregamento e tela final.

signal novo
signal continuar
signal voltar_menu
signal retomar

var _raiz: Control
var _fundo: ColorRect
var _caixa: VBoxContainer
var _titulo: Label
var _sub: Label
var _rodape: Label
var _barra: ColorRect
var _bt: Label
var _f_tit: SystemFont
var _f_txt: SystemFont
var modo := ""
var _origem := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_f_tit = SystemFont.new()
	_f_tit.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "serif"])
	_f_txt = SystemFont.new()
	_f_txt.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)
	_fundo = ColorRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.color = Color(0, 0, 0, 1)
	_raiz.add_child(_fundo)
	_titulo = _rot(96, _f_tit, Color(0.92, 0.90, 0.84))
	_titulo.position = Vector2(120, 150)
	_sub = _rot(24, _f_tit, Color(0.66, 0.64, 0.58))
	_sub.position = Vector2(126, 268)
	_caixa = VBoxContainer.new()
	_caixa.position = Vector2(120, 400)
	_caixa.add_theme_constant_override("separation", 6)
	_raiz.add_child(_caixa)
	_rodape = _rot(16, _f_txt, Color(0.5, 0.5, 0.48))
	_rodape.anchor_top = 1.0
	_rodape.anchor_bottom = 1.0
	_rodape.offset_left = 122
	_rodape.offset_top = -64
	_bt = _rot(20, _f_tit, Color(0.7, 0.68, 0.62))
	_bt.anchor_top = 1.0
	_bt.anchor_bottom = 1.0
	_bt.offset_left = 122
	_bt.offset_top = -128
	_barra = ColorRect.new()
	_barra.color = Color(0.82, 0.80, 0.72, 0.8)
	_barra.anchor_top = 1.0
	_barra.anchor_bottom = 1.0
	_barra.offset_left = 122
	_barra.offset_top = -92
	_barra.offset_bottom = -90
	_barra.offset_right = 122
	_raiz.add_child(_barra)
	visible = false


func _rot(tam: int, f: Font, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_outline_size", 6)
	_raiz.add_child(l)
	return l


func _limpa() -> void:
	for c in _caixa.get_children():
		c.queue_free()
	_rodape.text = ""
	_bt.text = ""
	_barra.visible = false


func _botao(t: String, f: Callable, ativo: bool = true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _f_tit)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color(0.74, 0.72, 0.66))
	b.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.90))
	b.add_theme_color_override("font_focus_color", Color(1, 0.98, 0.90))
	b.add_theme_color_override("font_disabled_color", Color(0.34, 0.34, 0.33))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not ativo
	b.mouse_entered.connect(func(): if not b.disabled: Som.toca("p_folha%d" % randi_range(1, 5), -24, 1.2, "UI"))
	b.pressed.connect(func():
		Som.toca("galho%d" % randi_range(1, 3), -14, 1.0, "UI")
		f.call())
	_caixa.add_child(b)
	return b


func carregando(txt: String, p: float) -> void:
	if modo != "carga":
		modo = "carga"
		visible = true
		_limpa()
		_fundo.color = Color(0, 0, 0, 1)
		_titulo.text = "HOLLER"
		_sub.text = "não responda"
		_barra.visible = true
	_bt.text = txt + "..."
	_barra.offset_right = 122 + 520.0 * p


func principal() -> void:
	modo = "menu"
	visible = true
	_limpa()
	_fundo.color = Color(0, 0, 0, 0.22)
	_titulo.text = "HOLLER"
	_sub.text = "não responda"
	if Jogo.tem_salvo():
		_botao("Continuar", func(): continuar.emit())
	_botao("Novo jogo", func(): novo.emit())
	_botao("Opções", func(): opcoes("menu"))
	_botao("Sair", func(): get_tree().quit())
	_rodape.text = "Use fones de ouvido.   v0.3"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func pausa() -> void:
	modo = "pausa"
	visible = true
	_limpa()
	_fundo.color = Color(0, 0, 0, 0.66)
	_titulo.text = "Pausado"
	_sub.text = Jogo.objetivo
	_botao("Voltar ao jogo", func(): retomar.emit())
	_botao("Opções", func(): opcoes("pausa"))
	_botao("Menu principal", func(): voltar_menu.emit())
	_rodape.text = "WASD andar   ·   Shift correr   ·   Ctrl agachar   ·   E usar   ·   Tab mochila   ·   M mapa   ·   F lanterna   ·   C bússola   ·   H curativo   ·   2 rifle   ·   R recarregar   ·   Clique atirar / arremessar   ·   Q gritar"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func opcoes(origem: String) -> void:
	modo = "opcoes"
	_origem = origem
	_limpa()
	_titulo.text = "Opções"
	_sub.text = ""
	_fundo.color = Color(0, 0, 0, 0.72)
	var nomes := ["Baixa", "Média", "Alta", "Ultra"]
	_botao("Qualidade:  " + nomes[Jogo.qualidade], func():
		Jogo.qualidade = (Jogo.qualidade + 1) % 4
		Jogo.salvar_opcoes()
		opcoes(origem))
	_desliza("Brilho", Jogo.gama, 0.7, 1.5, func(v): Jogo.gama = v)
	_desliza("Sensibilidade", Jogo.sens, 0.2, 3.0, func(v): Jogo.sens = v)
	_desliza("Volume", Jogo.volume, 0.0, 1.0, func(v):
		Jogo.volume = v
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	_botao("Legendas:  " + ("Sim" if Jogo.legendas else "Não"), func():
		Jogo.legendas = not Jogo.legendas
		opcoes(origem))
	_botao("Tela cheia:  " + ("Sim" if Jogo.tela_cheia else "Não"), func():
		Jogo.tela_cheia = not Jogo.tela_cheia
		Jogo.salvar_opcoes()
		opcoes(origem))
	_botao("Voltar", func():
		Jogo.salvar_opcoes()
		if origem == "pausa": pausa()
		else: principal())


func _desliza(nome: String, v: float, a: float, b: float, f: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	var l := Label.new()
	l.text = nome
	l.custom_minimum_size = Vector2(260, 50)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _f_tit)
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color(0.74, 0.72, 0.66))
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = a
	s.max_value = b
	s.step = 0.01
	s.value = v
	s.custom_minimum_size = Vector2(320, 50)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(f)
	h.add_child(s)
	_caixa.add_child(h)


func final(qual: String) -> void:
	modo = "final"
	visible = true
	_limpa()
	_fundo.color = Color(0, 0, 0, 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var m := int(Jogo.tempo / 60.0)
	if qual == "matou":
		_titulo.text = "Silêncio"
		_sub.text = "A polícia seguiu o rastro de sangue na neve por onze quilômetros.\nEle termina numa árvore, na altura de três homens.\n\nNa manhã seguinte, o telefone do quarto tocou. Era a voz da Ruth."
	else:
		_titulo.text = "Amanhecer"
		_sub.text = "Contaram dezoito corpos no avião. Nenhuma vila.\nNo mapa que estava na sua mochila, não há nada circulado.\n\nNa manhã seguinte, o telefone do quarto tocou. Era a sua voz."
	_rodape.text = "Tempo: %d min    ·    Mortes: %d    ·    Vezes que você respondeu: %d" % [m, Jogo.mortes, Jogo.chamados]
	_caixa.position.y = 470
	_botao("Menu principal", func(): voltar_menu.emit())


func esconder() -> void:
	modo = ""
	visible = false
	_limpa()
