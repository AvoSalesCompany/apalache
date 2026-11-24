class_name Aviao
extends Node3D
## Abertura: voo noturno, pane, turbulencia e queda.

signal caiu(protegido: bool)

var cam: Camera3D
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
	env.ambient_light_energy = 0.10
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
	env.fog_density = 0.00075
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(0.8, 0.85, 0.95)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 14.0
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
	lua.directional_shadow_max_distance = 26.0
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
	Aeronave.casco(casco, 15, -6.4)
	Aeronave.piso(casco, 12.0, -6.4)
	Aeronave.bagageiro(casco, 12.0, -6.4)
	Aeronave.fileiras(casco, 13, -5.4)
	asa = Aeronave.asa(casco, 1.0)
	var a2 := Node3D.new()
	casco.add_child(a2)
	Aeronave.asa(a2, -1.0)
	# parede da frente e de tras
	var pr := Malha.new()
	pr.cx(Vector3(-0.85, 0.1, -6.4), Vector3(1.3, 2.4, 0.08))
	pr.cx(Vector3(0.85, 0.1, -6.4), Vector3(1.3, 2.4, 0.08))
	pr.cx(Vector3(0, 1.15, -6.4), Vector3(0.6, 0.6, 0.08))
	pr.cx(Vector3(0, 0, 5.6), Vector3(2.9, 2.9, 0.08))
	pr.no(Mat.liso(Color(0.42, 0.40, 0.36), 0.7), casco)
	var ct := Malha.new()
	for i in 6:
		ct.tubo([Vector3(-0.22 + i * 0.09, 0.86, -6.33), Vector3(-0.23 + i * 0.092, -0.76, -6.33 + 0.02 * (i % 2))], [0.05, 0.06], 8)
	ct.no(Mat.pbr("fabric_pattern_07", 1.0, Color(0.16, 0.10, 0.10)), casco)
	# passageiros
	var cores := [[Color(0.24, 0.10, 0.09), Color(0.06, 0.06, 0.08), Color(0.05, 0.035, 0.02)], [Color(0.45, 0.43, 0.38), Color(0.10, 0.09, 0.07), Color(0.22, 0.20, 0.18)], [Color(0.10, 0.16, 0.26), Color(0.05, 0.06, 0.10), Color(0.10, 0.05, 0.02)], [Color(0.14, 0.20, 0.13), Color(0.12, 0.10, 0.08), Color(0.02, 0.016, 0.012)]]
	var peles := [Color(0.60, 0.42, 0.34), Color(0.34, 0.21, 0.15), Color(0.66, 0.49, 0.40), Color(0.45, 0.30, 0.22)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 609
	for q in [[0, 0], [0, 3], [1, 2], [2, 0], [2, 1], [3, 3], [4, 0], [5, 1], [6, 0], [7, 2], [7, 3], [8, 1], [9, 0], [10, 3], [11, 2], [4, 3], [3, 1], [9, 2]]:
		var h := MeshInstance3D.new()
		h.mesh = load("res://dados/humano.res")
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/humano.gdshader")
		var c: Array = cores[rng.randi() % 4]
		m.set_shader_parameter("camisa", c[0])
		m.set_shader_parameter("calca", c[1])
		m.set_shader_parameter("cabelo", c[2])
		m.set_shader_parameter("pele", peles[rng.randi() % 4])
		h.material_override = m
		h.position = Vector3([-0.98, -0.50, 0.50, 0.98][q[1]], Aeronave.PISO + 0.46, -5.4 + (q[0] + 0.5) * 0.8 + 0.04)
		h.rotation = Vector3(rng.randf_range(-0.06, 0.04), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05))
		h.scale = Vector3.ONE * rng.randf_range(0.94, 1.03)
		casco.add_child(h)
		_passag.append(h)
	# luzes da cabine
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.58)
		l.light_energy = 0.75
		l.omni_range = 3.4
		l.position = Vector3(0, 0.95, -4.8 + i * 2.9)
		l.light_volumetric_fog_energy = 0.4
		l.shadow_enabled = i == 1
		casco.add_child(l)
		luzes.append(l)
	var fa := Malha.new()
	for sx in [-1.0, 1.0]:
		fa.cx(Vector3(0.36 * sx, 1.32, -0.6), Vector3(0.10, 0.02, 11.4))
	luzes.append(fa.no(Mat.liso(Color(0.4, 0.38, 0.32), 0.5, 0, Color(1.0, 0.84, 0.6), 0.75).duplicate(), casco))
	luz_em = OmniLight3D.new()
	luz_em.light_color = Color(1.0, 0.06, 0.03)
	luz_em.light_energy = 0.0
	luz_em.omni_range = 7.0
	luz_em.position = Vector3(0, 0.6, -4.4)
	casco.add_child(luz_em)
	luz_fogo = OmniLight3D.new()
	luz_fogo.light_color = Color(1.0, 0.45, 0.12)
	luz_fogo.light_energy = 0.0
	luz_fogo.omni_range = 16.0
	luz_fogo.shadow_enabled = true
	luz_fogo.position = asa.motor + Vector3(0, 0.7, 0)
	luz_fogo.light_volumetric_fog_energy = 1.2
	casco.add_child(luz_fogo)
	# luzes de navegacao
	var nv := OmniLight3D.new()
	nv.light_color = Color(0.1, 1.0, 0.3)
	nv.light_energy = 1.2
	nv.omni_range = 4
	nv.position = asa.ponta
	casco.add_child(nv)
	var nb := Malha.new()
	nb.cx(asa.ponta, Vector3(0.12, 0.1, 0.3))
	nb.no(Mat.liso(Color.BLACK, 0.4, 0, Color(0.1, 1.0, 0.3), 5.0), casco)
	# aviso de cinto
	aviso_cinto = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.17)
	aviso_cinto.mesh = qm
	aviso_cinto.position = Vector3(0.62, 0.80, -6.34)
	aviso_cinto.material_override = Mat.placa("placa_cinto.png", 0.0).duplicate()
	casco.add_child(aviso_cinto)
	# mascaras (guardadas)
	for i in 13:
		for sx in [-1.0, 1.0]:
			var n := Node3D.new()
			n.position = Vector3(0.66 * sx, 0.68, -5.15 + i * 0.8)
			n.visible = false
			var mm := Malha.new()
			mm.tubo([Vector3.ZERO, Vector3(0.01, -0.22, 0.01), Vector3(0, -0.42, 0)], [0.005, 0.005, 0.005], 4)
			mm.no(Mat.liso(Color(0.8, 0.8, 0.75), 0.6), n)
			var mk := Malha.new()
			mk.tubo([Vector3(0, -0.42, 0), Vector3(0, -0.50, 0)], [0.028, 0.048], 10)
			mk.no(Mat.liso(Color(0.80, 0.60, 0.08), 0.5, 0, Color.BLACK, 0, true), n)
			casco.add_child(n)
			mascaras.append(n)
	# objetos que voam
	for i in 12:
		var mi := Malha.new()
		mi.cx(Vector3.ZERO, Vector3(rng.randf_range(0.08, 0.4), rng.randf_range(0.04, 0.2), rng.randf_range(0.1, 0.3)))
		var no := mi.no(Mat.liso([Color(0.15, 0.07, 0.05), Color(0.05, 0.07, 0.13), Color(0.6, 0.58, 0.5)][i % 3], 0.6), casco)
		no.visible = false
		_soltos.append({"n": no, "p": Vector3(rng.randf_range(-0.7, 0.7), 1.0, rng.randf_range(-6, 3)), "v": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-4, -1)), "r": Vector3(rng.randf(), rng.randf(), rng.randf()) * 6.0})
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
	_fagulhas.position = Vector3(-0.3, 1.2, -2.4)
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
	olhos_janela.position = Vector3(3.0, -0.35, -1.2)
	olhos_janela.rotation = Vector3(-0.95, 0.9, 0)
	olhos_janela.visible = false
	casco.add_child(olhos_janela)

	cam = Camera3D.new()
	cam.fov = 70
	cam.near = 0.04
	cam.far = 3500
	cam.environment = env
	casco.add_child(cam)
	cam.position = Vector3(0.92, 0.45, -0.20)
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
	if e.is_action_pressed("usar") and dica != "" and not cinto:
		apertar_cinto()


