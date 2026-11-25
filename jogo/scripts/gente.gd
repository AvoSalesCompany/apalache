class_name Gente
extends Node3D
## Pessoa viva (ou nao): esqueleto, rosto que pisca, fala e olha, poses e gestos por codigo.
## Olha para -Z. De pe: origem nos pes. Sentada: origem no quadril.

var d: DadosGente
var id := ""
var esq: Skeleton3D
var rosto: MeshInstance3D
var corpo: MeshInstance3D
var idx := {}
var _r := {}                   # osso -> rotacao global alvo (Quaternion)
var _g := []                   # rotacoes globais calculadas
var _eixo_dedo := {}
var m_pele: Array = []
var m_tec: Array = []
var m_olho: StandardMaterial3D
var bf := {}                   # blend -> indice

# ---- estado
var sentado := false
var pose := "pe"               # pe, sentado, dorme, le, janela, conversa, mesa, impacto, medo, morto...
var morto := false
var olhar = null               # Node3D ou Vector3 global; null = livre
var olhar_peso := 0.0
var fala_ate := 0.0
var sorriso := 0.0
var medo := 0.0
var fecha := 0.0               # olhos fechados 0..1
var boca := 0.0
var vel := 0.0                 # andando
var fase := 0.0
var agita := 0.0               # turbulencia
var fase0 := randf() * 100.0
var _t := 0.0
var _pisca := randf_range(1.0, 4.0)
var _sac := Vector2.ZERO
var _tsac := 0.0
var _cab := Vector2.ZERO       # giro atual da cabeca (yaw, pitch)
var _mist := {}                # pose suavizada: osso -> direcao
var _alvos := {}
var _curva := 0.25
var _curva_a := 0.25
var _tronco := Vector3.ZERO    # rotacao extra do tronco
var _tronco_a := Vector3.ZERO
var caminho: Array = []
var chegou: Callable
var vel_anda := 1.0
var giro_alvo = null
var _tick := 0
static var _mats := {}
var maos := {}


static func criar(pai: Node3D, qual: String, pos: Vector3 = Vector3.ZERO, ry: float = 0.0, sent: bool = false) -> Gente:
	var g := Gente.new()
	g.id = qual
	g.sentado = sent
	g.pose = "sentado" if sent else "pe"
	pai.add_child(g)
	g.position = pos
	g.rotation.y = ry
	g._montar()
	return g


func _montar() -> void:
	d = load("res://dados/gente/%s.res" % id)
	esq = Skeleton3D.new()
	add_child(esq)
	for i in d.ossos.size():
		esq.add_bone(d.ossos[i].replace(".", "_"))
		idx[d.ossos[i]] = i
		if d.pais[i] >= 0: esq.set_bone_parent(i, d.pais[i])
		var loc := d.pos[i] - (d.pos[d.pais[i]] if d.pais[i] >= 0 else Vector3.ZERO)
		esq.set_bone_rest(i, Transform3D(Basis.IDENTITY, loc))
		_g.append(Quaternion.IDENTITY)
	esq.reset_bone_poses()
	var skin := Skin.new()
	for i in d.ossos.size():
		skin.add_bind(i, Transform3D(Basis.IDENTITY, d.pos[i]).affine_inverse())
	rosto = MeshInstance3D.new()
	rosto.mesh = d.rosto
	corpo = MeshInstance3D.new()
	corpo.mesh = d.corpo
	for m in [rosto, corpo]:
		m.skin = skin
		esq.add_child(m)
		m.skeleton = NodePath("..")
		m.custom_aabb = AABB(Vector3(-1.2, -0.3, -1.2), Vector3(2.4, 2.4, 2.4))
		m.lod_bias = 0.55
	rosto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in d.rosto.get_blend_shape_count():
		bf[String(d.rosto.get_blend_shape_name(i))] = i
	for i in d.sup_rosto.size(): rosto.set_surface_override_material(i, _mat(d.sup_rosto[i]))
	for i in d.sup_corpo.size():
		if d.sup_corpo[i] == "cabelo" and d.gorro.a > 0.0 and not d.fem:
			var nada := StandardMaterial3D.new()
			nada.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			nada.alpha_scissor_threshold = 0.9
			nada.albedo_color = Color(0, 0, 0, 0)
			corpo.set_surface_override_material(i, nada)
			continue
		corpo.set_surface_override_material(i, _mat(d.sup_corpo[i]))
	if sentado:
		esq.position = -_quadril()
	_dedos()
	_acessorios()
	_pose_base()
	for k in _alvos: _mist[k] = _alvos[k]
	_curva = _curva_a
	_tronco = _tronco_a
	_aplica(0.0)


