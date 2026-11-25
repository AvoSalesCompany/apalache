class_name Vila
extends Node3D
## COLD HOLLER: meia duzia de casas de tronco, uma igreja, um galpao e cinco moradores.
## Coordenadas locais com centro na fogueira. Depois do ataque, destruir().

var fl: Floresta
var loc: Locais
var it := {}
var casas := {}               # id -> Node3D (metas: telhado, troncos, fumaca, porta)
var gente := {}               # id -> Gente
var janelas: Array = []       # [material, forca, casa]
var lampioes: Array = []      # [OmniLight3D, material]
var fogueira: Node3D
var fogao: LuzFogo
var luz_mesa: OmniLight3D
var porta_ruth: Node3D
var porta_aberta := false
var portas_galpao: Array = []
var destruida := false
var ruina: Node3D
var _t := 0.0

const CASAS := {
	"ruth": [Vector2(-17, -13), 4.2, 3.4],
	"elias": [Vector2(15, -19), 3.2, 2.8],
	"caleb": [Vector2(27, 8), 3.4, 2.9],
	"hannah": [Vector2(-21, 18), 3.1, 2.7],
	"velha": [Vector2(-5, 29), 3.0, 2.6],
}
const GALPAO := Vector2(11, 23)
const IGREJA := Vector2(-1, -29)


func construir(f: Floresta, passo: Callable) -> void:
	fl = f
	loc = f.locais
	position = Mundo.chaov(Mundo.VILA)
	for id in CASAS:
		_casa(id, CASAS[id][0], CASAS[id][1], CASAS[id][2], id == "ruth")
	await passo.call("Erguendo a vila", 0.89)
	_interior_ruth()
	_igreja()
	_galpao()
	_praca()
	loc.colidir(self)
	await passo.call("Acendendo os lampioes", 0.92)
	_moradores()
	await passo.call("Chamando os moradores", 0.95)


## ponto local -> chao (em coordenadas locais)
func ch(x: float, z: float) -> Vector3:
	return Vector3(x, Mundo.altura(position.x + x, position.z + z) - position.y, z)


func mundo(x: float, z: float) -> Vector3:
	return Mundo.chao(position.x + x, position.z + z)


func _para_centro(p: Vector2) -> float:
	return atan2(-p.x, -p.y)


# ------------------------------------------------------------------ casas
func _parede(m: Malha, a: Vector3, b: Vector3, H: float, aber: Array, desl: float, r: float = 0.135) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / L
	var n := int(H / (r * 1.75))
	for i in n:
		var y := r + i * r * 1.75 + desl
		var segs := [[-0.26, L + 0.26]]
		for q in aber:
			if y > q[2] - 0.05 and y < q[3] + 0.05:
				var ns := []
				for s in segs:
					if q[1] <= s[0] or q[0] >= s[1]: ns.append(s)
					else:
						if q[0] > s[0]: ns.append([s[0], q[0]])
						if q[1] < s[1]: ns.append([q[1], s[1]])
				segs = ns
		for s in segs:
			var p0: Vector3 = a + d * s[0] + Vector3.UP * y
			var p1: Vector3 = a + d * s[1] + Vector3.UP * y
			var jit := r * (1.0 + 0.06 * sin(i * 12.9 + s[0] * 3.0))
			m.tubo([p0, p0.lerp(p1, 0.5), p1], [jit, jit * 1.04, jit * 0.97], 9, 0.6, 2.0, Color(0, 0, 0.5), true)


