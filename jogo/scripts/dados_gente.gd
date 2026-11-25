class_name DadosGente
extends Resource
## Pessoa assada por ferr/gente_assar.gd.

@export var rosto: ArrayMesh
@export var corpo: ArrayMesh
@export var sup_rosto: PackedStringArray
@export var sup_corpo: PackedStringArray
@export var ossos: PackedStringArray
@export var pais: PackedInt32Array
@export var pos: PackedVector3Array
@export var tex := {}
@export var altura := 1.75
@export var topo := Vector3.ZERO
@export var cab_cor := Color.BLACK
@export var barba := 0.0
@export var cranio := Vector2(0.08, 0.1)
@export var fem := false
@export var etnia := "caucasian"
@export var lenco := Color(0, 0, 0, 0)
@export var gorro := Color(0, 0, 0, 0)
@export var cachecol := Color(0, 0, 0, 0)