func _quadril() -> Vector3:
	return (d.pos[idx["upperleg01.L"]] + d.pos[idx["upperleg01.R"]]) * 0.5


func _tex(n: String) -> Texture2D:
	return load("res://tex/gente/" + n)


func _mat(sup: String) -> Material:
	match sup:
		"pele":
			if m_pele.is_empty():
				var m := ShaderMaterial.new()
				m.shader = load("res://shaders/pele.gdshader")
				m.set_shader_parameter("cor", _tex(d.tex.pele))
				m.set_shader_parameter("tinta", {"african": Color(0.60, 0.52, 0.50), "asian": Color(0.80, 0.73, 0.68)}.get(d.etnia, Color(0.80, 0.71, 0.67)))
				m.set_shader_parameter("barba", d.barba)
				m.set_shader_parameter("barba_cor", d.cab_cor * 0.8)
				m.set_shader_parameter("semente", fmod(fase0, 7.0))
				m_pele.append(m)
			return m_pele[0]
		"roupa", "sapato", "chapeu":
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/tecido.gdshader")
			m.set_shader_parameter("cor", _tex(d.tex[sup]))
			if sup == "roupa" and d.tex.roupa_n != "":
				m.set_shader_parameter("nor", _tex(d.tex.roupa_n))
			else:
				m.set_shader_parameter("relevo", 0.0)
			m.set_shader_parameter("rug", {"roupa": 0.88, "sapato": 0.55, "chapeu": 0.9}[sup])
			m.set_shader_parameter("trama", 1.0 if sup == "roupa" else 0.2)
			m.set_shader_parameter("semente", fmod(fase0, 5.0))
			m_tec.append(m)
			return m
		"olhos":
			m_olho = StandardMaterial3D.new()
			m_olho.albedo_texture = _tex(d.tex.olhos)
			m_olho.albedo_color = Color(0.92, 0.92, 0.92)
			m_olho.roughness = 0.06
			m_olho.metallic_specular = 0.6
			return m_olho
		"dentes":
			var m := StandardMaterial3D.new()
			m.albedo_texture = _tex(d.tex.dentes)
			m.albedo_color = Color(0.82, 0.78, 0.72)
			m.roughness = 0.3
			return m
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cabelo.gdshader")
	m.set_shader_parameter("cor", _tex(d.tex[sup]))
	m.set_shader_parameter("tom", Color(0.03, 0.025, 0.02) if sup == "cilios" else d.cab_cor * (0.75 if sup == "sobr" else 1.0))
	m.set_shader_parameter("corte", 0.22 if sup != "cabelo" else 0.38)
	if sup == "cabelo": m_tec.append(m)
	return m


