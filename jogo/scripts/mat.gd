class_name Mat
extends RefCounted
## Fabrica de materiais (com cache).

static var _c := {}


static func tex(nome: String) -> Texture2D:
	return load("res://tex/" + nome)


static func casca(base: String, tinta: Color, musgo: float, vento: float = 1.0) -> ShaderMaterial:
	var k := "casca%s%s%s%s" % [base, tinta, musgo, vento]
	if not _c.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/casca.gdshader")
		m.set_shader_parameter("cor", tex(base + "_cor.jpg"))
		m.set_shader_parameter("nor", tex(base + "_nor.jpg"))
		m.set_shader_parameter("arm", tex(base + "_arm.jpg"))
		m.set_shader_parameter("tinta", tinta)
		m.set_shader_parameter("musgo", musgo)
		m.set_shader_parameter("vento", vento)
		_c[k] = m
	return _c[k]


static func folha(png: String, tinta: Color, trans: float, corte: float = 0.42, rug: float = 0.75, vento: float = 1.0, mip: float = 0.28) -> ShaderMaterial:
	var k := "folha%s%s%s%s%s%s" % [png, tinta, trans, corte, rug, vento]
	if not _c.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/folhagem.gdshader")
		m.set_shader_parameter("cor", tex(png))
		m.set_shader_parameter("tinta", tinta)
		m.set_shader_parameter("trans", trans)
		m.set_shader_parameter("corte", corte)
		m.set_shader_parameter("rug", rug)
		m.set_shader_parameter("vento", vento)
		m.set_shader_parameter("mip_comp", mip)
		_c[k] = m
	return _c[k]


## PBR com texturas do Poly Haven
static func pbr(base: String, esc: float = 1.0, tinta: Color = Color.WHITE, rug: float = 1.0, metal: float = 0.0, duplo: bool = false) -> StandardMaterial3D:
	var k := "pbr%s%s%s%s%s%s" % [base, esc, tinta, rug, metal, duplo]
	if not _c.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex(base + "_cor.jpg")
		m.albedo_color = tinta
		m.normal_enabled = true
		m.normal_texture = tex(base + "_nor.jpg")
		m.roughness = rug
		m.roughness_texture = tex(base + "_arm.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = tex(base + "_arm.jpg")
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.metallic = metal
		m.metallic_specular = 0.4
		m.uv1_scale = Vector3(esc, esc, esc)
		if duplo:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_c[k] = m
	return _c[k]


static func liso(cor: Color, rug: float = 0.8, metal: float = 0.0, emis: Color = Color.BLACK, forca: float = 0.0, duplo: bool = false) -> StandardMaterial3D:
	var k := "liso%s%s%s%s%s%s" % [cor, rug, metal, emis, forca, duplo]
	if not _c.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = rug
		m.metallic = metal
		if forca > 0.0:
			m.emission_enabled = true
			m.emission = emis
			m.emission_energy_multiplier = forca
		if duplo:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_c[k] = m
	return _c[k]


static func placa(png: String, emis: float = 0.0, rug: float = 0.8) -> StandardMaterial3D:
	var k := "placa%s%s" % [png, emis]
	if not _c.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex(png)
		m.roughness = rug
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if emis > 0.0:
			m.emission_enabled = true
			m.emission_texture = tex(png)
			m.emission_energy_multiplier = emis
		_c[k] = m
	return _c[k]


## Particula de fumaca/fogo
static func sprite(cor: Color, emis: float = 0.0, aditivo: bool = false) -> StandardMaterial3D:
	var k := "spr%s%s%s" % [cor, emis, aditivo]
	if not _c.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex("fumaca.png")
		m.albedo_color = cor
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emis > 0.0 else BaseMaterial3D.SHADING_MODE_PER_VERTEX
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.6
		if aditivo:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if emis > 0.0:
			m.albedo_color = Color(cor.r * emis, cor.g * emis, cor.b * emis, cor.a)
		_c[k] = m
	return _c[k]


## modelo do Poly Haven (cena)
static func modelo(id: String) -> Node3D:
	return (load("res://mod/%s.gltf" % id) as PackedScene).instantiate()


## malhas soltas de um modelo: [[Mesh, Transform3D], ...]
static func malhas_de(id: String) -> Array:
	var k := "malhas" + id
	if not _c.has(k):
		var out := []
		var r := modelo(id)
		_coleta(r, Transform3D.IDENTITY, out)
		r.free()
		_c[k] = out
	return _c[k]


static func _coleta(no: Node, tr: Transform3D, out: Array) -> void:
	var t2 := tr
	if no is Node3D:
		t2 = tr * (no as Node3D).transform
	if no is MeshInstance3D and no.mesh:
		out.append([no.mesh, t2])
	for f in no.get_children():
		_coleta(f, t2, out)
