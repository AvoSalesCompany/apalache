class_name Itens
extends RefCounted
## Nome, descricao e modelo de cada item. Os icones sao fotos destes modelos (ferr: assar icones).

const ORDEM := ["mochila", "mapa", "lanterna", "pilha", "jaqueta", "bussola", "curativo", "lanche", "chave", "gasolina", "rifle", "municao", "pedra"]

const INFO := {
	"mochila": ["Mochila", "De um passageiro. Cabe tudo o que você achar.", ""],
	"mapa": ["Mapa da serra", "Alguém circulou um nome a lápis: COLD HOLLER.", "[M] abrir"],
	"lanterna": ["Lanterna", "A luz ajuda, mas também mostra você.", "[F] liga e desliga"],
	"pilha": ["Pilhas", "Trocam sozinhas quando a lanterna acaba e você aperta F.", ""],
	"jaqueta": ["Casaco de lona", "Você perde calor bem mais devagar.", "vestido"],
	"bussola": ["Bússola", "Enlouquece perto dele.", "segure [C]"],
	"curativo": ["Curativos", "Fecham um ferimento.", "[H] usar"],
	"lanche": ["Lanche do voo", "Ainda está na embalagem. Aquece um pouco.", "clique para comer"],
	"chave": ["Chave da torre", "Você prefere não lembrar de onde veio.", ""],
	"gasolina": ["Galão de gasolina", "Vinte litros. Para o gerador da torre.", ""],
	"rifle": ["Rifle de ferrolho", "Pesado e velho. Um tiro de cada vez.", "[2] empunhar"],
	"municao": ["Munição 7,62", "Cartuchos para o rifle.", "[R] recarregar"],
	"pedra": ["Pedra do rio", "Arremesse para distrair.", "clique"],
}


static func icone(id: String) -> Texture2D:
	var p := "res://tex/ic_%s.png" % id
	return load(p) if ResourceLoader.exists(p) else null


static func modelo(pai: Node3D, id: String) -> void:
	match id:
		"mochila": mochila(pai)
		"mapa": mapa(pai)
		"lanterna":
			var n := Node3D.new()
			n.rotation = Vector3(0.5, -0.9, 0)
			pai.add_child(n)
			Lanterna.modelo(n)
		"pilha": pilhas(pai)
		"jaqueta": casaco(pai)
		"bussola": bussola(pai)
		"curativo": curativo(pai)
		"lanche": lanche(pai, "sanduiche")
		"chave": chave(pai)
		"gasolina": _modelo(pai, "metal_jerrycan", 0.47)
		"rifle": rifle(pai)
		"municao": municao(pai)
		"pedra": _modelo(pai, "rock_09", 0.1)


static func _modelo(pai: Node3D, id: String, alt: float) -> Node3D:
	var m := Mat.modelo(id)
	pai.add_child(m)
	var bb := AABB()
	var pri := true
	for q in Mat.malhas_de(id):
		var b: AABB = (q[1] as Transform3D) * (q[0] as Mesh).get_aabb()
		bb = b if pri else bb.merge(b)
		pri = false
	var e := alt / bb.size.y
	m.scale = Vector3.ONE * e
	m.position = Vector3(-bb.get_center().x, -bb.position.y, -bb.get_center().z) * e
	return m


