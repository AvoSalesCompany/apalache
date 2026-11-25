class_name Hud
extends CanvasLayer
## Interface minima + pos-processamento + leitura + diario + pausa.

signal leitura_fechou

var pos: ShaderMaterial
var pulso := 0.0
var preto := 1.0
var preto_alvo := 1.0
var preto_vel := 1.0
var branco := 0.0
var pisca := 0.0
var tonto := 0.0
var dano := 0.0
var lendo := false
var em_diario := false

var f_titulo: SystemFont
var f_texto: SystemFont
var _raiz: Control
var _mira: Control
var _dica: Label
var _leg_quem: Label
var _leg: Label
var _obj: Label
var _obj_t := 0.0
var _aviso: Label
var _aviso_t := 0.0
var _cap: Label
var _cap2: Label
var _ind: Indicadores
var _painel: Control
var _p_tit: Label
var _p_corpo: Label
var inv: Inventario
var _faixa: HBoxContainer
var _faixa_s := {}
var _faixa_t := 0.0
var _ganhos: VBoxContainer
var _esc_painel: Control
var _leg_t := 0.0
var _fila := []
var _cor_preto: ColorRect


class Indicadores extends Control:
	var luz := 0.0
	var vida := 1.0
	var frio := 0.0
	var fol := 1.0
	var seg := 0.0
	var esc := 0.0
	var bat := 0.0
	var tem_bat := false
	var danos := -1
	var tiros := -1
	var reserva := 0
	var a_luz := 0.0
	var a_vida := 0.0
	var a_frio := 0.0
	var a_fol := 0.0
	func _draw() -> void:
		var h := size.y
		var c := Vector2(58, h - 58)
		# lua: quanto voce esta exposto
		if a_luz > 0.01:
			draw_circle(c, 15, Color(0.03, 0.04, 0.06, 0.6 * a_luz))
			var pts := PackedVector2Array()
			for i in 25:
				var a := -PI * 0.5 + PI * i / 24.0
				pts.push_back(c + Vector2(cos(a), sin(a)) * 13.0)
			for i in 25:
				var a := PI * 0.5 - PI * i / 24.0
				pts.push_back(c + Vector2(cos(a) * (1.0 - 2.0 * luz), sin(a)) * 13.0)
			if luz > 0.03:
				draw_colored_polygon(pts, Color(0.86, 0.90, 1.0, 0.75 * a_luz))
			draw_arc(c, 14, 0, TAU, 40, Color(0.75, 0.82, 0.95, 0.35 * a_luz), 1.2, true)
			if esc > 0.5:
				draw_arc(c, 19, 0, TAU, 40, Color(0.45, 0.75, 0.5, 0.7 * a_luz), 1.6, true)
		if tem_bat:
			var bx := Vector2(44, h - 112)
			draw_rect(Rect2(bx, Vector2(26, 13)), Color(0.8, 0.8, 0.75, 0.45 * a_luz), false, 1.3)
			draw_rect(Rect2(bx + Vector2(27, 4), Vector2(3, 5)), Color(0.8, 0.8, 0.75, 0.45 * a_luz))
			for i in 4:
				if bat > i * 0.25 + 0.02:
					draw_rect(Rect2(bx + Vector2(3 + i * 5.4, 3), Vector2(4, 7)), Color(0.95, 0.80, 0.45, 0.8 * a_luz) if bat > 0.2 else Color(0.9, 0.2, 0.12, 0.8 * a_luz))
		_barra(Vector2(92, h - 66), 150, fol, Color(0.85, 0.85, 0.80), a_fol)
		_barra(Vector2(92, h - 54), 150, vida, Color(0.70, 0.12, 0.10), a_vida)
		_barra(Vector2(92, h - 42), 150, 1.0 - frio, Color(0.45, 0.68, 0.90), a_frio)
		# golpes levados: tres riscos de garra
		if danos >= 0:
			for i in 3:
				var o := Vector2(50 + i * 26, h - 150)
				var cor := Color(0.72, 0.05, 0.04, 0.95) if i < danos else Color(0.8, 0.8, 0.78, 0.28)
				draw_line(o, o + Vector2(12, -30), cor, 5.0 if i < danos else 2.0, true)
		if tiros >= 0:
			for i in 5:
				var o := Vector2(size.x - 60 - i * 15, h - 128)
				var cor := Color(0.86, 0.66, 0.30, 0.95) if i < tiros else Color(0.8, 0.8, 0.78, 0.22)
				draw_rect(Rect2(o, Vector2(6, 22)), cor)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, 0), o + Vector2(6, 0), o + Vector2(3, -8)]), cor)
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 196, h - 108), "+%d" % reserva, HORIZONTAL_ALIGNMENT_RIGHT, 50, 18, Color(0.85, 0.82, 0.74, 0.8))
		if seg > 0.0:
			draw_arc(size * 0.5, 16, -PI * 0.5, -PI * 0.5 + TAU * seg, 40, Color(0.95, 0.92, 0.82, 0.9), 2.4, true)
	func _barra(p: Vector2, w: float, v: float, cor: Color, a: float) -> void:
		if a < 0.01: return
		draw_rect(Rect2(p, Vector2(w, 3)), Color(0, 0, 0, 0.45 * a))
		draw_rect(Rect2(p, Vector2(w * clampf(v, 0, 1), 3)), Color(cor.r, cor.g, cor.b, 0.85 * a))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Jogo.hud = self
	f_titulo = SystemFont.new()
	f_titulo.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "serif"])
	f_texto = SystemFont.new()
	f_texto.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	# pos-processamento numa camada abaixo
	var cl := CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos = ShaderMaterial.new()
	pos.shader = load("res://shaders/pos.gdshader")
	r.material = pos
	cl.add_child(r)
	layer = 5
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_ind = Indicadores.new()
	_ind.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_ind)
	_mira = ColorRect.new()
	_mira.color = Color(0.9, 0.9, 0.9, 0.35)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mira.size = Vector2(3, 3)
	_raiz.add_child(_mira)
	_dica = rotulo(22, f_texto, Color(0.95, 0.93, 0.86))
	_ancora(_dica, 0.5, 0.60)
	_obj = rotulo(21, f_titulo, Color(0.92, 0.88, 0.76))
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_obj.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_obj.position = Vector2(56, 46)
	_obj.size = Vector2(820, 80)
	_obj.modulate.a = 0.0
	_aviso = rotulo(18, f_texto, Color(0.80, 0.84, 0.90))
	_ancora(_aviso, 0.5, 0.08)
	_leg_quem = rotulo(19, f_texto, Color(0.72, 0.66, 0.50))
	_ancora(_leg_quem, 0.5, 0.815)
	_leg = rotulo(25, f_texto, Color(0.96, 0.95, 0.92))
	_ancora(_leg, 0.5, 0.845)
	_leg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap = rotulo(62, f_titulo, Color(0.93, 0.90, 0.82))
	_ancora(_cap, 0.5, 0.42)
	_cap2 = rotulo(22, f_titulo, Color(0.70, 0.66, 0.58))
	_ancora(_cap2, 0.5, 0.52)
	_cap.modulate.a = 0
	_cap2.modulate.a = 0
	_faz_painel()
	_faz_faixa()
	inv = Inventario.new()
	add_child(inv)
	inv.montar(self)
	Jogo.legenda.connect(_on_legenda)
	Jogo.objetivo_mudou.connect(_on_obj)
	Jogo.aviso.connect(_on_aviso)
	Jogo.nota.connect(abrir_nota)