func _casa(id: String, p: Vector2, W: float, D: float, aberta: bool) -> void:
	var g := Node3D.new()
	add_child(g)
	g.position = ch(p.x, p.y) + Vector3.UP * 0.42
	g.rotation.y = _para_centro(p)
	casas[id] = g
	var H := 2.55
	var xp := -1.5 if aberta else 0.0             # onde fica a porta
	var tr := Malha.new()
	# aberturas por parede: [u0, u1, y0, y1]
	var fr_ab := [[W + xp - 0.5, W + xp + 0.5, 0.0, 2.05]]
	var la_ab := []
	var fu_ab := []
	if aberta:
		fr_ab.append([W + 1.9, W + 3.0, 0.95, 1.80])
		la_ab.append([D - 0.5, D + 0.5, 0.95, 1.80])
		fu_ab.append([W - 2.6, W - 1.5, 0.95, 1.80])
	_parede(tr, Vector3(-W, 0, D), Vector3(W, 0, D), H, fr_ab, 0.12)
	_parede(tr, Vector3(-W, 0, -D), Vector3(W, 0, -D), H, fu_ab, 0.12)
	_parede(tr, Vector3(-W, 0, -D), Vector3(-W, 0, D), H, la_ab, 0.0)
	_parede(tr, Vector3(W, 0, -D), Vector3(W, 0, D), H, la_ab, 0.0)
	var mt := Mat.casca("bark_brown_02", Color(0.60, 0.55, 0.50), 0.0, 0.0).duplicate() as ShaderMaterial
	mt.set_shader_parameter("neve", 0.0 if aberta else 0.35)
	tr.no(mt, g)
	g.set_meta("troncos", mt)
	var md := Malha.new()
	var al := Malha.new()
	al.cx(Vector3(0, -1.14, 0), Vector3(W * 2 + 0.3, 2.2, D * 2 + 0.3), Vector3.ZERO, 0.5)
	al.no(Mat.pbr("mossy_rock", 0.7, Color(0.62, 0.62, 0.62)), g)
	for i in int(W * 2 / 0.35):
		md.cx(Vector3(-W + 0.18 + i * 0.35, -0.02, 0), Vector3(0.335, 0.06, D * 2.0), Vector3(0, 0, sin(i * 7.0) * 0.006), 0.5, true)
	# varanda
	for i in int(W * 2 / 0.5):
		md.cx(Vector3(-W + 0.25 + i * 0.5, -0.05, D + 0.85), Vector3(0.48, 0.06, 1.6), Vector3(sin(i * 5.0) * 0.012, 0, 0), 0.5, true)
	for sx in [-1.0, 1.0]:
		md.cx(Vector3((W - 0.15) * sx, 1.1, D + 1.55), Vector3(0.14, 2.3, 0.14))
		md.viga(Vector3((W - 0.15) * sx, 0.85, D + 0.1), Vector3((W - 0.15) * sx, 0.85, D + 1.5), 0.07)
	for k in 3:
		md.cx(Vector3(xp, -0.14 - k * 0.14, D + 1.78 + k * 0.28), Vector3(1.3, 0.06, 0.30))
	for sx in [-0.52, 0.52]: md.cx(Vector3(xp + sx, 1.03, D + 0.02), Vector3(0.1, 2.1, 0.32))
	md.cx(Vector3(xp, 2.12, D + 0.02), Vector3(1.14, 0.1, 0.32))
	# janelas
	var vd := StandardMaterial3D.new()
	vd.albedo_color = Color(0.10, 0.07, 0.04)
	vd.roughness = 0.1
	vd.emission_enabled = true
	vd.emission = Color(1.0, 0.60, 0.26)
	vd.emission_energy_multiplier = 0.0
	janelas.append([vd, randf_range(0.7, 1.3), id])
	var vm := Malha.new()
	var js := []
	if aberta:
		js = [[Vector3(2.45, 1.375, D), 0.0, 1.1], [Vector3(-W, 1.375, 0), PI * 0.5, 1.0], [Vector3(W, 1.375, 0), PI * 0.5, 1.0], [Vector3(-2.05, 1.375, -D), 0.0, 1.1]]
	else:
		js = [[Vector3(-W * 0.58, 1.4, D + 0.15), 0.0, 0.9], [Vector3(W * 0.58, 1.4, D + 0.15), 0.0, 0.9], [Vector3(-W - 0.15, 1.4, 0.2), PI * 0.5, 0.9], [Vector3(W + 0.15, 1.4, 0.2), PI * 0.5, 0.9]]
	for q in js:
		var bs := Basis(Vector3.UP, q[1])
		var w: float = q[2]
		var esp := 0.34 if aberta else 0.12
		for y in [-0.46, 0.46]: md.caixa(Transform3D(bs, q[0] + Vector3.UP * y), Vector3(w + 0.14, 0.08, esp), 0.6)
		for x in [-0.5, 0.5]: md.caixa(Transform3D(bs, q[0] + bs * Vector3((w + 0.04) * x, 0, 0)), Vector3(0.08, 0.92, esp), 0.6)
		md.caixa(Transform3D(bs, q[0]), Vector3(0.045, 0.9, 0.06), 0.6)
		md.caixa(Transform3D(bs, q[0]), Vector3(w, 0.045, 0.06), 0.6)
		vm.caixa(Transform3D(bs, q[0]), Vector3(w, 0.86, 0.012))
	if aberta:
		var vt := StandardMaterial3D.new()
		vt.albedo_color = Color(0.55, 0.62, 0.68, 0.16)
		vt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vt.roughness = 0.08
		vt.cull_mode = BaseMaterial3D.CULL_DISABLED
		vm.no(vt, g, false)
	else:
		vm.no(vd, g, false)
	# cumeeira e oitao
	var pico := H + 1.45
	md.viga(Vector3(-W - 0.55, pico - 0.05, 0), Vector3(W + 0.55, pico - 0.05, 0), 0.16)
	for i in 5:
		var x := -W + i * (W * 2 / 4.0)
		for sz in [-1.0, 1.0]:
			md.viga(Vector3(x, pico - 0.08, 0), Vector3(x, H - 0.05, (D + 0.5) * sz), 0.11)
	if aberta:
		for x in [-W * 0.5, 0.0, W * 0.5]: md.viga(Vector3(x, H - 0.1, -D), Vector3(x, H - 0.1, D), 0.16)
	for sx in [-1.0, 1.0]:
		var nt := int(D * 2 / 0.38)
		for i in nt:
			var z := -D + 0.19 + i * (D * 2 / nt)
			var alt := (pico - H) * (1.0 - absf(z) / D)
			if alt > 0.05: md.cx(Vector3(W * sx, H + alt * 0.5 - 0.06, z), Vector3(0.05, alt + 0.14, D * 2 / nt - 0.02), Vector3.ZERO, 0.5)
	md.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.56, 0.50, 0.45)), g)
	# telhado com neve
	var te := Node3D.new()
	g.add_child(te)
	g.set_meta("telhado", te)
	_telhado(te, W, D, H, pico)
	var tv := Malha.new()
	tv.cx(Vector3(0, 2.42, D + 0.95), Vector3(W * 2 + 0.6, 0.05, 1.9), Vector3(0.14, 0, 0), 0.5)
	tv.no(Mat.pbr("rusty_corrugated_iron", 1.0, Color(0.5, 0.46, 0.44)), te)
	var nv := Malha.new()
	nv.cx(Vector3(0, 2.52, D + 0.95), Vector3(W * 2 + 0.56, 0.15, 1.86), Vector3(0.14, 0, 0))
	nv.no(Mat.neve_lisa(), te)
	_gelo(te, Vector3(-W - 0.2, 2.26, D + 1.86), Vector3(W + 0.2, 2.26, D + 1.86), 18)
	# chamine
	var cm := Malha.new()
	cm.cx(Vector3(-W - 0.38, 1.9, -0.6), Vector3(0.76, 4.9, 0.95), Vector3.ZERO, 0.5)
	cm.cx(Vector3(-W - 0.38, 4.40, -0.6), Vector3(0.92, 0.16, 1.1), Vector3.ZERO, 0.5)
	cm.no(Mat.pbrn("mossy_rock", 0.7, Color(0.66, 0.66, 0.66)), g)
	g.set_meta("fumaca", Fx.fumaca(g, Vector3(-W - 0.38, 4.6, -0.6), 0.9, 16))
	var b := loc.corpo(g)
	loc.bx(b, Vector3(0, -0.28, 0.8), Vector3(W * 2, 0.5, D * 2 + 1.7))
	loc.bx(b, Vector3(xp, -0.36, D + 2.1), Vector3(1.4, 0.4, 1.2), Vector3(0.46, 0, 0))
	if not aberta:
		loc.bx(b, Vector3(0, 1.3, 0), Vector3(W * 2, 2.8, D * 2))
	else:
		for q in [[Vector3(-W, 1.3, 0), Vector3(0.3, 2.8, D * 2)], [Vector3(W, 1.3, 0), Vector3(0.3, 2.8, D * 2)], [Vector3(0, 1.3, -D), Vector3(W * 2, 2.8, 0.3)], [Vector3((-W + xp - 0.5) * 0.5, 1.3, D), Vector3(W + xp - 0.5, 2.8, 0.3)], [Vector3((W + xp + 0.5) * 0.5, 1.3, D), Vector3(W - xp - 0.5, 2.8, 0.3)]]:
			loc.bx(b, q[0], q[1])
	# porta
	var po := Node3D.new()
	g.add_child(po)
	po.position = Vector3(xp - 0.46, 0.0, D)
	var pm := Malha.new()
	for i in 5: pm.cx(Vector3(0.095 + i * 0.184, 1.03, 0), Vector3(0.178, 2.02, 0.05), Vector3.ZERO, 0.6)
	for y in [0.5, 1.6]: pm.cx(Vector3(0.46, y, 0.035), Vector3(0.88, 0.12, 0.03), Vector3.ZERO, 0.6)
	pm.no(Mat.pbr("weathered_planks", 1.0, Color(0.46, 0.40, 0.36)), po)
	var mc := Malha.new()
	mc.tubo([Vector3(0.82, 1.0, 0.03), Vector3(0.82, 1.0, 0.09)], [0.012, 0.028], 10)
	mc.no(Mat.liso(Color(0.3, 0.25, 0.12), 0.3, 0.9), po)
	po.add_to_group("sem_col")
	g.set_meta("porta", po)
	if aberta:
		var pb := loc.corpo(po)
		loc.bx(pb, Vector3(0.46, 1.0, 0), Vector3(0.92, 2.0, 0.08))
		porta_ruth = po
		it["porta"] = Interativo.criar(po, Vector3(0.8, 1.05, 0), "Abrir porta", func(): mover_porta(not porta_aberta), 2.2)
	else:
		it["tranca_" + id] = Interativo.criar(po, Vector3(0.46, 1.05, 0.1), "Bater na porta", func(): Jogo.historia.bater(id), 1.9)