static func mochila(pai: Node3D) -> void:
	var n := MeshInstance3D.new()
	n.mesh = load("res://dados/mochila.res")
	n.material_override = Aeronave.m_forro(Color(0.16, 0.20, 0.12), 0.45, 0.0, 1.0)
	pai.add_child(n)
	var co := Malha.new()
	for sx in [-1.0, 1.0]:
		co.tubo([Vector3(0.085 * sx, 0.40, -0.075), Vector3(0.085 * sx, 0.415, -0.13), Vector3(0.085 * sx, 0.33, -0.155), Vector3(0.085 * sx, 0.20, -0.165)], [0.011, 0.011, 0.011, 0.011], 6)
		co.cx(Vector3(0.085 * sx, 0.27, -0.165), Vector3(0.036, 0.030, 0.008))
		co.tubo([Vector3(0.07 * sx, 0.42, 0.06), Vector3(0.095 * sx, 0.40, 0.13), Vector3(0.11 * sx, 0.28, 0.165), Vector3(0.12 * sx, 0.14, 0.13), Vector3(0.13 * sx, 0.06, 0.07)], [0.018, 0.022, 0.022, 0.016, 0.012], 8)
	co.tubo([Vector3(-0.04, 0.44, 0.06), Vector3(-0.03, 0.48, 0.06), Vector3(0.03, 0.48, 0.06), Vector3(0.04, 0.44, 0.06)], [0.008, 0.008, 0.008, 0.008], 6)
	co.no(Aeronave.m_forro(Color(0.17, 0.10, 0.05), 0.4, 0.0, 0.3), pai)


static func mapa(pai: Node3D) -> void:
	var m := Malha.new()
	# folha dobrada em sanfona
	for i in 4:
		var x := -0.165 + i * 0.11
		var a := 0.20 if i % 2 == 0 else -0.20
		m.caixa(Transform3D(Basis(Vector3.BACK, a), Vector3(x, 0.02, 0)), Vector3(0.113, 0.0015, 0.30), 1.0)
	var n := m.no(Mat.liso(Color(0.72, 0.66, 0.50), 0.95), pai)
	n.rotation = Vector3(0.5, 0.3, 0)
	var l := Malha.new()
	for i in 14:
		var pts := []
		var rs := []
		for k in 9:
			var u := k / 8.0
			pts.append(Vector3(-0.20 + u * 0.40, 0.030 + 0.011 * absf(fmod(u * 4.0, 2.0) - 1.0) - 0.006, -0.12 + i * 0.018 + 0.012 * sin(u * 7.0 + i * 0.8)))
			rs.append(0.0011)
		l.tubo(pts, rs, 4)
	var ln := l.no(Mat.liso(Color(0.30, 0.22, 0.12), 0.9), pai)
	ln.rotation = Vector3(0.5, 0.3, 0)


static func pilhas(pai: Node3D) -> void:
	var m := Malha.new()
	var m2 := Malha.new()
	for i in 2:
		var o := Vector3(i * 0.045 - 0.02, 0.017, i * 0.02)
		m.tubo([o, o + Vector3(0.01, 0, 0.042)], [0.0165, 0.0165], 18, 1, 1, Color(0, 0, 0.5), true)
		m2.tubo([o + Vector3(0.01, 0, 0.042), o + Vector3(0.014, 0, 0.060)], [0.0168, 0.0168], 18, 1, 1, Color(0, 0, 0.5), true)
	m.no(Mat.liso(Color(0.02, 0.02, 0.02), 0.35), pai)
	m2.no(Mat.liso(Color(0.62, 0.40, 0.12), 0.25, 0.9), pai)


static func casaco(pai: Node3D) -> void:
	# a jaqueta de alguem, so a roupa
	var d: DadosGente = load("res://dados/gente/p03.res")
	var k := d.sup_corpo.find("roupa")
	var mi := MeshInstance3D.new()
	var am := ArrayMesh.new()
	var a := d.corpo.surface_get_arrays(k)
	a[Mesh.ARRAY_BONES] = null
	a[Mesh.ARRAY_WEIGHTS] = null
	# so o tronco e as mangas
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var ni := PackedInt32Array()
	for t in range(0, ix.size(), 3):
		if v[ix[t]].y > 0.92 and v[ix[t + 1]].y > 0.92 and v[ix[t + 2]].y > 0.92:
			ni.append_array(PackedInt32Array([ix[t], ix[t + 1], ix[t + 2]]))
	a[Mesh.ARRAY_INDEX] = ni
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	mi.mesh = am
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tecido.gdshader")
	m.set_shader_parameter("cor", load("res://tex/gente/" + d.tex.roupa))
	m.set_shader_parameter("nor", load("res://tex/gente/" + d.tex.roupa_n))
	mi.material_override = m
	mi.position.y = -1.2
	pai.add_child(mi)


