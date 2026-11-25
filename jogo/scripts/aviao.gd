class_name Aviao
extends Node3D
## Abertura: voo noturno, lanche, pane, turbulencia e queda.
## Antes dos acontecimentos (pre) da para conversar, ler, acender a luz e escolher o lanche.

signal caiu(protegido: bool)

const ZI := -3.2          # onde a cabine comeca
const LUZ := 0.85

var cam: Camera3D
var serv := {}
var disco: MeshInstance3D
var leitura: Array = []
var calha: StandardMaterial3D
var casco: Node3D            # balanca com a turbulencia (cabine + jogador + asa)
var env: Environment
var lua: DirectionalLight3D
var chao: MeshInstance3D
var m_chao: ShaderMaterial
var m_ceu: ShaderMaterial
var asa := {}
var t := 0.0
var rodando := false
var yaw := 0.0
var pitch := 0.0
var turb := 0.0
var turb_alvo := 0.0
var mergulho := 0.0
var rolagem := 0.0
var vel := 88.0
var altura := 430.0
var luzes: Array = []
var luz_em: OmniLight3D
var luz_fogo: OmniLight3D
var mascaras: Array = []
var nuvens: Array = []
var orbe: Node3D
var olhos_janela: Node3D
var aviso_cinto: MeshInstance3D
var cinto := false
var protegendo := 0.0
var tempo_prot := 0.0
var tempo_prot_max := 0.0
var _d := Vector2.ZERO
var _feito := {}
var _passag: Array = []
var _fagulhas: GPUParticles3D
var _soltos: Array = []
var _apag := 0.0
var _estrobo := 0.0
var dica := ""
var acao_dica: Callable
var pre := true
var tp := 0.0                 # relogio da parte calma
var ta := 0.0                 # relogio das animacoes
var gente := {}
var com: Gente
var carrinho: Node3D
var bandeja: Node3D
var prato: Node3D
var luz_minha: SpotLight3D
var mordidas := 0
var lanche := ""
var alvos: Array = []         # {pos: Callable, txt, acao, vale: Callable}
var _fala_viz := 0
var _fase_com := 0
var _t_fim := -1.0
var luzes_rebatidas: Array = []
var _tp_alvo := -1.0


