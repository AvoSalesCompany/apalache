class_name Malha
extends RefCounted
## Construtor de malhas: tubos, caixas, cartoes de folhagem, fitas.
## cor.r = peso do vento | cor.g = tremor da folha | cor.b = variacao | cor.a = livre

var v := PackedVector3Array()
var n := PackedVector3Array()
var t := PackedFloat32Array()
var uv := PackedVector2Array()
var c := PackedColorArray()
var idx := PackedInt32Array()


func vert(p: Vector3, no: Vector3, u: Vector2, tg: Vector3 = Vector3.RIGHT, cor: Color = Color(0, 0, 0.5, 1), w: float = 1.0) -> int:
	v.push_back(p)
	n.push_back(no)
	uv.push_back(u)
	t.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, w]))
	c.push_back(cor)
	return v.size() - 1


func tri(a: int, b: int, d: int) -> void:
	idx.push_back(a)
	idx.push_back(b)
	idx.push_back(d)


func quad(a: int, b: int, d: int, e: int) -> void:
	tri(a, b, d)
	tri(a, d, e)


## Tubo ao longo de pontos. raios: um por ponto.
func tubo(pts: Array, raios: Array, lados: int, uv_comp: float = 1.0, uv_volta: float = 1.0, cor: Color = Color(0, 0, 0.5, 1), tampa: bool = false, raiz: float = 0.0) -> void:
	var np := pts.size()
	var up := Vector3.RIGHT
	var base := v.size()
	var acum := 0.0
	for i in np:
		var dir: Vector3
		if i == 0:
			dir = (pts[1] - pts[0]).normalized()
		elif i == np - 1:
			dir = (pts[i] - pts[i - 1]).normalized()
		else:
			dir = (pts[i + 1] - pts[i - 1]).normalized()
		if i > 0:
			acum += (pts[i] as Vector3).distance_to(pts[i - 1])
		var lado := dir.cross(up)
		if lado.length_squared() < 0.001:
			lado = dir.cross(Vector3.FORWARD)
		lado = lado.normalized()
		up = lado.cross(dir).normalized()
		for k in lados + 1:
			var a := TAU * k / lados
			var rn := lado * cos(a) + up * sin(a)
			var r: float = raios[i]
			if raiz > 0.0 and i < 3:
				r *= 1.0 + raiz * (1.0 - i / 3.0) * (0.35 + 0.65 * pow(absf(sin(a * 2.5 + 0.7)), 1.5))
			var tg := (-lado * sin(a) + up * cos(a))
			vert(pts[i] + rn * r, rn, Vector2(float(k) / lados * uv_volta, -acum * uv_comp), tg, cor, -1.0)
	for i in np - 1:
		for k in lados:
			var a0 := base + i * (lados + 1) + k
			var b0 := a0 + lados + 1
			quad(a0, a0 + 1, b0 + 1, b0)
	if tampa:
		for ponta in [0, np - 1]:
			var dirp: Vector3 = (pts[0] - pts[1]).normalized() if ponta == 0 else (pts[np - 1] - pts[np - 2]).normalized()
			var cen := vert(pts[ponta], dirp, Vector2(0.5, 0.5), Vector3.RIGHT, cor)
			var b2 = base + ponta * (lados + 1)
			var ini := v.size()
			for k in lados + 1:
				var a := TAU * k / lados
				vert(v[b2 + k], dirp, Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)), Vector3.RIGHT, cor)
			for k in lados:
				if ponta == 0:
					tri(cen, ini + k + 1, ini + k)
				else:
					tri(cen, ini + k, ini + k + 1)