func _telhado(te: Node3D, W: float, D: float, H: float, pico: float) -> void:
	var dz := D + 0.6
	var dy := pico - (H - 0.22)
	var inc := atan2(dy, dz)
	var comp := Vector2(dy, dz).length()
	var tb := Malha.new()
	var nv := Malha.new()
	for sz in [-1.0, 1.0]:
		var meio := Vector3(0, pico - dy * 0.5, dz * 0.5 * sz)
		tb.caixa(Transform3D(Basis(Vector3.RIGHT, inc * sz), meio + Vector3.UP * 0.06), Vector3(W * 2 + 1.15, 0.06, comp + 0.05), 0.5)
		# manto de neve com ondulacao
		var nx := 22
		var nz := 6
		var base := nv.v.size()
		for iz in nz + 1:
			for ix in nx + 1:
				var fx := float(ix) / nx
				var fz := float(iz) / nz
				var x := lerpf(-W - 0.56, W + 0.56, fx)
				var borda := minf(minf(fx, 1.0 - fx) * 14.0, (1.0 - fz) * 7.0)
				var esp := 0.06 + 0.20 * smoothstep(0.0, 1.0, borda) + 0.035 * sin(x * 2.1 + fz * 5.0 + sz) + 0.02 * sin(x * 5.3)
				var no := Vector3(0, dz, dy * sz).normalized()
				var p := Vector3(x, pico + 0.10 - dy * fz * 1.02, dz * 1.03 * fz * sz) + no * esp
				nv.vert(p, (no + Vector3(0.10 * cos(x * 2.1), 0, 0.1 * sin(x * 3.0))).normalized(), Vector2(x, fz * comp) * 0.35, Vector3.RIGHT)
		for iz in nz:
			for ix in nx:
				var a := base + iz * (nx + 1) + ix
				if sz > 0: nv.quad(a, a + 1, a + nx + 2, a + nx + 1)
				else: nv.quad(a, a + nx + 1, a + nx + 2, a + 1)
		# beirada arredondada
		var e0 := Vector3(-W - 0.56, pico + 0.12 - dy * 1.02, dz * 1.03 * sz)
		var e1 := Vector3(W + 0.56, pico + 0.12 - dy * 1.02, dz * 1.03 * sz)
		var pts := []
		var rs := []
		for k in 15:
			pts.append(e0.lerp(e1, k / 14.0) + Vector3(0, 0.02 * sin(k * 1.7) + 0.02, 0))
			rs.append(0.10 + 0.035 * sin(k * 2.3) - (0.05 if k in [0, 14] else 0.0))
		nv.tubo(pts, rs, 10, 0.5, 1.0)
		_gelo(te, Vector3(-W - 0.4, pico - dy * 1.02 + 0.02, dz * 1.04 * sz), Vector3(W + 0.4, pico - dy * 1.02 + 0.02, dz * 1.04 * sz), 22)
		for sx in [-1.0, 1.0]:
			nv.tubo([Vector3((W + 0.55) * sx, pico + 0.18, 0), Vector3((W + 0.57) * sx, pico + 0.14 - dy * 0.5, dz * 0.5 * sz), Vector3((W + 0.55) * sx, pico + 0.12 - dy, dz * sz)], [0.11, 0.12, 0.09], 9, 0.5, 1.0)
	nv.tubo([Vector3(-W - 0.5, pico + 0.22, 0), Vector3(0, pico + 0.25, 0), Vector3(W + 0.5, pico + 0.22, 0)], [0.14, 0.17, 0.14], 10, 0.5, 1.0)
	tb.no(Mat.pbr("weathered_planks", 1.0, Color(0.42, 0.40, 0.38)), te)
	nv.no(Mat.neve_lisa(), te)


## pingentes de gelo numa beirada
func _gelo(pai: Node3D, a: Vector3, b: Vector3, n: int) -> void:
	var m := Malha.new()
	for i in n:
		var f := (i + 0.5 + 0.4 * sin(i * 4.7)) / n
		var l := 0.06 + 0.22 * pow(absf(sin(i * 2.9 + a.x)), 2.0)
		var p := a.lerp(b, f)
		m.tubo([p, p + Vector3(0.004, -l * 0.5, 0), p + Vector3(0, -l, 0)], [0.018, 0.011, 0.001], 6)
	m.no(Mat.liso(Color(0.72, 0.82, 0.90), 0.08), pai, false).add_to_group("sem_col")