func construir() -> void:
	env = Environment.new()
	m_ceu = ShaderMaterial.new()
	m_ceu.shader = load("res://shaders/ceu.gdshader")
	var dl := Vector3(0.86, 0.42, -0.30).normalized()
	m_ceu.set_shader_parameter("lua", dl)
	m_ceu.set_shader_parameter("raio", 0.036)
	m_ceu.set_shader_parameter("nuvens", 0.2)
	var sky := Sky.new()
	sky.sky_material = m_ceu
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.58)
	env.ambient_light_energy = 0.11
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.5
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.19)
	env.fog_light_energy = 0.35
	env.fog_density = 0.00052
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.042
	env.volumetric_fog_albedo = Color(0.8, 0.85, 0.95)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 9.0
	env.volumetric_fog_detail_spread = 1.2
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	lua = DirectionalLight3D.new()
	lua.light_color = Color(0.64, 0.76, 1.0)
	lua.light_energy = 1.15
	lua.light_volumetric_fog_energy = 2.6
	lua.light_angular_distance = 0.4
	lua.shadow_enabled = true
	lua.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	lua.directional_shadow_max_distance = 7.5
	lua.shadow_blur = 2.2
	lua.directional_shadow_split_1 = 0.4
	lua.shadow_bias = 0.02
	lua.shadow_normal_bias = 0.8
	add_child(lua)
	lua.look_at_from_position(dl * 50.0, Vector3.ZERO)

	chao = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5200, 5200)
	pm.subdivide_width = 260
	pm.subdivide_depth = 260
	chao.mesh = pm
	m_chao = ShaderMaterial.new()
	m_chao.shader = load("res://shaders/voo_chao.gdshader")
	chao.material_override = m_chao
	chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chao.extra_cull_margin = 400
	add_child(chao)

	casco = Node3D.new()
	add_child(casco)
	Aeronave.casco(casco, 8, ZI, Callable(), 0.0, true)
	Aeronave.piso(casco, 6.4, ZI)
	Aeronave.fileiras(casco, 7, ZI, [[6, 0], [6, 1]])
	serv = Aeronave.servico(casco, 7, ZI)
	Aeronave.cockpit(casco, ZI)
	asa = Aeronave.asa(casco, 1.0)
	disco = Aeronave.disco_helice(casco, asa.helice.position + Vector3(0, 0, -0.05))
	var a2 := Node3D.new()
	casco.add_child(a2)
	Aeronave.asa(a2, -1.0)
	# divisoria da frente com vao para o cockpit, e parede de tras
	var fdiv := Aeronave.m_forro(Color(0.40, 0.375, 0.33), 0.45)
	var pr := Malha.new()
	pr.cx(Vector3(-0.83, 0.05, ZI), Vector3(0.72, 1.9, 0.05))
	pr.cx(Vector3(0.62, 0.05, ZI), Vector3(1.14, 1.9, 0.05))
	pr.cx(Vector3(-0.22, 1.02, ZI), Vector3(0.60, 0.34, 0.05))
	pr.cx(Vector3(0, 0.05, ZI + 6.4), Vector3(2.3, 2.3, 0.05))
	pr.no(fdiv, casco)
	var fr := Malha.new()
	for x in [-0.475, 0.045]:
		fr.cx(Vector3(x, 0.05, ZI + 0.02), Vector3(0.05, 1.62, 0.07))
	fr.cx(Vector3(-0.215, 0.86, ZI + 0.02), Vector3(0.57, 0.05, 0.07))
	fr.no(Mat.liso(Color(0.25, 0.25, 0.26), 0.4, 0.6), casco)
	var ct := Malha.new()
	for i in 5:
		var x := -0.45 + i * 0.045
		ct.tubo([Vector3(x, 0.83, ZI + 0.05), Vector3(x - 0.004, 0.0, ZI + 0.055 + 0.018 * (i % 2)), Vector3(x, -0.70, ZI + 0.05 + 0.02 * (i % 2))], [0.026, 0.030, 0.034], 8, 1.0, 1.0)
	ct.no(Aeronave.m_forro(Color(0.13, 0.05, 0.05), 0.2, 0.0, 1.0), casco)
	# placas de saida e proibido fumar
	var ex := MeshInstance3D.new()
	var exm := QuadMesh.new()
	exm.size = Vector2(0.26, 0.09)
	ex.mesh = exm
	ex.position = Vector3(-0.215, 0.95, ZI + 0.04)
	ex.material_override = Mat.placa("placa_saida.png", 1.2)
	casco.add_child(ex)
	# cockpit: painel aceso e dois pilotos
	var pnl := Malha.new()
	pnl.cx(Vector3(0, -0.12, ZI - 1.18), Vector3(1.7, 0.42, 0.06), Vector3(-0.25, 0, 0))
	pnl.no(Mat.liso(Color(0.03, 0.03, 0.035), 0.6), casco)
	var rngp := RandomNumberGenerator.new()
	rngp.seed = 40
	for grupo in [[Color(0.55, 0.95, 0.60), 16, 1.6], [Color(1.0, 0.55, 0.20), 9, 1.8], [Color(1.0, 0.12, 0.08), 4, 2.0]]:
		var lp := Malha.new()
		for i in grupo[1]:
			lp.cx(Vector3(rngp.randf_range(-0.75, 0.75), rngp.randf_range(-0.28, 0.06), ZI - 1.125), Vector3(0.03, 0.022, 0.01))
		lp.no(Mat.liso(Color.BLACK, 0.5, 0, grupo[0], grupo[2]), casco, false)
	var lpn := OmniLight3D.new()
	lpn.light_color = Color(0.55, 0.85, 0.60)
	lpn.light_energy = 0.28
	lpn.omni_range = 1.6
	lpn.position = Vector3(0, 0.1, ZI - 0.85)
	casco.add_child(lpn)
	# gente: [fileira, banco, quem, pose]
	var rng := RandomNumberGenerator.new()
	rng.seed = 609
	for q in [[0, 0, "p03", "sentado"], [0, 2, "p08", "dorme"], [1, 1, "p05", "le"], [1, 2, "p01", "nervoso"], [2, 0, "p02", "le"], [2, 1, "p07", "conversa"], [2, 2, "p04", "dorme"], [3, 0, "p06", "dorme"], [3, 1, "viz", "sentado"], [4, 0, "p08", "sentado"], [5, 1, "p05", "dorme"], [-1, 0, "pil", "sentado"], [-1, 1, "p01", "sentado"]]:
		var pp := Vector3(Aeronave.BANCOS[q[1]], Aeronave.PISO + 0.52, ZI + (q[0] + 0.5) * 0.8 - 0.02) if q[0] >= 0 else Vector3([-0.42, 0.42][q[1]], -0.30, ZI - 0.60)
		var h := Gente.criar(casco, q[2], pp, rng.randf_range(-0.08, 0.08), true)
		h.pose = q[3]
		h.set_meta("pose0", q[3])
		_passag.append(h)
		if not gente.has(q[2]): gente[q[2]] = h
		if q[3] == "le":
			var rv := Malha.new()
			for sx in [-1.0, 1.0]: rv.caixa(Transform3D(Basis.from_euler(Vector3(-0.95, 0.22 * sx, 0)), Vector3(0.085 * sx, 0.30, -0.36)), Vector3(0.17, 0.004, 0.24), 1.0)
			rv.no(Mat.liso(Color(0.62, 0.58, 0.50), 0.4), h)
	gente.p07.olhar = gente.p04
	gente.p03.olhar = Vector3(-4, 0.2, -3.0)
	# o seu corpo
	var eu := Gente.criar(casco, "p06", Vector3(Aeronave.BANCOS[2], Aeronave.PISO + 0.48, ZI + 3.5 * 0.8 + 0.07), 0.0, true)
	eu.rosto.visible = false
	var some := StandardMaterial3D.new()
	some.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	some.alpha_scissor_threshold = 0.9
	some.albedo_color = Color(0, 0, 0, 0)
	for i in eu.d.sup_corpo.size():
		if eu.d.sup_corpo[i] in ["cabelo", "olhos"]: eu.corpo.set_surface_override_material(i, some)
	eu.corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mm in eu.m_tec: mm.set_shader_parameter("corta", 1.27)
	eu.m_pele[0].set_shader_parameter("corta", 1.27)
	gente["eu"] = eu
	# comissaria e carrinho
	com = Gente.criar(casco, "com", Vector3(CORR, Aeronave.PISO, ZI + 0.25), PI, false)
	com.visible = false
	_faz_carrinho()
	_faz_bandeja()
	# luz da cabine: fraca, de madrugada
	for i in 3:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.80, 0.54)
		l.light_energy = LUZ
		l.omni_range = 2.6
		l.position = Vector3(-0.1, 0.82, -2.3 + i * 2.2)
		l.light_volumetric_fog_energy = 0.35
		l.shadow_enabled = true
		casco.add_child(l)
		luzes.append(l)
	# luzes de leitura acesas em algumas poltronas
	for q in [[1, 1.0, 0.70], [4, -1.0, -0.68], [5, 1.0, 0.23]]:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.86, 0.62)
		s.light_energy = 2.6
		s.spot_range = 2.2
		s.spot_angle = 20
		s.light_volumetric_fog_energy = 1.4
		s.shadow_enabled = true
		s.position = Vector3(q[2] * 0.92, 0.80, ZI + (q[0] + 0.5) * 0.8 - 0.1)
		s.rotation.x = -PI * 0.5
		casco.add_child(s)
		leitura.append(s)
	for k in serv.lampadas.size():
		if k in [2, 4, 14, 16]:
			serv.lampadas[k][0].material_override.emission_energy_multiplier = 6.0
	luz_minha = SpotLight3D.new()
	luz_minha.light_color = Color(1.0, 0.86, 0.62)
	luz_minha.light_energy = 1.8
	luz_minha.spot_range = 2.2
	luz_minha.spot_angle = 22
	luz_minha.light_volumetric_fog_energy = 1.2
	luz_minha.shadow_enabled = true
	luz_minha.position = Vector3(0.66, 0.84, ZI + 3.5 * 0.8 - 0.22)
	luz_minha.rotation.x = -PI * 0.5
	casco.add_child(luz_minha)
	var reb := OmniLight3D.new()       # luz rebatida no encosto da frente
	reb.light_color = Color(1.0, 0.82, 0.60)
	reb.light_energy = 0.30
	reb.omni_range = 1.3
	reb.position = Vector3(0.30, 0.40, -0.80)
	casco.add_child(reb)
	luzes_rebatidas = [reb]
	alvos = [
		{"pos": func(): return gente.viz.cabeca(), "txt": "Conversar", "acao": _conversa_viz, "vale": func(): return tp > 24.0 and _fala_viz < 3 and _fase_com != 2},
		{"pos": func(): return casco.to_global(Vector3(0.66, 0.02, -0.80)), "txt": "Ler a revista de bordo", "acao": _le_revista, "vale": func(): return tp > 18.0 and lanche == ""},
		{"pos": func(): return casco.to_global(Vector3(0.66, 0.80, -0.62)), "txt": "Luz de leitura", "acao": func():
			luz_minha.light_energy = 0.0 if luz_minha.light_energy > 0.1 else 2.4
			Som.toca("radio_clique", -10, 1.5), "vale": func(): return true},
		{"pos": func(): return casco.to_global(Vector3(0.64, -0.10, -0.74)), "txt": "Comer", "acao": _morde, "vale": func(): return lanche != "" and mordidas < 4 and _fase_com >= 3},
	]
	calha = serv.calha.mesh.surface_get_material(0)
	luz_em = OmniLight3D.new()
	luz_em.light_color = Color(1.0, 0.06, 0.03)
	luz_em.light_energy = 0.0
	luz_em.omni_range = 5.5
	luz_em.shadow_enabled = true
	luz_em.position = Vector3(-0.2, 0.75, -2.5)
	casco.add_child(luz_em)
	luz_fogo = OmniLight3D.new()
	luz_fogo.light_color = Color(1.0, 0.45, 0.12)
	luz_fogo.light_energy = 0.0
	luz_fogo.omni_range = 14.0
	luz_fogo.shadow_enabled = true
	luz_fogo.position = asa.motor + Vector3(0, 0.75, 0)
	luz_fogo.light_volumetric_fog_energy = 1.2
	casco.add_child(luz_fogo)
	# luz de navegacao
	var nv := OmniLight3D.new()
	nv.light_color = Color(0.1, 1.0, 0.3)
	nv.light_energy = 1.0
	nv.omni_range = 3
	nv.position = asa.ponta
	casco.add_child(nv)
	var nb := Malha.new()
	nb.cx(asa.ponta, Vector3(0.10, 0.07, 0.24))
	nb.no(Mat.liso(Color.BLACK, 0.4, 0, Color(0.1, 1.0, 0.3), 5.0), casco)
	# mascaras (guardadas)
	for i in 7:
		for sx in [-1.0, 1.0]:
			var n := Node3D.new()
			n.position = Vector3(0.56 * sx, 0.84, ZI + (i + 0.5) * 0.8 - 0.06)
			n.visible = false
			var mm := Malha.new()
			mm.tubo([Vector3.ZERO, Vector3(0.012, -0.16, 0.01), Vector3(-0.006, -0.32, 0.004), Vector3(0, -0.44, 0)], [0.0045, 0.0045, 0.0045, 0.0045], 6)
			mm.no(Mat.liso(Color(0.62, 0.62, 0.58), 0.4), n)
			var mk := Malha.new()
			mk.tubo([Vector3(0, -0.44, 0), Vector3(0, -0.452, 0), Vector3(0, -0.49, 0), Vector3(0, -0.515, 0)], [0.012, 0.034, 0.042, 0.050], 18)
			mk.no(Mat.liso(Color(0.72, 0.50, 0.05), 0.42, 0, Color.BLACK, 0, true), n)
			var bg := Malha.new()
			bg.tubo([Vector3(0, -0.30, 0.02), Vector3(0.01, -0.36, 0.03), Vector3(0, -0.43, 0.01)], [0.006, 0.032, 0.008], 10)
			bg.no(Mat.liso(Color(0.66, 0.66, 0.62, 0.6), 0.2), n)
			casco.add_child(n)
			mascaras.append(n)
	# objetos que voam
	for i in 12:
		var mi := Malha.new()
		mi.cx(Vector3.ZERO, Vector3(rng.randf_range(0.08, 0.4), rng.randf_range(0.04, 0.2), rng.randf_range(0.1, 0.3)))
		var no := mi.no(Mat.liso([Color(0.15, 0.07, 0.05), Color(0.05, 0.07, 0.13), Color(0.6, 0.58, 0.5)][i % 3], 0.6), casco)
		no.visible = false
		_soltos.append({"n": no, "p": Vector3(rng.randf_range(-0.6, 0.6), 0.7, rng.randf_range(-3, 2.5)), "v": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-4, -1)), "r": Vector3(rng.randf(), rng.randf(), rng.randf()) * 6.0})
	# fogo do motor (apagado) e fagulhas na cabine
	var ff := Node3D.new()
	ff.name = "Fogo"
	ff.visible = false
	casco.add_child(ff)
	var fp := GPUParticles3D.new()
	fp.amount = 90
	fp.lifetime = 0.55
	fp.local_coords = true
	var fpm := ParticleProcessMaterial.new()
	fpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fpm.emission_sphere_radius = 0.34
	fpm.direction = Vector3(0, 0.08, 1)
	fpm.spread = 9
	fpm.initial_velocity_min = 9.0
	fpm.initial_velocity_max = 17.0
	fpm.gravity = Vector3.ZERO
	fpm.scale_min = 0.7
	fpm.scale_max = 1.7
	fpm.angle_min = -180
	fpm.angle_max = 180
	fpm.color_ramp = Fx._rampa([[0, Color(1, 0.8, 0.4, 0.9)], [0.35, Color(1, 0.35, 0.07, 0.7)], [1, Color(0.2, 0.04, 0.02, 0)]])
	fp.process_material = fpm
	var fq := QuadMesh.new()
	fq.material = Mat.sprite(Color(1, 1, 1), 3.0, true)
	fp.draw_pass_1 = fq
	fp.position = asa.motor + Vector3(0, 0.1, 0.2)
	ff.add_child(fp)
	var fm := Fx.fumaca(ff, asa.motor + Vector3(0, 0.3, 3.0), 1.5, 40)
	(fm.process_material as ParticleProcessMaterial).direction = Vector3(0, 0.1, 1)
	(fm.process_material as ParticleProcessMaterial).initial_velocity_min = 14
	(fm.process_material as ParticleProcessMaterial).initial_velocity_max = 20
	fm.lifetime = 1.2
	_fagulhas = GPUParticles3D.new()
	_fagulhas.amount = 60
	_fagulhas.lifetime = 0.8
	_fagulhas.one_shot = true
	_fagulhas.emitting = false
	_fagulhas.explosiveness = 0.9
	var sp := ParticleProcessMaterial.new()
	sp.direction = Vector3.DOWN
	sp.spread = 60
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 4.0
	sp.scale_min = 0.012
	sp.scale_max = 0.03
	sp.color_ramp = Fx._rampa([[0, Color(1, 0.9, 0.6, 1)], [1, Color(1, 0.3, 0.05, 0)]])
	_fagulhas.process_material = sp
	var sq := QuadMesh.new()
	sq.material = Mat.sprite(Color(1, 1, 1), 8.0, true)
	_fagulhas.draw_pass_1 = sq
	_fagulhas.position = Vector3(-0.3, 0.95, -1.6)
	casco.add_child(_fagulhas)
	# nuvens que passam
	for i in 26:
		var n := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(90, 60)
		n.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = Mat.tex("fumaca.png")
		m.albedo_color = Color(0.30, 0.36, 0.46, 0.32)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 12.0
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 6.0
		m.distance_fade_max_distance = 40.0
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = Vector3((1.0 if rng.randf() < 0.75 else -1.0) * rng.randf_range(40, 260), rng.randf_range(-90, 30), rng.randf_range(-600, 300))
		n.scale = Vector3.ONE * rng.randf_range(0.6, 2.2)
		add_child(n)
		nuvens.append(n)
	# a luz que acompanha
	orbe = Node3D.new()
	var om := MeshInstance3D.new()
	var os := SphereMesh.new()
	os.radius = 0.22
	os.height = 0.44
	om.mesh = os
	om.material_override = Mat.liso(Color.BLACK, 0.5, 0, Color(1.0, 0.60, 0.22), 10.0)
	orbe.add_child(om)
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.55, 0.2)
	ol.light_energy = 1.4
	ol.omni_range = 9
	orbe.add_child(ol)
	orbe.visible = false
	casco.add_child(orbe)
	# o rosto na asa
	olhos_janela = Node3D.new()
	var cm := MeshInstance3D.new()
	cm.mesh = load("res://dados/criatura.res")
	var cs := ShaderMaterial.new()
	cs.shader = load("res://shaders/criatura.gdshader")
	cm.material_override = cs
	olhos_janela.add_child(cm)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.02
		es.height = 0.04
		e.mesh = es
		e.material_override = Mat.liso(Color.BLACK, 0.2, 0, Color(0.85, 0.95, 0.8), 6.0)
		e.position = Vector3(0.060 * sx, 2.026, -1.168)
		olhos_janela.add_child(e)
	olhos_janela.position = Vector3(2.15, -1.02, -0.75)
	olhos_janela.rotation = Vector3(0.0, 1.15, 0)
	olhos_janela.visible = false
	casco.add_child(olhos_janela)

	cam = Camera3D.new()
	cam.fov = 70
	cam.near = 0.04
	cam.far = 3500
	cam.environment = env
	casco.add_child(cam)
	cam.position = Vector3(0.66, OLHO, -0.36)
	yaw = -0.35


