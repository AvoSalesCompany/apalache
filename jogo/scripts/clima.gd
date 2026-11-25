class_name Clima
extends Node
## Hora do dia, sol, lua, neblina e neve. Uma unica luz direcional que e sol de dia e lua de noite.

const NASCE := 6.6
const POE := 17.3

var fl: Floresta
var hora := 2.8
var hora_alvo := 2.8
var vel := 0.04               # horas por segundo, no maximo
var sol := Vector3.UP
var elev := 0.0               # graus
var dia := 0.0
var crep := 0.0
var noite := 1.0
var lua_fator := 1.0
var _lua_alvo := 1.0
var _lua_t := 0.0
var neve := 0.5               # intensidade da neve caindo 0..1
var neve_alvo := 0.5
var extra_fog := 0.0          # neblina por roteiro
var extra_alvo := 0.0
var interior := 0.0           # 0 fora .. 1 dentro de casa
var _tl := 0.0

const LUA_E := 0.135


static func direcao(h: float) -> Array:
	var u := (h - NASCE) / (POE - NASCE)
	var e := 0.0
	if u >= 0.0 and u <= 1.0: e = sin(PI * u) * 31.0
	elif u < 0.0: e = maxf(-40.0, u * 62.0)
	else: e = maxf(-40.0, (1.0 - u) * 62.0)
	var az := -0.12 + PI * clampf(u, -0.15, 1.15) * 1.02
	var r := deg_to_rad(e)
	return [Vector3(cos(az) * cos(r), sin(r), sin(az) * cos(r)).normalized(), e]


func por(h: float) -> void:
	hora = h
	hora_alvo = h
	atualiza(0.0, true)


func ir(h: float, v: float = 0.04) -> void:
	hora_alvo = h
	vel = v


func cobrir_lua(s: float) -> void:
	if noite < 0.9: return
	_lua_alvo = 0.05
	_lua_t = s
	if Jogo.jogador: Jogo.falar("", "Uma nuvem cobre a lua.", 2.5)