# ------------------------------------------------------------------ casa de Ruth por dentro
func _interior_ruth() -> void:
	var g: Node3D = casas.ruth
	var W := 4.2
	var D := 3.4
	var md := Malha.new()
	# divisoria do quarto, com vao
	for i in 8:
		var z := -D + 0.22 + i * 0.42
		if z > 0.45 and z < 1.75: continue
		md.cx(Vector3(1.3, 1.22, z), Vector3(0.06, 2.45, 0.40), Vector3.ZERO, 0.6)
	for z in [2.0, 2.42, 2.84, 3.2]: md.cx(Vector3(1.3, 1.22, z), Vector3(0.06, 2.45, 0.40), Vector3.ZERO, 0.6)
	md.cx(Vector3(1.3, 2.25, 1.1), Vector3(0.08, 0.4, 1.4), Vector3.ZERO, 0.6)
	for i in 24: md.cx(Vector3(-W + 0.18 + i * 0.35, 2.60, 0), Vector3(0.34, 0.03, D * 2), Vector3.ZERO, 0.5, true)
	md.no(Mat.pbr("weathered_planks", 1.0, Color(0.55, 0.46, 0.38)), g)
	var tp := Malha.new()
	tp.cx(Vector3(-1.4, 0.018, -0.2), Vector3(3.0, 0.012, 2.2), Vector3(0, 0.08, 0), 0.8)
	tp.no(Mat.pbr("dirty_carpet", 1.0, Color(0.50, 0.22, 0.18)), g).add_to_group("sem_col")
	var l2 := loc
	l2.prop(g, "barrel_stove", Vector3(-3.35, 0.01, -2.3), PI * 0.25, 1.05)
	var cn := Malha.new()
	cn.tubo([Vector3(-3.40, 1.0, -2.4), Vector3(-3.42, 2.0, -2.5), Vector3(-3.5, 2.7, -2.6)], [0.075, 0.075, 0.075], 14)
	cn.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.25, 0.24, 0.23), 0.7, 0.6), g)
	l2.prop(g, "WoodenTable_01", Vector3(-1.4, 0.01, -0.3), 0.08, 0.78)
	ObjetoFisico.movel(g, "WoodenChair_01", Vector3(-0.4, 0.02, -0.9), -1.2, 0.9, 5.0, "cadeira")
	ObjetoFisico.movel(g, "WoodenChair_01", Vector3(-2.45, 0.02, -0.2), 1.6, 0.9, 5.0, "cadeira")
	l2.prop(g, "ArmChair_01", Vector3(-3.0, 0.0, 1.0), 2.2, 1.0)
	l2.prop(g, "wooden_bookshelf_worn", Vector3(0.95, 0.0, -2.2), -PI * 0.5, 1.95)
	l2.prop(g, "mantel_clock_01", Vector3(0.92, 1.96, -2.2), -PI * 0.5, 0.30)
	l2.prop(g, "vintage_oil_lamp", Vector3(-1.55, 0.80, -0.45), 0.4, 0.40)
	l2.prop(g, "carved_wooden_plate", Vector3(-1.1, 0.80, -0.1), 0.0, 0.05, "y")
	l2.prop(g, "pot_enamel_01", Vector3(-3.35, 1.06, -2.25), 0.6, 0.20)
	l2.prop(g, "Rockingchair_01", Vector3(-3.1, 0.0, 2.4), 2.6, 1.05)
	l2.prop(g, "wooden_bucket_01", Vector3(-2.4, 0.0, -2.9), 0.2, 0.30)
	var lm := Malha.new()
	for k in 7:
		lm.tubo([Vector3(-1.95 + 0.17 * (k % 4), 0.09 + 0.16 * (k / 4), -3.1), Vector3(-1.95 + 0.17 * (k % 4), 0.09 + 0.16 * (k / 4), -2.65)], [0.08, 0.075], 9, 0.8, 1.0, Color(0, 0, 0.5), true)
	lm.no(Mat.pbr("bark_willow_02", 1.0, Color(0.6, 0.5, 0.42)), g)
	# quarto
	l2.prop(g, "old_bed_frame", Vector3(3.1, 0.0, -1.6), 0.0, 1.0)
	var cl := Malha.new()
	cl.cx(Vector3(3.1, 0.50, -1.55), Vector3(0.92, 0.17, 1.85))
	cl.no(Aeronave.m_forro(Color(0.55, 0.52, 0.46), 0.4, 0.0, 1.0), g)
	var cb := Malha.new()
	cb.cx(Vector3(3.1, 0.60, -1.15), Vector3(1.02, 0.07, 1.15), Vector3(0.02, 0, 0.0))
	cb.cx(Vector3(3.62, 0.46, -1.15), Vector3(0.04, 0.32, 1.12), Vector3(0, 0, 0.08))
	cb.cx(Vector3(2.58, 0.46, -1.15), Vector3(0.04, 0.32, 1.12), Vector3(0, 0, -0.08))
	cb.no(Mat.pbr("fabric_pattern_07", 2.2, Color(0.42, 0.20, 0.16)), g)
	var tv := Malha.new()
	tv.tubo([Vector3(2.78, 0.66, -2.25), Vector3(2.95, 0.68, -2.25), Vector3(3.25, 0.68, -2.25), Vector3(3.42, 0.66, -2.25)], [0.05, 0.10, 0.10, 0.05], 14, 1, 1, Color(0, 0, 0.5), true)
	tv.no(Aeronave.m_forro(Color(0.72, 0.70, 0.64), 0.25, 0.0, 1.0), g)
	l2.prop(g, "painted_wooden_cabinet", Vector3(3.85, 0, 1.2), -PI * 0.5, 1.5)
	l2.prop(g, "wooden_crate_01", Vector3(2.15, 0, -2.5), 0.2, 0.46)
	l2.prop(g, "vintage_oil_lamp", Vector3(2.15, 0.47, -2.5), 0.0, 0.36)
	it["cama"] = Interativo.criar(g, Vector3(3.1, 0.75, -1.2), "Dormir", func(): Jogo.historia.dormir(), 2.4, 1.0)
	it["cama"].ativo = false
	it["sopa"] = Interativo.criar(g, Vector3(-1.1, 0.88, -0.1), "Tomar a sopa", func(): Jogo.historia.sopa(), 2.2, 1.5)
	it["sopa"].ativo = false
	# luzes
	fogao = LuzFogo.new()
	fogao.base = 1.5
	fogao.light_color = Color(1.0, 0.58, 0.28)
	fogao.omni_range = 7.0
	fogao.shadow_enabled = true
	fogao.position = Vector3(-2.9, 0.55, -1.8)
	g.add_child(fogao)
	Som.loop3d("fogo", fogao, Vector3.ZERO, -12.0, 9.0, 1.6)
	luz_mesa = OmniLight3D.new()
	luz_mesa.light_color = Color(1.0, 0.72, 0.42)
	luz_mesa.light_energy = 1.1
	luz_mesa.omni_range = 5.5
	luz_mesa.shadow_enabled = true
	luz_mesa.position = Vector3(-1.55, 1.35, -0.45)
	g.add_child(luz_mesa)
	var lq := OmniLight3D.new()
	lq.light_color = Color(1.0, 0.70, 0.40)
	lq.light_energy = 0.7
	lq.omni_range = 4.0
	lq.shadow_enabled = true
	lq.position = Vector3(2.15, 0.95, -2.4)
	g.add_child(lq)
	g.set_meta("luz_quarto", lq)


func mover_porta(abre: bool, rapido: bool = false) -> void:
	porta_aberta = abre
	it["porta"].texto = "Fechar porta" if abre else "Abrir porta"
	Som.em("porta", porta_ruth.global_position, 0.0, 40)
	create_tween().tween_property(porta_ruth, "rotation:y", 1.9 if abre else 0.0, 0.25 if rapido else 1.1).set_trans(Tween.TRANS_SINE)


func dentro_ruth(p: Vector3) -> bool:
	var l: Vector3 = (casas.ruth as Node3D).to_local(p)
	return absf(l.x) < 4.1 and absf(l.z) < 3.3 and l.y > -0.6 and l.y < 2.6