func iniciar() -> void:
	rodando = true
	t = 0.0
	cam.current = true
	Som.camada("av_cabine", 0.75, 0.4)
	Jogo.hud.escurecer(0.0, 4.0)


func _unhandled_input(e: InputEvent) -> void:
	if not rodando:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = clampf(yaw - e.relative.x * 0.0020 * Jogo.sens, -1.95, 1.95)
		pitch = clampf(pitch - e.relative.y * 0.0020 * Jogo.sens, -0.95, 0.75)
	if e.is_action_pressed("usar") and dica != "":
		if acao_dica.is_valid(): acao_dica.call()
		elif not cinto and t > 39.0: apertar_cinto()


func apertar_cinto() -> void:
	cinto = true
	dica = ""
	Som.toca("chave", -6, 0.8)


const CORR := -0.215          # meio do corredor
const OLHO := 0.50


func _faz_carrinho() -> void:
	carrinho = Node3D.new()
	casco.add_child(carrinho)
	var m := Malha.new()
	m.cx(Vector3(0, 0.50, 0), Vector3(0.27, 0.86, 0.42))
	m.cx(Vector3(0, 0.95, 0), Vector3(0.29, 0.03, 0.44))
	m.no(Mat.liso(Color(0.42, 0.43, 0.45), 0.35, 0.7), carrinho)
	var f := Malha.new()
	f.cx(Vector3(0, 0.52, -0.212), Vector3(0.22, 0.70, 0.006))
	f.no(Mat.liso(Color(0.05, 0.10, 0.20), 0.4), carrinho)
	for k in 4:
		var l := Malha.new()
		var o := Vector3(-0.09 + 0.06 * k, 0.965, 0.12 - 0.02 * (k % 2))
		l.tubo([o, o + Vector3(0, 0.12, 0)], [0.026, 0.026], 16, 1, 1, Color(0, 0, 0.5), true)
		l.no(Mat.liso([Color(0.5, 0.05, 0.04), Color(0.06, 0.25, 0.10), Color(0.6, 0.5, 0.1), Color(0.7, 0.7, 0.72)][k], 0.3, 0.5), carrinho)
	for k in 2:
		var p := Node3D.new()
		p.position = Vector3(-0.06 + 0.12 * k, 0.968, -0.08)
		p.scale = Vector3.ONE * 0.85
		carrinho.add_child(p)
		Itens.lanche(p, "sanduiche" if k == 0 else "biscoito")
	carrinho.visible = false


