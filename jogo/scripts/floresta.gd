class_name Floresta
extends Node3D
## Monta e transmite (streaming) a floresta inteira.

const CH := 32.0                  # chunk de arvores
const R0 := 40.0                  # detalhe total
const R1 := 108.0                 # detalhe medio
const CM := 14.0                  # celula do mato rasteiro
const RM := 40.0

var env: Environment
var lua: DirectionalLight3D
var mat_ceu: ShaderMaterial
var raios: MeshInstance3D
var mat_raios: ShaderMaterial
var ar: Node3D
var locais: Locais
var foco := Vector3.ZERO          # de onde o streaming olha
var pronta := false
var lua_fator := 1.0
var _lua_alvo := 1.0
var _lua_t := 0.0
const LUA_E := 0.40
const RAIOS := 0.15

var _malhas := []                 # tipo -> [lod0, lod1]
var _rodo := []
var _chunks := {}                 # Vector2i -> dados
var _nivel := {}                  # Vector2i -> nivel atual
var _nos := {}                    # Vector2i -> [nos]
var _mato := {}                   # celula -> [nos]
var _fila := []
var _t := 0.0
var _corpos: Array[StaticBody3D] = []
var _corpo_de := {}
var _mat_mato := []
var _ped := []
var _ruido := FastNoiseLite.new()
var _tc := 0.0


func construir(passo: Callable) -> void:
	Mundo.carregar()
	_ruido.frequency = 0.06
	_ruido.seed = 5
	_luz_e_ceu()
	await passo.call("Nascendo a lua", 0.08)
	_terreno()
	await passo.call("Levantando a serra", 0.25)
	for tp in 8:
		_malhas.append(Arvores.gerar(tp))
		if tp % 2 == 1:
			await passo.call("Plantando a mata", 0.28 + tp * 0.03)
	for k in 3:
		_rodo.append([Arvores.rododendro(k, 0), Arvores.rododendro(k, 1)])
	await passo.call("Fechando o rododendro", 0.55)
	_distribui()
	await passo.call("Espalhando 30 mil arvores", 0.66)
	_agua()
	_rodovia()
	_prepara_mato()
	await passo.call("Enchendo o riacho", 0.74)
	locais = Locais.new()
	add_child(locais)
	await locais.construir(self, passo)
	_nevoas()
	_colisores()
	ar = Fx.ar(self)
	opcoes_mudaram()
	add_to_group("opcoes")
	pronta = true


# ------------------------------------------------------------------ luz
func _luz_e_ceu() -> void:
	mat_ceu = ShaderMaterial.new()
	mat_ceu.shader = load("res://shaders/ceu.gdshader")
	mat_ceu.set_shader_parameter("lua", Mundo.LUA)
	var sky := Sky.new()
	sky.sky_material = mat_ceu
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.47, 0.70)
	env.ambient_light_energy = 0.085
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.55
	env.tonemap_agx_contrast = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.05
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.4
	env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.085, 0.115, 0.175)
	env.fog_light_energy = 0.13
	env.fog_density = 0.0075
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.16
	env.fog_aerial_perspective = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.72, 0.80, 0.95)
	env.volumetric_fog_anisotropy = 0.62
	env.volumetric_fog_length = 84.0
	env.volumetric_fog_detail_spread = 1.8
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.92

	lua = DirectionalLight3D.new()
	lua.light_color = Color(0.60, 0.73, 1.0)
	lua.light_energy = LUA_E
	lua.light_angular_distance = 0.5
	lua.light_volumetric_fog_energy = 1.0
	lua.shadow_enabled = true
	lua.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	lua.directional_shadow_max_distance = 110.0
	lua.directional_shadow_split_1 = 0.08
	lua.directional_shadow_split_2 = 0.22
	lua.directional_shadow_split_3 = 0.5
	lua.directional_shadow_blend_splits = true
	lua.shadow_bias = 0.06
	lua.shadow_normal_bias = 1.6
	lua.shadow_blur = 1.1
	lua.shadow_opacity = 0.985
	add_child(lua)
	lua.look_at_from_position(Mundo.LUA * 100.0, Vector3.ZERO)

	raios = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	raios.mesh = q
	mat_raios = ShaderMaterial.new()
	mat_raios.shader = load("res://shaders/raios.gdshader")
	mat_raios.set_shader_parameter("lua", Mundo.LUA)
	mat_raios.render_priority = 20
	raios.material_override = mat_raios
	raios.extra_cull_margin = 16384.0
	raios.ignore_occlusion_culling = true
	raios.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(raios)