func rotulo(tam: int, fonte: Font, cor: Color, pai: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pai if pai else _raiz).add_child(l)
	return l


func _ancora(l: Control, ax: float, ay: float) -> void:
	l.anchor_left = ax - 0.36
	l.anchor_right = ax + 0.36
	l.anchor_top = ay
	l.anchor_bottom = ay
	l.grow_vertical = Control.GROW_DIRECTION_END


func _faz_painel() -> void:
	_painel = Control.new()
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.visible = false
	add_child(_painel)
	var esc := ColorRect.new()
	esc.color = Color(0, 0, 0, 0.72)
	esc.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(esc)
	var papel := PanelContainer.new()
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.66, 0.60, 0.48)
	sb.border_color = Color(0.36, 0.30, 0.20)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 30
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 46
	sb.content_margin_bottom = 46
	papel.add_theme_stylebox_override("panel", sb)
	papel.anchor_left = 0.5
	papel.anchor_right = 0.5
	papel.anchor_top = 0.5
	papel.anchor_bottom = 0.5
	papel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	papel.grow_vertical = Control.GROW_DIRECTION_BOTH
	papel.custom_minimum_size = Vector2(700, 300)
	_painel.add_child(papel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	papel.add_child(vb)
	_p_tit = rotulo(30, f_titulo, Color(0.14, 0.08, 0.04), vb)
	_p_corpo = rotulo(22, f_titulo, Color(0.13, 0.09, 0.06), vb)
	for l in [_p_tit, _p_corpo]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_p_corpo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_p_corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p_corpo.custom_minimum_size = Vector2(600, 0)
	var d := rotulo(17, f_texto, Color(0.8, 0.8, 0.78), _painel)
	d.text = "[E] fechar"
	_ancora(d, 0.5, 0.93)


# ------------------------------------------------------------------ icones na tela
func _faz_faixa() -> void:
	_faixa = HBoxContainer.new()
	_faixa.anchor_left = 1.0
	_faixa.anchor_right = 1.0
	_faixa.anchor_top = 1.0
	_faixa.anchor_bottom = 1.0
	_faixa.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_faixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_faixa.offset_right = -40
	_faixa.offset_bottom = -34
	_faixa.add_theme_constant_override("separation", 6)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_faixa)
	_ganhos = VBoxContainer.new()
	_ganhos.anchor_left = 1.0
	_ganhos.anchor_right = 1.0
	_ganhos.anchor_top = 0.5
	_ganhos.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ganhos.offset_right = -44
	_ganhos.offset_left = -360
	_ganhos.alignment = BoxContainer.ALIGNMENT_END
	_ganhos.add_theme_constant_override("separation", 10)
	_ganhos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_ganhos)