## mesinha das costas da poltrona da frente
func _faz_bandeja() -> void:
	bandeja = Node3D.new()
	casco.add_child(bandeja)
	bandeja.position = Vector3(0.68, -0.145, -0.62)
	var m := Malha.new()
	m.cx(Vector3(0, 0, -0.06), Vector3(0.40, 0.018, 0.26))
	m.no(Aeronave.m_forro(Color(0.44, 0.42, 0.38), 0.35, 0.0), bandeja)
	var b := Malha.new()
	for sx in [-1.0, 1.0]: b.viga(Vector3(0.17 * sx, -0.01, 0.0), Vector3(0.17 * sx, 0.02, -0.28), 0.014)
	b.no(Mat.liso(Color(0.3, 0.3, 0.31), 0.4, 0.8), bandeja)
	prato = Node3D.new()
	bandeja.add_child(prato)
	prato.position = Vector3(-0.02, 0.012, -0.05)
	bandeja.visible = false


func _conversa_viz() -> void:
	var v: Gente = gente.viz
	if t_fala > 0.0: return
	_fala_viz += 1
	v.olhar = cam
	v.pose = "conversa"
	match _fala_viz:
		1:
			v.dizer("v_viz2", "passageira ao lado", "Minha avó nasceu aí embaixo. Dizia que à noite essas montanhas chamam a gente pelo nome. Bobagem de gente velha.", 8.0)
			t_fala = 8.2
		2:
			v.dizer("v_viz3", "passageira ao lado", "Vou ver minha neta nascer. Levo um casaquinho de lã na bolsa.", 5.0)
			t_fala = 5.2
		3:
			v.dizer("v_viz4", "passageira ao lado", "Você dorme em avião? Eu nunca consegui.", 3.4)
			t_fala = 3.6

