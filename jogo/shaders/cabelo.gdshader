shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, specular_schlick_ggx;
// Cabelo em cartoes: cor por pessoa, brilho alongado.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tom : source_color = vec3(0.1, 0.07, 0.05);
uniform float corte = 0.38;
uniform float geada = 0.0;
varying vec3 wn;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	vec4 t = texture(cor, UV);
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = corte;
	float fio = ru(UV * vec2(520.0, 22.0)) * 0.55 + ru(UV * vec2(1400.0, 40.0)) * 0.45;
	vec3 c = tom * (0.25 + l * 2.6) * (0.55 + 0.9 * fio);
	c = mix(c, vec3(0.82, 0.86, 0.92), geada * 0.8 * smoothstep(0.45, 0.85, wn.y * 0.7 + ru(UV * 34.0) * 0.35));
	ALBEDO = c;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ROUGHNESS = mix(0.50, 0.85, fio);
	SPECULAR = 0.22;
	BACKLIGHT = tom * 0.25;
}