func dentro_galpao(p: Vector3) -> bool:
	var l: Vector3 = (casas.galpao as Node3D).to_local(p)
	return absf(l.x) < 4.0 and absf(l.z) < 4.8 and l.y < 3.5


# ------------------------------------------------------------------ igreja
func _igreja() -> void:
	var g := Node3D.new()
	add_child(g)
	g.position = ch(IGREJA.x, IGREJA.y) + Vector3.UP * 0.3
	g.rotation.y = _para_centro(IGREJA)
	casas["igreja"] = g
	var m := Malha.new()
	for sx in [-1.0, 1.0]:
		for i in 22: m.cx(Vector3(2.6 * sx, 0.13 + i * 0.145, 0), Vector3(0.08, 0.15, 8.0), Vector3(0, 0, 0.06 * sx), 0.5)
	for i in 22:
		for sz in [-1.0, 1.0]:
			m.cx(Vector3(0, 0.13 + i * 0.145, 4.0 * sz), Vector3(5.2, 0.15, 0.08), Vector3(0.06 * sz, 0, 0), 0.5)
	for sz in [-1.0, 1.0]:
		for i in 14:
			var x := -2.4 + i * 0.37
			var h := 2.2 * (1.0 - absf(x) / 2.6)
			m.cx(Vector3(x, 3.2 + h * 0.5, 4.0 * sz), Vector3(0.36, h + 0.1, 0.06), Vector3.ZERO, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: m.cx(Vector3(0.62 * sx, 6.1, 2.9 + 0.62 * sz), Vector3(0.14, 1.8, 0.14))
	m.cx(Vector3(0, 5.2, 2.9), Vector3(1.5, 0.8, 1.5), Vector3.ZERO, 0.5)
	m.cx(Vector3(0, 7.0, 2.9), Vector3(1.6, 0.1, 1.6), Vector3.ZERO, 0.5)
	m.no(Mat.pbrn("weathered_planks", 1.0, Color(0.78, 0.78, 0.76), 1.0, 0.0, 0.5), g)
	var te := Node3D.new()
	g.add_child(te)
	g.set_meta("telhado", te)
	var r := Node3D.new()
	r.rotation.y = PI * 0.5
	te.add_child(r)
	_telhado(r, 4.1, 2.5, 3.15, 5.35)
	var pi_ := Malha.new()
	pi_.tubo([Vector3(0, 7.0, 2.9), Vector3(0, 9.4, 2.9)], [1.15, 0.02], 4)
	pi_.no(Mat.pbrn("rusty_corrugated_iron", 1.0, Color(0.5, 0.48, 0.46)), g)
	var cz := Malha.new()
	cz.cx(Vector3(0, 9.9, 2.9), Vector3(0.08, 1.2, 0.08))
	cz.cx(Vector3(0, 10.1, 2.9), Vector3(0.6, 0.08, 0.08))
	cz.no(Mat.liso(Color(0.08, 0.07, 0.06), 0.8), g)
	var si := Malha.new()
	si.tubo([Vector3(0, 6.6, 2.9), Vector3(0, 6.45, 2.9), Vector3(0, 6.15, 2.9), Vector3(0, 6.02, 2.9)], [0.06, 0.20, 0.27, 0.36], 20)
	si.no(Mat.liso(Color(0.28, 0.20, 0.08), 0.35, 0.9), g)
	var po := Malha.new()
	for i in 6: po.cx(Vector3(-0.63 + i * 0.25, 1.05, 4.10), Vector3(0.24, 2.1, 0.05), Vector3.ZERO, 0.7)
	po.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.36, 0.26, 0.22)), g)
	var vd := StandardMaterial3D.new()
	vd.albedo_color = Color(0.08, 0.06, 0.05)
	vd.roughness = 0.15
	vd.emission_enabled = true
	vd.emission = Color(1.0, 0.55, 0.25)
	vd.emission_energy_multiplier = 0.0
	janelas.append([vd, 0.5, "igreja"])
	var vm := Malha.new()
	for sx in [-1.0, 1.0]:
		for z in [-2.4, 0.0, 2.4]: vm.cx(Vector3(2.68 * sx, 1.7, z), Vector3(0.03, 1.5, 0.7))
	vm.no(vd, g, false)
	var b := loc.corpo(g)
	loc.bx(b, Vector3(0, 1.6, 0), Vector3(5.4, 3.6, 8.2))
	it["igreja"] = Interativo.criar(g, Vector3(0, 1.2, 4.25), "Ler o aviso na porta", func(): Jogo.historia.ler_nota("igreja"), 2.4)


