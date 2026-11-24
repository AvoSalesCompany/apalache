class_name ObjetoFisico
extends RigidBody3D
## Objeto com peso de verdade: da para empurrar, pegar (E), soltar e arremessar.
## Barulho de queda atrai a criatura.

var nome := "objeto"
var som := "p_madeira"
var pesado := false
var _t := 0.0


func _init() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	angular_damp = 0.6
	linear_damp = 0.05
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.08
	physics_material_override = pm
	add_to_group("sem_col")


func _ready() -> void:
	body_entered.connect(_bateu)


func _physics_process(dt: float) -> void:
	_t = maxf(0.0, _t - dt)
	# nunca some pelo chao
	var y := Mundo.altura(global_position.x, global_position.z)
	if global_position.y < y - 1.5:
		global_position.y = y + 0.4
		linear_velocity = Vector3.ZERO


func _bateu(_b: Node) -> void:
	var v := linear_velocity.length()
	if v < 1.3 or _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.25
	Som.em("%s%d" % [som, randi_range(1, 4)], global_position, clampf(-14.0 + v * 2.2, -14.0, 3.0), 45, randf_range(0.8, 1.1), "Eco", 4.0)
	if v > 2.5 and Jogo.criatura and Jogo.flags.get("vivo", false):
		Jogo.criatura.ouvir(global_position, 18.0 + v * 4.0)


static func _caixa(b: ObjetoFisico, pos: Vector3, tam: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tam
	c.shape = s
	c.position = pos
	c.rotation = rot
	b.add_child(c)


static func poltrona(pai: Node3D, pos: Vector3, rot: Vector3) -> ObjetoFisico:
	var b := ObjetoFisico.new()
	b.nome = "poltrona"
	b.mass = 14.0
	b.pesado = true
	b.som = "p_metal"
	pai.add_child(b)
	b.position = pos
	b.rotation = rot
	Aeronave.poltrona_no(b, Vector3(0, -0.55, 0))
	_caixa(b, Vector3(0, -0.30, 0.02), Vector3(0.48, 0.48, 0.46))
	_caixa(b, Vector3(0, 0.22, 0.30), Vector3(0.44, 0.76, 0.14), Vector3(0.2, 0, 0))
	return b


static func mala(pai: Node3D, pos: Vector3, tam: Vector3, ry: float, cor: Color) -> ObjetoFisico:
	var b := ObjetoFisico.new()
	b.nome = "mala"
	b.mass = 5.0
	pai.add_child(b)
	b.position = pos
	b.rotation = Vector3(0.2, ry, 0.15)
	var m := Malha.new()
	m.cx(Vector3.ZERO, tam)
	m.no(Aeronave.m_forro(cor, 0.6, 0.0, 0.7), b)
	var d := Malha.new()
	d.cx(Vector3.ZERO, Vector3(tam.x * 1.012, tam.y * 0.07, tam.z * 1.015))
	for sx in [-1.0, 1.0]:
		d.cx(Vector3(tam.x * 0.28 * sx, 0, 0), Vector3(0.035, tam.y * 1.03, tam.z * 1.03))
		for sz in [-1.0, 1.0]:
			d.cx(Vector3(tam.x * 0.485 * sx, 0, tam.z * 0.475 * sz), Vector3(0.05, tam.y * 1.04, 0.05))
	var hx := tam.x * 0.14
	d.tubo([Vector3(-hx, 0, tam.z * 0.5), Vector3(-hx * 0.9, 0, tam.z * 0.5 + 0.05), Vector3(hx * 0.9, 0, tam.z * 0.5 + 0.05), Vector3(hx, 0, tam.z * 0.5)], [0.012, 0.014, 0.014, 0.012], 8)
	d.no(Mat.liso(Color(0.05, 0.04, 0.035), 0.5), b)
	var f := Malha.new()
	for sx in [-1.0, 1.0]:
		f.cx(Vector3(tam.x * 0.2 * sx, 0, tam.z * 0.505), Vector3(0.05, 0.03, 0.012))
	f.no(Mat.liso(Color(0.45, 0.40, 0.25), 0.3, 0.9), b)
	_caixa(b, Vector3.ZERO, tam)
	return b


static func lata(pai: Node3D, pos: Vector3, cor: Color = Color(0.4, 0.1, 0.06)) -> ObjetoFisico:
	var b := ObjetoFisico.new()
	b.nome = "lata"
	b.mass = 0.4
	b.som = "p_metal"
	pai.add_child(b)
	b.position = pos
	var m := Malha.new()
	m.tubo([Vector3(0, -0.055, 0), Vector3(0, -0.05, 0), Vector3(0, 0.05, 0), Vector3(0, 0.055, 0)], [0.034, 0.036, 0.036, 0.034], 16, 1, 1, Color(0, 0, 0.5), true)
	m.no(Mat.liso(cor, 0.4, 0.4), b)
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.036
	s.height = 0.11
	c.shape = s
	b.add_child(c)
	return b


## movel do Poly Haven como corpo rigido
static func movel(pai: Node3D, id: String, pos: Vector3, ry: float, alvo: float, massa: float, nm: String, snd: String = "p_madeira") -> ObjetoFisico:
	var b := ObjetoFisico.new()
	b.nome = nm
	b.mass = massa
	b.pesado = massa > 10.0
	b.som = snd
	pai.add_child(b)
	var bb := AABB()
	var pri := true
	for q in Mat.malhas_de(id):
		var a: AABB = (q[1] as Transform3D) * (q[0] as Mesh).get_aabb()
		bb = a if pri else bb.merge(a)
		pri = false
	var e := alvo / bb.size.y
	for q in Mat.malhas_de(id):
		var mi := MeshInstance3D.new()
		mi.mesh = q[0]
		var t: Transform3D = q[1]
		mi.transform = Transform3D(t.basis.scaled(Vector3.ONE * e), (t.origin - bb.get_center()) * e)
		b.add_child(mi)
		var c := CollisionShape3D.new()
		c.shape = (q[0] as Mesh).create_convex_shape(true, true)
		c.transform = mi.transform
		b.add_child(c)
	b.position = pos + Vector3.UP * (bb.size.y * e * 0.5 + 0.02)
	b.rotation.y = ry
	return b
