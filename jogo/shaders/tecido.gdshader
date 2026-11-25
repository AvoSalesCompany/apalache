shader_type spatial;
render_mode cull_disabled;
// Roupa: trama, relevo, sangue e neve acumulada.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float rug = 0.86;
uniform float relevo = 1.0;
uniform float sangue = 0.0;
uniform float geada = 0.0;
uniform float semente = 0.0;
uniform float trama = 1.0;
uniform float corta = 99.0;
varying float alt_c;
varying vec3 wn;
varying vec3 wp;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return ru(p) * 0.5 + ru(p * 2.13 + 7.1) * 0.3 + ru(p * 4.7 + 3.3) * 0.2; }
void vertex() { alt_c = VERTEX.y; wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (alt_c > corta) discard;
	vec3 c = texture(cor, UV).rgb * tinta;
	float t = 0.93 + 0.07 * sin(UV.x * 2600.0) * sin(UV.y * 2600.0) * trama;
	c *= t * (0.90 + 0.16 * fbm(UV * 22.0));
	float r = rug;
	float sg = smoothstep(0.55, 0.63, fbm(UV * 5.0 + semente * 2.7)) * sangue;
	c = mix(c, vec3(0.060, 0.005, 0.004), sg * 0.9);
	r = mix(r, 0.42, sg);
	vec3 n3 = wn * (FRONT_FACING ? 1.0 : -1.0);
	float gd = smoothstep(0.30, 0.62, n3.y * 0.75 + fbm(wp.xz * 14.0) * 0.45 - 0.16) * geada;
	c = mix(c, vec3(0.84, 0.88, 0.93), gd);
	ALBEDO = c;
	NORMAL_MAP = mix(texture(nor, UV).rgb, vec3(0.5, 0.5, 1.0), gd * 0.8);
	NORMAL_MAP_DEPTH = relevo;
	ROUGHNESS = mix(r, 0.8, gd);
	SPECULAR = 0.25;
}