func apertar_cinto() -> void:
	cinto = true
	dica = ""
	Som.toca("chave", -6, 0.8)


func _uma(id: String, em: float) -> bool:
	if t >= em and not _feito.has(id):
		_feito[id] = true
		return true
	return false


func _process(dt: float) -> void:
	if not rodando:
		return
	t += dt
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
	turb = lerpf(turb, turb_alvo, dt * 1.6)
	var a := t
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
	cam.position = Vector3(0.92, 0.45 - 0.30 * protegendo, -0.20 - 0.22 * protegendo) + ch + Vector3(sx, sy, 0) * 0.018 * turb
	cam.rotation = Vector3(pitch - 0.75 * protegendo * (1.0 - absf(pitch) * 0.3) + ch.y * 2.2 + sin(t * 0.9) * 0.004, yaw * (1.0 - 0.6 * protegendo) + ch.x * 2.0, ch.z * 2.4 - casco.rotation.z * 0.15)
	# luzes
	_apag -= dt
	var liga := 1.0
	if t > 46.0 and t < 53.0: liga = 1.0 if sin(t * 23.0) + sin(t * 37.0) > -0.8 else 0.15
	if t >= 53.0: liga = 0.0
	if t >= 53.0 and t < 58.0 and sin(t * 41.0) > 0.7: liga = 0.7
	for i in luzes.size() - 1:
		luzes[i].light_energy = 0.75 * liga
	(luzes[-1].material_override if luzes[-1].material_override else luzes[-1].mesh.surface_get_material(0)).emission_energy_multiplier = 0.75 * liga
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
	for h in _passag.size():
		_passag[h].rotation.z = sin(t * 5.0 + h * 1.7) * 0.07 * turb
		_passag[h].rotation.x = sin(t * 6.1 + h * 2.3) * 0.05 * turb - (0.5 if t > 78.0 else 0.0) * minf(1.0, (t - 78.0))
	if t > 66.0:
		for s in _soltos:
			s.n.visible = true
			s.p += s.v * dt * (0.4 + turb * 0.5)
			if s.p.z < -6.2: s.p = Vector3(randf_range(-0.7, 0.7), randf_range(-0.4, 1.0), randf_range(1.0, 5.0))
			if absf(s.p.x) > 1.0: s.v.x *= -1.0
			if s.p.y > 1.1 or s.p.y < -0.6: s.v.y *= -1.0
			s.n.position = s.p
			s.n.rotation += s.r * dt
	# orbe
	if orbe.visible:
		orbe.position = Vector3(lerpf(26.0, 7.5, smoothstep(24.0, 50.0, t)), 1.2 + sin(t * 1.4) * 0.6, -4.0 + sin(t * 0.7) * 2.0)
	if Jogo.hud:
		Jogo.hud._dica.text = dica
		Jogo.hud.tonto = maxf(0.0, turb - 1.6) * 0.16


