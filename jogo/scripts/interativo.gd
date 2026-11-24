class_name Interativo
extends Node3D
## Algo que o jogador pode usar com [E].

signal usado

var texto := "Usar"
var raio := 2.3
var ativo := true
var segurar := 0.0      # segundos segurando E (0 = toque)
var acao: Callable


static func criar(pai: Node3D, pos: Vector3, txt: String, f: Callable, r: float = 2.3, seg: float = 0.0) -> Interativo:
	var i := Interativo.new()
	i.texto = txt
	i.acao = f
	i.raio = r
	i.segurar = seg
	i.add_to_group("interativo")
	pai.add_child(i)
	i.position = pos
	return i


func usar() -> void:
	if not ativo:
		return
	usado.emit()
	if acao.is_valid():
		acao.call()