func _caixinha(tam: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(tam, tam)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.06, 0.55)
	sb.border_color = Color(0.6, 0.58, 0.5, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _icone_em(p: Control, id: String, m: int) -> TextureRect:
	var im := TextureRect.new()
	im.set_anchors_preset(Control.PRESET_FULL_RECT)
	im.offset_left = m
	im.offset_top = m
	im.offset_right = -m
	im.offset_bottom = -m
	im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	im.texture = Itens.icone(id)
	p.add_child(im)
	return im


## aviso grande de item novo, com icone
func mostrar_item(id: String, n: int = 1) -> void:
	_faixa_t = 8.0
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := rotulo(24, f_titulo, Color(0.96, 0.92, 0.82), h)
	l.text = Itens.INFO[id][0] + ("  ×%d" % n if n > 1 else "")
	var p := _caixinha(78)
	_icone_em(p, id, 6)
	h.add_child(p)
	_ganhos.add_child(h)
	h.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(h, "modulate:a", 1.0, 0.35)
	t.tween_interval(3.2)
	t.tween_property(h, "modulate:a", 0.0, 0.8)
	t.tween_callback(h.queue_free)


func _pinta_faixa(dt: float, ok: bool) -> void:
	_faixa_t -= dt
	for id in Itens.ORDEM:
		var n := Jogo.tem(id)
		if n > 0 and not _faixa_s.has(id):
			var p := _caixinha(52)
			_icone_em(p, id, 4)
			var l := rotulo(14, f_texto, Color(0.95, 0.92, 0.82), p)
			l.position = Vector2(20, 32)
			l.size = Vector2(29, 18)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_faixa.add_child(p)
			_faixa_s[id] = [p, l]
		if _faixa_s.has(id):
			_faixa_s[id][0].visible = n > 0
			_faixa_s[id][1].text = str(n) if n > 1 else ""
	_faixa.modulate.a = move_toward(_faixa.modulate.a, (1.0 if _faixa_t > 0.0 else 0.50) if ok else 0.0, dt * 1.5)


## pergunta com opcoes [ [texto, icone], ... ] ; devolve o indice
func escolha(titulo: String, ops: Array) -> int:
	var pn := Control.new()
	pn.set_anchors_preset(Control.PRESET_FULL_RECT)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pn)
	var tt := rotulo(26, f_titulo, Color(0.95, 0.92, 0.84), pn)
	_ancora(tt, 0.5, 0.55)
	tt.text = titulo
	var cx := HBoxContainer.new()
	cx.anchor_left = 0.5
	cx.anchor_right = 0.5
	cx.anchor_top = 0.605
	cx.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cx.alignment = BoxContainer.ALIGNMENT_CENTER
	cx.add_theme_constant_override("separation", 26)
	pn.add_child(cx)
	var ps := []
	for i in ops.size():
		var p := _caixinha(190)
		p.custom_minimum_size = Vector2(230, 170)
		var l := rotulo(20, f_texto, Color(0.95, 0.93, 0.86), p)
		l.text = "[%d]  %s" % [i + 1, ops[i]]
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.custom_minimum_size = Vector2(270, 92)
		cx.add_child(p)
		ps.append(p)
	var d := rotulo(16, f_texto, Color(0.7, 0.7, 0.66), pn)
	d.text = "A / D escolher    ·    E confirmar    ·    ou aperte 1 / 2"
	_ancora(d, 0.5, 0.715)
	var sel := 0
	var t := 0.0
	var r := -1
	while r < 0:
		await get_tree().process_frame
		if not is_inside_tree(): return 0
		t += get_process_delta_time()
		for i in ps.size():
			(ps[i].get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(0.9, 0.74, 0.42, 0.95) if i == sel else Color(0.6, 0.58, 0.5, 0.25)
			(ps[i].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.18, 0.16, 0.12, 0.8) if i == sel else Color(0.05, 0.055, 0.06, 0.6)
		if Teste.ativo:
			if t > 0.6: r = int(Teste.num("lanche", 0))
			continue
		if get_tree().paused: continue
		if Input.is_action_just_pressed("esquerda"): sel = maxi(0, sel - 1)
		if Input.is_action_just_pressed("direita"): sel = mini(ops.size() - 1, sel + 1)
		if t > 0.3:
			if Input.is_action_just_pressed("guardar"): r = 0
			elif Input.is_action_just_pressed("arma") and ops.size() > 1: r = 1
			elif Input.is_action_just_pressed("usar"): r = sel
	pn.queue_free()
	Som.toca("papel", -10, 1.3, "UI")
	return r


func abrir_nota(titulo: String, corpo: String) -> void:
	_p_tit.text = titulo
	_p_corpo.text = corpo
	_painel.visible = true
	lendo = true
	if Jogo.jogador:
		Jogo.jogador.travado = true
	Som.toca("papel", -6, 1.0, "UI")


func fechar_nota() -> void:
	_painel.visible = false
	lendo = false
	em_diario = false
	if Jogo.jogador and Jogo.jogador.is_visible_in_tree():
		Jogo.jogador.travado = false
	Som.toca("papel", -10, 1.2, "UI")
	leitura_fechou.emit()


func _unhandled_input(e: InputEvent) -> void:
	if Teste.ativo:
		return
	if inv.visible and not get_tree().paused:
		if e.is_action_pressed("diario") or e.is_action_pressed("pausa") or e.is_action_pressed("inventario"):
			get_viewport().set_input_as_handled()
			inv.fecha()
		elif e.is_action_pressed("mapa"):
			get_viewport().set_input_as_handled()
			if inv.aba == "mapa": inv.fecha()
			else: inv.mostra("mapa")
	elif lendo and not get_tree().paused:
		if e.is_action_pressed("usar") or e.is_action_pressed("diario") or e.is_action_pressed("pausa"):
			get_viewport().set_input_as_handled()
			fechar_nota()
	elif (e.is_action_pressed("diario") or e.is_action_pressed("inventario") or e.is_action_pressed("mapa")) and Jogo.jogador and not Jogo.jogador.travado and not Jogo.jogador.morto and not get_tree().paused and Jogo.jogador.is_visible_in_tree():
		get_viewport().set_input_as_handled()
		inv.abre("mapa" if e.is_action_pressed("mapa") else "itens")


func abrir_diario() -> void:
	var t := ""
	if Jogo.objetivo != "":
		t += "AGORA:  " + Jogo.objetivo + "\n\n"
	var nomes := {"jaqueta": "Jaqueta de lona", "bussola": "Bússola  [C]", "curativo": "Curativos  [H]", "pedra": "Pedras do rio  [clique]", "lanterna": "Lanterna  [F]", "pilha": "Pilhas", "chave": "Chave — Torre 4", "fosforos": "Fósforos"}
	var li := ""
	for k in nomes:
		if Jogo.tem(k) > 0:
			li += "   •  " + nomes[k] + ("  ×%d" % Jogo.tem(k) if k in ["curativo", "pedra", "pilha"] else "") + "\n"
	t += "COM VOCÊ:\n" + (li if li != "" else "   nada\n")
	if Jogo.notas.size() > 0:
		t += "\nO QUE VOCÊ LEU:\n"
		for q in Jogo.notas:
			t += "   •  " + q[0] + "\n"
		if "regras" in Jogo.flags:
			t += "\nNão grite. Não responda. Não siga as luzes.\nSe o mato calar, cale também."
	abrir_nota("Caderno", t)
	em_diario = true


func _on_legenda(quem: String, texto: String, dur: float) -> void:
	if not Jogo.legendas:
		return
	_leg_quem.text = quem
	_leg.text = texto
	_leg_t = dur


func _on_obj(t: String) -> void:
	_obj.text = t
	_obj_t = 9.0
	if t != "":
		Som.toca("radio_clique", -26, 0.5, "UI")


func mostrar_objetivo() -> void:
	_obj_t = 5.0


func _on_aviso(t: String) -> void:
	_aviso.text = t
	_aviso_t = 3.6


func capitulo(a: String, b: String, dur: float = 4.0) -> void:
	_cap.text = a
	_cap2.text = b
	var t := create_tween()
	t.tween_property(_cap, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_cap2, "modulate:a", 1.0, 2.2)
	t.tween_interval(dur)
	t.tween_property(_cap, "modulate:a", 0.0, 1.6)
	t.parallel().tween_property(_cap2, "modulate:a", 0.0, 1.6)


func escurecer(alvo: float, dur: float) -> void:
	preto_alvo = alvo
	preto_vel = 1.0 / maxf(dur, 0.01)
	if dur <= 0.0:
		preto = alvo


func piscar(s: float) -> void:
	pisca = maxf(pisca, s)


func limpar() -> void:
	_leg.text = ""
	_leg_quem.text = ""
	_aviso.text = ""
	_obj_t = 0.0
	_obj.modulate.a = 0
	_painel.visible = false
	if inv: inv.visible = false
	lendo = false
	dano = 0.0
	tonto = 0.0
	branco = 0.0


func _process(dt: float) -> void:
	preto = move_toward(preto, preto_alvo, dt * preto_vel)
	branco = move_toward(branco, 0.0, dt * 0.55)
	pulso = move_toward(pulso, 0.0, dt * 3.2)
	_leg_t -= dt
	var la := clampf(_leg_t * 2.0, 0.0, 1.0)
	_leg.modulate.a = la
	_leg_quem.modulate.a = la
	_aviso_t -= dt
	_aviso.modulate.a = clampf(_aviso_t, 0.0, 1.0)
	_obj_t -= dt
	_obj.modulate.a = move_toward(_obj.modulate.a, 1.0 if _obj_t > 0.0 else 0.0, dt * 1.2)
	pisca = maxf(0.0, pisca - dt)
	pos.set_shader_parameter("preto", maxf(preto, 0.97 * smoothstep(0.0, 0.10, pisca)))
	pos.set_shader_parameter("branco", branco)
	pos.set_shader_parameter("tonto", tonto)
	pos.set_shader_parameter("gama", 1.0 / Jogo.gama)
	pos.set_shader_parameter("pulso", pulso)
	var j = Jogo.jogador
	var ok: bool = j != null and j.is_visible_in_tree() and not j.morto
	_pinta_faixa(dt, ok and not lendo and Jogo.etapa > 0)
	_mira.visible = ok and not lendo and not j.travado
	_ind.visible = ok and not lendo
	_dica.text = j.dica() if ok and not lendo else ""
	if ok:
		pos.set_shader_parameter("medo", j.medo)
		pos.set_shader_parameter("frio", smoothstep(0.45, 1.0, j.frio / 100.0))
		dano = move_toward(dano, clampf((55.0 - j.vida) / 55.0, 0.0, 1.0) * 0.8, dt * 0.5)
		pos.set_shader_parameter("dano", dano)
		_mira.color.a = 0.75 if j.alvo else 0.28
		_ind.luz = j.luz
		_ind.vida = j.vida / 100.0
		_ind.frio = j.frio / 100.0
		_ind.fol = j.folego / 100.0
		_ind.seg = j.prog_segurar()
		_ind.esc = j.escondido
		_ind.bat = j.lanterna.bateria / 100.0
		_ind.tem_bat = j.lanterna.ligada
		_ind.danos = j.danos if Jogo.etapa == 7 else -1
		_ind.tiros = j.rifle.pente if j.rifle.na_mao and j.rifle.tem else -1
		_ind.reserva = Jogo.tem("municao")
		_ind.a_luz = move_toward(_ind.a_luz, 0.9 if not j.travado else 0.0, dt)
		_ind.a_fol = move_toward(_ind.a_fol, 1.0 if j.folego < 99.0 else 0.0, dt * 2.0)
		_ind.a_vida = move_toward(_ind.a_vida, 1.0 if j.vida < 99.0 else 0.0, dt)
		_ind.a_frio = move_toward(_ind.a_frio, 1.0 if j.frio > 22.0 else 0.0, dt)
		_ind.queue_redraw()
	else:
		pos.set_shader_parameter("medo", 0.0)
		pos.set_shader_parameter("frio", 0.0)
		pos.set_shader_parameter("dano", dano)
