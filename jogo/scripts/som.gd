extends Node
## Autoload "Som": efeitos, camadas de ambiente com volume suave, voz.

var _camadas := {}      # nome -> {p, alvo, vel, v}
var _cache := {}
var _abafa: AudioEffectLowPassFilter
var abafado := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in [["Mundo", "Master"], ["Eco", "Mundo"], ["Musica", "Master"], ["Voz", "Mundo"], ["UI", "Master"]]:
		if AudioServer.get_bus_index(b[0]) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b[0])
			AudioServer.set_bus_send(i, b[1])
	_abafa = AudioEffectLowPassFilter.new()
	_abafa.cutoff_hz = 20500
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Mundo"), _abafa)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.85
	rv.damping = 0.65
	rv.wet = 0.22
	rv.dry = 0.9
	rv.predelay_msec = 90
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Eco"), rv)


func fluxo(nome: String, loop: bool = false) -> AudioStream:
	var k := nome + ("#" if loop else "")
	if not _cache.has(k):
		var s = load("res://som/%s.wav" % nome)
		if s == null:
			push_warning("som ausente: " + nome)
			return null
		if loop:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		_cache[k] = s
	return _cache[k]


func toca(nome: String, db: float = 0.0, tom: float = 1.0, bus: String = "Mundo") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = fluxo(nome)
	p.volume_db = db
	p.pitch_scale = tom
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


func varia(base: String, n: int, db: float = 0.0, v: float = 0.08) -> void:
	toca("%s%d" % [base, randi_range(1, n)], db + randf_range(-1.5, 1.0), randf_range(1.0 - v, 1.0 + v))


func em(nome: String, pos: Vector3, db: float = 0.0, alcance: float = 60.0, tom: float = 1.0, bus: String = "Eco", unidade: float = 6.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = fluxo(nome)
	p.volume_db = db
	p.max_distance = alcance
	p.unit_size = unidade
	p.pitch_scale = tom
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 7000
	var pai: Node = Jogo.floresta if Jogo.floresta else self
	pai.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


func loop3d(nome: String, pai: Node3D, pos: Vector3, db: float, alcance: float, unidade: float = 5.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = fluxo(nome, true)
	p.volume_db = db
	p.max_distance = alcance
	p.unit_size = unidade
	p.bus = "Mundo"
	pai.add_child(p)
	p.position = pos
	p.play(randf() * 2.0)
	return p


## camada continua: volume linear alvo, velocidade por segundo
func camada(nome: String, alvo: float, vel: float = 0.5, bus: String = "Mundo") -> void:
	if not _camadas.has(nome):
		if alvo <= 0.0:
			return
		var p := AudioStreamPlayer.new()
		p.stream = fluxo(nome, true)
		p.bus = bus
		p.volume_db = -80
		add_child(p)
		p.play()
		_camadas[nome] = {"p": p, "alvo": alvo, "vel": vel, "v": 0.0}
	var c: Dictionary = _camadas[nome]
	c.alvo = alvo
	c.vel = vel
	if alvo > 0.0 and not c.p.playing:
		c.p.play(randf() * 3.0)


func tom_camada(nome: String, t: float) -> void:
	if _camadas.has(nome):
		_camadas[nome].p.pitch_scale = maxf(0.05, t)


func vol_camada(nome: String) -> float:
	return _camadas[nome].v if _camadas.has(nome) else 0.0


func silencio(vel: float = 0.5) -> void:
	for n in _camadas:
		_camadas[n].alvo = 0.0
		_camadas[n].vel = vel


func _process(dt: float) -> void:
	for n in _camadas:
		var c: Dictionary = _camadas[n]
		c.v = move_toward(c.v, c.alvo, c.vel * dt)
		c.p.volume_db = linear_to_db(maxf(c.v, 0.0001))
		if c.v <= 0.0 and c.alvo <= 0.0 and c.p.playing:
			c.p.stop()
	_abafa.cutoff_hz = lerpf(20500.0, 420.0, pow(clampf(abafado, 0, 1), 0.35))
