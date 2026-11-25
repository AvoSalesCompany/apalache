shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Igual ao neve_obj, com recorte (arbustos, galhos).
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float rug = 1.0;
uniform float metal = 0.0;
uniform float quanta = 1.0;
uniform float esc = 1.0;
uniform float corte = 0.5;
varying vec3 wp;
varying vec3 wn;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec4 t = texture(cor, UV * esc);
	vec3 c = t.rgb * tinta;
	vec3 a = texture(arm, UV * esc).rgb;
	vec3 nm = texture(nor, UV * esc).rgb;
	vec3 up = wn;
	if (!FRONT_FACING) { up = -up; NORMAL = -NORMAL; }
	float sul = ru(wp.xz * 7.0 + wp.y * 3.0) * 0.6 + ru(wp.xz * 21.0 - wp.y * 9.0) * 0.4;
	float k = smoothstep(0.42, 0.62, up.y + (sul - 0.5) * 0.45 - (1.0 - quanta) * 0.6 + (nm.y - 0.5) * 0.15) * step(0.001, quanta);
	vec3 nv = mix(vec3(0.72, 0.78, 0.86), vec3(0.92, 0.94, 0.97), sul);
	ALBEDO = mix(c, nv, k);
	NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), k * 0.85);
	ROUGHNESS = mix(clamp(a.g * rug, 0.05, 1.0), 0.7, k);
	METALLIC = metal * (1.0 - k);
	AO = mix(a.r, 1.0, k);
	SPECULAR = 0.4;	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = corte;
}
