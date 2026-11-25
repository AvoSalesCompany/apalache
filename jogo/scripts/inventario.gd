class_name Inventario
extends Control
## Mochila aberta: grade de icones, descricao, objetivo, notas lidas e mapa.

var hud: Hud
var aba := "itens"            # itens | mapa
var sel := ""
var _slots: Array = []
var _grade: GridContainer
var _nome: Label
var _desc: Label
var _uso: Label
var _img: TextureRect
var _obj: Label
var _notas: VBoxContainer
var _pag_itens: Control
var _pag_mapa: Control
var _bt_i: Button
var _bt_m: Button
var _mapa: TextureRect
var _seta: Control
const REC := Rect2(-470, -420, 740, 510)      # pedaco do mundo que o mapa mostra


class Seta extends Control:
	var ang := 0.0
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var b := Transform2D(ang, Vector2.ZERO)
		draw_circle(Vector2.ZERO, 13.0 + 3.0 * sin(t * 3.0), Color(0.75, 0.08, 0.05, 0.18))
		draw_colored_polygon(PackedVector2Array([b * Vector2(0, -13), b * Vector2(8, 9), b * Vector2(0, 5), b * Vector2(-8, 9)]), Color(0.62, 0.05, 0.03))


class Rabisco extends Control:
	var pts := []
	func _draw() -> void:
		for q in pts:
			var c: Vector2 = q[0]
			var r: float = q[1]
			var p := PackedVector2Array()
			for i in 46:
				var a := TAU * i / 40.0
				p.push_back(c + Vector2(cos(a) * (r + 3.0 * sin(a * 3.0 + r)) * 1.25, sin(a) * (r + 2.0 * cos(a * 2.0)) + i * 0.05))
			draw_polyline(p, q[2], 3.0, true)


func montar(h: Hud) -> void:
	hud = h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var esc := ColorRect.new()
	esc.color = Color(0.010, 0.012, 0.016, 0.86)
	esc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(esc)
	var caixa := Control.new()
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 0.5
	caixa.anchor_bottom = 0.5
	caixa.offset_left = -620
	caixa.offset_right = 620
	caixa.offset_top = -370
	caixa.offset_bottom = 370
	caixa.pivot_offset = Vector2(620, 370)
	caixa.scale = Vector2(1.22, 1.22)
	add_child(caixa)
	_bt_i = _aba("MOCHILA", caixa, 0, func(): mostra("itens"))
	_bt_m = _aba("MAPA", caixa, 210, func(): mostra("mapa"))
	# ---- itens
	_pag_itens = Control.new()
	_pag_itens.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(_pag_itens)
	_grade = GridContainer.new()
	_grade.columns = 5
	_grade.add_theme_constant_override("h_separation", 10)
	_grade.add_theme_constant_override("v_separation", 10)
	_grade.position = Vector2(0, 70)
	_pag_itens.add_child(_grade)
	for i in 15: _slots.append(_slot())
	_img = TextureRect.new()
	_img.position = Vector2(760, 62)
	_img.size = Vector2(210, 210)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pag_itens.add_child(_img)
	_nome = hud.rotulo(34, hud.f_titulo, Color(0.95, 0.92, 0.84), _pag_itens)
	_desc = hud.rotulo(20, hud.f_texto, Color(0.80, 0.79, 0.74), _pag_itens)
	_uso = hud.rotulo(18, hud.f_texto, Color(0.86, 0.70, 0.40), _pag_itens)
	var y := 280
	for l in [_nome, _desc, _uso]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(760, y)
		l.size = Vector2(470, 60)
		y += 52 if l == _nome else 62
	var tl := hud.rotulo(16, hud.f_texto, Color(0.55, 0.54, 0.50), _pag_itens)
	tl.text = "AGORA"
	tl.position = Vector2(760, 470)
	_obj = hud.rotulo(22, hud.f_titulo, Color(0.92, 0.88, 0.76), _pag_itens)
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj.position = Vector2(760, 494)
	_obj.size = Vector2(470, 70)
	var tn := hud.rotulo(16, hud.f_texto, Color(0.55, 0.54, 0.50), _pag_itens)
	tn.text = "O QUE VOCÊ LEU"
	tn.position = Vector2(760, 584)
	_notas = VBoxContainer.new()
	_notas.position = Vector2(756, 606)
	_pag_itens.add_child(_notas)
	# ---- mapa
	_pag_mapa = Control.new()
	_pag_mapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(_pag_mapa)
	_mapa = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://tex/mapa.png")
	at.region = Rect2(REC.position + Vector2(512, 512), REC.size)
	_mapa.texture = at
	_mapa.position = Vector2(100, 62)
	_mapa.size = Vector2(1040, 1040.0 * REC.size.y / REC.size.x)
	_mapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mapa.rotation = -0.008
	_pag_mapa.add_child(_mapa)
	var rb := Rabisco.new()
	rb.pts = [[_no_mapa(Mundo.VILA), 40.0, Color(0.55, 0.06, 0.04, 0.85)], [_no_mapa(Mundo.TORRE), 17.0, Color(0.20, 0.16, 0.12, 0.7)]]
	_mapa.add_child(rb)
	for q in [["COLD HOLLER", Mundo.VILA, Vector2(-70, -86), 24, Color(0.50, 0.05, 0.03)], ["Torre 4", Mundo.TORRE, Vector2(-34, -52), 18, Color(0.22, 0.16, 0.10)], ["Cemitério", Mundo.CEMITERIO, Vector2(-40, 12), 14, Color(0.22, 0.16, 0.10)], ["Riacho", Vector2(-270, -262), Vector2(26, 4), 14, Color(0.10, 0.24, 0.38)], ["estrada de serviço", Vector2(232, 10), Vector2(-150, 0), 13, Color(0.30, 0.18, 0.10)]]:
		var l := Label.new()
		l.text = q[0]
		l.add_theme_font_override("font", hud.f_titulo)
		l.add_theme_font_size_override("font_size", q[3])
		l.add_theme_color_override("font_color", q[4])
		l.position = _no_mapa(q[1]) + q[2]
		_mapa.add_child(l)
	_seta = Seta.new()
	_mapa.add_child(_seta)
	var d := hud.rotulo(17, hud.f_texto, Color(0.7, 0.7, 0.68), self)
	d.text = "[Tab] fechar    ·    [M] mapa"
	hud._ancora(d, 0.5, 0.955)