func opcoes_mudaram() -> void:
	var q := Jogo.qualidade
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 3
	lua.directional_shadow_max_distance = [60.0, 85.0, 110.0, 140.0][q]
	lua.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


## uma nuvem cobre a lua por alguns segundos: breu
func cobrir_lua(s: float) -> void:
	_lua_alvo = 0.04
	_lua_t = s
	if Jogo.jogador:
		Jogo.falar("", "Uma nuvem cobre a lua.", 2.5)


# ------------------------------------------------------------------ terreno
func _terreno() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terreno.gdshader")
	m.set_shader_parameter("splat", ImageTexture.create_from_image(load("res://dados/splat.res")))
	for par in [["folha", "forest_leaves_02"], ["lama", "brown_mud_leaves_01"], ["mato", "forrest_ground_01"], ["rocha", "mossy_rock"], ["seixo", "river_small_rocks"], ["terra", "gravel_ground_01"]]:
		m.set_shader_parameter(par[0] + "_c", Mat.tex(par[1] + "_cor.jpg"))
		m.set_shader_parameter(par[0] + "_n", Mat.tex(par[1] + "_nor.jpg"))
	m.set_shader_parameter("folha_a", Mat.tex("forest_leaves_02_arm.jpg"))
	var h := Mundo.dados.alt
	var N := Mundo.N
	# normais de uma vez
	var nor := PackedVector3Array()
	nor.resize(N * N)
	for z in N:
		for x in N:
			var xa := maxi(x - 1, 0)
			var xb := mini(x + 1, N - 1)
			var za := maxi(z - 1, 0)
			var zb := mini(z + 1, N - 1)
			nor[z * N + x] = Vector3(h[z * N + xa] - h[z * N + xb], 4.0, h[za * N + x] - h[zb * N + x]).normalized()
	var Q := 32
	var idx := PackedInt32Array()
	for z in Q:
		for x in Q:
			var a := z * (Q + 1) + x
			idx.append_array(PackedInt32Array([a, a + 1, a + Q + 2, a, a + Q + 2, a + Q + 1]))
	for cz in 16:
		for cx in 16:
			var v := PackedVector3Array()
			var n := PackedVector3Array()
			v.resize((Q + 1) * (Q + 1))
			n.resize((Q + 1) * (Q + 1))
			var k := 0
			for z in Q + 1:
				for x in Q + 1:
					var ix := cx * Q + x
					var iz := cz * Q + z
					v[k] = Vector3(ix * 2.0 - 512.0, h[iz * N + ix], iz * 2.0 - 512.0)
					n[k] = nor[iz * N + ix]
					k += 1
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = n
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(0, m)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = N
	hs.map_depth = N
	var hd := PackedFloat32Array()
	hd.resize(N * N)
	for i in N * N:
		hd[i] = h[i] * 0.5
	hs.map_data = hd
	cs.shape = hs
	cs.scale = Vector3(2, 2, 2)
	sb.add_child(cs)
	add_child(sb)


# ------------------------------------------------------------------ arvores
func _linha(x: float, y: float, z: float, r: float, s: float) -> PackedFloat32Array:
	var c := cos(r) * s
	var n := sin(r) * s
	return PackedFloat32Array([c, 0, n, x, 0, s, 0, y, -n, 0, c, z])