func _acessorios() -> void:
	if d.gorro.a > 0.0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "head"
		esq.add_child(ba)
		var o := d.topo - d.pos[idx["head"]]
		var fl := 1.12 if d.fem else 1.05
		var m := Malha.new()
		var ps := []
		var rs := []
		for q in [[-0.075, 1.02], [-0.05, 1.03], [-0.02, 0.97], [0.005, 0.84], [0.022, 0.62], [0.033, 0.32], [0.037, 0.04]]:
			ps.append(Vector3(0, q[0], 0))
			rs.append(q[1])
		m.tubo(ps, rs, 30, 8.0, 6.0)
		var pf := []
		var rf := []
		for q in [[-0.098, 1.0], [-0.094, 1.06], [-0.080, 1.09], [-0.062, 1.08], [-0.052, 1.0]]:
			pf.append(Vector3(0, q[0], 0))
			rf.append(q[1])
		m.tubo(pf, rf, 30, 8.0, 6.0)
		# canelado de trico
		for i in m.v.size():
			var a := atan2(m.v[i].z, m.v[i].x)
			m.v[i] *= Vector3(1.0 + 0.012 * sin(a * 44.0), 1.0, 1.0 + 0.012 * sin(a * 44.0))
			m.v[i] *= Vector3(d.cranio.x * fl, 1.0, d.cranio.y * fl)
		var n := m.no(Aeronave.m_forro(d.gorro, 0.25, 0.0, 1.0), ba)
		n.position = o + Vector3(0, 0.012 if d.fem else 0.004, 0)
		n.rotation.x = 0.10
	if d.lenco.a > 0.0:
		var bl := BoneAttachment3D.new()
		bl.bone_name = "neck01"
		esq.add_child(bl)
		var ml := Malha.new()
		var pl := []
		var rl := []
		for i in 25:
			var a := TAU * i / 24.0
			pl.append(Vector3(sin(a) * 0.054, 0.052 + 0.006 * cos(a * 5.0) - 0.012 * cos(a), -cos(a) * 0.060 - 0.012))
			rl.append(0.014 + 0.003 * sin(a * 9.0))
		ml.tubo(pl, rl, 8, 6.0, 1.0)
		ml.tubo([Vector3(0.0, 0.045, -0.078), Vector3(-0.015, 0.02, -0.098), Vector3(-0.03, -0.03, -0.108), Vector3(-0.034, -0.06, -0.108)], [0.016, 0.020, 0.022, 0.004], 8)
		ml.tubo([Vector3(0.0, 0.045, -0.078), Vector3(0.015, 0.022, -0.098), Vector3(0.026, -0.02, -0.106), Vector3(0.030, -0.045, -0.106)], [0.016, 0.020, 0.020, 0.004], 8)
		ml.no(Aeronave.m_forro(d.lenco, 0.1, 0.0, 0.5), bl)
	if d.cachecol.a > 0.0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "neck01"
		esq.add_child(ba)
		var m := Malha.new()
		var ps := []
		var rs := []
		for i in 25:
			var a := TAU * i / 24.0
			ps.append(Vector3(sin(a) * 0.074, 0.028 + 0.010 * cos(a * 3.0) - 0.022 * cos(a), -cos(a) * 0.078 - 0.004))
			rs.append(0.026 + 0.004 * sin(a * 5.0))
		m.tubo(ps, rs, 12, 6.0, 2.0)
		m.tubo([Vector3(0.02, 0.0, -0.088), Vector3(0.034, -0.05, -0.125), Vector3(0.045, -0.16, -0.140), Vector3(0.05, -0.27, -0.130), Vector3(0.05, -0.29, -0.126)], [0.022, 0.027, 0.029, 0.030, 0.016], 12, 6.0, 2.0)
		for i in m.v.size(): m.v[i] += m.n[i] * 0.0035 * sin(m.uv[i].y * 120.0)
		m.no(Aeronave.m_forro(d.cachecol, 0.2, 0.0, 1.0), ba)


# ------------------------------------------------------------------ ossos
func _dir_repouso(b: String) -> Vector3:
	var f := {"upperarm01": "lowerarm01", "lowerarm01": "wrist", "upperleg01": "lowerleg01", "lowerleg01": "foot", "wrist": "finger3-1", "clavicle": "upperarm01"}
	var p := b.split(".")
	var c: String = f[p[0]] + "." + p[1]
	return (d.pos[idx[c]] - d.pos[idx[b]]).normalized()