func atualiza(dt: float, ja: bool = false) -> void:
	hora = move_toward(hora, hora_alvo, vel * dt)
	var q := direcao(hora)
	sol = q[0]
	elev = q[1]
	dia = smoothstep(-7.0, 7.0, elev)
	crep = smoothstep(-9.0, -1.0, elev) * (1.0 - smoothstep(5.0, 19.0, elev))
	noite = 1.0 - smoothstep(-10.0, -3.0, elev)
	_lua_t -= dt
	if _lua_t <= 0.0: _lua_alvo = 1.0
	lua_fator = move_toward(lua_fator, _lua_alvo, dt * (0.40 if _lua_alvo < lua_fator else 0.16))
	neve = move_toward(neve, neve_alvo, dt * 0.08)
	extra_fog = move_toward(extra_fog, extra_alvo, dt * 0.15)
	interior = move_toward(interior, 1.0 if Jogo.jogador and Jogo.jogador.abrigado else 0.0, dt * 1.5)
	# ---------- luz
	_tl -= dt
	var de_sol := elev > -2.2
	if _tl <= 0.0 or ja:
		_tl = 0.10
		var dir := sol if de_sol else Mundo.LUA
		if de_sol and dir.y < 0.06:
			dir.y = 0.06
			dir = dir.normalized()
		Mundo.luz_dir = dir
		fl.lua.look_at_from_position(dir * 100.0, Vector3.ZERO)
		fl.mat_raios.set_shader_parameter("lua", sol if de_sol else Mundo.LUA)
	if de_sol:
		var e := smoothstep(-2.2, 3.0, elev)
		var alto := smoothstep(3.0, 22.0, elev)
		fl.lua.light_color = Color(1.0, 0.50, 0.22).lerp(Color(1.0, 0.76, 0.52), smoothstep(1.0, 9.0, elev)).lerp(Color(1.0, 0.94, 0.86), alto)
		fl.lua.light_energy = e * lerpf(1.25, 2.1, alto)
		fl.lua.light_volumetric_fog_energy = lerpf(1.5, 0.8, alto)
		fl.lua.light_angular_distance = 0.0
		fl.mat_raios.set_shader_parameter("cor", Color(1.0, 0.66, 0.36).lerp(Color(1.0, 0.92, 0.80), alto))
		fl.mat_raios.set_shader_parameter("forca", 0.34 * e * lerpf(1.0, 0.45, alto))
	else:
		var n := smoothstep(-2.4, -8.0, elev)
		fl.lua.light_color = Color(0.60, 0.73, 1.0)
		fl.lua.light_energy = LUA_E * lua_fator * n
		fl.lua.light_volumetric_fog_energy = 1.0
		fl.lua.light_angular_distance = 0.0
		fl.mat_raios.set_shader_parameter("cor", Color(0.62, 0.74, 1.0))
		fl.mat_raios.set_shader_parameter("forca", 0.12 * lua_fator * n)
	if fl.mat_terreno:
		var lc := fl.lua.light_color * fl.lua.light_energy * (1.1 if de_sol else 2.2)
		fl.mat_terreno.set_shader_parameter("luz_dir", sol if de_sol else Mundo.LUA)
		fl.mat_terreno.set_shader_parameter("luz_cor", Vector3(lc.r, lc.g, lc.b))
	# ---------- ceu
	var mc := fl.mat_ceu
	mc.set_shader_parameter("sol", sol)
	mc.set_shader_parameter("dia", dia)
	mc.set_shader_parameter("crep", crep)
	mc.set_shader_parameter("brilho", lerpf(0.06, 0.42, lua_fator))
	mc.set_shader_parameter("nuvens", lerpf(0.55, 0.85, neve) if dia > 0.2 else 0.5)
	mc.set_shader_parameter("neblina", 0.55)
	# ---------- ambiente
	var env := fl.env
	var foco := fl.foco
	var altop := smoothstep(5.0, 13.0, foco.y - Mundo.altura(foco.x, foco.z))
	var amb_n := Color(0.36, 0.47, 0.70)
	var amb_d := Color(0.62, 0.72, 0.90)
	var amb_c := Color(0.64, 0.56, 0.68)
	env.ambient_light_color = amb_n.lerp(amb_d, dia).lerp(amb_c, crep * 0.6)
	env.ambient_light_energy = lerpf(lerpf(0.016, 0.030, lua_fator), lerpf(0.60, 0.40, crep), dia) * lerpf(1.0, 0.16, interior)
	env.tonemap_exposure = lerpf(1.55, lerpf(1.22, 1.34, crep), smoothstep(-6.0, 4.0, elev)) * lerpf(1.0, 1.25, interior * dia)
	env.fog_light_color = Color(0.085, 0.115, 0.175).lerp(Color(0.66, 0.73, 0.82), dia).lerp(Color(0.80, 0.56, 0.45), crep * dia * 0.75)
	env.fog_light_energy = lerpf(lerpf(0.012, 0.026, lua_fator), 0.62, dia) * lerpf(1.0, 0.10, interior)
	env.fog_sun_scatter = lerpf(0.16, 0.28, crep)
	var den := lerpf(0.0085, 0.0060, dia) * (1.0 + neve * 0.8) + extra_fog * 0.02
	env.fog_density = lerpf(den, 0.0026, altop) * lerpf(1.0, 0.2, interior)
	env.volumetric_fog_density = lerpf(lerpf(0.016, 0.011, dia) + extra_fog * 0.02, 0.0035, altop) * lerpf(1.0, 0.35, interior)
	env.volumetric_fog_albedo = Color(0.72, 0.80, 0.95).lerp(Color(0.90, 0.90, 0.92), dia)
	env.volumetric_fog_ambient_inject = lerpf(0.10, 0.10, dia)
	env.volumetric_fog_length = 84.0
	env.glow_intensity = lerpf(0.55, 0.35, dia)
	env.ssao_light_affect = lerpf(0.15, 0.05, dia)
	# ---------- neve
	if fl.ar:
		Fx.forca_neve(fl.ar, neve * (1.0 - interior))