func _distribui() -> void:
	var a := Mundo.dados.arv
	for i in a.size() / 6:
		var k := Vector2i(floori(a[i * 6] / CH), floori(a[i * 6 + 2] / CH))
		if not _chunks.has(k):
			_chunks[k] = {"arv": {}, "imp": PackedFloat32Array(), "rod": {}, "ped": {}}
		var c: Dictionary = _chunks[k]
		var tp := int(a[i * 6 + 5])
		var l := _linha(a[i * 6], a[i * 6 + 1], a[i * 6 + 2], a[i * 6 + 3], a[i * 6 + 4])
		if not c.arv.has(tp):
			c.arv[tp] = PackedFloat32Array()
		var b: PackedFloat32Array = c.arv[tp]
		b.append_array(l)
		c.arv[tp] = b
		if tp != 7:
			var H: float = Arvores.ALTURAS[tp] * 1.06
			var s := a[i * 6 + 4] * H
			var li := _linha(a[i * 6], a[i * 6 + 1] - 0.3, a[i * 6 + 2], a[i * 6 + 3], s)
			li.append_array(PackedFloat32Array([tp / 8.0, 0, 0, 0]))
			var im: PackedFloat32Array = c.imp
			im.append_array(li)
			c.imp = im
	var r := Mundo.dados.rod
	for i in r.size() / 5:
		var k := Vector2i(floori(r[i * 5] / CH), floori(r[i * 5 + 2] / CH))
		if not _chunks.has(k):
			_chunks[k] = {"arv": {}, "imp": PackedFloat32Array(), "rod": {}, "ped": {}}
		var tp := i % 3
		var d: Dictionary = _chunks[k].rod
		if not d.has(tp): d[tp] = PackedFloat32Array()
		var b: PackedFloat32Array = d[tp]
		b.append_array(_linha(r[i * 5], r[i * 5 + 1], r[i * 5 + 2], r[i * 5 + 3], r[i * 5 + 4]))
		d[tp] = b
	# pedras e troncos
	_ped = [_peca("rock_moss_set_01", 0), _peca("rock_moss_set_01", 1), _peca("rock_moss_set_02", 0), _peca("boulder_01", 0), _peca("rock_09", 0),
		_peca("dead_tree_trunk", 0), _peca("dead_tree_trunk_02", 0), _peca("tree_stump_01", 0), _peca("tree_stump_02", 0), _peca("root_cluster_01", 0)]
	var p := Mundo.dados.ped
	for i in p.size() / 6:
		var k := Vector2i(floori(p[i * 6] / CH), floori(p[i * 6 + 2] / CH))
		if not _chunks.has(k):
			continue
		var tp := int(p[i * 6 + 5])
		var d: Dictionary = _chunks[k].ped
		if not d.has(tp): d[tp] = PackedFloat32Array()
		var b: PackedFloat32Array = d[tp]
		var pc: Array = _ped[tp]
		var nrm := Mundo.normal(p[i * 6], p[i * 6 + 2]) if tp in [5, 6] else Vector3.UP
		var bs := Basis(Vector3.UP, p[i * 6 + 3])
		if tp in [5, 6]:
			bs = Basis(Quaternion(Vector3.UP, nrm)) * bs
		bs = bs.scaled(Vector3.ONE * p[i * 6 + 4] * pc[2])
		var t := Transform3D(bs, Vector3(p[i * 6], p[i * 6 + 1] - pc[3] * p[i * 6 + 4], p[i * 6 + 2])) * (pc[1] as Transform3D)
		b.append_array(PackedFloat32Array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y, t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z]))
		d[tp] = b
	# impostores
	var mi := Malha.new()
	for k in 2:
		var ang := PI * k / 2.0 + 0.4
		var lado := Vector3(cos(ang), 0, sin(ang)) * 0.25
		var no := Vector3(-sin(ang), 0.35, cos(ang)).normalized()
		var i0 := mi.vert(-lado, no, Vector2(0, 1))
		mi.vert(lado, no, Vector2(1, 1))
		mi.vert(lado + Vector3.UP, no, Vector2(1, 0))
		mi.vert(-lado + Vector3.UP, no, Vector2(0, 0))
		mi.quad(i0, i0 + 1, i0 + 2, i0 + 3)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/impostor.gdshader")
	sm.set_shader_parameter("atlas", Mat.tex("impostores.png"))
	var mimp := mi.malha(sm)
	for k in _chunks:
		_nivel[k] = 2
		_nos[k] = []
		var im: PackedFloat32Array = _chunks[k].imp
		if im.size() > 0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = mimp
			mm.instance_count = im.size() / 16
			mm.buffer = im
			var no := MultiMeshInstance3D.new()
			no.multimesh = mm
			no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(no)
			_chunks[k]["no"] = no


