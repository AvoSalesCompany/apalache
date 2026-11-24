class_name Fx
extends RefCounted
## Fogo, fumaca, poeira, folhas caindo.

static func _rampa(cs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var of := PackedFloat32Array()
	var co := PackedColorArray()
	for q in cs:
		of.push_back(q[0])
		co.push_back(q[1])
	g.offsets = of
	g.colors = co
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curva(ps: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0
	for q in ps:
		c.add_point(Vector2(q[0], q[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func fogo(pai: Node3D, pos: Vector3, esc: float = 1.0, luz: float = 2.5, alcance: float = 14.0, sombra: bool = true) -> Node3D:
	var r := Node3D.new()
	pai.add_child(r)
	r.position = pos
	var p := GPUParticles3D.new()
	p.amount = 46
	p.lifetime = 0.95
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.42 * esc
	m.direction = Vector3.UP
	m.spread = 14
	m.initial_velocity_min = 0.7 * esc
	m.initial_velocity_max = 2.0 * esc
	m.gravity = Vector3(0.25, 1.5 * esc, 0.1)
	m.scale_min = 0.45 * esc
	m.scale_max = 1.0 * esc
	m.scale_curve = _curva([[0, 0.5], [0.25, 1.0], [1, 0.12]])
	m.angle_min = -180
	m.angle_max = 180
	m.color_ramp = _rampa([[0.0, Color(1, 0.75, 0.35, 0.0)], [0.12, Color(1, 0.62, 0.22, 0.75)], [0.5, Color(1, 0.28, 0.05, 0.5)], [1.0, Color(0.35, 0.05, 0.02, 0.0)]])
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = Mat.sprite(Color(1, 1, 1, 1), 2.4, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(p)
	# brasas
	var b := GPUParticles3D.new()
	b.amount = 26
	b.lifetime = 2.6
	var bm := ParticleProcessMaterial.new()
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bm.emission_sphere_radius = 0.4 * esc
	bm.direction = Vector3.UP
	bm.spread = 30
	bm.initial_velocity_min = 0.8
	bm.initial_velocity_max = 2.6
	bm.gravity = Vector3(0.3, 0.5, 0)
	bm.turbulence_enabled = true
	bm.turbulence_noise_strength = 1.4
	bm.scale_min = 0.012
	bm.scale_max = 0.03
	bm.color_ramp = _rampa([[0, Color(1, 0.6, 0.2, 1)], [1, Color(1, 0.15, 0.0, 0)]])
	b.process_material = bm
	var bq := QuadMesh.new()
	bq.size = Vector2(1, 1)
	bq.material = Mat.sprite(Color(1, 1, 1, 1), 6.0, true)
	b.draw_pass_1 = bq
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(b)
	fumaca(r, Vector3(0, 0.9 * esc, 0), esc)
	var l := LuzFogo.new()
	l.light_color = Color(1.0, 0.50, 0.18)
	l.base = luz
	l.omni_range = alcance
	l.omni_attenuation = 1.3
	l.shadow_enabled = sombra
	l.light_volumetric_fog_energy = 0.55
	l.position = Vector3(0, 0.9 * esc, 0)
	r.add_child(l)
	Som.loop3d("fogo", r, Vector3.ZERO, -2.0, 40.0, 4.0)
	return r


static func fumaca(pai: Node3D, pos: Vector3, esc: float = 1.0, qt: int = 26) -> GPUParticles3D:
	var s := GPUParticles3D.new()
	s.amount = qt
	s.lifetime = 5.5
	s.preprocess = 4.0
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.3 * esc
	sm.direction = Vector3.UP
	sm.spread = 12
	sm.initial_velocity_min = 0.8
	sm.initial_velocity_max = 1.6
	sm.gravity = Vector3(0.22, 0.12, 0.1)
	sm.scale_min = 1.2 * esc
	sm.scale_max = 2.4 * esc
	sm.scale_curve = _curva([[0, 0.3], [1, 2.2]])
	sm.angle_min = -180
	sm.angle_max = 180
	sm.angular_velocity_min = -12
	sm.angular_velocity_max = 12
	sm.color_ramp = _rampa([[0, Color(0.10, 0.09, 0.085, 0)], [0.15, Color(0.11, 0.10, 0.095, 0.34)], [1, Color(0.14, 0.15, 0.17, 0)]])
	s.process_material = sm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = Mat.sprite(Color(1, 1, 1, 1))
	s.draw_pass_1 = q
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(s)
	s.position = pos
	return s


## folhas que caem + poeira que brilha nos raios da lua; segue a camera
static func ar(pai: Node3D) -> Node3D:
	var r := Node3D.new()
	pai.add_child(r)
	var f := GPUParticles3D.new()
	f.amount = 46
	f.lifetime = 9.0
	f.preprocess = 8.0
	f.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(16, 1, 16)
	m.direction = Vector3(0.3, -1, 0.1)
	m.spread = 20
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.8
	m.gravity = Vector3(0.12, -0.32, 0.05)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.9
	m.turbulence_noise_scale = 3.0
	m.angle_min = -180
	m.angle_max = 180
	m.angular_velocity_min = -130
	m.angular_velocity_max = 130
	m.particle_flag_rotate_y = true
	m.scale_min = 0.05
	m.scale_max = 0.10
	f.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1, 0.8)
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = Mat.tex("fol_folha.png")
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mt.alpha_scissor_threshold = 0.4
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.backlight_enabled = true
	mt.backlight = Color(0.3, 0.2, 0.1)
	q.material = mt
	f.draw_pass_1 = q
	f.position = Vector3(0, 9, 0)
	f.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(f)
	var d := GPUParticles3D.new()
	d.amount = 120
	d.lifetime = 7.0
	d.preprocess = 6.0
	d.local_coords = false
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dm.emission_box_extents = Vector3(9, 3, 9)
	dm.gravity = Vector3.ZERO
	dm.initial_velocity_min = 0.02
	dm.initial_velocity_max = 0.12
	dm.spread = 180
	dm.turbulence_enabled = true
	dm.turbulence_noise_strength = 0.25
	dm.scale_min = 0.008
	dm.scale_max = 0.02
	dm.color_ramp = _rampa([[0, Color(0.6, 0.7, 0.9, 0)], [0.3, Color(0.6, 0.7, 0.9, 0.5)], [1, Color(0.6, 0.7, 0.9, 0)]])
	d.process_material = dm
	var dq := QuadMesh.new()
	dq.size = Vector2(1, 1)
	var dmat := Mat.sprite(Color(1, 1, 1, 0.6))
	dq.material = dmat
	d.draw_pass_1 = dq
	d.visibility_aabb = AABB(Vector3(-14, -8, -14), Vector3(28, 16, 28))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(d)
	return r
