class_name Lanterna
extends Node3D
## Lanterna de metal dos anos 80: luz amarelada, pilha que acaba, falha perto deles.

var ligada := false
var bateria := 100.0
var apagao := 0.0            # segundos forcada a apagar (sustos)
var falha := 0.0             # 0..1 interferencia
var luz: SpotLight3D
var halo: OmniLight3D
var _modelo: Node3D
var _lente: StandardMaterial3D
var _q := Quaternion.IDENTITY
var _t := 0.0
var _pos := Vector3(0.24, -0.23, -0.40)

static var _proj: ImageTexture


## mancha de luz: ponto quente, aneis e borda irregular, como lampada com refletor
static func projetor() -> ImageTexture:
	if _proj:
		return _proj
	var n := 256
	var im := Image.create(n, n, false, Image.FORMAT_RGB8)
	var ru := FastNoiseLite.new()
	ru.frequency = 0.03
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var r := p.length()
			var a := p.angle()
			var v := 1.05 * exp(-r * r * 13.0) + 0.50 * exp(-pow(r - 0.16, 2.0) * 60.0) * 0.5
			v += 0.30 * (1.0 - smoothstep(0.50, 0.80, r + 0.03 * ru.get_noise_2d(cos(a) * 60.0, sin(a) * 60.0)))
			v += 0.10 * exp(-pow(r - 0.62, 2.0) * 320.0) + 0.06 * exp(-pow(r - 0.40, 2.0) * 420.0)
			v += 0.05 * (1.0 - smoothstep(0.78, 0.99, r))
			v *= 0.92 + 0.10 * ru.get_noise_2d(x * 1.6, y * 1.6)
			v *= 1.0 - smoothstep(0.93, 1.0, r)
			v = clampf(v, 0, 1)
			im.set_pixel(x, y, Color(v, v * (0.97 - 0.06 * r), v * (0.92 - 0.16 * r)))
	im.generate_mipmaps()
	_proj = ImageTexture.create_from_image(im)
	return _proj


static func modelo(pai: Node3D) -> StandardMaterial3D:
	var m := Malha.new()
	m.tubo([Vector3(0, 0, 0.16), Vector3(0, 0, 0.155), Vector3(0, 0, -0.03), Vector3(0, 0, -0.05), Vector3(0, 0, -0.09), Vector3(0, 0, -0.125)], [0.012, 0.0185, 0.0185, 0.021, 0.031, 0.033], 22, 3.0, 2.0, Color(0, 0, 0.5), false)
	m.no(Mat.pbr("rusty_metal_02", 3.0, Color(0.30, 0.31, 0.32), 0.45, 0.9), pai)
	var g := Malha.new()
	for i in 9:
		g.tubo([Vector3(0, 0, 0.12 - i * 0.014), Vector3(0, 0, 0.114 - i * 0.014)], [0.0198, 0.0198], 18)
	g.cx(Vector3(0, 0.021, -0.005), Vector3(0.010, 0.008, 0.028))
	g.no(Mat.liso(Color(0.025, 0.025, 0.028), 0.6), pai)
	var r := Malha.new()
	r.tubo([Vector3(0, 0, -0.122), Vector3(0, 0, -0.128)], [0.034, 0.033], 22)
	r.no(Mat.liso(Color(0.5, 0.5, 0.5), 0.2, 0.95), pai)
	var l := Malha.new()
	l.tubo([Vector3(0, 0, -0.118), Vector3(0, 0, -0.121)], [0.030, 0.030], 22, 1, 1, Color(0, 0, 0.5), true)
	var mt := Mat.liso(Color(0.2, 0.2, 0.18), 0.1, 0, Color(1.0, 0.86, 0.62), 0.01).duplicate() as StandardMaterial3D
	l.no(mt, pai, false)
	return mt


static func spot(pai: Node3D) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = Color(1.0, 0.87, 0.66)
	s.light_energy = 9.5
	s.light_projector = projetor()
	s.spot_range = 34.0
	s.spot_angle = 30.0
	s.spot_attenuation = 0.55
	s.spot_angle_attenuation = 0.35
	s.shadow_enabled = true
	s.shadow_bias = 0.04
	s.shadow_normal_bias = 1.2
	s.shadow_blur = 1.4
	s.light_volumetric_fog_energy = 0.75
	s.light_size = 0.03
	pai.add_child(s)
	return s


func _ready() -> void:
	top_level = true
	_modelo = Node3D.new()
	add_child(_modelo)
	_lente = modelo(_modelo)
	luz = spot(self)
	luz.position = Vector3(0, 0, -0.15)
	luz.visible = false
	halo = OmniLight3D.new()
	halo.light_color = Color(1.0, 0.86, 0.64)
	halo.light_energy = 0.10
	halo.omni_range = 3.0
	halo.position = Vector3(0, 0, -0.3)
	halo.visible = false
	add_child(halo)
	visible = false


func alternar() -> void:
	if Jogo.tem("lanterna") <= 0:
		return
	if not ligada and bateria <= 0.0:
		if Jogo.gastar("pilha"):
			bateria = 100.0
			Jogo.aviso.emit("Você troca as pilhas (%d sobrando)" % Jogo.tem("pilha"))
		else:
			Som.toca("radio_clique", -14, 1.4)
			Jogo.aviso.emit("Sem pilhas")
			return
	ligada = not ligada
	Som.toca("radio_clique", -10, 1.6)


## quanto este ponto esta dentro do facho (0..1)
func ilumina(p: Vector3) -> float:
	if not ligada or not luz.visible:
		return 0.0
	var d := p - luz.global_position
	var l := d.length()
	if l > 32.0 or l < 0.1:
		return 0.0
	var c := (-luz.global_transform.basis.z).dot(d / l)
	return smoothstep(0.885, 0.965, c) * (1.0 - l / 34.0)


func atualiza(dt: float, cam: Camera3D, balanco: float) -> void:
	visible = Jogo.tem("lanterna") > 0
	if not visible:
		ligada = false
		return
	_t += dt
	apagao = maxf(0.0, apagao - dt)
	var alvo := cam.global_transform.basis.get_rotation_quaternion()
	_q = _q.slerp(alvo, minf(1.0, dt * 11.0)) if _q.is_normalized() else alvo
	var off := _pos + Vector3(cos(_t * 1.1) * 0.003, sin(_t * 1.7) * 0.004 + sin(balanco * 2.0) * 0.010, 0)
	global_transform = Transform3D(Basis(_q) * Basis(Vector3.UP, 0.035) * Basis(Vector3.RIGHT, 0.02), cam.global_transform * off)
	if ligada:
		bateria = maxf(0.0, bateria - dt * 0.20)
		if bateria <= 0.0:
			ligada = false
			Som.toca("radio_clique", -8, 0.8)
			Jogo.aviso.emit("A lanterna apagou. [F] troca as pilhas" if Jogo.tem("pilha") > 0 else "A lanterna apagou")
	var f := 1.0
	if bateria < 18.0:
		f *= 0.45 + 0.4 * absf(sin(_t * 7.0)) * (bateria / 18.0 + 0.3)
	if falha > 0.02:
		var n := sin(_t * 43.0) * sin(_t * 27.1 + 2.0) + 0.5 * sin(_t * 9.7)
		f *= 1.0 if n > -0.9 + falha * 1.3 else lerpf(0.6, 0.06, falha)
	var acesa := ligada and apagao <= 0.0
	luz.visible = acesa
	halo.visible = acesa
	luz.light_energy = 9.5 * f
	_lente.emission_energy_multiplier = 9.0 * f if acesa else 0.01
