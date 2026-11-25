class_name GenteAssar
extends RefCounted
## Monta as pessoas a partir dos dados CC0 do MakeHuman (corpo, pele, cabelo, roupa).
## Rodar:  godot --path jogo --headless res://ferr/assar.tscn -- gente mh=C:/pasta
## A pasta tem "mpfb" (corpo, alvos, esqueleto) e "mh/x" (roupas, cabelos, peles).

const ESC := 0.1                      # decimetros -> metros

# osso nosso -> osso da fonte (posicao) ; os demais caem no ancestral mantido
const MANTIDOS := ["root", "spine05", "spine04", "spine03", "spine02", "spine01", "neck01", "head", "jaw", "eye.L", "eye.R",
	"clavicle.L", "upperarm01.L", "lowerarm01.L", "wrist.L", "clavicle.R", "upperarm01.R", "lowerarm01.R", "wrist.R",
	"finger1-1.L", "finger1-2.L", "finger2-1.L", "finger2-2.L", "finger3-1.L", "finger3-2.L", "finger4-1.L", "finger4-2.L", "finger5-1.L", "finger5-2.L",
	"finger1-1.R", "finger1-2.R", "finger2-1.R", "finger2-2.R", "finger3-1.R", "finger3-2.R", "finger4-1.R", "finger4-2.R", "finger5-1.R", "finger5-2.R",
	"upperleg01.L", "lowerleg01.L", "foot.L", "upperleg01.R", "lowerleg01.R", "foot.R"]