## [mesh, transform sem deslocamento, escala, afundar]
func _peca(id: String, i: int) -> Array:
	var ms := Mat.malhas_de(id)
	var q: Array = ms[mini(i, ms.size() - 1)]
	var t: Transform3D = q[1]
	t.origin = Vector3.ZERO
	var bb: AABB = t * (q[0] as Mesh).get_aabb()
	t.origin = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var maior := maxf(bb.size.x, bb.size.z)
	var desejo: float = {"rock_moss_set_01": 1.5, "rock_moss_set_02": 1.6, "boulder_01": 2.2, "rock_09": 1.4, "dead_tree_trunk": 5.0, "dead_tree_trunk_02": 4.6, "tree_stump_01": 1.5, "tree_stump_02": 1.3, "root_cluster_01": 2.0}.get(id, maior)
	var e := desejo / maior
	return [q[0], t, e, bb.size.y * e * 0.16]


func _mm(mesh: Mesh, buf: PackedFloat32Array, sombra: bool, fim: float = 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = buf.size() / 12
	mm.buffer = buf
	var no := MultiMeshInstance3D.new()
	no.multimesh = mm
	if not sombra:
		no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if fim > 0.0:
		no.visibility_range_end = fim
	add_child(no)
	return no


func _aplica_nivel(k: Vector2i, nv: int) -> void:
	for q in _nos[k]:
		q.queue_free()
	_nos[k] = []
	_nivel[k] = nv
	var c: Dictionary = _chunks[k]
	if c.has("no"):
		c.no.visible = nv == 2
	if nv < 2:
		for tp in c.arv:
			_nos[k].append(_mm(_malhas[tp][nv], c.arv[tp], true))
		for tp in c.rod:
			_nos[k].append(_mm(_rodo[tp][nv], c.rod[tp], nv == 0 or Jogo.qualidade >= 2))
		for tp in c.ped:
			_nos[k].append(_mm(_ped[tp][0], c.ped[tp], nv == 0))


## atualiza todos os niveis de uma vez (carregamento/teleporte)
func firmar(p: Vector3) -> void:
	foco = p
	_varre(9999)
	for i in 200:
		if _fila.is_empty():
			break
		_mato_passo(40)
	_atualiza_colisores(true)


func _varre(limite: int) -> void:
	var n := 0
	for k in _chunks:
		var d := Vector2((k.x + 0.5) * CH - foco.x, (k.y + 0.5) * CH - foco.z).length()
		var at: int = _nivel[k]
		var nv := at
		if d < R0: nv = 0
		elif d < R1: nv = 1 if at != 0 or d > R0 + 6.0 else 0
		elif d > R1 + 8.0 or at == 2: nv = 2
		if nv != at:
			_aplica_nivel(k, nv)
			n += 1
			if n >= limite:
				break
	_mato_varre()


# ------------------------------------------------------------------ mato rasteiro
func _prepara_mato() -> void:
	var pega := func(id: String, alvo: float) -> Array:
		var out := []
		for q in Mat.malhas_de(id):
			var t: Transform3D = q[1]
			t.origin = Vector3.ZERO
			var bb: AABB = t * (q[0] as Mesh).get_aabb()
			t.origin = -Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.02, bb.get_center().z)
			out.append([q[0], t, alvo / maxf(maxf(bb.size.x, bb.size.z), bb.size.y)])
		return out
	# [variantes, prob, freq de ruido]
	_mat_mato = [
		[pega.call("fern_02", 0.95), 26, 0],
		[pega.call("shrub_02", 0.9), 4, 1],
		[pega.call("shrub_03", 0.8), 5, 1],
		[pega.call("shrub_04", 0.8), 5, 2],
		[pega.call("nettle_plant", 0.7), 5, 0],
		[pega.call("weed_plant_02", 0.5), 5, 2],
		[pega.call("dry_branches_medium_01", 1.6), 5, 3],
		[[[Arvores.capim(1), Transform3D.IDENTITY, 1.0], [Arvores.capim(2), Transform3D.IDENTITY, 1.0]], 46, 2],
	]


