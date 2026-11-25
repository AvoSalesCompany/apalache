extends Node
## Autoload "Teste": so age quando o jogo e aberto com argumentos apos "--".
##   foto=C:/x.png pos=x,z olhar=giro,inclina espera=90 cena=floresta|aviao|menu t=12 alt=1.7
##   robo=1  -> joga sozinho do inicio ao fim e registra cada passo
## No jogo normal este script nao faz nada.

var ativo := false
var a := {}


func _enter_tree() -> void:
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1].uri_decode()
	ativo = not a.is_empty()
	if ativo:
		# teste nunca rouba o foco nem aparece por cima do que a pessoa faz
		get_window().unfocusable = true
		get_window().position = Vector2i(-6000, -6000)


func num(k: String, d: float) -> float:
	return float(a[k]) if a.has(k) else d


func par(k: String, d: Vector2) -> Vector2:
	if not a.has(k):
		return d
	var p := (a[k] as String).split(",")
	return Vector2(float(p[0]), float(p[1]))


func fotografar() -> void:
	var n := int(num("espera", 90))
	for i in n:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in 30:
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - t0) / 30000.0
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.save_png(a.foto)
	var vp := get_viewport()
	print("FOTO ", a.foto, "  ms/quadro=%.1f" % ms, "  draws=", RenderingServer.viewport_get_render_info(vp.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), "  prims=", RenderingServer.viewport_get_render_info(vp.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME), "  vram=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576, "MB")
	get_tree().quit()


## lista=arquivo.json : varias fotos numa carga so
func album(pr) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080) if a.has("hd") else Vector2i(1600, 900)
	var l: Array = JSON.parse_string(FileAccess.get_file_as_string(a.lista))
	for q in l:
		pr.teste_cena(q)
		var n := int(q.get("espera", 50))
		for i in n:
			await get_tree().process_frame
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for i in 4: await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in 20:
			await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t0) / 20000.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(a.pasta + "/" + q.nome + ".jpg", 0.9)
		print("FOTO ", q.nome, " ms=%.1f gpu=%.1f cpu=%.1f proc=%.1f fis=%.1f prims=%dk" % [ms, RenderingServer.viewport_get_measured_render_time_gpu(vp), RenderingServer.viewport_get_measured_render_time_cpu(vp), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000], " draws=", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), " vram=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576)
	get_tree().quit()