## id: {s sexo, i idade 0 jovem..1 velho, e etnia {c,a,n}, p peso -1..1, h altura, pele, cab, cabcor, olho, sob, roupa, cor, sapato, chapeu, alvos}
const PESSOAS := {
	"viz": {"s": "female", "i": 0.75, "e": {"caucasian": 1.0}, "p": 0.25, "h": 1.62, "pele": "old_caucasian_female", "cab": "short03", "cabcor": [0.50, 0.48, 0.45], "olho": "bluegreen", "sob": "eyebrow009", "roupa": "female_casualsuit01", "cor": [0.30, 0.14, 0.22], "sapato": "shoes04", "alvos": {"head/head-round": 0.5, "nose/nose-volume-incr": 0.3, "cheek/l-cheek-volume-incr": 0.4, "cheek/r-cheek-volume-incr": 0.4}},
	"p01": {"s": "male", "i": 0.35, "e": {"caucasian": 1.0}, "p": 0.3, "h": 1.80, "pele": "middleage_caucasian_male", "cab": "short02", "cabcor": [0.20, 0.13, 0.08], "olho": "brown", "sob": "eyebrow001", "roupa": "male_elegantsuit01", "cor": [0.30, 0.30, 0.34], "sapato": "shoes03", "alvos": {"head/head-square": 0.5, "nose/nose-hump-incr": 0.5, "chin/chin-width-incr": 0.4}},
	"p02": {"s": "female", "i": 0.1, "e": {"caucasian": 1.0}, "p": -0.2, "h": 1.67, "pele": "young_caucasian_female2", "cab": "long01", "cabcor": [0.34, 0.20, 0.09], "olho": "green", "sob": "eyebrow006", "roupa": "female_casualsuit01", "cor": [0.46, 0.16, 0.13], "sapato": "shoes01", "alvos": {"head/head-oval": 0.4, "mouth/mouth-upperlip-volume-incr": 0.4, "nose/nose-point-up": 0.3}},
	"p03": {"s": "male", "i": 0.15, "e": {"african": 1.0}, "p": 0.0, "h": 1.78, "pele": "young_african_male", "cab": "afro01", "cabcor": [0.05, 0.04, 0.035], "olho": "brown", "sob": "eyebrow003", "roupa": "male_casualsuit05", "cor": [1.0, 1.0, 1.0], "sapato": "shoes01", "alvos": {"head/head-rectangular": 0.3, "chin/chin-prominent-incr": 0.3}},
	"p04": {"s": "male", "i": 0.85, "e": {"caucasian": 1.0}, "p": -0.1, "h": 1.72, "pele": "old_caucasian_male", "cab": "short04", "cabcor": [0.55, 0.54, 0.52], "olho": "grey", "sob": "eyebrow010", "roupa": "male_casualsuit03", "cor": [1.0, 1.0, 1.0], "sapato": "shoes04", "chapeu": "fedora01", "alvos": {"nose/nose-scale-vert-incr": 0.5, "cheek/l-cheek-inner-decr": 0.6, "cheek/r-cheek-inner-decr": 0.6}},
	"p05": {"s": "female", "i": 0.4, "e": {"asian": 1.0}, "p": 0.0, "h": 1.60, "pele": "middleage_asian_female", "cab": "bob01", "cabcor": [0.05, 0.045, 0.05], "olho": "brown", "sob": "eyebrow007", "roupa": "male_casualsuit01", "cor": [0.55, 0.85, 0.66], "sapato": "shoes04", "alvos": {"head/head-oval": 0.5}},
	"p06": {"s": "male", "i": 0.2, "e": {"caucasian": 0.6, "asian": 0.4}, "p": 0.15, "h": 1.76, "pele": "young_caucasian_male2", "cab": "short01", "cabcor": [0.10, 0.07, 0.05], "olho": "brownlight", "sob": "eyebrow002", "roupa": "male_casualsuit01", "cor": [1.0, 1.0, 1.0], "sapato": "shoes02", "alvos": {"head/head-triangular": 0.3, "eyes/l-eye-height2-decr": 0.4, "eyes/r-eye-height2-decr": 0.4}},
	"p07": {"s": "female", "i": 0.3, "e": {"african": 1.0}, "p": 0.1, "h": 1.65, "pele": "middleage_african_female", "cab": "braid01", "cabcor": [0.05, 0.04, 0.035], "olho": "brown", "sob": "eyebrow005", "roupa": "female_casualsuit01", "cor": [0.42, 0.34, 0.14], "sapato": "shoes01", "alvos": {"head/head-round": 0.3, "mouth/mouth-scale-horiz-incr": 0.3}},
	"p08": {"s": "male", "i": 0.55, "e": {"caucasian": 1.0}, "p": 0.8, "h": 1.74, "pele": "middleage_caucasian_male", "cab": "short03", "cabcor": [0.30, 0.22, 0.14], "olho": "lightblue", "sob": "eyebrow012", "roupa": "male_casualsuit01", "cor": [0.55, 0.50, 0.40], "sapato": "shoes01", "alvos": {"head/head-fat-incr": 0.7, "chin/chin-jaw-drop-incr": 0.5, "nose/nose-scale-horiz-incr": 0.4}},
	"com": {"s": "female", "i": 0.15, "e": {"caucasian": 1.0}, "p": -0.1, "h": 1.70, "pele": "young_caucasian_female", "cab": "ponytail01", "cabcor": [0.26, 0.15, 0.07], "olho": "blue", "sob": "eyebrow006", "roupa": "female_elegantsuit01", "cor": [0.055, 0.075, 0.16], "liso": 1.0, "sapato": "shoes04", "lenco": [0.42, 0.03, 0.03], "alvos": {"head/head-oval": 0.5, "mouth/mouth-scale-horiz-incr": 0.25, "cheek/l-cheek-bones-incr": 0.4, "cheek/r-cheek-bones-incr": 0.4}},
	"pil": {"s": "male", "i": 0.4, "e": {"caucasian": 1.0}, "p": 0.0, "h": 1.80, "pele": "middleage_caucasian_male", "cab": "short04", "cabcor": [0.16, 0.12, 0.09], "olho": "brown", "sob": "eyebrow001", "roupa": "male_elegantsuit01", "cor": [0.10, 0.12, 0.2], "sapato": "shoes03", "alvos": {"head/head-square": 0.3}},
	"ruth": {"s": "female", "i": 0.95, "e": {"caucasian": 1.0}, "p": 0.1, "h": 1.58, "pele": "old_caucasian_female", "cab": "ponytail01", "cabcor": [0.44, 0.42, 0.40], "olho": "lightblue", "sob": "eyebrow009", "roupa": "female_elegantsuit01", "cor": [0.20, 0.13, 0.09], "liso": 0.9, "infla": 0.012, "sapato": "shoes03", "cachecol": [0.30, 0.08, 0.06], "alvos": {"head/head-diamond": 0.5, "nose/nose-point-down": 0.5, "mouth/mouth-angles-down": 0.3}},
	"elias": {"s": "male", "i": 1.0, "e": {"african": 1.0}, "p": -0.2, "h": 1.75, "pele": "old_african_male", "cab": "short01", "cabcor": [0.60, 0.58, 0.55], "olho": "brown", "sob": "eyebrow010", "roupa": "male_casualsuit05", "cor": [0.8, 0.72, 0.6], "infla": 0.008, "sapato": "shoes03", "chapeu": "fedora_cocked", "cachecol": [0.20, 0.17, 0.12], "alvos": {"cheek/l-cheek-inner-decr": 0.6, "cheek/r-cheek-inner-decr": 0.6, "head/head-rectangular": 0.4}},
	"caleb": {"s": "male", "i": 0.5, "e": {"caucasian": 1.0}, "p": 0.35, "h": 1.84, "pele": "middleage_caucasian_male", "cab": "short02", "cabcor": [0.24, 0.11, 0.05], "olho": "green", "sob": "eyebrow012", "roupa": "male_casualsuit05", "cor": [0.62, 0.58, 0.50], "infla": 0.010, "sapato": "shoes03", "gorro": [0.20, 0.07, 0.05], "barba": 1.0, "alvos": {"head/head-square": 0.7, "chin/chin-width-incr": 0.5, "nose/nose-flaring-incr": 0.4}},
	"hannah": {"s": "female", "i": 0.2, "e": {"caucasian": 1.0}, "p": 0.0, "h": 1.66, "pele": "young_caucasian_female2", "cab": "braid01", "cabcor": [0.42, 0.28, 0.12], "olho": "blue", "sob": "eyebrow006", "roupa": "male_casualsuit05", "cor": [1.15, 0.62, 0.55], "infla": 0.006, "sapato": "shoes03", "cachecol": [0.36, 0.30, 0.20], "gorro": [0.30, 0.26, 0.22], "alvos": {"head/head-oval": 0.3, "nose/nose-point-width-decr": 0.4}},
	"amos": {"s": "male", "i": 0.6, "e": {"caucasian": 1.0}, "p": 0.1, "h": 1.77, "pele": "middleage_caucasian_male", "cab": "short04", "cabcor": [0.35, 0.33, 0.31], "olho": "grey", "sob": "eyebrow010", "roupa": "male_casualsuit01", "cor": [0.95, 0.66, 0.46], "infla": 0.006, "sapato": "shoes03", "gorro": [0.10, 0.12, 0.15], "barba": 0.6, "alvos": {"nose/nose-hump-incr": 0.6, "head/head-rectangular": 0.5}},
	"pol1": {"s": "male", "i": 0.45, "e": {"caucasian": 1.0}, "p": 0.3, "h": 1.83, "pele": "middleage_caucasian_male", "cab": "short04", "cabcor": [0.20, 0.17, 0.13], "olho": "brown", "sob": "eyebrow001", "roupa": "male_casualsuit05", "cor": [0.34, 0.30, 0.22], "calca": [0.16, 0.13, 0.09], "sapato": "shoes03", "chapeu": "fedora01", "alvos": {"head/head-square": 0.5, "chin/chin-width-incr": 0.3}},
	"pol2": {"s": "female", "i": 0.3, "e": {"caucasian": 0.7, "african": 0.3}, "p": 0.1, "h": 1.70, "pele": "middleage_caucasian_female", "cab": "ponytail01", "cabcor": [0.10, 0.07, 0.05], "olho": "brownlight", "sob": "eyebrow005", "roupa": "male_casualsuit05", "cor": [0.34, 0.30, 0.22], "calca": [0.16, 0.13, 0.09], "sapato": "shoes03", "chapeu": "fedora01", "alvos": {"head/head-oval": 0.3}},
}