# ------------------------------------------------------------------ galpao do Amos
func _galpao() -> void:
	var g := Node3D.new()
	add_child(g)
	g.position = ch(GALPAO.x, GALPAO.y) + Vector3.UP * 0.1
	g.rotation.y = _para_centro(GALPAO)
	casas["galpao"] = g
	var m := Malha.new()
	for sx in [-1.0, 1.0]:
		for i in 24: m.cx(Vector3(4.0 * sx, 1.6, -4.6 + i * 0.4), Vector3(0.05, 3.3, 0.38), Vector3(sin(i * 5.0) * 0.006, 0, 0), 0.6)
	for i in 20:
		var x := -3.8 + i * 0.4
		var h := 3.2 + 1.8 * (1.0 - absf(x) / 4.0)
		m.cx(Vector3(x, h * 0.5, -4.8), Vector3(0.38, h, 0.05), Vector3.ZERO, 0.6)
		if absf(x) > 1.75: m.cx(Vector3(x, h * 0.5, 4.8), Vector3(0.38, h, 0.05), Vector3.ZERO, 0.6)
		else: m.cx(Vector3(x, (h + 2.7) * 0.5, 4.8), Vector3(0.38, h - 2.7, 0.05), Vector3.ZERO, 0.6)
	for z in [-4.6, -1.6, 1.6, 4.6]:
		m.viga(Vector3(-3.9, 3.15, z), Vector3(3.9, 3.15, z), 0.16)
		for sx in [-1.0, 1.0]: m.cx(Vector3(3.88 * sx, 1.6, z), Vector3(0.18, 3.2, 0.18))
	m.no(Mat.pbr("weathered_planks", 1.0, Color(0.46, 0.36, 0.32)), g)
	var te := Node3D.new()
	te.rotation.y = PI * 0.5
	g.add_child(te)
	g.set_meta("telhado", te)
	_telhado(te, 4.9, 3.8, 3.2, 5.1)
	for sx in [-1.0, 1.0]:
		var pt := Node3D.new()
		g.add_child(pt)
		pt.position = Vector3(1.75 * sx, 0.05, 4.86)
		var pm := Malha.new()
		for i in 5: pm.cx(Vector3((-0.17 - i * 0.34) * sx, 1.32, 0), Vector3(0.33, 2.62, 0.05), Vector3.ZERO, 0.6)
		pm.viga(Vector3(-0.1 * sx, 0.3, 0.04), Vector3(-1.6 * sx, 2.3, 0.04), 0.05, 1.0, 0.14)
		pm.no(Mat.pbr("weathered_planks", 1.0, Color(0.40, 0.30, 0.26)), pt)
		var pb := loc.corpo(pt)
		loc.bx(pb, Vector3(-0.86 * sx, 1.3, 0), Vector3(1.72, 2.6, 0.08))
		pt.add_to_group("sem_col")
		portas_galpao.append(pt)
	it["galpao"] = Interativo.criar(g, Vector3(0, 1.2, 5.0), "Abrir galpão", func(): Jogo.historia.bater("galpao"), 2.6)
	var b := loc.corpo(g)
	loc.bx(b, Vector3(0, 0.0, 0), Vector3(8, 0.12, 9.6))
	for q in [[Vector3(-4, 1.6, 0), Vector3(0.12, 3.4, 9.6)], [Vector3(4, 1.6, 0), Vector3(0.12, 3.4, 9.6)], [Vector3(0, 1.6, -4.8), Vector3(8, 3.4, 0.12)], [Vector3(-2.9, 1.6, 4.8), Vector3(2.2, 3.4, 0.12)], [Vector3(2.9, 1.6, 4.8), Vector3(2.2, 3.4, 0.12)]]:
		loc.bx(b, q[0], q[1])
	var pis := Malha.new()
	pis.cx(Vector3(0, 0.04, 0), Vector3(7.9, 0.06, 9.5), Vector3.ZERO, 0.4)
	pis.no(Mat.pbr("gravel_ground_01", 0.5, Color(0.45, 0.40, 0.36)), g).add_to_group("sem_col")
	var bc := Malha.new()
	bc.cx(Vector3(-2.4, 0.88, -4.3), Vector3(2.6, 0.07, 0.75))
	for x in [-3.6, -1.2]:
		for z in [-4.6, -4.0]: bc.cx(Vector3(x, 0.44, z), Vector3(0.09, 0.88, 0.09))
	bc.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.5, 0.44, 0.4)), g)
	loc.prop(g, "wine_barrel_01", Vector3(3.2, 0.06, -3.9), 0.3, 0.95)
	loc.prop(g, "wine_barrel_01", Vector3(3.25, 0.06, -2.9), 1.3, 0.95)
	loc.prop(g, "Barrel_01", Vector3(2.4, 0.06, -4.2), 0.9, 0.9)
	ObjetoFisico.movel(g, "wooden_crate_01", Vector3(-3.2, 0.08, 1.2), 0.4, 0.5, 7.0, "caixote")
	ObjetoFisico.movel(g, "wooden_crate_01", Vector3(-3.0, 0.08, 2.1), 1.0, 0.46, 7.0, "caixote")
	ObjetoFisico.movel(g, "wooden_bucket_01", Vector3(1.8, 0.08, -4.2), 0.4, 0.32, 1.5, "balde")
	loc.prop(g, "metal_trash_can", Vector3(3.3, 0.06, 2.8), 0.0, 0.8)
	var fe := Malha.new()
	for i in 4:
		fe.cx(Vector3(-3.4 + i * 0.5, 1.6, -4.72), Vector3(0.05, 0.9, 0.03), Vector3(0, 0, 0.06 * (i - 1)))
		fe.cx(Vector3(-3.4 + i * 0.5, 1.2, -4.70), Vector3(0.18, 0.22, 0.02), Vector3(0, 0, 0.06 * (i - 1)))
	fe.no(Mat.pbr("rusty_metal_02", 1.0, Color(0.4, 0.36, 0.34), 0.7, 0.5), g).add_to_group("sem_col")
	var gal := Node3D.new()
	g.add_child(gal)
	gal.position = Vector3(-1.9, 0.92, -4.25)
	Itens._modelo(gal, "metal_jerrycan", 0.47)
	gal.add_to_group("sem_col")
	loc.nos["gasolina"] = gal
	loc.it["gasolina"] = Interativo.criar(g, gal.position + Vector3.UP * 0.2, "Pegar galão de gasolina", func(): Jogo.historia.pegar("gasolina"), 2.4)
	loc.it["gasolina"].ativo = false
	var lg := OmniLight3D.new()
	lg.light_color = Color(1.0, 0.62, 0.30)
	lg.light_energy = 0.0
	lg.omni_range = 6.0
	lg.position = Vector3(-1.2, 2.2, -3.4)
	g.add_child(lg)
	g.set_meta("luz", lg)


