class_name Rifle
extends Node3D
## Rifle de ferrolho: modelo na mao, mira, tiro, ferrolho e recarga.

const PENTE := 5
var tem := false
var na_mao := false
var pente := PENTE
var _m: Node3D
var _t := 0.0                 # tempo ate poder atirar de novo
var _rec := 0.0               # coice
var _mira := 0.0
var _sobe := 0.0
var _recarrega := 0.0
var _clarao: OmniLight3D
var _fogo: MeshInstance3D


func _ready() -> void:
	top_level = true
	_m = Node3D.new()
	add_child(_m)
	_clarao = OmniLight3D.new()
	_clarao.light_color = Color(1.0, 0.72, 0.36)
	_clarao.omni_range = 12.0
	_clarao.light_energy = 0.0
	add_child(_clarao)
	_fogo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	q.material = Mat.sprite(Color(1, 0.8, 0.4), 7.0, true)
	_fogo.mesh = q
	_fogo.visible = false
	add_child(_fogo)
	visible = false


func pegar() -> void:
	tem = true
	if _m.get_child_count() == 0: Itens.rifle(_m)
	_orienta()
	na_mao = true
	Som.toca("ferrolho", -4)


## o modelo pode vir com o cano em qualquer eixo: descobre pelo tamanho
func _orienta() -> void:
	var bb := AABB()
	var pri := true
	for q in Mat.malhas_de("bolt_action_rifle_7_62"):
		var b: AABB = (q[1] as Transform3D) * (q[0] as Mesh).get_aabb()
		bb = b if pri else bb.merge(b)
		pri = false
	if bb.size.x > bb.size.z: _m.rotation.y = PI * 0.5


func alternar() -> void:
	if not tem: return
	na_mao = not na_mao
	Som.toca("ferrolho", -12, 1.2)


func mirando() -> bool:
	return na_mao and _mira > 0.5


func recarregar() -> void:
	if not na_mao or _recarrega > 0.0 or pente >= PENTE: return
	if Jogo.tem("municao") <= 0:
		Jogo.aviso.emit("Sem munição")
		return
	_recarrega = 1.9
	Som.toca("ferrolho", -2, 0.9)


func atirar(j: Jogador) -> void:
	if not na_mao or _t > 0.0 or _recarrega > 0.0: return
	if pente <= 0:
		Som.toca("radio_clique", -6, 0.8)
		recarregar()
		return
	pente -= 1
	_t = 1.35
	_rec = 1.0
	Som.toca("tiro", 3)
	j.tremer(0.22)
	j.incl = minf(1.4, j.incl + 0.045)
	j.ruido = 90.0
	_clarao.light_energy = 9.0
	_fogo.visible = true
	_fogo.rotation.z = randf() * TAU
	get_tree().create_timer(0.55, false).timeout.connect(func(): Som.toca("ferrolho", -5))
	# acerto
	var o := j.cam.global_position
	var d := -j.cam.global_transform.basis.z
	var esp := 0.004 if mirando() else 0.022
	d = (d + j.cam.global_transform.basis.x * randf_range(-esp, esp) + j.cam.global_transform.basis.y * randf_range(-esp, esp)).normalized()
	var c: Criatura = Jogo.criatura
	if c.visible and not c.morta and c.estado != Criatura.E.OCULTO:
		var base := c.global_position + Vector3.UP * 0.3
		var topo := c.altura_cabeca()
		var pts := Geometry3D.get_closest_points_between_segments(o, o + d * 120.0, base, topo)
		var dist := pts[0].distance_to(pts[1])
		var q := PhysicsRayQueryParameters3D.create(o, pts[0])
		q.exclude = [j.get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		var livre: bool = h.is_empty() or (h.position as Vector3).distance_to(pts[0]) < 0.8 or h.collider is RigidBody3D
		if dist < 0.55 and livre:
			c.baleada(pts[1])
			return
	# marca na neve / madeira
	var q2 := PhysicsRayQueryParameters3D.create(o, o + d * 90.0)
	q2.exclude = [j.get_rid()]
	var h2 := get_world_3d().direct_space_state.intersect_ray(q2)
	if not h2.is_empty():
		Som.em("p_neve%d" % randi_range(1, 5), h2.position, 4.0, 40, 0.7)
		if h2.collider is RigidBody3D: h2.collider.apply_impulse(d * 12.0, h2.position - h2.collider.global_position)


func atualiza(dt: float, j: Jogador, balanco: float) -> void:
	_t = maxf(0.0, _t - dt)
	_rec = move_toward(_rec, 0.0, dt * 3.4)
	_clarao.light_energy = move_toward(_clarao.light_energy, 0.0, dt * 120.0)
	if _clarao.light_energy < 4.0: _fogo.visible = false
	if _recarrega > 0.0:
		_recarrega -= dt
		if _recarrega <= 0.0:
			while pente < PENTE and Jogo.gastar("municao"): pente += 1
			Som.toca("ferrolho", -3)
	var quer := na_mao and tem and not j.travado and not j.morto and j.carrega == null
	_sobe = move_toward(_sobe, 1.0 if quer else 0.0, dt * 3.2)
	visible = _sobe > 0.02
	if not visible: return
	_mira = move_toward(_mira, 1.0 if j._ac("foco") and quer and _recarrega <= 0.0 else 0.0, dt * 5.0)
	var m := smoothstep(0.0, 1.0, _mira)
	var pos := Vector3(0.17, -0.175, -0.46).lerp(Vector3(0.006, -0.0795, -0.40), m)
	pos += Vector3(cos(balanco) * 0.006, sin(balanco * 2.0) * 0.007, 0) * (1.0 - m * 0.8)
	pos += Vector3(0, 0.012, 0.085) * _rec
	pos.y -= (1.0 - smoothstep(0.0, 1.0, _sobe)) * 0.5
	var rx := _rec * 0.10 - (1.0 - _sobe) * 0.9
	if _recarrega > 0.0:
		var k := sin(clampf(_recarrega / 1.9, 0, 1) * PI)
		pos += Vector3(0.0, -0.06, 0.04) * k
		rx += 0.35 * k
	elif _t > 0.2 and _t < 1.0:
		var k := sin((1.0 - _t) / 0.8 * PI)
		rx += 0.05 * k
		pos += Vector3(0.01, -0.01, 0.02) * k
	var ct := j.cam.global_transform
	global_transform = Transform3D(ct.basis * Basis.from_euler(Vector3(rx, 0.03 * (1.0 - m), 0.0)), ct * pos)
	_clarao.position = Vector3(0, 0.03, -0.75)
	_fogo.position = Vector3(0, 0.03, -0.66)