func _no_mapa(p: Vector2) -> Vector2:
	return (p - REC.position) / REC.size * _mapa.size


func _aba(t: String, pai: Control, x: float, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.position = Vector2(x - 8, 0)
	b.add_theme_font_override("font", hud.f_titulo)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(0.55, 0.54, 0.50))
	b.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.9))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	pai.add_child(b)
	return b


func _slot() -> Dictionary:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(134, 134)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.095, 0.10, 0.85)
	sb.border_color = Color(0.30, 0.29, 0.26, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var im := TextureRect.new()
	im.set_anchors_preset(Control.PRESET_FULL_RECT)
	im.offset_left = 12
	im.offset_top = 12
	im.offset_right = -12
	im.offset_bottom = -12
	im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(im)
	var n := hud.rotulo(20, hud.f_texto, Color(0.95, 0.92, 0.82), p)
	n.position = Vector2(88, 102)
	n.size = Vector2(38, 26)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grade.add_child(p)
	var d := {"p": p, "sb": sb, "im": im, "n": n, "id": ""}
	p.mouse_entered.connect(func(): if d.id != "": escolhe(d.id))
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and d.id != "": usar(d.id))
	return d


func escolhe(id: String) -> void:
	if sel != id: Som.toca("papel", -24, 1.6, "UI")
	sel = id
	_pinta()


func usar(id: String) -> void:
	var j: Jogador = Jogo.jogador
	match id:
		"mapa":
			mostra("mapa")
			return
		"curativo": j.curar()
		"lanche":
			if Jogo.gastar("lanche"):
				j.frio = maxf(0.0, j.frio - 18.0)
				j.vida = minf(100.0, j.vida + 12.0)
				Som.toca("comer", -4)
				Jogo.aviso.emit("Você come devagar. Ajuda")
		"lanterna":
			fecha()
			j.lanterna.alternar()
		"rifle":
			fecha()
			j.rifle.alternar()
	_pinta()


func abre(a: String) -> void:
	if a == "mapa" and Jogo.tem("mapa") <= 0:
		Jogo.aviso.emit("Você não tem um mapa")
		return
	visible = true
	hud.lendo = true
	if Jogo.jogador: Jogo.jogador.travado = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Som.toca("mochila", -8, 1.0, "UI")
	mostra(a)


func fecha() -> void:
	visible = false
	hud.lendo = false
	if Jogo.jogador: Jogo.jogador.travado = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Som.toca("papel", -12, 1.2, "UI")
	hud.leitura_fechou.emit()


func mostra(a: String) -> void:
	if a == "mapa" and Jogo.tem("mapa") <= 0: a = "itens"
	aba = a
	_pag_itens.visible = a == "itens"
	_pag_mapa.visible = a == "mapa"
	_bt_m.visible = Jogo.tem("mapa") > 0
	_bt_i.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84) if a == "itens" else Color(0.55, 0.54, 0.50))
	_bt_m.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84) if a == "mapa" else Color(0.55, 0.54, 0.50))
	if a == "mapa":
		var j: Jogador = Jogo.jogador
		_seta.position = _no_mapa(Vector2(j.global_position.x, j.global_position.z))
		_seta.ang = -j.rotation.y
	_pinta()


func _pinta() -> void:
	var l := []
	for id in Itens.ORDEM:
		if Jogo.tem(id) > 0: l.append(id)
	if not (sel in l): sel = l[0] if l.size() > 0 else ""
	for i in _slots.size():
		var d: Dictionary = _slots[i]
		d.id = l[i] if i < l.size() else ""
		d.im.texture = Itens.icone(d.id) if d.id != "" else null
		d.n.text = "×%d" % Jogo.tem(d.id) if d.id != "" and Jogo.tem(d.id) > 1 else ""
		d.sb.border_color = Color(0.86, 0.72, 0.42, 0.95) if d.id == sel and sel != "" else Color(0.30, 0.29, 0.26, 0.6)
		d.sb.bg_color = Color(0.16, 0.15, 0.13, 0.9) if d.id == sel and sel != "" else Color(0.09, 0.095, 0.10, 0.85)
	if sel != "":
		_nome.text = Itens.INFO[sel][0]
		_desc.text = Itens.INFO[sel][1]
		_uso.text = Itens.INFO[sel][2]
		_img.texture = Itens.icone(sel)
		if sel == "rifle": _uso.text += "    %d no pente" % Jogo.jogador.rifle.pente
	else:
		_nome.text = "Vazio"
		_desc.text = "Você não tem nada."
		_uso.text = ""
		_img.texture = null
	_obj.text = Jogo.objetivo
	for c in _notas.get_children(): c.queue_free()
	for q in Jogo.notas:
		var b := Button.new()
		b.text = "·  " + str(q[0])
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", hud.f_titulo)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", Color(0.78, 0.75, 0.66))
		b.pressed.connect(func():
			fecha()
			hud.abrir_nota(q[0], q[1]))
		_notas.add_child(b)