const EXPR := {
	"pisca": {"eye-left-closure": 1.0, "eye-right-closure": 1.0},
	"fala": {"mouth-open": 0.75, "mouth-parling": 0.3},
	"sorri": {"mouth-corner-puller": 0.8, "mouth-parling": 0.12},
	"medo": {"eyebrows-left-inner-up": 1.0, "eyebrows-right-inner-up": 1.0, "eye-left-opened-up": 0.8, "eye-right-opened-up": 0.8, "mouth-depression-retraction": 0.5, "mouth-open": 0.3},
}

var raiz := ""
var verts0 := PackedVector3Array()
var uvs := PackedVector2Array()
var faces := {}                 # grupo -> [[v,vt]*n]
var grupo_v := {}               # grupo -> indices unicos
var pesos := []                 # por vertice: {osso: peso}
var rig := {}
var pai := []                   # indice do pai por osso mantido
var mapa_osso := {}
var _cache_alvo := {}
var jaw := {}


func rodar(pasta: String, so: PackedStringArray) -> void:
	raiz = pasta
	DirAccess.make_dir_recursive_absolute("res://dados/gente")
	DirAccess.make_dir_recursive_absolute("res://tex/gente")
	_base()
	_rig()
	for id in PESSOAS:
		if so.size() > 0 and not (id in so):
			continue
		var t0 := Time.get_ticks_msec()
		_pessoa(id, PESSOAS[id])
		print("pessoa ", id, " ", (Time.get_ticks_msec() - t0) / 1000.0, " s")


func _texto(p: String) -> String:
	if p.ends_with(".gz"):
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			push_error("falta " + p)
			return ""
		var b := f.get_buffer(f.get_length())
		return b.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	return FileAccess.get_file_as_string(p)


func _obj(p: String) -> Dictionary:
	var v := PackedVector3Array()
	var t := PackedVector2Array()
	var fs := {}
	var g := ""
	for l in _texto(p).split("\n", false):
		if l.begins_with("v "):
			var q := l.split(" ", false)
			v.push_back(Vector3(float(q[1]), float(q[2]), float(q[3])))
		elif l.begins_with("vt "):
			var q := l.split(" ", false)
			t.push_back(Vector2(float(q[1]), 1.0 - float(q[2])))
		elif l.begins_with("g "):
			g = l.substr(2).strip_edges()
		elif l.begins_with("f "):
			var q := l.strip_edges().split(" ", false)
			var fc := []
			for k in range(1, q.size()):
				var s := q[k].split("/")
				fc.append([int(s[0]) - 1, int(s[1]) - 1 if s.size() > 1 and s[1] != "" else 0])
			if not fs.has(g): fs[g] = []
			fs[g].append(fc)
	return {"v": v, "t": t, "f": fs}


