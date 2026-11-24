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

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float f = base.x * 0.13 + base.z * 0.17;
	float raj = 0.6 + 0.4 * sin(TIME * 0.31 + f * 0.3);
	float s = (sin(TIME * 0.9 + f) + 0.5 * sin(TIME * 2.1 + f * 2.3)) * COLOR.r * 0.22 * vento * raj;
	vec3 fl = vec3(sin(TIME * 2.7 + VERTEX.x * 2.0 + f), sin(TIME * 3.3 + VERTEX.z * 2.4 + f * 2.0) * 0.8, sin(TIME * 2.3 + VERTEX.y * 2.2)) * COLOR.g * 0.045 * vento * raj;
	VERTEX += vec3(s, 0.0, s * 0.6) + fl;
}

void fragment() {
	vec4 t = texture(cor, UV);
	float lod = textureQueryLod(cor, UV).x;
	ALPHA = clamp(t.a * (1.0 + max(0.0, lod) * mip_comp), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = corte;
	vec3 c = t.rgb * tinta * (0.72 + 0.56 * COLOR.b);
	ALBEDO = c;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	BACKLIGHT = c * trans;
	ROUGHNESS = rug;
	SPECULAR = brilho;
}