var t_fala := 0.0


func _le_revista() -> void:
	if Jogo.hud.lendo: return
	Jogo.hud.abrir_nota("Revista de bordo — janeiro de 1987", "OS MONTES MAIS VELHOS DO MUNDO\n\nOs Apalaches já eram antigos quando os primeiros dinossauros apareceram. Debaixo da neve há vales que ninguém mapeou a pé.\n\nOs moradores têm uma regra curiosa: se ouvir alguém chamar o seu nome na mata, depois que escurece, não responda.\n\n\"Pode ser que não seja alguém\", explica um guia, rindo.\n\nO guia não quis ser fotografado.")


func _morde() -> void:
	mordidas += 1
	Som.toca("comer", -5, randf_range(0.9, 1.1))
	prato.scale = Vector3.ONE * (1.0 - mordidas * 0.2)
	if mordidas >= 4:
		prato.visible = false
		Jogo.flags["comeu"] = true


func _pre(dt: float) -> void:
	tp += dt
	t_fala -= dt
	if _ump("cap", 1.5): Jogo.hud.capitulo("VOO 609", "24 de janeiro de 1987  —  1h52 da madrugada", 3.0)
	if _ump("ch1", 5.5): Som.toca("av_chime", -8)
	if _ump("p1", 7.0):
		Som.toca("v_piloto1", -2, 1.0, "Voz")
		Jogo.falar("comandante", "Boa noite, senhores passageiros. Aqui é a comandante.", 4.0)
	if _ump("p1b", 11.2): Jogo.falar("comandante", "Estamos sobrevoando os montes Apalaches. Lua cheia do lado direito da aeronave. Pouso previsto em quarenta minutos.", 8.0)
	if _ump("viz", 20.5):
		gente.viz.olhar = cam
		gente.viz.sorriso = 0.6
		gente.viz.dizer("v_viz1", "passageira ao lado", "Primeira vez que voo à noite. A minha filha diz que a serra fica bonita com neve.", 5.5)
		t_fala = 5.6
	if _ump("vizj", 27.5): gente.viz.olhar = Vector3(6, -2, -2)
	if _ump("dica1", 27.0): Jogo.aviso.emit("Mouse olhar  ·  E interagir")
	# a comissaria vem servindo
	if _ump("com", 54.0):
		com.visible = true
		carrinho.visible = true
		com.pose = "bandeja"
		com.sorriso = 0.35
		com.ir([Vector3(CORR, Aeronave.PISO, ZI + 0.9)], 0.45, func(): _fase_com = 1)
		Som.em("carrinho", com.global_position, -4.0, 8, 1.0, "Mundo", 1.5)
	if _fase_com == 1 and _umpf("serve2", 2.0):
		com.pose = "serve"
		com.giro_alvo = -PI * 0.5
		com.dizer("v_com0", "comissária", "Sanduíche ou biscoito? Aqui está.", 2.6)
	if _fase_com == 1 and _umpf("vem", 5.5):
		com.pose = "bandeja"
		com.giro_alvo = null
		Som.em("carrinho", com.global_position, -4.0, 8, 1.0, "Mundo", 1.5)
		com.ir([Vector3(CORR, Aeronave.PISO, -0.98)], 0.5, func(): _chegou_com())
	if carrinho.visible:
		var fr := Vector3(0, 0, 1)
		carrinho.position = carrinho.position.lerp(Vector3(CORR, Aeronave.PISO + 0.02, minf(com.position.z + 0.60, 2.7)), minf(1.0, dt * 9.0)) if carrinho.position != Vector3.ZERO else Vector3(CORR, Aeronave.PISO + 0.02, com.position.z + 0.60)
	if _t_fim > 0.0 and tp > _t_fim:
		pre = false
		t = 22.0
		com.visible = false
		carrinho.visible = false
		dica = ""
		acao_dica = Callable()
		return
	# alvo do olhar
	dica = ""
	acao_dica = Callable()
	if not Jogo.hud.lendo and _fase_com != 2:
		var melhor := 0.90
		for q in alvos:
			if not q.vale.call(): continue
			var d: Vector3 = (q.pos.call() as Vector3) - cam.global_position
			var k := (-cam.global_transform.basis.z).dot(d.normalized())
			if k > melhor:
				melhor = k
				dica = "[E] " + q.txt
				acao_dica = q.acao