func _base() -> void:
	var o := _obj(raiz + "/mpfb/3dobjs/base.obj")
	verts0 = o.v
	uvs = o.t
	faces = o.f
	for g in faces:
		var d := {}
		for f in faces[g]:
			for q in f: d[q[0]] = true
		grupo_v[g] = d.keys()
	print("base: ", verts0.size(), " verts, ", faces.size(), " grupos")


func _rig() -> void:
	rig = JSON.parse_string(_texto(raiz + "/mpfb/rigs/standard/rig.default.json"))
	if rig.has("bones"): rig = rig.bones
	var w = JSON.parse_string(_texto(raiz + "/mpfb/rigs/standard/weights.default.json"))
	if w.has("weights"): w = w.weights
	for b in MANTIDOS:
		mapa_osso[b] = MANTIDOS.find(b)
	# osso qualquer -> mantido mais proximo acima
	for b in rig:
		var q: String = b
		while not (q in MANTIDOS):
			q = rig[q].parent
			if q == "": q = "root"
		mapa_osso[b] = MANTIDOS.find(q)
	for b in MANTIDOS:
		var q: String = rig[b].parent
		while q != "" and not (q in MANTIDOS): q = rig[q].parent
		pai.append(MANTIDOS.find(q) if q != "" else -1)
	pesos.resize(verts0.size())
	for i in pesos.size(): pesos[i] = {}
	for b in w:
		if not mapa_osso.has(b): continue
		var k: int = mapa_osso[b]
		for q in w[b]:
			var d: Dictionary = pesos[int(q[0])]
			d[k] = d.get(k, 0.0) + float(q[1])
	_mascara_barba()


## onde nasce barba: abaixo do nariz, na frente da orelha, fora dos labios
func _mascara_barba() -> void:
	var med := func(g: String) -> Vector3:
		var s := Vector3.ZERO
		for i in grupo_v[g]: s += verts0[i]
		return s / grupo_v[g].size()
	var eye: Vector3 = med.call("joint-l-eye")
	var hb := MANTIDOS.find("head")
	var jb := MANTIDOS.find("jaw")
	var nb := MANTIDOS.find("neck01")
	var chin := 1e9
	var zf := -1e9
	var zt := 1e9
	for i in grupo_v["body"]:
		var p: Vector3 = verts0[i]
		var wh: float = pesos[i].get(hb, 0.0) + pesos[i].get(jb, 0.0)
		if wh < 0.6: continue
		zt = minf(zt, p.z)
		if absf(p.x) < 0.12:
			zf = maxf(zf, p.z)
			if p.z > eye.z - 0.1: chin = minf(chin, p.y)
	for i in grupo_v["body"]:
		var p: Vector3 = verts0[i]
		var wh: float = pesos[i].get(hb, 0.0) + pesos[i].get(jb, 0.0)
		if wh < 0.25: continue
		var t := (eye.y - p.y) / (eye.y - chin)
		var m := smoothstep(0.50, 0.60, t) * smoothstep(eye.z - 0.95, eye.z - 0.45, p.z)
		# labios ficam livres
		if absf(p.x) < 0.27:
			m *= 1.0 - smoothstep(0.60, 0.64, t) * (1.0 - smoothstep(0.74, 0.79, t)) * smoothstep(eye.z - 0.05, eye.z + 0.15, p.z)
		# nariz livre
		if absf(p.x) < 0.2 and t < 0.56: m = 0.0
		jaw[i] = m * smoothstep(0.25, 0.8, wh)


func _pos_osso(b: String, v: PackedVector3Array) -> Vector3:
	var h: Dictionary = rig[b].head
	match h.strategy:
		"CUBE":
			var s := Vector3.ZERO
			for i in grupo_v[h.cube_name]: s += v[i]
			return s / grupo_v[h.cube_name].size()
		"VERTEX":
			return v[int(h.vertex_index)]
		"MEAN":
			var s := Vector3.ZERO
			for i in h.vertex_indices: s += v[int(i)]
			return s / h.vertex_indices.size()
	return Vector3.ZERO


func _alvo(nome: String) -> Array:
	if not _cache_alvo.has(nome):
		var p := raiz + "/mpfb/targets/" + nome + ".target.gz"
		var ids := PackedInt32Array()
		var ds := PackedVector3Array()
		if not FileAccess.file_exists(p):
			print("  alvo ausente: ", nome)
		else:
			for l in _texto(p).split("\n", false):
				if l.begins_with("#") or l.begins_with('"'): continue
				var q := l.strip_edges().split(" ", false)
				if q.size() < 4: continue
				ids.push_back(int(q[0]))
				ds.push_back(Vector3(float(q[1]), float(q[2]), float(q[3])))
		_cache_alvo[nome] = [ids, ds]
	return _cache_alvo[nome]


func _soma(v: PackedVector3Array, nome: String, w: float) -> void:
	if absf(w) < 0.001: return
	var a := _alvo(nome)
	for i in a[0].size():
		v[a[0][i]] += a[1][i] * w


