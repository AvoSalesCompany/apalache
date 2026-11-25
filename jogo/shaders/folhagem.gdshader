shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, specular_schlick_ggx;
// Folhas e galhos em cartao: recorte, vento e luz atravessando.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float corte = 0.42;
uniform float trans = 0.5;
uniform float rug = 0.75;
uniform float vento = 1.0;
uniform float brilho = 0.3;
uniform float mip_comp = 0.28;
uniform float neve = 0.75;
varying vec3 wn;
varying vec3 wp;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float f = base.x * 0.13 + base.z * 0.17;
	float raj = 0.6 + 0.4 * sin(TIME * 0.31 + f * 0.3);
	float s = (sin(TIME * 0.9 + f) + 0.5 * sin(TIME * 2.1 + f * 2.3)) * COLOR.r * 0.22 * vento * raj;
	vec3 fl = vec3(sin(TIME * 2.7 + VERTEX.x * 2.0 + f), sin(TIME * 3.3 + VERTEX.z * 2.4 + f * 2.0) * 0.8, sin(TIME * 2.3 + VERTEX.y * 2.2)) * COLOR.g * 0.045 * vento * raj;
	VERTEX += vec3(s, 0.0, s * 0.6) + fl;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 t = texture(cor, UV);
	float lod = textureQueryLod(cor, UV).x;
	ALPHA = clamp(t.a * (1.0 + max(0.0, lod) * mip_comp), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = corte;
	vec3 c = t.rgb * tinta * (0.72 + 0.56 * COLOR.b);
	float sul = ru(wp.xz * 2.6 + wp.y * 1.7) * 0.55 + ru(wp.xz * 9.0 - wp.y * 4.0) * 0.45;
	float nv = smoothstep(0.30, 0.66, wn.y * 0.75 + (sul - 0.5) * 0.85 + neve * 0.35) * neve;
	if (!FRONT_FACING) nv *= 0.35;
	float agl = clamp(dot(t.rgb, vec3(0.3, 0.59, 0.11)) * 3.2, 0.0, 1.0);
	nv *= mix(0.55, 1.0, smoothstep(0.25, 0.60, sul + agl * 0.25));
	c = mix(c * vec3(0.80, 0.86, 0.92), mix(vec3(0.62, 0.69, 0.78), vec3(0.93, 0.95, 0.98), clamp(sul * 0.6 + agl * 0.5, 0.0, 1.0)), nv);
	ALBEDO = c;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	BACKLIGHT = c * trans * (1.0 - nv * 0.4);
	ROUGHNESS = rug;
	SPECULAR = brilho;
}
