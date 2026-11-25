shader_type spatial;
// Casca de arvore com musgo e balanco do vento.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float musgo = 0.6;
uniform float vento = 1.0;
uniform float neve = 1.0;
varying vec3 wp;
varying vec3 wn;
varying float hgt;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float f = base.x * 0.13 + base.z * 0.17;
	float raj = 0.6 + 0.4 * sin(TIME * 0.31 + f * 0.3);
	float s = (sin(TIME * 0.9 + f) + 0.5 * sin(TIME * 2.1 + f * 2.3)) * COLOR.r * 0.22 * vento * raj;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hgt = max(0.0, wp.y - base.y);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }

void fragment() {
	vec3 c = texture(cor, UV).rgb * tinta;
	vec3 a = texture(arm, UV).rgb;
	float m = smoothstep(0.35, 0.75, ru(wp.xz * 2.1 + wp.y * 1.3) * 0.55 + ru(wp.zy * 6.0) * 0.3 + (wn.y * 0.5) + (1.0 - smoothstep(0.0, 3.0, hgt)) * 0.45 - 0.15) * musgo * 0.35;
	c = mix(c, vec3(0.055, 0.075, 0.03) * (0.6 + 0.8 * ru(wp.xz * 25.0 + wp.y * 20.0)), m);
	c = mix(c, vec3(dot(c, vec3(0.33))) * vec3(0.95, 0.98, 1.05), 0.35);
	float sul = ru(wp.xz * 5.0 + wp.y * 2.3) * 0.6 + ru(vec2(wp.x + wp.z, wp.y) * 13.0) * 0.4;
	// em cima dos galhos e colada do lado do vento
	float cima = smoothstep(0.30, 0.62, wn.y + (sul - 0.5) * 0.5);
	float lado = smoothstep(0.62, 0.92, dot(wn, normalize(vec3(-0.75, 0.15, -0.6))) * 0.55 + sul * 0.62) * (0.55 + 0.45 * smoothstep(6.0, 0.0, hgt));
	float pe = smoothstep(0.55, 0.0, hgt + (sul - 0.5) * 0.5) * 0.9;
	float nv = clamp(max(max(cima, lado), pe), 0.0, 1.0) * neve;
	c = mix(c, mix(vec3(0.72, 0.78, 0.86), vec3(0.92, 0.94, 0.97), sul), nv);
	ALBEDO = c;
	NORMAL_MAP = mix(texture(nor, UV).rgb, vec3(0.5, 0.5, 1.0), nv * 0.7);
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = clamp(a.g * 0.9, 0.35, 1.0);
	AO = a.r * mix(0.45, 1.0, smoothstep(0.0, 0.9, hgt));
	SPECULAR = 0.35;
}