func _dedos() -> void:
	for s in ["L", "R"]:
		var pu := d.pos[idx["wrist." + s]]
		var ind := d.pos[idx["finger2-1." + s]]
		var mi := d.pos[idx["finger5-1." + s]]
		var dr := (d.pos[idx["finger3-2." + s]] - d.pos[idx["finger3-1." + s]]).normalized()
		var n := (ind - mi).cross(dr).normalized()
		var th := d.pos[idx["finger1-2." + s]] - pu
		if n.dot(th) < 0.0: n = -n
		# eixo que leva os dedos para a palma
		_eixo_dedo[s] = dr.cross(n).normalized()


func _rg(i: int) -> Quaternion:
	return _g[i]


func _aplica(_dt: float) -> void:
	var t := _t + fase0
	for i in d.ossos.size():
		var b := d.ossos[i]
		var pg: Quaternion = _g[d.pais[i]] if d.pais[i] >= 0 else Quaternion.IDENTITY
		var g := pg
		if _mist.has(b):
			var atual: Vector3 = pg * _dir_repouso(b)
			var quer: Vector3 = (_mist[b] as Vector3).normalized()
			if b.begins_with("wrist"):
				g = Quaternion(atual, quer) * pg if atual.dot(quer) > -0.999 else pg
			else:
				# membros giram com o tronco
				g = Quaternion(atual, quer) * pg if atual.dot(quer) > -0.999 else pg
		else:
			match b:
				"spine04", "spine03", "spine02", "spine01":
					var k := 0.25
					var resp := sin(t * (1.15 + medo * 2.2)) * (0.010 + 0.014 * medo) if not morto else 0.0
					var e := _tronco * k
					if b == "spine02": e.x -= resp
					if b == "spine01": e.x += resp * 0.6
					e += Vector3(sin(t * 5.1), sin(t * 3.7 + 1.0) * 0.6, sin(t * 4.3 + 2.0)) * agita * 0.035
					g = pg * Quaternion.from_euler(e)
				"neck01":
					g = pg * Quaternion.from_euler(Vector3(_cab.y * 0.35, _cab.x * 0.35, sin(t * 4.7) * agita * 0.06))
				"head":
					var osc := Vector3(sin(t * 0.83) * 0.012, sin(t * 0.61) * 0.018, sin(t * 0.47) * 0.012) if not morto else Vector3.ZERO
					g = pg * Quaternion.from_euler(Vector3(_cab.y * 0.65, _cab.x * 0.65, 0) + osc + Vector3(sin(t * 6.1), sin(t * 4.9), sin(t * 5.3)) * agita * 0.05)
				"jaw":
					g = pg * Quaternion.from_euler(Vector3(boca * 0.16, 0, 0))
				"eye.L", "eye.R":
					g = pg * Quaternion.from_euler(Vector3(_sac.y, _sac.x, 0))
				"foot.L", "foot.R":
					if vel < 0.05 or sentado: g = Quaternion.IDENTITY.slerp(pg, 0.15)
					else: g = Quaternion.IDENTITY.slerp(pg, 0.55)
				_:
					if b.begins_with("finger"):
						var s := b.right(1)
						var c: float = _curva * (0.5 if b.begins_with("finger1") else 1.0)
						var ex: Vector3 = _eixo_dedo[s]
						g = pg * Quaternion(ex, -c * (1.0 if b.contains("-1") else 1.15))
		_g[i] = g.normalized()
		esq.set_bone_pose_rotation(i, (pg.inverse() * _g[i]).normalized())


# ------------------------------------------------------------------ poses (direcoes no espaco da pessoa)
func _par(b: String, v: Vector3) -> void:
	_alvos[b + ".L"] = Vector3(-v.x, v.y, v.z)
	_alvos[b + ".R"] = v