func _mato_varre() -> void:
	var r := int(ceil(RM / CM))
	var cx := floori(foco.x / CM)
	var cz := floori(foco.z / CM)
	for k in _mato.keys():
		if maxi(absi(k.x - cx), absi(k.y - cz)) > r + 1:
			for q in _mato[k]:
				q.queue_free()
			_mato.erase(k)
	for x in range(cx - r, cx + r + 1):
		for z in range(cz - r, cz + r + 1):
			var k := Vector2i(x, z)
			if not _mato.has(k) and not (k in _fila) and Vector2((x + 0.5) * CM - foco.x, (z + 0.5) * CM - foco.z).length() < RM + CM:
				_fila.append(k)
	_fila.sort_custom(func(a, b): return Vector2((a.x + 0.5) * CM - foco.x, (a.y + 0.5) * CM - foco.z).length_squared() < Vector2((b.x + 0.5) * CM - foco.x, (b.y + 0.5) * CM - foco.z).length_squared())


func _mato_passo(n: int) -> void:
	for i in n:
		if _fila.is_empty():
			return
		var k: Vector2i = _fila.pop_front()
		if _mato.has(k):
			continue
		_mato[k] = _mato_celula(k)


func _mato_celula(k: Vector2i) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var dens: float = [0.45, 0.7, 1.0, 1.35][Jogo.qualidade]
	for e in _mat_mato.size():
		var esp: Array = _mat_mato[e]
		var bufs := []
		for v in esp[0]:
			bufs.append(PackedFloat32Array())
		for i in int(esp[1] * dens * 1.6):
			var x := (k.x + rng.randf()) * CM
			var z := (k.y + rng.randf()) * CM
			var n := _ruido.get_noise_2d(x * 0.7 + esp[2] * 300.0, z * 0.7) * 0.5 + 0.5
			if rng.randf() > smoothstep(0.38, 0.72, n) * 1.3:
				continue
			if Mundo.dist(Mundo.RIO, x, z) < 2.8 or Mundo.dist(Mundo.RODOVIA, x, z) < 6.0 or Mundo.dist(Mundo.ESTRADA, x, z) < 2.6:
				continue
			if locais and locais.ocupado(x, z):
				continue
			var tr := 9.0
			for q in Mundo.TRILHAS:
				tr = minf(tr, Mundo.dist(q, x, z))
			if tr < 0.9:
				continue
			var vi = rng.randi() % esp[0].size()
			var var_: Array = esp[0][vi]
			var s: float = var_[2] * rng.randf_range(0.65, 1.3)
			var nm := Mundo.normal(x, z)
			var b := Basis(Quaternion(Vector3.UP, Vector3.UP.lerp(nm, 0.75).normalized())) * Basis(Vector3.UP, rng.randf() * TAU)
			var t := Transform3D(b.scaled(Vector3.ONE * s), Vector3(x, Mundo.altura(x, z) - 0.03, z)) * (var_[1] as Transform3D)
			var buf: PackedFloat32Array = bufs[vi]
			buf.append_array(PackedFloat32Array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y, t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z]))
			bufs[vi] = buf
		for vi in bufs.size():
			if bufs[vi].size() > 0:
				out.append(_mm(esp[0][vi][0], bufs[vi], Jogo.qualidade >= 2 and e != 7, RM + 4.0))
	return out


