class_name Pedra
extends Node3D
## Pedra arremessada: faz barulho onde cai e distrai a criatura.

var v := Vector3.ZERO
var _viva := true


func _ready() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.07
	s.radial_segments = 8
	s.rings = 4
	m.mesh = s
	m.material_override = Mat.pbr("mossy_rock", 0.2)
	add_child(m)


func _physics_process(dt: float) -> void:
	if not _viva:
		return
	v.y -= 11.0 * dt
	global_position += v * dt
	var bateu := global_position.y <= Mundo.altura(global_position.x, global_position.z)
	for i in Mundo.arvores_perto(global_position, 1.2):
		var d := Vector2(Mundo.dados.arv[i * 6] - global_position.x, Mundo.dados.arv[i * 6 + 2] - global_position.z).length()
		if d < Mundo.raio_tronco(i) + 0.05:
			bateu = true
	if bateu:
		_viva = false
		Som.em("pedra", global_position, 4.0, 60)
		Som.em("galho%d" % randi_range(1, 4), global_position, -4.0, 60)
		if Jogo.criatura:
			Jogo.criatura.ouvir(global_position, 55.0)
		get_tree().create_timer(4.0).timeout.connect(queue_free)