func _ump(id: String, em: float) -> bool:
	if tp >= em and not _feito.has("pre" + id):
		_feito["pre" + id] = true
		return true
	return false

var _tf1 := -1.0


## uma vez, x segundos depois de a comissaria parar
func _umpf(id: String, depois: float) -> bool:
	if _tf1 < 0.0: _tf1 = tp
	if tp - _tf1 >= depois and not _feito.has("pre" + id):
		_feito["pre" + id] = true
		return true
	return false


func _chegou_com() -> void:
	_fase_com = 2
	com.pose = "pe"
	com.giro_alvo = -PI * 0.5 - 0.25
	com.olhar = cam
	gente.viz.olhar = com
	gente.viz.pose = "sentado"
	Jogo.hud._dica.text = ""
	await get_tree().create_timer(0.9, false).timeout
	com.dizer("v_com1", "comissária", "Boa noite. Hoje temos sanduíche de queijo ou biscoito com chocolate. O que você prefere?", 5.6)
	await get_tree().create_timer(5.0 if not Teste.ativo else 0.5, false).timeout
	var r: int = await Jogo.hud.escolha("O que você vai querer?", ["Sanduíche de queijo", "Biscoito com chocolate"])
	if not is_inside_tree(): return
	lanche = "sanduiche" if r == 0 else "biscoito"
	Jogo.flags["lanche"] = lanche
	com.pose = "serve"
	com.sorriso = 0.8
	com.dizer("v_com2" if r == 0 else "v_com3", "comissária", "Sanduíche. Ótima escolha. Bom apetite." if r == 0 else "Os biscoitos são os meus preferidos. Bom apetite.", 3.4)
	await get_tree().create_timer(0.9, false).timeout
	bandeja.visible = true
	prato.visible = true
	Itens.lanche(prato, lanche)
	Som.toca("talher", -8)
	await get_tree().create_timer(2.6, false).timeout
	_fase_com = 3
	com.pose = "bandeja"
	com.olhar = null
	com.sorriso = 0.2
	com.giro_alvo = null
	Som.em("carrinho", com.global_position, -4.0, 8, 1.0, "Mundo", 1.5)
	com.ir([Vector3(CORR, Aeronave.PISO, 2.75)], 0.62, func(): com.visible = false)
	gente.viz.olhar = cam
	gente.viz.dizer("v_viz5", "passageira ao lado", "Eu peguei o biscoito. Se enjoar, a gente troca.", 3.6)
	t_fala = 4.0
	_t_fim = tp + (17.0 if not Teste.ativo else 3.0)