static func bussola(pai: Node3D) -> void:
	var r := Node3D.new()
	r.rotation = Vector3(0.75, 0.2, 0)
	pai.add_child(r)
	var m := Malha.new()
	m.tubo([Vector3(0, -0.010, 0), Vector3(0, 0.0, 0), Vector3(0, 0.010, 0)], [0.050, 0.056, 0.050], 30, 1, 1, Color(0, 0, 0.5), true)
	m.no(Mat.liso(Color(0.50, 0.36, 0.14), 0.28, 0.9), r)
	var f := Malha.new()
	f.tubo([Vector3(0, 0.0101, 0), Vector3(0, 0.0106, 0)], [0.045, 0.045], 30, 1, 1, Color(0, 0, 0.5), true)
	f.no(Mat.liso(Color(0.78, 0.75, 0.66), 0.8), r)
	var a := Malha.new()
	a.cx(Vector3(0.006, 0.0125, -0.016), Vector3(0.007, 0.002, 0.030), Vector3(0, -0.4, 0))
	a.no(Mat.liso(Color(0.65, 0.03, 0.02), 0.4), r)
	var b := Malha.new()
	b.cx(Vector3(-0.006, 0.0125, 0.014), Vector3(0.007, 0.002, 0.030), Vector3(0, -0.4, 0))
	b.no(Mat.liso(Color(0.1, 0.1, 0.1), 0.4), r)


static func curativo(pai: Node3D) -> void:
	var m := Malha.new()
	m.tubo([Vector3(0, 0, 0), Vector3(0, 0.085, 0)], [0.05, 0.05], 26, 1, 1, Color(0, 0, 0.5), true)
	for i in 5: m.tubo([Vector3(0, 0.01 + i * 0.016, 0), Vector3(0, 0.018 + i * 0.016, 0)], [0.0512, 0.0512], 26)
	m.cx(Vector3(0.05, 0.02, 0.03), Vector3(0.10, 0.003, 0.07), Vector3(0, 0.3, -0.1))
	m.no(Mat.liso(Color(0.80, 0.77, 0.70), 0.95), pai)
	var c := Malha.new()
	c.tubo([Vector3(0, 0.086, 0), Vector3(0, 0.087, 0)], [0.02, 0.02], 16, 1, 1, Color(0, 0, 0.5), true)
	c.no(Mat.liso(Color(0.35, 0.28, 0.2), 0.9), pai)


static func lanche(pai: Node3D, qual: String) -> void:
	if qual == "sanduiche":
		var p := Malha.new()
		for k in 2:
			p.cx(Vector3(0, 0.018 + k * 0.036, 0), Vector3(0.12, 0.018, 0.11), Vector3(0.02 * k, 0.1 * k, 0.01))
		p.no(Aeronave.m_forro(Color(0.62, 0.44, 0.24), 0.25, 0.0, 0.6), pai)
		var c := Malha.new()
		c.cx(Vector3(0, 0.036, 0), Vector3(0.128, 0.010, 0.116), Vector3(0, 0.12, 0))
		c.no(Mat.liso(Color(0.80, 0.55, 0.16), 0.5), pai)
		var v := Malha.new()
		for i in 12:
			var a := i * 0.6
			v.cx(Vector3(cos(a) * 0.055, 0.030 + 0.003 * sin(i * 4.0), sin(a) * 0.05), Vector3(0.04, 0.004, 0.03), Vector3(0.2, a, 0.2))
		v.no(Mat.liso(Color(0.16, 0.34, 0.07), 0.6), pai)
	else:
		for i in 4:
			var b := Malha.new()
			b.tubo([Vector3((i % 2) * 0.07 - 0.035, 0.006 + 0.016 * (i / 2), (i / 2) * 0.03 - 0.01), Vector3((i % 2) * 0.07 - 0.035, 0.018 + 0.016 * (i / 2), (i / 2) * 0.03 - 0.01)], [0.036, 0.032], 18, 1, 1, Color(0, 0, 0.5), true)
			b.no(Aeronave.m_forro(Color(0.58, 0.38, 0.16), 0.5, 0.0, 0.4), pai)
			var g := Malha.new()
			for k in 7:
				var a := k * 2.4 + i
				g.cx(Vector3((i % 2) * 0.07 - 0.035 + cos(a) * 0.018, 0.020 + 0.016 * (i / 2), (i / 2) * 0.03 - 0.01 + sin(a) * 0.018), Vector3(0.008, 0.006, 0.008))
			g.no(Mat.liso(Color(0.07, 0.035, 0.02), 0.4), pai)


