class_name Mundo
extends RefCounted
## Dados do mundo: onde fica cada coisa, altura do terreno, consulta de arvores.
## x = leste, z = sul, -z = norte. Tudo em metros.

const TAM := 1024.0
const N := 513
const PASSO := 2.0

# ---------- lugares
const QUEDA := Vector2(-365, -300)
const VILA := Vector2(-62, -112)
const CEMITERIO := Vector2(45, -96)
const TORRE := Vector2(172, -62)
const VAU := Vector2(-117, -87)          # passarela sobre o riacho

# caminhos: [x, z, altura]
const RIO := [[-345, -512, 108], [-330, -400, 96], [-290, -285, 84], [-232, -215, 77], [-200, -130, 70], [-120, -90, 62], [-80, -10, 53], [-10, 40, 45], [40, 110, 37], [130, 140, 31], [190, 215, 24], [262, 268, 18.5], [330, 300, 15], [420, 318, 11], [512, 330, 8]]
const ESTRADA := [[172, -56, 127], [190, -40, 124], [215, -20, 117], [248, 45, 99], [262, 110, 80], [300, 165, 60], [318, 220, 40], [309, 256, 25], [283, 312, 24], [262, 350, 23], [256, 392, 21]]
const RODOVIA := [[-512, 420, 52], [-200, 405, 40], [0, 398, 31], [150, 402, 25], [262, 400, 20.5], [380, 394, 17.5], [512, 388, 16]]
const TRILHAS := [
	[[-348, -294], [-300, -272], [-262, -236], [-236, -196], [-222, -158], [-208, -124], [-176, -108], [-150, -96], [-128, -81], [-106, -94], [-92, -102], [-62, -112]],
	[[-62, -112], [-34, -121], [-20, -124], [10, -118], [40, -104], [60, -96], [95, -92], [140, -78], [166, -64]],
]

# rumo da lua (aponta DO mundo PARA a lua)
static var LUA := Vector3(0.62, 0.58, 0.58).normalized()
static var luz_dir := Vector3(0.62, 0.58, 0.58).normalized()      # sol ou lua, agora

static var dados: DadosMundo
static var _grade := {}        # celula -> PackedInt32Array de indices
const CEL := 8.0


static func carregar() -> void:
	if dados:
		return
	dados = load("res://dados/mundo.res")
	_grade.clear()
	var nt := dados.arv.size() / 6
	for i in nt:
		var k := Vector2i(floori(dados.arv[i * 6] / CEL), floori(dados.arv[i * 6 + 2] / CEL))
		if not _grade.has(k):
			_grade[k] = PackedInt32Array()
		var a: PackedInt32Array = _grade[k]
		a.push_back(i)
		_grade[k] = a