## Cartao (quad) que nasce em 'o', vai 'comp' na direcao 'dir', com largura 'larg' em 'lado'.
func cartao(o: Vector3, dir: Vector3, lado: Vector3, comp: float, larg: float, centro: Vector3, esfer: float = 0.7, tremor: float = 1.0, uvr: Rect2 = Rect2(0, 0, 1, 1), horizontal: bool = false, queda: float = 0.0) -> void:
	var fn := lado.cross(dir).normalized()
	var segs := 1 if queda == 0.0 else 2
	var ini := v.size()
	var varia := fposmod(o.x * 3.17 + o.y * 1.37 + o.z * 2.31, 1.0)
	for i in segs + 1:
		var f := float(i) / segs
		var p := o + dir * comp * f + Vector3.DOWN * queda * f * f
		for s in 2:
			var q := p + lado * larg * (float(s) - 0.5)
			var no := fn.lerp((q - centro).normalized(), esfer).normalized()
			var u: Vector2
			if horizontal:
				u = Vector2(uvr.position.x + uvr.size.x * f, uvr.position.y + uvr.size.y * s)
			else:
				u = Vector2(uvr.position.x + uvr.size.x * s, uvr.position.y + uvr.size.y * (1.0 - f))
			vert(q, no, u, lado, Color(0, tremor * f, varia, 1))
	for i in segs:
		var a := ini + i * 2
		quad(a, a + 1, a + 3, a + 2)


## Caixa com UV em metros (bom para madeira/metal).
func caixa(tr: Transform3D, tam: Vector3, uv_esc: float = 1.0, cor: Color = Color(0, 0, 0.5, 1), giro_uv: bool = false) -> void:
	var h := tam * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	var off := Vector2(fposmod(tr.origin.x * 0.37 + tr.origin.z * 0.71, 1.0), fposmod(tr.origin.y * 0.53 + tr.origin.x * 0.19, 1.0))
	for f in faces:
		var fn: Vector3 = f[0]
		var fu: Vector3 = f[1]
		var fv: Vector3 = f[2]
		var ini := v.size()
		var su := absf(fu.dot(tam))
		var sv := absf(fv.dot(tam))
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p = fn * h + fu * h * q.x + fv * h * q.y
			var tx := Vector2((q.x * 0.5 + 0.5) * su, (0.5 - q.y * 0.5) * sv) * uv_esc + off
			if giro_uv:
				tx = Vector2(tx.y, tx.x)
			vert(tr * p, (tr.basis * fn).normalized(), tx, (tr.basis * fu).normalized(), cor, signf(fn.dot(fu.cross(fv))))
		if fn.dot(fu.cross(fv)) > 0.0:
			quad(ini, ini + 3, ini + 2, ini + 1)
		else:
			quad(ini, ini + 1, ini + 2, ini + 3)


func cx(pos: Vector3, tam: Vector3, rot: Vector3 = Vector3.ZERO, uv_esc: float = 1.0, giro_uv: bool = false) -> void:
	caixa(Transform3D(Basis.from_euler(rot), pos), tam, uv_esc, Color(0, 0, 0.5, 1), giro_uv)


## Viga entre dois pontos.
func viga(a: Vector3, b: Vector3, esp: float, uv_esc: float = 1.0, alt: float = -1.0) -> void:
	var d := b - a
	var l := d.length()
	var z := d / l
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	caixa(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(esp, esp if alt < 0.0 else alt, l), uv_esc)


func anexar(o: Malha, tr: Transform3D) -> void:
	var b := v.size()
	for i in o.v.size():
		v.push_back(tr * o.v[i])
		n.push_back((tr.basis * o.n[i]).normalized())
		var tg := (tr.basis * Vector3(o.t[i * 4], o.t[i * 4 + 1], o.t[i * 4 + 2])).normalized()
		t.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, o.t[i * 4 + 3]]))
	uv.append_array(o.uv)
	c.append_array(o.c)
	for i in o.idx:
		idx.push_back(i + b)


func vento(altura: float, expo: float = 1.7, forca: float = 1.0) -> void:
	for i in v.size():
		var k := c[i]
		k.r = clampf(pow(maxf(v[i].y, 0.0) / altura, expo) * forca, 0.0, 1.0)
		c[i] = k


func escala_total(e: float) -> void:
	for i in v.size():
		v[i] *= e


func aplicar(m: ArrayMesh, mat: Material) -> ArrayMesh:
	if v.is_empty():
		return m
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TANGENT] = t
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	if mat:
		m.surface_set_material(m.get_surface_count() - 1, mat)
	return m


func malha(mat: Material) -> ArrayMesh:
	return aplicar(ArrayMesh.new(), mat)


func no(mat: Material, pai: Node = null, sombra: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha(mat)
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if pai:
		pai.add_child(mi)
	return mi