static func chave(pai: Node3D) -> void:
	var ck := Malha.new()
	var pts := []
	var rs := []
	for i in 17:
		var a := TAU * i / 16.0
		pts.append(Vector3(cos(a) * 0.016, 0.075 + sin(a) * 0.016, 0))
		rs.append(0.0035)
	ck.tubo(pts, rs, 7)
	ck.tubo([Vector3(0, 0.06, 0), Vector3(0, 0, 0)], [0.0035, 0.0035], 8, 1, 1, Color(0, 0, 0.5), true)
	ck.cx(Vector3(0.008, 0.008, 0), Vector3(0.014, 0.006, 0.003))
	ck.cx(Vector3(0.007, 0.020, 0), Vector3(0.011, 0.005, 0.003))
	var n := ck.no(Mat.liso(Color(0.42, 0.32, 0.14), 0.35, 0.9), pai)
	n.rotation = Vector3(0, 0.3, 0.6)
	var pl := Malha.new()
	pl.cx(Vector3(-0.05, 0.07, 0.004), Vector3(0.035, 0.05, 0.003), Vector3(0, 0, 0.5))
	pl.no(Mat.liso(Color(0.35, 0.22, 0.10), 0.8), pai)


static func municao(pai: Node3D) -> void:
	var cx := Malha.new()
	cx.cx(Vector3(0, 0.03, 0), Vector3(0.12, 0.06, 0.07), Vector3(0, 0.2, 0))
	cx.no(Mat.liso(Color(0.36, 0.26, 0.10), 0.85), pai)
	var l := Malha.new()
	var b := Malha.new()
	for i in 5:
		var o := Vector3(0.03 + i * 0.016, 0.0, 0.065 + 0.008 * (i % 2))
		l.tubo([o, o + Vector3(0, 0.051, 0), o + Vector3(0, 0.058, 0), o + Vector3(0, 0.061, 0)], [0.0062, 0.0058, 0.0042, 0.0042], 12, 1, 1, Color(0, 0, 0.5), true)
		b.tubo([o + Vector3(0, 0.060, 0), o + Vector3(0, 0.072, 0), o + Vector3(0, 0.080, 0)], [0.0040, 0.0034, 0.0006], 12)
	l.no(Mat.liso(Color(0.66, 0.47, 0.16), 0.25, 0.95), pai)
	b.no(Mat.liso(Color(0.48, 0.24, 0.12), 0.3, 0.9), pai)


## rifle do Poly Haven, centrado, cano para -Z
static func rifle(pai: Node3D) -> Node3D:
	var m := Mat.modelo("bolt_action_rifle_7_62")
	pai.add_child(m)
	var bb := AABB()
	var pri := true
	for q in Mat.malhas_de("bolt_action_rifle_7_62"):
		var b: AABB = (q[1] as Transform3D) * (q[0] as Mesh).get_aabb()
		bb = b if pri else bb.merge(b)
		pri = false
	var maior := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var e := 1.14 / maior
	m.scale = Vector3.ONE * e
	m.position = -bb.get_center() * e
	return m