func _uma(id: String, em: float) -> bool:
	if t >= em and not _feito.has(id):
		_feito[id] = true
		return true
	return false


func _process(dt: float) -> void:
	if not rodando:
		return
	ta += dt
	if pre:
		_pre(dt)
	else:
		t += dt
		acao_dica = Callable()
		_roteiro(dt)
	# mundo passa
	_d.y -= vel * dt
	m_chao.set_shader_parameter("desloc", _d)
	chao.position.y = -altura
	for n in nuvens:
		n.position.z += vel * dt * 0.9
		if n.position.z > 320.0:
			n.position.z -= 920.0
	for k in ["helice"]:
		asa[k].rotation.z += dt * (46.0 if t < 53.0 else maxf(0.0, 46.0 - (t - 53.0) * 9.0))
	# turbulencia
	turb = lerpf(turb, turb_alvo, minf(1.0, dt * 1.6))
	var a := ta
	var sx := sin(a * 1.7) * 0.35 + sin(a * 7.3) * 0.3 + sin(a * 17.0) * 0.18 + sin(a * 31.0) * 0.12
	var sy := sin(a * 2.3 + 1.0) * 0.35 + sin(a * 9.1) * 0.3 + sin(a * 21.0) * 0.2 + sin(a * 37.0) * 0.14
	var sz := sin(a * 1.1 + 2.0) * 0.45 + sin(a * 5.7) * 0.25 + sin(a * 13.0) * 0.16
	casco.position = Vector3(sx * 0.10, sy * 0.22, sz * 0.04) * turb
	casco.rotation = Vector3(-mergulho + sy * 0.035 * turb, sx * 0.02 * turb, rolagem + sz * 0.075 * turb)
	protegendo = move_toward(protegendo, 1.0 if t > 72.0 and (Input.is_action_pressed("pular") or Teste.ativo) else 0.0, dt * 3.0)
	if t > 78.0:
		tempo_prot_max += dt
		tempo_prot += dt * protegendo
	var ch := Vector3(sin(a * 43.0), sin(a * 53.0), sin(a * 61.0)) * 0.012 * turb
	cam.position = Vector3(0.66, OLHO - 0.26 * protegendo, -0.36 - 0.18 * protegendo) + ch + Vector3(sx, sy, 0) * 0.018 * turb
	cam.rotation = Vector3(pitch - 0.75 * protegendo * (1.0 - absf(pitch) * 0.3) + ch.y * 2.2 + sin(ta * 0.9) * 0.004, yaw * (1.0 - 0.6 * protegendo) + ch.x * 2.0, ch.z * 2.4 - casco.rotation.z * 0.15)
	# luzes
	_apag -= dt
	var liga := 1.0
	if t > 46.0 and t < 53.0: liga = 1.0 if sin(t * 23.0) + sin(t * 37.0) > -0.8 else 0.15
	if t >= 53.0: liga = 0.0
	if t >= 53.0 and t < 58.0 and sin(t * 41.0) > 0.7: liga = 0.7
	for i in luzes.size():
		luzes[i].light_energy = LUZ * liga
	for s in leitura:
		s.light_energy = 2.6 * liga
	for r in luzes_rebatidas: r.light_energy = 0.30 * liga
	if t > 45.0: luz_minha.light_energy = 1.8 * liga
	calha.emission_energy_multiplier = 0.9 * liga
	for k in [2, 4, 14, 16]:
		if k < serv.lampadas.size():
			serv.lampadas[k][0].material_override.emission_energy_multiplier = 6.0 * liga
	if disco:
		disco.visible = t < 54.0
	if t > 53.5:
		luz_em.light_energy = 0.75 * (0.5 + 0.5 * sin(t * 5.2))
	if t > 53.0:
		luz_fogo.light_energy = 3.6 * (0.75 + 0.25 * sin(t * 23.0) + 0.15 * sin(t * 41.0))
	# estrobo da asa
	_estrobo -= dt
	if _estrobo <= 0.0: _estrobo = 1.15
	# mascaras balancam
	for i in mascaras.size():
		var m: Node3D = mascaras[i]
		if m.visible:
			m.rotation = Vector3(sin(t * 4.0 + i) * 0.25 * turb + mergulho, 0, sin(t * 3.3 + i * 2.0) * 0.3 * turb)
	for h in _passag:
		h.agita = turb * 0.55
		if pre: continue
		if t > 72.5: h.pose = "impacto"
		elif t > 43.0: h.pose = "agarra"
		elif t > 26.0 and h.pose in ["le", "conversa", "sentado", "nervoso"]: h.olhar = orbe.global_position if orbe.visible else null
		if t > 35.0 and h.pose == "dorme": h.pose = "sentado"
		h.medo = move_toward(h.medo, 1.0 if t > 52.0 else (0.6 if t > 38.0 else 0.0), dt * 0.6)
		h.sorriso = 0.0
	gente.eu.agita = turb * 0.4
	if t > 72.5 and protegendo > 0.3: gente.eu.pose = "impacto"
	elif t > 44.0: gente.eu.pose = "agarra"
	if bandeja.visible and t > 46.0:
		prato.visible = false
		bandeja.visible = false
	if t > 66.0:
		for s in _soltos:
			s.n.visible = true
			s.p += s.v * dt * (0.4 + turb * 0.5)
			if s.p.z < -3.0: s.p = Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.7), randf_range(0.8, 3.0))
			if absf(s.p.x) > 0.85: s.v.x *= -1.0
			if s.p.y > 0.85 or s.p.y < -0.5: s.v.y *= -1.0
			s.n.position = s.p
			s.n.rotation += s.r * dt
	# orbe
	if orbe.visible:
		orbe.position = Vector3(lerpf(26.0, 7.5, smoothstep(24.0, 50.0, t)), 1.2 + sin(t * 1.4) * 0.6, -4.0 + sin(t * 0.7) * 2.0)
	if Jogo.hud:
		Jogo.hud._dica.text = dica
		Jogo.hud.tonto = maxf(0.0, turb - 1.6) * 0.16


