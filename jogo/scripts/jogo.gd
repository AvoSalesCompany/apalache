extends Node
## Autoload "Jogo": estado global, opcoes, salvamento e teclas.

signal legenda(quem: String, texto: String, dur: float)
signal objetivo_mudou(texto: String)
signal aviso(texto: String)
signal nota(titulo: String, corpo: String)

const CFG := "user://opcoes.cfg"
const SAVE := "user://salvo.json"

# ---- opcoes
var qualidade := 1          # 0 baixa 1 media 2 alta 3 ultra
var sens := 1.0
var gama := 1.0
var volume := 0.9
var tela_cheia := true
var legendas := true

# ---- partida
var etapa := 0
var itens := {}             # id -> quantidade
var notas := []             # [titulo, corpo]
var objetivo := ""
var pos_salva := Vector3.ZERO
var giro_salvo := 0.0
var vida_salva := 100.0
var frio_salvo := 0.0
var tempo := 0.0
var mortes := 0
var chamados := 0
var flags := {}

var jogador = null
var floresta = null
var criatura = null
var hud = null
var historia = null
var diretor = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_teclas()
	carregar_opcoes()


func _teclas() -> void:
	var t := {
		"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN], "esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT],
		"correr": [KEY_SHIFT], "agachar": [KEY_CTRL], "pular": [KEY_SPACE], "usar": [KEY_E], "gritar": [KEY_Q],
		"bussola": [KEY_C], "diario": [KEY_TAB], "curar": [KEY_H], "pausa": [KEY_ESCAPE], "arremessar": [KEY_F],
	}
	for a in t:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in t[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for par in [["arremessar", MOUSE_BUTTON_LEFT], ["foco", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(par[0]):
			InputMap.add_action(par[0])
		var m := InputEventMouseButton.new()
		m.button_index = par[1]
		InputMap.action_add_event(par[0], m)


# ------------------------------------------------------------ opcoes
func carregar_opcoes() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) == OK:
		qualidade = c.get_value("v", "qualidade", qualidade)
		sens = c.get_value("v", "sens", sens)
		gama = c.get_value("v", "gama", gama)
		volume = c.get_value("v", "volume", volume)
		tela_cheia = c.get_value("v", "tela_cheia", tela_cheia)
		legendas = c.get_value("v", "legendas", legendas)
	aplicar_opcoes()


func salvar_opcoes() -> void:
	var c := ConfigFile.new()
	for k in ["qualidade", "sens", "gama", "volume", "tela_cheia", "legendas"]:
		c.set_value("v", k, get(k))
	c.save(CFG)
	aplicar_opcoes()


func aplicar_opcoes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not ("--windowed" in args) and DisplayServer.get_name() != "headless" and not Teste.ativo:
		var w := DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia else DisplayServer.WINDOW_MODE_MAXIMIZED
		if DisplayServer.window_get_mode() != w:
			DisplayServer.window_set_mode(w)
	var vp := get_viewport()
	if vp == null:
		return
	var esc: float = [0.55, 0.67, 0.77, 1.0][qualidade]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	vp.scaling_3d_scale = esc
	vp.fsr_sharpness = 0.35
	vp.mesh_lod_threshold = [4.0, 3.0, 2.0, 1.0][qualidade]
	RenderingServer.directional_shadow_atlas_set_size([2048, 3072, 4096, 4096][qualidade], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([1, 2, 3, 4][qualidade])
	RenderingServer.environment_set_volumetric_fog_volume_size([64, 80, 112, 160][qualidade], [64, 80, 112, 128][qualidade])
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	RenderingServer.environment_set_ssao_quality([0, 1, 2, 3][qualidade], qualidade < 3, 0.5, 2, 50, 300)
	get_tree().call_group("opcoes", "opcoes_mudaram")


# ------------------------------------------------------------ partida
func nova_partida() -> void:
	etapa = 0
	itens = {}
	notas = []
	objetivo = ""
	flags = {}
	tempo = 0.0
	mortes = 0
	chamados = 0
	vida_salva = 100.0
	frio_salvo = 0.0


func tem(id: String) -> int:
	return itens.get(id, 0)


func dar(id: String, n: int = 1) -> void:
	itens[id] = tem(id) + n


func gastar(id: String) -> bool:
	if tem(id) <= 0:
		return false
	itens[id] -= 1
	return true


func falar(quem: String, texto: String, dur: float = 4.0) -> void:
	legenda.emit(quem, texto, dur)


func definir_objetivo(t: String) -> void:
	objetivo = t
	objetivo_mudou.emit(t)


func ler(titulo: String, corpo: String) -> void:
	for q in notas:
		if q[0] == titulo:
			nota.emit(titulo, corpo)
			return
	notas.append([titulo, corpo])
	nota.emit(titulo, corpo)


func salvar() -> void:
	if jogador:
		pos_salva = jogador.global_position
		giro_salvo = jogador.rotation.y
		vida_salva = maxf(45.0, jogador.vida)
		frio_salvo = minf(60.0, jogador.frio)
	var d := {"etapa": etapa, "itens": itens, "notas": notas, "objetivo": objetivo, "flags": flags, "tempo": tempo, "mortes": mortes, "chamados": chamados,
		"px": pos_salva.x, "py": pos_salva.y, "pz": pos_salva.z, "giro": giro_salvo, "vida": vida_salva, "frio": frio_salvo}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	aviso.emit("Progresso salvo")


func tem_salvo() -> bool:
	return FileAccess.file_exists(SAVE)


func carregar() -> bool:
	if not tem_salvo():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	etapa = int(d.etapa)
	itens = {}
	for k in d.itens:
		itens[k] = int(d.itens[k])
	notas = d.notas
	objetivo = d.objetivo
	flags = d.flags
	tempo = d.tempo
	mortes = int(d.mortes)
	chamados = int(d.get("chamados", 0))
	pos_salva = Vector3(d.px, d.py, d.pz)
	giro_salvo = d.giro
	vida_salva = d.vida
	frio_salvo = d.frio
	return true


func apagar_salvo() -> void:
	if tem_salvo():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