func _pose_base() -> void:
	_alvos = {}
	_curva_a = 0.28
	_tronco_a = Vector3.ZERO
	if sentado:
		_par("upperleg01", Vector3(0.10, 0.05, -1.0))
		_par("lowerleg01", Vector3(0.01, -1.0, -0.10))
		_par("upperarm01", Vector3(0.30, -0.95, -0.10))
		_par("lowerarm01", Vector3(-0.28, -0.22, -0.92))
		_par("wrist", Vector3(-0.35, -0.10, -0.9))
		_tronco_a = Vector3(-0.10, 0, 0)
	else:
		_par("upperleg01", Vector3(0.04, -1.0, 0.0))
		_par("lowerleg01", Vector3(0.0, -1.0, 0.03))
		_par("upperarm01", Vector3(0.16, -1.0, 0.04))
		_par("lowerarm01", Vector3(0.05, -1.0, -0.16))
		_par("wrist", Vector3(0.0, -1.0, -0.15))
	var t := _t + fase0
	match pose:
		"dorme":
			_par("upperarm01", Vector3(0.20, -0.97, -0.05))
			_par("lowerarm01", Vector3(-0.55, -0.40, -0.72))
			_par("wrist", Vector3(-0.8, -0.25, -0.5))
		"le":
			_par("upperarm01", Vector3(0.16, -0.90, -0.40))
			_par("lowerarm01", Vector3(-0.22, 0.42, -0.86))
			_par("wrist", Vector3(-0.25, 0.75, -0.6))
			_curva_a = 0.8
		"conversa":
			var k := clampf(sin(t * 1.3) * 1.4, 0.0, 1.0) * clampf(sin(t * 0.37) * 2.0, 0.0, 1.0)
			_alvos["lowerarm01.R"] = Vector3(-0.35, lerpf(-0.22, 0.45, k), -0.85)
			_alvos["wrist.R"] = Vector3(-0.2, lerpf(-0.1, 0.6, k), -0.8)
		"nervoso":
			_par("lowerarm01", Vector3(-0.62, -0.10 + 0.05 * sin(t * 7.0), -0.78))
			_par("wrist", Vector3(-0.9, -0.15, -0.3))
			_alvos["lowerleg01.R"] = Vector3(0.01, -1.0, -0.10 + 0.04 * sin(t * 14.0))
			_tronco_a = Vector3(-0.22, 0, 0)
		"agarra":
			_par("upperarm01", Vector3(0.30, -0.95, -0.02))
			_par("lowerarm01", Vector3(0.02, -0.36, -0.93))
			_par("wrist", Vector3(0.0, -0.25, -0.97))
			_curva_a = 1.1
			_tronco_a = Vector3(0.05, 0, 0)
		"impacto":
			_par("upperarm01", Vector3(0.28, 0.10, -0.95))
			_par("lowerarm01", Vector3(-0.60, 0.72, 0.25))
			_par("wrist", Vector3(-0.8, 0.2, 0.5))
			_tronco_a = Vector3(-0.95, 0, 0)
			_curva_a = 0.5
		"bandeja":
			_par("upperarm01", Vector3(0.14, -0.97, -0.10))
			_par("lowerarm01", Vector3(-0.10, -0.02, -1.0))
			_par("wrist", Vector3(-0.1, 0.1, -1.0))
			_curva_a = 0.55
		"serve":
			_par("upperarm01", Vector3(0.14, -0.92, -0.30))
			_par("lowerarm01", Vector3(-0.08, 0.02, -1.0))
			_alvos["upperarm01.R"] = Vector3(0.10, -0.62, -0.78)
			_alvos["lowerarm01.R"] = Vector3(-0.05, -0.10, -1.0)
			_tronco_a = Vector3(-0.20, 0, 0)
			_curva_a = 0.4
		"aquece":
			_par("upperarm01", Vector3(0.10, -0.80, -0.50))
			_par("lowerarm01", Vector3(-0.14, 0.12 + 0.03 * sin(t * 1.1), -1.0))
			_par("wrist", Vector3(-0.1, 0.25, -0.95))
			_curva_a = 0.12
		"bracos":
			_par("upperarm01", Vector3(0.22, -0.94, -0.22))
			_par("lowerarm01", Vector3(-0.86, 0.16, -0.46))
			_par("wrist", Vector3(-0.9, 0.12, 0.2))
			_curva_a = 0.6
		"aponta":
			_alvos["upperarm01.R"] = Vector3(0.22, -0.10, -0.97)
			_alvos["lowerarm01.R"] = Vector3(0.10, 0.05, -1.0)
			_alvos["wrist.R"] = Vector3(0.06, 0.05, -1.0)
			_curva_a = 0.2
		"radio":
			_alvos["upperarm01.R"] = Vector3(0.30, -0.55, -0.60)
			_alvos["lowerarm01.R"] = Vector3(-0.35, 0.86, 0.1)
		"panico":
			_par("upperarm01", Vector3(0.42, -0.28, -0.72))
			_par("lowerarm01", Vector3(-0.22, 0.92, -0.22))
			_par("wrist", Vector3(-0.2, 0.8, -0.4))
			_curva_a = 0.6
			_tronco_a = Vector3(-0.12, 0, 0)
		"arma":
			_alvos["upperarm01.R"] = Vector3(0.25, -0.75, -0.40)
			_alvos["lowerarm01.R"] = Vector3(-0.45, 0.05, -0.88)
			_alvos["upperarm01.L"] = Vector3(-0.05, -0.62, -0.72)
			_alvos["lowerarm01.L"] = Vector3(0.45, 0.10, -0.85)
			_curva_a = 0.9
	if vel > 0.05 and not sentado:
		var s := sin(fase)
		var amp := clampf(vel / 1.5, 0.35, 1.5)
		for sd in ["L", "R"]:
			var sg := 1.0 if sd == "R" else -1.0
			var f := s * sg
			var rec := maxf(0.0, cos(fase) * sg)
			var coxa := f * 0.46 * amp
			var joelho := coxa - (0.12 + rec * 0.85 * amp)
			_alvos["upperleg01." + sd] = Vector3(0.04 * sg, -cos(coxa), -sin(coxa))
			_alvos["lowerleg01." + sd] = Vector3(0.0, -cos(joelho), -sin(joelho))
			if pose in ["pe", "corre"]:
				var br := -f * (0.36 if vel < 2.2 else 0.7) * amp
				var ct := br + (0.25 if vel < 2.2 else 1.25)
				_alvos["upperarm01." + sd] = Vector3(0.16 * sg, -cos(br), -sin(br))
				_alvos["lowerarm01." + sd] = Vector3(0.02 * sg, -cos(ct), -sin(ct))
				_alvos["wrist." + sd] = Vector3(0.0, -cos(ct), -sin(ct))
		_tronco_a += Vector3(-0.05 - 0.10 * clampf(vel - 1.6, 0.0, 1.0), sin(fase) * 0.10, 0)


