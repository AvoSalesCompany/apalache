class_name LuzFogo
extends OmniLight3D
## Luz que tremula (fogo, lampada ruim).

var base := 2.0
var falha := false
var _t := randf() * 100.0
var _p := Vector3.INF


func _ready() -> void:
	omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	set_meta("sombra", shadow_enabled)
	distance_fade_enabled = true
	distance_fade_begin = 60.0
	distance_fade_shadow = 24.0


func _process(dt: float) -> void:
	_t += dt
	if _p == Vector3.INF:
		_p = position
	if falha:
		var n := sin(_t * 31.0) * sin(_t * 17.3) + sin(_t * 3.1)
		light_energy = base * (1.0 if n > -0.55 else 0.08)
	else:
		light_energy = base * (0.80 + 0.12 * sin(_t * 9.1) + 0.10 * sin(_t * 14.7 + 1.3) + 0.06 * sin(_t * 27.0))
		position = _p + Vector3(sin(_t * 7.0), sin(_t * 9.0), cos(_t * 8.0)) * 0.035
