extends Node3D
## So para teste: estudio com as pessoas.  -- prova=gente pasta=C:/x quem=com,viz modo=pe|sentado|morto

func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.75)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	we.environment = env
	add_child(we)
	var l := SpotLight3D.new()
	l.position = Vector3(1.6, 2.6, -2.6)
	l.light_color = Color(1.0, 0.88, 0.72)
	l.light_energy = 6.0
	l.spot_range = 9
	l.spot_angle = 60
	l.shadow_enabled = true
	add_child(l)
	l.look_at(Vector3(0, 1.2, 0))
	var l2 := OmniLight3D.new()
	l2.position = Vector3(-2.0, 1.8, 1.4)
	l2.light_color = Color(0.6, 0.75, 1.0)
	l2.light_energy = 1.2
	add_child(l2)
	var ch := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ch.mesh = pm
	ch.material_override = Mat.liso(Color(0.2, 0.2, 0.2), 0.9)
	add_child(ch)
	var quem: PackedStringArray = Teste.a.get("quem", "com,viz").split(",")
	var modo: String = Teste.a.get("modo", "pe")
	var ns := []
	for i in quem.size():
		var x := (i - (quem.size() - 1) * 0.5) * 0.85
		var g := Gente.criar(self, quem[i], Vector3(x, 0.45 if modo != "pe" else 0.0, 0), 0.0, modo != "pe")
		g.pose = Teste.a.get("pose", g.pose)
		if modo == "morto": g.morrer(i + 3, 0.6, 0.7)
		if Teste.a.has("vel"): g.vel = 1.2
		g.sorriso = Teste.num("sorri", 0.0)
		g.medo = Teste.num("medo", 0.0)
		ns.append(g)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.current = true
	var perto := Teste.a.has("perto")
	for k in (quem.size() if perto else 1):
		var alvo: Vector3 = Vector3(0, 0.95, 0) if not perto else ns[k].cabeca()
		cam.position = alvo + (Vector3(0.0, 0.25, -maxf(2.6, quem.size() * 1.15)) if not perto else Vector3(0.16, 0.02, -0.75))
		cam.look_at(alvo)
		for i in 40: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("%s/%s%s.jpg" % [Teste.a.pasta, Teste.a.get("nome", "gente"), str(k) if perto else ""], 0.92)
	print("FOTO ok")
	get_tree().quit()