# ------------------------------------------------------------------ praca
func _praca() -> void:
	loc.prop(self, "stone_fire_pit", ch(0, 0), 0.3, 0.0)
	fogueira = Fx.fogo(self, ch(0, 0) + Vector3.UP * 0.25, 0.85, 4.2, 18.0)
	var tr := Malha.new()
	for q in [[2.6, 0.7, 1.2], [-1.9, 2.1, 0.75], [-1.4, -2.4, -0.55], [1.2, -2.7, 0.4]]:
		var d := Vector3(cos(q[2] + 0.9), 0, sin(q[2] + 0.9)) * 0.95
		var p := ch(q[0], q[1]) + Vector3.UP * 0.24
		tr.tubo([p - d, p + d], [0.24, 0.22], 14, 0.6, 1.0, Color(0, 0, 0.5), true)
	tr.no(Mat.casca("bark_brown_02", Color(0.6, 0.55, 0.5), 0.0, 0.0), self)
	# poco
	var po := Malha.new()
	var cp := ch(9.5, -8.0)
	for i in 4: po.tubo([cp + Vector3(0, i * 0.2 - 0.1, 0), cp + Vector3(0, i * 0.2 + 0.1, 0)], [0.85 - 0.01 * (i % 2), 0.85], 18, 0.6, 5.0)
	po.tubo([cp + Vector3(0, 0.70, 0), cp + Vector3(0, 0.1, 0)], [0.66, 0.66], 18, 0.6, 5.0)
	for k in 18:
		var a := TAU * k / 18.0
		po.caixa(Transform3D(Basis(Vector3.UP, -a), cp + Vector3(cos(a) * 0.75, 0.70, sin(a) * 0.75)), Vector3(0.24, 0.06, 0.28), 0.8)
	po.no(Mat.pbrn("mossy_rock", 0.8, Color(0.7, 0.7, 0.72)), self)
	var pw := Malha.new()
	for sx in [-1.0, 1.0]: pw.cx(cp + Vector3(0.78 * sx, 1.1, 0), Vector3(0.12, 2.2, 0.12))
	pw.tubo([cp + Vector3(-0.8, 1.6, 0), cp + Vector3(0.8, 1.6, 0)], [0.08, 0.08], 10)
	for sz in [-1.0, 1.0]: pw.cx(cp + Vector3(0, 2.3, 0.35 * sz), Vector3(2.0, 0.05, 0.9), Vector3(0.6 * sz, 0, 0))
	pw.no(Mat.pbrn("weathered_brown_planks", 1.0, Color(0.5, 0.46, 0.42)), self)
	ObjetoFisico.movel(self, "wooden_bucket_01", cp + Vector3(1.3, 0.05, 0.5), 0.4, 0.34, 1.5, "balde")
	# lenha
	for q in [[-11.5, -14.5, 0.9], [19.5, -15.0, 2.2], [21.5, 12.5, 0.2], [-16, 22, 1.9]]:
		var lm := Malha.new()
		var bs := Basis(Vector3.UP, q[2])
		var o := ch(q[0], q[1])
		for y in 4:
			for k in 9:
				var p := o + bs * Vector3(-0.95 + k * 0.235 + 0.1 * (y % 2), 0.12 + y * 0.20, 0)
				var r := 0.105 + 0.015 * sin(k * 3.0 + y)
				lm.tubo([p - bs * Vector3(0, 0, 0.35), p + bs * Vector3(0, 0, 0.35)], [r, r], 9, 0.8, 1.0, Color(0, 0, 0.5), true)
		lm.no(Mat.pbrn("bark_willow_02", 1.0, Color(0.6, 0.52, 0.46)), self)
		var nv := Malha.new()
		nv.tubo([o + bs * Vector3(-1.05, 0.86, 0), o + bs * Vector3(0, 0.92, 0), o + bs * Vector3(1.05, 0.86, 0)], [0.16, 0.26, 0.16], 9, 0.5, 1.0)
		nv.no(Mat.neve_lisa(), self)
	# cercas
	var ce := Malha.new()
	for seg in [[Vector2(-31, 15), Vector2(-27, 27)], [Vector2(-31, 3), Vector2(-28, -8)], [Vector2(-25, -20), Vector2(-9, -31)], [Vector2(9, -30), Vector2(24, -22)], [Vector2(30, -2), Vector2(31, 16)], [Vector2(24, 20), Vector2(15, 31)]]:
		var n := int(seg[0].distance_to(seg[1]) / 2.2)
		for i in n + 1:
			var p: Vector2 = seg[0].lerp(seg[1], float(i) / n)
			var q := ch(p.x, p.y)
			ce.cx(q + Vector3.UP * 0.5, Vector3(0.11, 1.3, 0.11), Vector3(sin(i * 3.0) * 0.06, 0, cos(i * 5.0) * 0.06))
			if i < n:
				var p2: Vector2 = seg[0].lerp(seg[1], float(i + 1) / n)
				var q2 := ch(p2.x, p2.y)
				for y in [0.45, 0.9]: ce.viga(q + Vector3.UP * (y + 0.04 * sin(i * 4.0)), q2 + Vector3.UP * (y + 0.04 * cos(i * 3.0)), 0.06, 1.0, 0.10)
	ce.no(Mat.pbrn("weathered_planks", 1.0, Color(0.55, 0.53, 0.5)), self)
	# postes com lampiao
	for q in [[-26, 12.5], [-10, 5], [6.5, 7.5], [8, -13], [20, -4], [-8, -20], [4, 17]]:
		var pm := Malha.new()
		var o := ch(q[0], q[1])
		pm.cx(o + Vector3.UP * 1.35, Vector3(0.12, 2.9, 0.12), Vector3(0.02, 0, 0.02))
		pm.cx(o + Vector3(0.28, 2.55, 0), Vector3(0.62, 0.07, 0.07))
		pm.no(Mat.pbrn("weathered_brown_planks", 1.0, Color(0.5, 0.46, 0.42)), self)
		var lp := Node3D.new()
		add_child(lp)
		lp.position = o + Vector3(0.52, 2.12, 0)
		loc.prop(lp, "wooden_lantern_01", Vector3.ZERO, 0.3, 0.36)
		lp.add_to_group("sem_col")
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.66, 0.34)
		l.light_energy = 0.0
		l.omni_range = 9.0
		l.light_volumetric_fog_energy = 1.6
		l.position = o + Vector3(0.52, 2.25, 0)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 70.0
		add_child(l)
		var cha := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.035
		sp.height = 0.09
		cha.mesh = sp
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0, 0, 0)
		em.emission_enabled = true
		em.emission = Color(1.0, 0.62, 0.25)
		em.emission_energy_multiplier = 0.0
		cha.material_override = em
		cha.position = l.position - Vector3.UP * 0.02
		cha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cha)
		lampioes.append([l, em])
	# placa na entrada
	var pl := Node3D.new()
	add_child(pl)
	pl.position = ch(-29.5, 5.0)
	pl.rotation.y = -1.25
	var pb := Malha.new()
	for x in [-0.95, 0.95]: pb.cx(Vector3(x, 1.0, 0), Vector3(0.14, 2.7, 0.14))
	pb.cx(Vector3(0, 1.75, 0.02), Vector3(2.2, 0.85, 0.07), Vector3(0, 0, 0.02))
	pb.no(Mat.pbrn("weathered_brown_planks", 1.0, Color(0.6, 0.54, 0.48)), pl)
	for q in [["COLD HOLLER", 120, 1.86], ["17 almas", 60, 1.54]]:
		var l3 := Label3D.new()
		l3.text = q[0]
		l3.font_size = q[1]
		l3.pixel_size = 0.0021
		l3.modulate = Color(0.10, 0.06, 0.04)
		l3.outline_size = 0
		l3.shaded = true
		l3.position = Vector3(0, q[2], 0.062)
		l3.rotation.z = 0.02
		pl.add_child(l3)
	# neve amontoada
	for q in [[-8, -9], [12, -11], [18, 5], [-14, 11], [4, 12]]:
		var mo := MeshInstance3D.new()
		mo.mesh = Arvores.montinho(int(q[0]) + 40)
		mo.position = ch(q[0], q[1])
		mo.scale = Vector3(2.4, 3.6, 2.2)
		add_child(mo)


# ------------------------------------------------------------------ gente
func _por(id: String, x: float, z: float, olha: Vector2, pose: String, sent: bool = false, alt: float = 0.0) -> Gente:
	var g := Gente.criar(self, id, ch(x, z) + Vector3.UP * alt, atan2(-(olha.x - x), -(olha.y - z)), sent)
	g.pose = pose
	g.set_meta("chao", -position.y)
	gente[id] = g
	return g