func _roteiro(dt: float) -> void:
	if _uma("orbe", 24.0):
		orbe.visible = true
	if _uma("olhe", 27.0):
		gente.viz.dizer("v_viz6", "passageira ao lado", "Que luz é aquela?", 2.6)
		gente.viz.olhar = orbe.global_position
	if _uma("olhe2", 31.0): Jogo.falar("", "Uma luz acompanha o avião. Ela não pisca.", 3.6)
	if _uma("b1", 35.0):
		turb_alvo = 0.35
		Som.toca("batida_metal", -10, 0.6)
	if _uma("ch2", 37.0):
		Som.toca("av_chime", -6)
		for q in serv.avisos:
			var m: StandardMaterial3D = q.material_override
			m.emission_enabled = true
			m.emission_texture = Mat.tex("placa_cinto.png")
			m.emission_energy_multiplier = 2.0
	if _uma("p2", 38.4):
		Som.toca("v_piloto2", -2, 1.0, "Voz")
		Jogo.falar("comandante", "Senhores, apertem os cintos. Vamos atravessar uma área de turbulência.", 5.0)
	if _uma("dica", 40.0) and not cinto: dica = "[E] Apertar o cinto"
	if _uma("t2", 44.0):
		turb_alvo = 1.0
		Som.camada("av_pane", 0.22, 0.2)
		Som.toca("metal1", -8)
	if _uma("orbe2", 49.5): Jogo.falar("", "A luz está mais perto.", 2.5)
	if _uma("cintoauto", 51.0) and not cinto: apertar_cinto()
	if _uma("bum", 53.0):
		Som.toca("explosao", 3)
		Som.toca("batida_metal", 0)
		orbe.visible = false
		Jogo.hud.branco = 0.55
		turb = 3.0
		turb_alvo = 1.7
		casco.get_node("Fogo").visible = true
		Som.camada("av_cabine", 0.25, 0.5)
		Som.camada("av_pane", 0.85, 1.5)
		_fagulhas.emitting = true
		create_tween().tween_property(self, "rolagem", -0.22, 3.0).set_trans(Tween.TRANS_SINE)
	if _uma("masc", 54.4):
		for m in mascaras: m.visible = true
		Som.toca("pegar", 0, 0.7)
		Som.camada("av_alarme", 0.34, 2.0)
	if _uma("p3", 56.5):
		Som.toca("v_piloto3", 0, 1.0, "Voz")
		Jogo.falar("comandante", "Torre, perdemos o motor direito. Repito, perdemos o motor direito.", 4.6)
	if _uma("p3b", 61.4): Jogo.falar("comandante", "Tem alguma coisa aqui fora. Tem uma luz aqui fora.", 4.0)
	if _uma("rosto", 64.2):
		olhos_janela.visible = true
		yaw = clampf(yaw, -1.95, 1.95)
		_fagulhas.restart()
	if _uma("rosto2", 64.2 + 0.85):
		olhos_janela.visible = false
		Som.toca("stinger3", -8)
	if _uma("merg", 66.0):
		Som.toca("av_queda", 0)
		turb_alvo = 2.2
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "mergulho", 0.40, 9.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "rolagem", 0.30, 8.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "altura", 205.0, 19.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "vel", 150.0, 14.0)
		Som.camada("av_pane", 0.5, 0.5)
	if _uma("prot", 72.0): dica = "[segure ESPAÇO] Proteger a cabeça"
	if _uma("p4", 74.5):
		Som.toca("v_piloto4", 2, 1.0, "Voz")
		Jogo.falar("comandante", "Posição de impacto! Posição de impacto!", 3.0)
	if _uma("c1", 77.0):
		Som.toca("v_comissaria", 2, 1.0, "Voz")
		Jogo.falar("comissária", "Abaixem a cabeça! Abaixem a cabeça!", 3.0)
	if _uma("arv", 81.2):
		turb = 3.4
		turb_alvo = 3.2
		dica = ""
		Som.toca("av_impacto", 4)
	for k in 5:
		if _uma("g%d" % k, 81.3 + k * 0.28):
			Som.varia("galho", 4, 4.0)
			turb = 4.0
	if _uma("fim", 82.75):
		Jogo.hud.branco = 1.0
		Jogo.hud.escurecer(1.0, 0.0)
		Som.abafado = 0.85
	if _uma("fim2", 85.6):
		rodando = false
		Som.silencio(1.5)
		dica = ""
		Jogo.hud._dica.text = ""
		caiu.emit(tempo_prot > tempo_prot_max * 0.45)