func _roteiro(dt: float) -> void:
	if _uma("cap", 1.5): Jogo.hud.capitulo("VOO 609", "24 de outubro de 1987  —  1h52 da madrugada", 3.0)
	if _uma("ch1", 5.5): Som.toca("av_chime", -8)
	if _uma("p1", 7.0):
		Som.toca("v_piloto1", -2, 1.0, "Voz")
		Jogo.falar("comandante", "Boa noite, senhores passageiros. Aqui é a comandante.", 4.0)
	if _uma("p1b", 11.2): Jogo.falar("comandante", "Estamos sobrevoando os montes Apalaches. Lua cheia do lado direito da aeronave. Pouso previsto em quarenta minutos.", 8.0)
	if _uma("orbe", 24.0):
		orbe.visible = true
	if _uma("olhe", 27.0): Jogo.falar("passageira da frente", "Que luz é aquela?", 3.0)
	if _uma("olhe2", 31.0): Jogo.falar("", "Uma luz acompanha o avião. Ela não pisca.", 3.6)
	if _uma("b1", 35.0):
		turb_alvo = 0.35
		Som.toca("batida_metal", -10, 0.6)
	if _uma("ch2", 37.0):
		Som.toca("av_chime", -6)
		var m: StandardMaterial3D = aviso_cinto.material_override
		m.emission_enabled = true
		m.emission_texture = Mat.tex("placa_cinto.png")
		m.emission_energy_multiplier = 2.2
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