func _moradores() -> void:
	_por("caleb", -27.0, 8.2, Vector2(-34, 11), "bracos")
	_por("elias", 2.5, 0.9, Vector2(0, 0), "conversa", true, 0.56)
	_por("hannah", 8.0, -6.9, Vector2(9.5, -8), "aquece")
	_por("amos", 8.4, 16.6, Vector2(0, 0), "bracos")
	var gr: Node3D = casas.ruth
	var pr := to_local(gr.to_global(Vector3(-0.3, -0.02, 4.3)))
	var r := _por("ruth", pr.x, pr.z, Vector2(0, 0), "pe")
	r.position.y = pr.y
	r.remove_meta("chao")
	for id in gente:
		var q: Gente = gente[id]
		q.add_to_group("sem_col")
		it["fala_" + id] = Interativo.criar(q, Vector3(0, 1.2, 0) if not q.sentado else Vector3(0, 0.35, 0), "Falar", func(): Jogo.historia.falar_com(id), 2.6)
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := CapsuleShape3D.new()
		s.radius = 0.24
		s.height = 1.7
		c.shape = s
		c.position.y = 0.85 if not q.sentado else 0.2
		b.add_child(c)
		q.add_child(b)
		q.set_meta("corpo", b)


func esconder_moradores(quem: Array = []) -> void:
	for id in gente:
		if quem.is_empty() or id in quem:
			var q: Gente = gente[id]
			q.visible = false
			for c in (q.get_meta("corpo") as Node).get_children(): (c as CollisionShape3D).set_deferred("disabled", true)
			it["fala_" + id].ativo = false


# ------------------------------------------------------------------ depois do ataque
func destruir() -> void:
	if destruida: return
	destruida = true
	ruina = Node3D.new()
	add_child(ruina)
	esconder_moradores()
	fogueira.visible = false
	for c in fogueira.get_children():
		if c is AudioStreamPlayer3D: c.stop()
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for id in ["elias", "hannah", "velha"]:
		queimar(id)
	porta_ruth.visible = false
	for c in porta_ruth.find_children("*", "CollisionShape3D", true, false): (c as CollisionShape3D).set_deferred("disabled", true)
	it["porta"].ativo = false
	fogao.base = 0.15
	luz_mesa.visible = false
	(casas.ruth.get_meta("luz_quarto") as OmniLight3D).visible = false
	(casas.ruth.get_meta("fumaca") as GPUParticles3D).emitting = false
	it["cama"].ativo = false
	it["sopa"].ativo = false
	# galpao arrombado
	portas_galpao[0].rotation = Vector3(0, -1.9, 0)
	portas_galpao[1].rotation = Vector3(-1.45, 0.3, 0.1)
	portas_galpao[1].position += Vector3(0.4, 0.1, 0.9)
	for c in portas_galpao[1].find_children("*", "CollisionShape3D", true, false): (c as CollisionShape3D).set_deferred("disabled", true)
	it["galpao"].ativo = false
	if not Jogo.flags.get("pegou_gasolina", false): loc.it["gasolina"].ativo = true
	(casas.galpao.get_meta("luz") as OmniLight3D).light_energy = 0.35
	for id in ["elias", "caleb", "hannah", "velha"]: it["tranca_" + id].ativo = false
	var k := 0
	for q in [["caleb", -12.0, 7.0, 0.7], ["hannah", 11.5, -5.5, 2.2], ["amos", 8.0, 14.0, -1.0]]:
		var n := Gente.criar(ruina, q[0], ch(q[1], q[2]) + Vector3.UP * 0.08)
		n.morrer(90 + k, 0.25, 0.8)
		n.basis = Basis(Vector3.UP, q[3]) * Basis(Vector3.RIGHT, PI * 0.5 if k != 1 else -PI * 0.5)
		k += 1
		Fx.sangue(ruina, mundo(q[1], q[2]), 2.6)
	for q in [[-4, 3, 1.8], [3, -6, 1.4], [-14, -6, 2.0], [14, 10, 1.6], [0, 9, 2.2]]:
		Fx.sangue(ruina, mundo(q[0], q[1]), q[2])
	var md := Malha.new()
	for i in 40:
		var p := ch(rng.randf_range(-24, 24), rng.randf_range(-24, 24)) + Vector3.UP * 0.05
		md.caixa(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))), p), Vector3(rng.randf_range(0.3, 1.6), 0.05, 0.16), 0.6)
	md.no(Mat.pbr("weathered_planks", 1.0, Color(0.36, 0.32, 0.30)), ruina).add_to_group("sem_col")


## poe fogo numa casa (uma vez so)
func queimar(id: String) -> void:
	var g: Node3D = casas[id]
	if g.has_meta("queimada"): return
	g.set_meta("queimada", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	(g.get_meta("telhado") as Node3D).visible = false
	(g.get_meta("fumaca") as GPUParticles3D).emitting = false
	var mt: ShaderMaterial = g.get_meta("troncos")
	mt.set_shader_parameter("tinta", Color(0.10, 0.085, 0.075))
	mt.set_shader_parameter("neve", 0.0)
	var W: float = CASAS[id][1]
	var D: float = CASAS[id][2]
	var vg := Malha.new()
	for i in 9:
		var a := Vector3(rng.randf_range(-W, W), rng.randf_range(0.2, 2.4), rng.randf_range(-D, D))
		vg.viga(a, a + Vector3(rng.randf_range(-2, 2), rng.randf_range(-1.0, 1.6), rng.randf_range(-2.4, 2.4)), 0.13)
	vg.no(Mat.pbr("weathered_brown_planks", 1.0, Color(0.10, 0.085, 0.075)), g).add_to_group("sem_col")
	Fx.fogo(g, Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)), 1.6, 5.5, 26.0, id == "elias")
	Fx.fogo(g, Vector3(rng.randf_range(-2, 2), 0.4, D + 0.4), 0.8, 2.0, 12.0, false)


func _process(dt: float) -> void:
	if fl == null or fl.clima == null or not fl.visible:
		return
	_t += dt
	var noite := 1.0 - smoothstep(0.15, 0.75, fl.clima.dia)
	var vivo := 0.0 if destruida else 1.0
	for q in janelas:
		q[0].emission_energy_multiplier = (0.12 + 2.0 * noite) * q[1] * vivo * (0.94 + 0.06 * sin(_t * 7.0 + q[1] * 20.0))
	for i in lampioes.size():
		var f := 0.0
		if not destruida: f = noite
		elif i in [1, 4]: f = noite * (1.0 if sin(_t * 11.0 + i) + sin(_t * 4.3) > -0.4 else 0.1)
		lampioes[i][0].light_energy = 1.5 * f
		lampioes[i][1].emission_energy_multiplier = 7.0 * f