# ------------------------------------------------------------------ roupas e cabelos (mhclo)
func _proxy(pasta: String, nome: String) -> Dictionary:
	var dir := raiz + "/mh/x/" + pasta + "/" + nome + "/"
	if pasta == "olhos": dir = raiz + "/mh/x/eyes/low-poly/"
	var arq := dir + nome + ".mhclo"
	var r := {"lig": [], "apaga": {}, "dir": dir, "ex": [], "mat": {}}
	var modo := ""
	for l0 in _texto(arq).split("\n", false):
		var l := l0.strip_edges()
		if l == "" or l.begins_with("#"): continue
		var q := l.split(" ", false)
		if q[0] == "verts":
			modo = "verts"
			continue
		if q[0] == "delete_verts":
			modo = "apaga"
			continue
		if q[0] in ["weights", "name", "uuid", "tag"]:
			modo = ""
			continue
		if q[0] in ["x_scale", "y_scale", "z_scale"]:
			r[q[0]] = [int(q[1]), int(q[2]), float(q[3])]
			continue
		if q[0] == "obj_file":
			r["obj"] = _obj(dir + q[1])
			continue
		if q[0] == "material":
			r["mhmat"] = q[1]
			continue
		if modo == "verts" and q[0].is_valid_int():
			if q.size() == 1:
				r.lig.append([int(q[0]), int(q[0]), int(q[0]), 1.0, 0.0, 0.0, Vector3.ZERO])
			elif q.size() >= 6:
				r.lig.append([int(q[0]), int(q[1]), int(q[2]), float(q[3]), float(q[4]), float(q[5]), Vector3(float(q[6]), float(q[7]), float(q[8])) if q.size() >= 9 else Vector3.ZERO])
		elif modo == "apaga":
			var k := 0
			while k < q.size():
				if k + 2 < q.size() and q[k + 1] == "-":
					for i in range(int(q[k]), int(q[k + 2]) + 1): r.apaga[i] = true
					k += 3
				else:
					if q[k].is_valid_int(): r.apaga[int(q[k])] = true
					k += 1
	if r.has("mhmat"):
		for l in _texto(dir + r.mhmat).split("\n", false):
			var q := l.strip_edges().split(" ", false)
			if q.size() >= 2 and q[0].ends_with("Texture"): r.mat[q[0]] = q[1]
	return r


func _veste(r: Dictionary, v: PackedVector3Array) -> PackedVector3Array:
	var e := Vector3.ONE
	for k in 3:
		var n: String = ["x_scale", "y_scale", "z_scale"][k]
		if r.has(n):
			e[k] = absf(v[r[n][0]][k] - v[r[n][1]][k]) / r[n][2]
	var out := PackedVector3Array()
	out.resize(r.lig.size())
	for i in r.lig.size():
		var q: Array = r.lig[i]
		out[i] = v[q[0]] * q[3] + v[q[1]] * q[4] + v[q[2]] * q[5] + (q[6] as Vector3) * e
	return out


func _pesos_proxy(r: Dictionary) -> Array:
	var out := []
	for q in r.lig:
		var d := {}
		for k in 3:
			var w: float = maxf(q[3 + k], 0.0)
			if w <= 0.0: continue
			for b in pesos[q[k]]:
				d[b] = d.get(b, 0.0) + pesos[q[k]][b] * w
		out.append(d)
	return out


