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


## flocos de neve + cristais que brilham no ar; segue a camera
static func ar(pai: Node3D) -> Node3D:
	var r := Node3D.new()
	pai.add_child(r)
	for k in 2:
		var f := GPUParticles3D.new()
		f.amount = [900, 260][k]
		f.lifetime = [7.0, 5.0][k]
		f.preprocess = 6.0
		f.local_coords = false
		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3([18, 7][k], 2.0, [18, 7][k])
		m.direction = Vector3(0.25, -1, 0.12)
		m.spread = 14
		m.initial_velocity_min = 0.7
		m.initial_velocity_max = 1.3
		m.gravity = Vector3(0.10, -0.22, 0.04)
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 0.8
		m.turbulence_noise_scale = 2.4
		m.scale_min = [0.016, 0.010][k]
		m.scale_max = [0.038, 0.022][k]
		m.color_ramp = _rampa([[0, Color(1, 1, 1, 0)], [0.1, Color(1, 1, 1, 0.85)], [0.9, Color(1, 1, 1, 0.8)], [1, Color(1, 1, 1, 0)]])
		f.process_material = m
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		var mt := StandardMaterial3D.new()
		mt.albedo_texture = Mat.tex("fumaca.png")
		mt.albedo_color = Color(0.95, 0.97, 1.0, 1.0)
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mt.billboard_keep_scale = true
		mt.vertex_color_use_as_albedo = true
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mt.backlight_enabled = true
		mt.backlight = Color(0.6, 0.6, 0.6)
		q.material = mt
		f.draw_pass_1 = q
		f.position = Vector3(0, [7.0, 3.5][k], 0)
		f.visibility_aabb = AABB(Vector3(-30, -24, -30), Vector3(60, 40, 60))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.name = "neve%d" % k
		r.add_child(f)
	return r


static func forca_neve(r: Node3D, v: float) -> void:
	for k in 2:
		var f: GPUParticles3D = r.get_node("neve%d" % k)
		f.amount_ratio = clampf(v, 0.0, 1.0)
		f.emitting = v > 0.02


static var _tex_sangue: ImageTexture

## mancha de sangue projetada no chao
static func sangue(pai: Node3D, pos: Vector3, tam: float) -> void:
	if _tex_sangue == null:
		var n := 256
		var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var ru := FastNoiseLite.new()
		ru.frequency = 0.022
		ru.fractal_octaves = 4
		for y in n:
			for x in n:
				var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
				var r := p.length() + ru.get_noise_2d(x, y) * 0.75
				var a := 1.0 - smoothstep(0.34, 0.50, r)
				var borda := 1.0 - smoothstep(0.15, 0.42, r)
				im.set_pixel(x, y, Color(0.20 - 0.13 * borda, 0.008, 0.006, a * 0.9))
		im.generate_mipmaps()
		_tex_sangue = ImageTexture.create_from_image(im)
	var d := Decal.new()
	d.texture_albedo = _tex_sangue
	d.size = Vector3(tam, 1.2, tam)
	d.rotation.y = randf() * TAU
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.normal_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 45.0
	pai.add_child(d)
	d.global_position = pos
