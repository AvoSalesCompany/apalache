class_name Pegadas
extends RefCounted
## Pegadas do jogador na neve (decais em rodizio).

static var _l: Array = []
static var _i := 0
static var _lado := 1.0
static var _tex: ImageTexture
static var _nor: ImageTexture


static func _faz() -> void:
	var n := 96
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var h := PackedFloat32Array()
	h.resize(n * n)
	for y in n:
		for x in n:
			var p := Vector2((x - n * 0.5) / (n * 0.5), (y - n * 0.5) / (n * 0.5))
			var sola := Vector2(p.x / 0.44, (p.y + 0.22) / 0.50).length()
			var salto := Vector2(p.x / 0.36, (p.y - 0.52) / 0.30).length()
			var d := minf(sola, salto)
			var v := 1.0 - smoothstep(0.82, 1.06, d)
			var trava := 0.82 + 0.18 * signf(sin(p.y * 26.0))
			h[y * n + x] = v
			im.set_pixel(x, y, Color(0.50, 0.58, 0.70, v * 0.62 * trava))
	im.generate_mipmaps()
	_tex = ImageTexture.create_from_image(im)
	var nm := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var gx := h[y * n + mini(x + 1, n - 1)] - h[y * n + maxi(x - 1, 0)]
			var gy := h[mini(y + 1, n - 1) * n + x] - h[maxi(y - 1, 0) * n + x]
			var v := Vector3(gx * 3.0, -gy * 3.0, 1.0).normalized()
			nm.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5, 1.0))
	nm.generate_mipmaps()
	_nor = ImageTexture.create_from_image(nm)


static func por(pai: Node3D, p: Vector3, giro: float, corre: bool) -> void:
	if _tex == null: _faz()
	_l = _l.filter(func(q): return is_instance_valid(q))
	_lado = -_lado
	var d: Decal
	if _l.size() < 70:
		d = Decal.new()
		d.texture_albedo = _tex
		d.texture_normal = _nor
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.normal_fade = 0.1
		d.cull_mask = 1
		pai.add_child(d)
		_l.append(d)
	else:
		_i = (_i + 1) % _l.size()
		d = _l[_i]
	d.size = Vector3(0.17, 0.6, 0.33 if not corre else 0.36)
	var b := Basis(Vector3.UP, giro)
	d.global_transform = Transform3D(b * Basis(Vector3.UP, 0.10 * _lado), p + b * Vector3(0.11 * _lado, 0.0, 0))