static func altura(x: float, z: float) -> float:
	var fx := clampf((x + TAM * 0.5) / PASSO, 0.0, N - 1.001)
	var fz := clampf((z + TAM * 0.5) / PASSO, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	fx -= ix
	fz -= iz
	var h := dados.alt
	var a := h[iz * N + ix]
	var b := h[iz * N + ix + 1]
	var c := h[(iz + 1) * N + ix]
	var d := h[(iz + 1) * N + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func chao(x: float, z: float) -> Vector3:
	return Vector3(x, altura(x, z), z)


static func chaov(p: Vector2) -> Vector3:
	return Vector3(p.x, altura(p.x, p.y), p.y)


static func normal(x: float, z: float) -> Vector3:
	var e := 1.5
	return Vector3(altura(x - e, z) - altura(x + e, z), 2.0 * e, altura(x, z - e) - altura(x, z + e)).normalized()


## distancia e parametros do ponto mais proximo numa polilinha [x,z,...]
static func perto(linha: Array, x: float, z: float) -> Array:
	var best := 1e18
	var bs := 0
	var bt := 0.0
	for i in linha.size() - 1:
		var ax: float = linha[i][0]
		var az: float = linha[i][1]
		var dx: float = linha[i + 1][0] - ax
		var dz: float = linha[i + 1][1] - az
		var tt := clampf(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0.0, 1.0)
		var qx := ax + dx * tt - x
		var qz := az + dz * tt - z
		var d := qx * qx + qz * qz
		if d < best:
			best = d
			bs = i
			bt = tt
	return [sqrt(best), bs, bt]


static func dist(linha: Array, x: float, z: float) -> float:
	return perto(linha, x, z)[0]


## pontos suavizados (Catmull-Rom) de uma polilinha com altura opcional
static func suave(linha: Array, sub: int = 6) -> Array:
	var out := []
	var n := linha.size()
	for i in n - 1:
		var p0: Array = linha[maxi(i - 1, 0)]
		var p1: Array = linha[i]
		var p2: Array = linha[i + 1]
		var p3: Array = linha[mini(i + 2, n - 1)]
		for s in sub:
			var u := float(s) / sub
			var o := []
			for k in p1.size():
				if k == 2:
					o.append(lerpf(p1[k], p2[k], u))
				else:
					o.append(cubic_interpolate(p1[k], p2[k], p0[k], p3[k], u))
			out.append(o)
	out.append(linha[n - 1].duplicate())
	return out


static func arvores_perto(p: Vector3, raio: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r := int(ceil(raio / CEL))
	var cx := floori(p.x / CEL)
	var cz := floori(p.z / CEL)
	for ix in range(cx - r, cx + r + 1):
		for iz in range(cz - r, cz + r + 1):
			var a = _grade.get(Vector2i(ix, iz))
			if a != null:
				for i in a:
					var dx: float = dados.arv[i * 6] - p.x
					var dz: float = dados.arv[i * 6 + 2] - p.z
					if dx * dx + dz * dz < raio * raio:
						out.push_back(i)
	return out


## Quanto um tronco atrapalha a visao entre dois pontos (0 livre .. 1+ tampado)
static func obstrucao(a: Vector3, b: Vector3) -> float:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var l := d.length()
	if l < 0.5:
		return 0.0
	d /= l
	var ob := 0.0
	var vistos := {}
	var passo := CEL * 0.7
	var s := 0.0
	while s <= l:
		var k := Vector2i(floori((a.x + d.x * s) / CEL), floori((a.z + d.y * s) / CEL))
		if not vistos.has(k):
			vistos[k] = true
			var ar = _grade.get(k)
			if ar != null:
				for i in ar:
					var px: float = dados.arv[i * 6] - a.x
					var pz: float = dados.arv[i * 6 + 2] - a.z
					var ao := px * d.x + pz * d.y
					if ao > 1.0 and ao < l - 0.8:
						var pe := absf(px * d.y - pz * d.x)
						var r := raio_tronco(i)
						if pe < r + 0.12:
							ob += 0.55
						elif pe < r + 0.35:
							ob += 0.15
			ar = _grade_r(k)
			for j in ar:
				var px: float = dados.rod[j * 5] - a.x
				var pz: float = dados.rod[j * 5 + 2] - a.z
				var ao := px * d.x + pz * d.y
				if ao > 1.5 and ao < l - 0.4 and absf(px * d.y - pz * d.x) < 1.1 * dados.rod[j * 5 + 4]:
					ob += 0.45
		s += passo
	# relevo
	for q in [0.25, 0.5, 0.75]:
		var m := a.lerp(b, q)
		if altura(m.x, m.z) > m.y + 0.2:
			ob += 1.0
	return ob


static var _gr := {}
static func _grade_r(k: Vector2i) -> PackedInt32Array:
	if _gr.is_empty() and dados.rod.size() > 0:
		for j in dados.rod.size() / 5:
			var kk := Vector2i(floori(dados.rod[j * 5] / CEL), floori(dados.rod[j * 5 + 2] / CEL))
			if not _gr.has(kk):
				_gr[kk] = PackedInt32Array()
			var a: PackedInt32Array = _gr[kk]
			a.push_back(j)
			_gr[kk] = a
	return _gr.get(k, PackedInt32Array())


## dentro de uma moita de rododendro? (bom esconderijo)
static func moita(p: Vector3) -> float:
	var m := 0.0
	var cx := floori(p.x / CEL)
	var cz := floori(p.z / CEL)
	for ix in range(cx - 1, cx + 2):
		for iz in range(cz - 1, cz + 2):
			for j in _grade_r(Vector2i(ix, iz)):
				var d := Vector2(dados.rod[j * 5] - p.x, dados.rod[j * 5 + 2] - p.z).length()
				var r := 1.5 * dados.rod[j * 5 + 4]
				if d < r:
					m = maxf(m, 1.0 - smoothstep(r * 0.55, r, d))
	return m


const RAIOS := [0.42, 0.34, 0.50, 0.40, 0.36, 0.40, 0.30, 0.10]

static func raio_tronco(i: int) -> float:
	return RAIOS[int(dados.arv[i * 6 + 5])] * dados.arv[i * 6 + 4]


## 0 = sombra total, 1 = luar direto (aproximado pelas copas)
static func luar(p: Vector3) -> float:
	var o := Vector2(p.x, p.z)
	var d := Vector2(LUA.x, LUA.z)
	var sub := LUA.y / d.length()
	d = d.normalized()
	var luz := 1.0
	for s in [4.0, 10.0, 16.0, 22.0]:
		var q = o + d * s
		var hh: float = p.y + sub * s
		for i in arvores_perto(Vector3(q.x, 0, q.y), 5.0):
			var a := dados.arv
			var tp := int(a[i * 6 + 5])
			if tp == 6:
				continue
			var pe := absf((a[i * 6] - o.x) * d.y - (a[i * 6 + 2] - o.y) * d.x)
			var rel := hh - a[i * 6 + 1]
			var conif := tp == 4 or tp == 5
			if conif and rel > 2.0 and rel < 17.0 and pe < 2.4:
				luz *= 0.45
			elif not conif and rel > 7.0 and rel < 20.0 and pe < 2.4:
				luz *= 0.86
			elif pe < 0.5 and rel < 14.0:
				luz *= 0.6
	return clampf(luz * 1.15, 0.0, 1.0)