## deixa uma pose de morto, parada
func morrer(semente: int, frio: float = 0.6, sg: float = 0.5) -> void:
	morto = true
	var r := RandomNumberGenerator.new()
	r.seed = semente
	fecha = [1.0, 0.9, 0.35, 1.0][r.randi() % 4]
	boca = r.randf_range(0.0, 0.5)
	_aplica_morto(frio, sg)
	_pose_base()
	if sentado:
		_tronco_a = Vector3(r.randf_range(-0.75, 0.05), r.randf_range(-0.2, 0.2), r.randf_range(-0.28, 0.28))
		_cab = Vector2(r.randf_range(-0.5, 0.5), r.randf_range(-0.75, -0.2))
		_par("upperarm01", Vector3(0.16, -1.0, r.randf_range(-0.2, 0.1)))
		_par("lowerarm01", Vector3(r.randf_range(-0.3, 0.2), -0.9, r.randf_range(-0.5, -0.1)))
		_par("wrist", Vector3(0, -1.0, -0.1))
		_alvos["lowerleg01.L"] = Vector3(-0.1, -1.0, r.randf_range(-0.5, 0.1))
	else:
		# deitado: a pessoa inteira e girada por quem a colocou
		for sd in ["L", "R"]:
			var sg2 := 1.0 if sd == "R" else -1.0
			_alvos["upperleg01." + sd] = Vector3(r.randf_range(0.0, 0.45) * sg2, -1.0, r.randf_range(-0.6, 0.1))
			_alvos["lowerleg01." + sd] = Vector3(r.randf_range(-0.2, 0.2), -1.0, r.randf_range(0.0, 0.7))
			_alvos["upperarm01." + sd] = Vector3(r.randf_range(0.5, 1.2) * sg2, r.randf_range(-0.9, 0.7), r.randf_range(-0.3, 0.1))
			_alvos["lowerarm01." + sd] = Vector3(r.randf_range(-0.2, 1.0) * sg2, r.randf_range(-0.8, 0.8), r.randf_range(-0.6, 0.0))
			_alvos["wrist." + sd] = _alvos["lowerarm01." + sd]
		_cab = Vector2(r.randf_range(-0.9, 0.9), r.randf_range(-0.2, 0.3))
	_curva_a = 0.5
	_curva = 0.5
	_tronco = _tronco_a
	for k in _alvos: _mist[k] = _alvos[k]
	_expressao()
	_aplica(0.0)
	set_process(false)