# ------------------------------------------------------------------ agua, rodovia, neblina
func _agua() -> void:
	var m := Malha.new()
	var pts := Mundo.suave(Mundo.RIO, 8)
	var ac := 0.0
	for i in pts.size():
		var p := Vector3(pts[i][0], pts[i][2], pts[i][1])
		var a: Array = pts[maxi(i - 1, 0)]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var d := Vector3(b[0] - a[0], 0, b[1] - a[1]).normalized()
		var l := Vector3(-d.z, 0, d.x)
		if i > 0:
			ac += p.distance_to(Vector3(pts[i - 1][0], pts[i - 1][2], pts[i - 1][1]))
		for q in 5:
			var o := (q / 4.0 - 0.5) * 8.4
			m.vert(p + l * o + Vector3(0, 0.02, 0), Vector3.UP, Vector2(o, ac), l)
		if i > 0:
			var k := (i - 1) * 5
			for q in 4:
				m.quad(k + q, k + q + 5, k + q + 6, k + q + 1)
	var mt := ShaderMaterial.new()
	mt.shader = load("res://shaders/agua.gdshader")
	m.no(mt, self, false)
	for i in range(0, pts.size(), 5):
		Som.loop3d("amb_riacho", self, Vector3(pts[i][0], pts[i][2], pts[i][1]), -3.0, 52.0, 5.0)


func _rodovia() -> void:
	var m := Malha.new()
	var pts := Mundo.suave(Mundo.RODOVIA, 40)
	var ac := 0.0
	for i in pts.size():
		var a: Array = pts[maxi(i - 1, 0)]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var d := Vector3(b[0] - a[0], 0, b[1] - a[1]).normalized()
		var l := Vector3(-d.z, 0, d.x)
		var p := Vector3(pts[i][0], 0, pts[i][1])
		if i > 0:
			ac += p.distance_to(Vector3(pts[i - 1][0], 0, pts[i - 1][1]))
		for q in 5:
			var o := (q / 4.0 - 0.5) * 8.2
			var w := p + l * o
			w.y = Mundo.altura(w.x, w.z) + 0.10
			m.vert(w, Vector3.UP, Vector2(q / 4.0, ac), l)
		if i > 0:
			var k := (i - 1) * 5
			for q in 4:
				m.quad(k + q, k + q + 5, k + q + 6, k + q + 1)
	var mt := ShaderMaterial.new()
	mt.shader = load("res://shaders/asfalto.gdshader")
	mt.set_shader_parameter("cor", Mat.tex("asphalt_02_cor.jpg"))
	mt.set_shader_parameter("nor", Mat.tex("asphalt_02_nor.jpg"))
	m.no(mt, self, false)


func _nevoas() -> void:
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/nevoa.gdshader")
	var pts := Mundo.suave(Mundo.RIO, 2)
	for i in range(1, pts.size() - 1):
		var f := FogVolume.new()
		f.size = Vector3(46, 7, 46)
		f.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		f.material = sh
		f.position = Vector3(pts[i][0], pts[i][2] + 2.2, pts[i][1])
		add_child(f)
	for q in [Mundo.CEMITERIO, Mundo.CABANA + Vector2(10, 14), Mundo.QUEDA, Vector2(300, 165), Vector2(330, 398), Vector2(245, 60)]:
		var f := FogVolume.new()
		f.size = Vector3(44, 6, 44)
		f.material = sh
		f.position = Mundo.chaov(q) + Vector3.UP * 1.6
		add_child(f)


# ------------------------------------------------------------------ colisao de troncos (piscina)
func _colisores() -> void:
	for i in 72:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := CylinderShape3D.new()
		s.radius = 0.4
		s.height = 5.0
		c.shape = s
		c.position.y = 2.2
		b.add_child(c)
		b.position = Vector3(0, -500, 0)
		b.set_meta("id", -1)
		add_child(b)
		_corpos.append(b)