# ------------------------------------------------------------------ montagem
func _conv(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


## faces: lista de [[v,vt]...] ; devolve arrays + blend
func _malha(v: PackedVector3Array, fs: Array, uv: PackedVector2Array, pw: Array, formas: Array, esc: float, chao: float, infla: float = 0.0) -> Dictionary:
	# normais suaves por vertice
	var nr := PackedVector3Array()
	nr.resize(v.size())
	for f in fs:
		for k in range(1, f.size() - 1):
			var n := (v[f[k][0]] - v[f[0][0]]).cross(v[f[k + 1][0]] - v[f[0][0]])
			for q in [f[0], f[k], f[k + 1]]: nr[q[0]] += n
	for i in nr.size(): nr[i] = nr[i].normalized()
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	var C := PackedColorArray()
	var base := v.size() == verts0.size()
	var mapa := {}
	var orig := PackedInt32Array()
	for f in fs:
		var ix := []
		for q in f:
			var k: int = q[0] * 65536 + q[1]
			if not mapa.has(k):
				mapa[k] = P.size()
				orig.push_back(q[0])
				P.push_back((_conv(v[q[0]]) + _conv(nr[q[0]]) * infla / ESC) * ESC * esc - Vector3(0, chao, 0))
				N.push_back(_conv(nr[q[0]]))
				U.push_back(uv[q[1]])
				C.push_back(Color(jaw.get(q[0], 0.0) if base else 0.0, 0, 0, 1))
				var l := []
				for b in pw[q[0]]: l.append([pw[q[0]][b], b])
				l.sort_custom(func(a, b): return a[0] > b[0])
				var s := 0.0
				for m in mini(4, l.size()): s += l[m][0]
				for m in 4:
					if m < l.size() and s > 0.0:
						B.push_back(l[m][1])
						W.push_back(l[m][0] / s)
					else:
						B.push_back(0)
						W.push_back(1.0 if m == 0 and s <= 0.0 else 0.0)
			ix.append(mapa[k])
		for k in range(1, ix.size() - 1):
			# frente horaria
			I.append_array(PackedInt32Array([ix[0], ix[k + 1], ix[k]]))
	var bl := []
	for fv in formas:
		var P2 := PackedVector3Array()
		P2.resize(P.size())
		for i in P.size():
			P2[i] = (_conv(fv[orig[i]]) + _conv(nr[orig[i]]) * infla / ESC) * ESC * esc - Vector3(0, chao, 0)
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = P2
		a2[Mesh.ARRAY_NORMAL] = N
		bl.append(a2)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = P
	a[Mesh.ARRAY_NORMAL] = N
	a[Mesh.ARRAY_TEX_UV] = U
	a[Mesh.ARRAY_COLOR] = C
	a[Mesh.ARRAY_BONES] = B
	a[Mesh.ARRAY_WEIGHTS] = W
	a[Mesh.ARRAY_INDEX] = I
	# tangentes
	var st := SurfaceTool.new()
	st.create_from_arrays(a)
	st.generate_tangents()
	var at := st.commit_to_arrays()
	a[Mesh.ARRAY_TANGENT] = at[Mesh.ARRAY_TANGENT]
	if (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() != P.size() * 4:
		a[Mesh.ARRAY_TANGENT] = null
	else:
		for b2 in bl: b2[Mesh.ARRAY_TANGENT] = a[Mesh.ARRAY_TANGENT]
	return {"a": a, "bl": bl}


func _faces_proxy(r: Dictionary) -> Array:
	var fs := []
	for g in r.obj.f: fs.append_array(r.obj.f[g])
	return fs


func _img(origem: String, destino: String, tam: int, alfa: bool = false, f: Callable = Callable()) -> void:
	var d := "res://tex/gente/" + destino
	if FileAccess.file_exists(d): return
	var im := Image.load_from_file(origem)
	if im == null:
		print("  imagem ausente ", origem)
		return
	if im.get_width() > tam: im.resize(tam, int(tam * float(im.get_height()) / im.get_width()), Image.INTERPOLATE_LANCZOS)
	im.convert(Image.FORMAT_RGBA8 if alfa else Image.FORMAT_RGB8)
	if f.is_valid(): f.call(im)
	if alfa: im.save_png(d)
	else: im.save_jpg(d, 0.92)


## roupa: limpa o logotipo, alisa listras e tinge
func _tinge(im: Image, ao: Image, cor: Color, liso: float, calca) -> void:
	var w := im.get_width()
	var h := im.get_height()
	if ao: ao.resize(w, h)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			var l := c.get_luminance()
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var sat := (mx - mn) / maxf(mx, 0.001)
			var jeans := c.b > c.r * 1.05 and sat > 0.12 and sat < 0.62
			if calca != null and jeans and liso < 0.0:
				im.set_pixel(x, y, Color(calca[0], calca[1], calca[2]) * (0.5 + l * 1.4))
				continue
			var a := ao.get_pixel(x, y).r if ao else 1.0
			if liso > 0.0:
				var b := Color(cor.r, cor.g, cor.b) * (0.35 + 0.65 * a)
				c = c.lerp(b, liso)
				if liso < 1.0: c = Color(c.r, c.g, c.b)
				else: c = b * (0.86 + 0.5 * (l - 0.25))
			else:
				c = Color(c.r * cor.r, c.g * cor.g, c.b * cor.b)
			im.set_pixel(x, y, c)


func _pessoa(id: String, d: Dictionary) -> void:
	var v := verts0.duplicate()
	var y: float = 1.0 - d.i
	for et in d.e:
		_soma(v, "macrodetails/%s-%s-young" % [et, d.s], d.e[et] * y)
		_soma(v, "macrodetails/%s-%s-old" % [et, d.s], d.e[et] * d.i)
	var pk := {"average": 1.0 - absf(d.p), "max": maxf(d.p, 0.0), "min": maxf(-d.p, 0.0)}
	for k in pk:
		for q in [["young", y], ["old", d.i]]:
			_soma(v, "macrodetails/universal-%s-%s-averagemuscle-%sweight" % [d.s, q[0], k], pk[k] * q[1])
	for k in d.alvos: _soma(v, k, d.alvos[k])
	# altura real
	var ymin := 1e9
	var ymax := -1e9
	for i in grupo_v["body"]:
		ymin = minf(ymin, v[i].y)
		ymax = maxf(ymax, v[i].y)
	var esc: float = d.h / ((ymax - ymin) * ESC)
	# expressoes
	var et0: String = d.e.keys()[0]
	var formas := []
	var nomes := []
	for ex in EXPR:
		var fv := v.duplicate()
		for k in EXPR[ex]: _soma(fv, "expression/units/%s/%s" % [et0, k], EXPR[ex][k])
		formas.append(fv)
		nomes.append(ex)
	# pecas
	var roupas := [["clothes", d.roupa, "roupa"], ["clothes", d.sapato, "sapato"]]
	if d.has("chapeu"): roupas.append(["clothes", d.chapeu, "chapeu"])
	var pr := {}
	for q in roupas: pr[q[2]] = _proxy(q[0], q[1])
	pr["cabelo"] = _proxy("hair", d.cab)
	pr["cilios"] = _proxy("eyelashes", "eyelashes02" if d.s == "female" else "eyelashes01")
	pr["sobr"] = _proxy("eyebrows", d.sob)
	pr["dentes"] = _proxy("teeth", "teeth_base")
	pr["olhos"] = _proxy("olhos", "low-poly")
	var some := {}
	for k in ["roupa", "sapato"]: some.merge(pr[k].apaga)
	# chao: sola do sapato
	var chao := 1e9
	for p in _veste(pr.sapato, v): chao = minf(chao, p.y)
	chao *= ESC * esc
	# separa rosto e corpo
	var cab_ossos := {}
	for b in ["head", "jaw", "eye.L", "eye.R", "neck01"]: cab_ossos[MANTIDOS.find(b)] = true
	var fr := []
	var fc := []
	for f in faces["body"]:
		var fora := true
		for q in f:
			if not some.has(q[0]): fora = false
		if fora: continue
		var r := true
		for q in f:
			var s := 0.0
			for b in pesos[q[0]]:
				if cab_ossos.has(b): s += pesos[q[0]][b]
			if s < 0.35: r = false
		if r: fr.append(f)
		else: fc.append(f)
	var dg := DadosGente.new()
	var im_r := ImporterMesh.new()
	for n in nomes: im_r.add_blend_shape(n)
	var im_c := ImporterMesh.new()
	var bota := func(im: ImporterMesh, m: Dictionary, nome: String) -> void:
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.a, m.bl, {}, null, nome)
	bota.call(im_r, _malha(v, fr, uvs, pesos, formas, esc, chao), "pele")
	for k in ["cilios", "sobr", "dentes"]:
		var fo := []
		for f in formas: fo.append(_veste(pr[k], f))
		bota.call(im_r, _malha(_veste(pr[k], v), _faces_proxy(pr[k]), pr[k].obj.t, _pesos_proxy(pr[k]), fo, esc, chao), k)
	if fc.size() > 0: bota.call(im_c, _malha(v, fc, uvs, pesos, [], esc, chao), "pele")
	for k in ["roupa", "sapato", "cabelo", "chapeu"]:
		if pr.has(k):
			bota.call(im_c, _malha(_veste(pr[k], v), _faces_proxy(pr[k]), pr[k].obj.t, _pesos_proxy(pr[k]), [], esc, chao, d.get("infla", 0.0) if k == "roupa" else 0.0), k)
	# olhos: cada um preso ao seu osso
	var po := _pesos_proxy(pr.olhos)
	var vo := _veste(pr.olhos, v)
	for i in po.size():
		po[i] = {MANTIDOS.find("eye.L" if vo[i].x > 0.0 else "eye.R"): 1.0}
	bota.call(im_c, _malha(vo, _faces_proxy(pr.olhos), pr.olhos.obj.t, po, [], esc, chao), "olhos")
	im_c.generate_lods(60.0, 25.0, [])
	im_r.generate_lods(60.0, 25.0, [])
	dg.rosto = im_r.get_mesh()
	dg.corpo = im_c.get_mesh()
	dg.sup_rosto = PackedStringArray()
	for i in im_r.get_surface_count(): dg.sup_rosto.push_back(im_r.get_surface_name(i))
	dg.sup_corpo = PackedStringArray()
	for i in im_c.get_surface_count(): dg.sup_corpo.push_back(im_c.get_surface_name(i))
	dg.ossos = PackedStringArray(MANTIDOS)
	dg.pais = PackedInt32Array(pai)
	var ps := PackedVector3Array()
	for b in MANTIDOS: ps.push_back(_conv(_pos_osso(b, v)) * ESC * esc - Vector3(0, chao, 0))
	dg.pos = ps
	# pontas (direcao dos segmentos finais)
	dg.altura = d.h
	# ---------- texturas
	var sx: String = d.pele
	var pd := raiz + "/mh/x/skins/" + sx + "/"
	for a in DirAccess.get_files_at(pd):
		if a.ends_with(".png"): _img(pd + a, "pele_%s.jpg" % sx, 2048)
	dg.tex = {"pele": "pele_%s.jpg" % sx}
	var rp: Dictionary = pr.roupa
	var liso: float = d.get("liso", 0.0)
	var aoim: Image = null
	if rp.mat.has("aomapTexture"): aoim = Image.load_from_file(rp.dir + rp.mat.aomapTexture)
	var cor := Color(d.cor[0], d.cor[1], d.cor[2])
	var fem: bool = d.roupa == "female_casualsuit01"
	var calca = d.get("calca")
	_img(rp.dir + rp.mat.diffuseTexture, "roupa_%s.jpg" % id, 1024, false, func(im: Image):
		if fem: _camiseta(im, cor)
		else: _tinge(im, aoim, cor, liso if calca == null else -1.0, calca))
	if rp.mat.has("normalmapTexture"): _img(rp.dir + rp.mat.normalmapTexture, "n_%s.jpg" % d.roupa, 1024)
	dg.tex["roupa"] = "roupa_%s.jpg" % id
	dg.tex["roupa_n"] = "n_%s.jpg" % d.roupa if rp.mat.has("normalmapTexture") else ""
	var sp: Dictionary = pr.sapato
	_img(sp.dir + sp.mat.diffuseTexture, "%s.jpg" % d.sapato, 512)
	dg.tex["sapato"] = "%s.jpg" % d.sapato
	if pr.has("chapeu"):
		_img(pr.chapeu.dir + pr.chapeu.mat.diffuseTexture, "%s.jpg" % d.chapeu, 512)
		dg.tex["chapeu"] = "%s.jpg" % d.chapeu
	_img(pr.cabelo.dir + pr.cabelo.mat.diffuseTexture, "cab_%s.png" % d.cab, 1024, true, func(im: Image): im.fix_alpha_edges())
	dg.tex["cabelo"] = "cab_%s.png" % d.cab
	for k in ["cilios", "sobr", "dentes"]:
		var nm: String = str(pr[k].mat.get("diffuseTexture", ""))
		if nm == "": continue
		_img(pr[k].dir + nm, nm.get_basename() + ".png", 512, true, func(im: Image): im.fix_alpha_edges())
		dg.tex[k] = nm.get_basename() + ".png"
	_img(raiz + "/mh/x/eyes/materials/%s_eye.png" % d.olho, "olho_%s.jpg" % d.olho, 512)
	dg.tex["olhos"] = "olho_%s.jpg" % d.olho
	dg.cab_cor = Color(d.cabcor[0], d.cabcor[1], d.cabcor[2])
	dg.barba = d.get("barba", 0.0)
	dg.gorro = Color(d.gorro[0], d.gorro[1], d.gorro[2]) if d.has("gorro") else Color(0, 0, 0, 0)
	dg.cachecol = Color(d.cachecol[0], d.cachecol[1], d.cachecol[2]) if d.has("cachecol") else Color(0, 0, 0, 0)
	# topo da cabeca, para o gorro
	var top := Vector3(0, -1e9, 0)
	for f in fr:
		for q in f:
			var p := _conv(v[q[0]]) * ESC * esc - Vector3(0, chao, 0)
			if p.y > top.y: top = p
	# centro e tamanho do cranio
	var x0 := 1e9
	var x1 := -1e9
	var z0 := 1e9
	var z1 := -1e9
	for f in fr:
		for q in f:
			var p := _conv(v[q[0]]) * ESC * esc - Vector3(0, chao, 0)
			if p.y > top.y - 0.085:
				x0 = minf(x0, p.x)
				x1 = maxf(x1, p.x)
				z0 = minf(z0, p.z)
				z1 = maxf(z1, p.z)
	dg.topo = Vector3((x0 + x1) * 0.5, top.y, (z0 + z1) * 0.5)
	dg.cranio = Vector2(x1 - x0, z1 - z0) * 0.5
	dg.fem = d.s == "female"
	dg.lenco = Color(d.lenco[0], d.lenco[1], d.lenco[2]) if d.has("lenco") else Color(0, 0, 0, 0)
	dg.etnia = et0
	ResourceSaver.save(dg, "res://dados/gente/%s.res" % id, ResourceSaver.FLAG_COMPRESS)


## camiseta azul com estampa laranja -> malha de la lisa na cor pedida
func _camiseta(im: Image, cor: Color) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var ms := PackedByteArray()
	ms.resize(w * h)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var sat := (mx - minf(c.r, minf(c.g, c.b))) / maxf(mx, 0.001)
			if (c.b > c.r and sat > 0.60) or (c.r > c.b * 1.10 and sat > 0.22): ms[y * w + x] = 1
	# fecha buracos da estampa
	for volta in 3:
		var it := PackedInt32Array()
		it.resize((w + 1) * (h + 1))
		for y in h:
			var lin := 0
			for x in w:
				lin += ms[y * w + x]
				it[(y + 1) * (w + 1) + x + 1] = it[y * (w + 1) + x + 1] + lin
		var r := 9
		for y in range(r, h - r):
			for x in range(r, w - r):
				if ms[y * w + x] == 0:
					var s := it[(y + r) * (w + 1) + x + r] - it[(y - r) * (w + 1) + x + r] - it[(y + r) * (w + 1) + x - r] + it[(y - r) * (w + 1) + x - r]
					if s > 4 * r * r * 0.55: ms[y * w + x] = 1
	for y in h:
		for x in w:
			if ms[y * w + x] == 1:
				var tr := 0.82 + 0.10 * sin(y * 2.1) * sin(x * 1.05) + 0.05 * sin(x * 0.13) * sin(y * 0.11)
				im.set_pixel(x, y, Color(cor.r * tr, cor.g * tr, cor.b * tr))