func _aplica_morto(frio: float, sg: float) -> void:
	for m in m_pele:
		m.set_shader_parameter("palidez", 0.88)
		m.set_shader_parameter("geada", frio * 0.4)
		m.set_shader_parameter("sangue", sg)
	for m in m_tec:
		m.set_shader_parameter("geada", frio)
		m.set_shader_parameter("sangue", sg * 0.8)
	if m_olho: m_olho.albedo_color = Color(0.62, 0.64, 0.66)


func dizer(som: String, quem: String, texto: String, dur: float, tom: float = 1.0) -> void:
	fala_ate = _t + dur
	if som != "": Som.em(som, cabeca(), 2.0, 26, tom, "Voz", 4.0)
	Jogo.falar(quem, texto, dur + 0.3)


func olhar_fim(_j) -> void:
	get_tree().create_timer(2.5, false).timeout.connect(func(): if is_instance_valid(self) and not morto: olhar = null)


func cabeca() -> Vector3:
	return (esq.global_transform * esq.get_bone_global_pose(idx["head"])).origin + Vector3.UP * 0.06


func mao(lado: String) -> BoneAttachment3D:
	if not maos.has(lado):
		var ba := BoneAttachment3D.new()
		ba.bone_name = "wrist_" + lado
		esq.add_child(ba)
		maos[lado] = ba
	return maos[lado]


func ir(pts: Array, v: float = 1.0, f: Callable = Callable()) -> void:
	caminho = pts.duplicate()
	vel_anda = v
	chegou = f


func _expressao() -> void:
	if bf.has("pisca"): rosto.set_blend_shape_value(bf.pisca, fecha)
	if bf.has("fala"): rosto.set_blend_shape_value(bf.fala, boca)
	if bf.has("sorri"): rosto.set_blend_shape_value(bf.sorri, sorriso * (1.0 - boca * 0.4))
	if bf.has("medo"): rosto.set_blend_shape_value(bf.medo, medo * (1.0 - fecha * 0.5))