func _atualiza_colisores(_f: bool = false) -> void:
	var quer := {}
	for i in Mundo.arvores_perto(foco, 9.0):
		quer[i] = true
	var p := Mundo.dados.ped
	if _grade_ped.is_empty():
		for i in p.size() / 6:
			var k := Vector2i(floori(p[i * 6] / 12.0), floori(p[i * 6 + 2] / 12.0))
			if not _grade_ped.has(k): _grade_ped[k] = []
			_grade_ped[k].append(i)
	var cx := floori(foco.x / 12.0)
	var cz := floori(foco.z / 12.0)
	for x in range(cx - 1, cx + 2):
		for z in range(cz - 1, cz + 2):
			for i in _grade_ped.get(Vector2i(x, z), []):
				if int(p[i * 6 + 5]) != 9:
					quer[100000 + i] = true
	var livres := []
	for b in _corpos:
		var id: int = b.get_meta("id")
		if id >= 0 and quer.has(id):
			quer.erase(id)
		else:
			livres.append(b)
	for id in quer:
		if livres.is_empty():
			break
		var b: StaticBody3D = livres.pop_back()
		b.set_meta("id", id)
		var cs: CollisionShape3D = b.get_child(0)
		if id < 100000:
			var a := Mundo.dados.arv
			var s := CylinderShape3D.new()
			s.radius = maxf(0.08, Mundo.raio_tronco(id) * 1.05)
			s.height = 5.0
			cs.shape = s
			cs.transform = Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0))
			b.transform = Transform3D(Basis.IDENTITY, Vector3(a[id * 6], a[id * 6 + 1], a[id * 6 + 2]))
		else:
			var i: int = id - 100000
			var tp := int(p[i * 6 + 5])
			var e := p[i * 6 + 4]
			var pc: Array = _ped[tp]
			var bb: AABB = (pc[1] as Transform3D) * (pc[0] as Mesh).get_aabb()
			var sz: Vector3 = bb.size * pc[2] * e
			var pos := Vector3(p[i * 6], p[i * 6 + 1] - pc[3] * e, p[i * 6 + 2])
			if tp in [5, 6]:
				var bx := BoxShape3D.new()
				bx.size = sz * Vector3(0.86, 0.62, 0.62)
				cs.shape = bx
				cs.transform = Transform3D(Basis.IDENTITY, Vector3(0, sz.y * 0.36, 0))
				b.transform = Transform3D(Basis(Quaternion(Vector3.UP, Mundo.normal(pos.x, pos.z))) * Basis(Vector3.UP, p[i * 6 + 3]), pos)
			else:
				# formato real da pedra / toco
				if not _convexo.has(tp):
					_convexo[tp] = (pc[0] as Mesh).create_convex_shape(true, true)
				cs.shape = _convexo[tp]
				var esc: float = pc[2] * e
				cs.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * esc), Vector3.ZERO) * (pc[1] as Transform3D)
				b.transform = Transform3D(Basis(Vector3.UP, p[i * 6 + 3]), pos)

var _grade_ped := {}
var _convexo := {}


func _process(dt: float) -> void:
	if not pronta or not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	foco = cam.global_position
	# no alto da torre a neblina fica embaixo e a vista abre
	var alto := smoothstep(5.0, 13.0, foco.y - Mundo.altura(foco.x, foco.z))
	env.fog_density = lerpf(0.0075, 0.0026, alto)
	env.fog_light_energy = lerpf(0.055, 0.05, alto) * lerpf(0.35, 1.0, lua_fator)
	# nuvem na frente da lua
	_lua_t -= dt
	if _lua_t <= 0.0: _lua_alvo = 1.0
	lua_fator = move_toward(lua_fator, _lua_alvo, dt * (0.40 if _lua_alvo < lua_fator else 0.16))
	lua.light_energy = LUA_E * lua_fator
	mat_raios.set_shader_parameter("forca", RAIOS * lua_fator)
	mat_ceu.set_shader_parameter("brilho", lerpf(0.06, 0.42, lua_fator))
	env.ambient_light_energy = lerpf(0.022, 0.060, lua_fator)
	env.volumetric_fog_density = lerpf(0.016, 0.0035, alto)
	ar.global_position = foco
	_t -= dt
	if _t <= 0.0:
		_t = 0.2
		_varre(2)
	_mato_passo(1)
	_tc -= dt
	if _tc <= 0.0:
		_tc = 0.22
		_atualiza_colisores()
