class_name Vigia
extends Node3D
## Um dos dezoito. Fica parado, longe, olhando. Nunca corre atras: some.

var olhos: StandardMaterial3D
var braco: Node3D
var corpo: MeshInstance3D
var modo := ""               # "", acena, costas
var visto := 0.0
var vida := 0.0
var alvo_vira := 0.0
var _t := randf() * 10.0

const CAMISAS := [Color(0.20, 0.17, 0.14), Color(0.10, 0.12, 0.16), Color(0.22, 0.20, 0.18), Color(0.14, 0.08, 0.07), Color(0.12, 0.14, 0.10)]


func montar(acena: bool = false) -> Vigia:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/humano.gdshader")
	m.set_shader_parameter("camisa", CAMISAS[randi() % CAMISAS.size()])
	m.set_shader_parameter("calca", Color(0.05, 0.05, 0.06))
	m.set_shader_parameter("pele", Color(0.21, 0.195, 0.18))
	m.set_shader_parameter("cabelo", Color(0.012, 0.010, 0.010))
	corpo = MeshInstance3D.new()
	corpo.mesh = load("res://dados/vigia%d.res" % (1 if acena else 0))
	corpo.material_override = m
	add_child(corpo)
	if acena:
		modo = "acena"
		braco = Node3D.new()
		braco.position = Vector3(0.22, 1.64, 0)
		add_child(braco)
		var b := MeshInstance3D.new()
		b.mesh = load("res://dados/vigia2.res")
		b.material_override = m
		braco.add_child(b)
	olhos = StandardMaterial3D.new()
	olhos.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	olhos.albedo_color = Color(0, 0, 0)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.0135
		s.height = 0.027
		s.radial_segments = 8
		s.rings = 4
		e.mesh = s
		e.material_override = olhos
		e.position = Vector3(0.045 + 0.034 * sx, 2.076 - 0.004 * sx, -0.139)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
	# boca aberta: escura
	var bo := MeshInstance3D.new()
	var sb := SphereMesh.new()
	sb.radius = 0.027
	sb.height = 0.092
	bo.mesh = sb
	bo.position = Vector3(0.027, 1.942, -0.113)
	bo.material_override = Mat.liso(Color(0.002, 0.001, 0.001), 1.0)
	bo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bo)
	return self


func por(p: Vector3, encara: Vector3) -> void:
	global_position = Vector3(p.x, Mundo.altura(p.x, p.z) - 0.04, p.z)
	var d := encara - global_position
	rotation.y = atan2(-d.x, -d.z)


func encarar(p: Vector3, dt: float, vel: float = 3.0) -> void:
	var d := p - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * vel))


func _process(dt: float) -> void:
	_t += dt
	vida += dt
	var j = Jogo.jogador
	if j == null:
		return
	if modo != "costas":
		encarar(j.global_position, dt, 1.2)
	if braco:
		braco.rotation.z = -0.15 + 0.34 * sin(_t * 2.1)
	# olhos devolvem a luz da lanterna
	var luzv: float = j.lanterna.ilumina(global_position + Vector3.UP * 2.05) if j.lanterna else 0.0
	var fr := clampf((-global_transform.basis.z).dot((j.cam.global_position - global_position).normalized()), 0.0, 1.0)
	var k := (0.17 + luzv * 2.6) * fr * (0.0 if fmod(_t, 4.7) < 0.09 else 1.0)
	olhos.albedo_color = Color(0.90, 0.95, 0.80) * k
	# leve tremor errado
	if fmod(_t, 3.3) < 0.05:
		corpo.rotation.z = randf_range(-0.05, 0.05)
	else:
		corpo.rotation.z = lerpf(corpo.rotation.z, 0.0, minf(1.0, dt * 6.0))


## esta no campo de visao, sem tronco na frente?
func na_vista(cone: float = 0.86) -> bool:
	var j = Jogo.jogador
	var c := global_position + Vector3.UP * 1.8
	var d: Vector3 = c - j.cam.global_position
	var l := d.length()
	if l > 70.0: return false
	if (-j.cam.global_transform.basis.z).dot(d / l) < cone: return false
	return Mundo.obstrucao(j.cam.global_position, c) < 0.75