func _process(dt: float) -> void:
	if morto or not is_visible_in_tree():
		return
	_t += dt
	_tick += 1
	# caminho
	if caminho.size() > 0:
		var p: Vector3 = caminho[0]
		var dl := p - position
		dl.y = 0.0
		if dl.length() < maxf(0.10, vel_anda * dt * 1.5):
			caminho.pop_front()
			if caminho.is_empty():
				vel = 0.0
				if chegou.is_valid():
					var f := chegou
					chegou = Callable()
					f.call()
		else:
			vel = move_toward(vel, vel_anda, dt * 3.0)
			position += dl.normalized() * vel * dt
			if has_meta("chao"): position.y = Mundo.altura(position.x, position.z) + float(get_meta("chao"))
			else: position.y = move_toward(position.y, p.y, dt * 0.8)
			rotation.y = lerp_angle(rotation.y, atan2(-dl.x, -dl.z), minf(1.0, dt * 6.0))
			fase += dt * vel * 4.4 / maxf(0.8, d.altura * 0.55 + 0.1 * vel)
	else:
		vel = move_toward(vel, 0.0, dt * 4.0)
		if giro_alvo != null:
			rotation.y = lerp_angle(rotation.y, giro_alvo, minf(1.0, dt * 3.0))
	var cam := get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(global_position) if cam else 0.0
	if dist > 22.0 and _tick % 3 != 0 and vel < 0.05:
		return
	if dist > 90.0:
		return
	# olhos
	_pisca -= dt
	var fe := 0.0
	if _pisca < 0.14: fe = 1.0 - absf(_pisca - 0.07) / 0.07
	if _pisca <= 0.0: _pisca = randf_range(1.6, 5.2) * (0.6 if medo > 0.5 else 1.0)
	if pose == "dorme": fe = 1.0
	fecha = maxf(fe, 0.0)
	_tsac -= dt
	if _tsac <= 0.0:
		_tsac = randf_range(0.4, 2.2)
		_sac = Vector2(randf_range(-0.10, 0.10), randf_range(-0.05, 0.05)) if pose != "dorme" else Vector2.ZERO
	# cabeca
	var alvo := Vector2(sin(_t * 0.31 + fase0) * 0.16, sin(_t * 0.23 + fase0) * 0.05)
	match pose:
		"dorme": alvo = Vector2(0.35 * signf(sin(fase0)), -0.42)
		"le": alvo = Vector2(sin(_t * 0.5 + fase0) * 0.06, -0.42)
		"impacto": alvo = Vector2(0, -0.5)
		"bandeja", "serve": alvo = Vector2(0.0, -0.05)
	if olhar != null and pose != "dorme":
		var pt: Vector3 = olhar if olhar is Vector3 else (olhar.global_position + (Vector3.UP * 1.5 if not (olhar is Camera3D) else Vector3.ZERO))
		var l := to_local(pt) - to_local(cabeca())
		var yaw := atan2(-l.x, -l.z)
		if absf(yaw) < 1.9:
			alvo = alvo.lerp(Vector2(clampf(yaw, -1.25, 1.25), clampf(atan2(l.y, Vector2(l.x, l.z).length()), -0.6, 0.55)), 0.95)
	_cab = _cab.lerp(alvo, minf(1.0, dt * (3.2 + medo * 2.0)))
	# boca
	var fala := _t < fala_ate
	var b := 0.0
	if fala:
		b = clampf(0.18 + 0.36 * sin(_t * 13.0) + 0.30 * sin(_t * 7.7 + 1.0) + 0.2 * sin(_t * 21.0), 0.0, 1.0)
	elif medo > 0.6: b = 0.16 * medo
	elif pose == "dorme": b = 0.10
	boca = lerpf(boca, b, minf(1.0, dt * 16.0))
	_pose_base()
	var k := minf(1.0, dt * (4.0 if vel < 0.05 else 12.0))
	for q in _alvos:
		_mist[q] = (_mist.get(q, _alvos[q]) as Vector3).lerp(_alvos[q], k)
	_curva = lerpf(_curva, _curva_a, k)
	_tronco = _tronco.lerp(_tronco_a, minf(1.0, dt * 4.0))
	if not sentado:
		esq.position.y = absf(sin(fase)) * 0.025 * clampf(vel, 0.0, 1.6) - 0.02 * clampf(vel, 0.0, 1.0)
	_expressao()
	_aplica(dt)