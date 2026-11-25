shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Arvore distante: cartoes cruzados com foto da arvore (atlas 8x1).
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float tipo;

void vertex() {
	tipo = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 u = vec2((floor(tipo * 8.0 + 0.01) + clamp(UV.x, 0.01, 0.99)) / 8.0, UV.y);
	vec4 t = texture(atlas, u);
	float lod = textureQueryLod(atlas, u).x;
	ALPHA = clamp(t.a * (1.0 + max(0.0, lod) * 0.3), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ALBEDO = t.rgb * 0.72;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	BACKLIGHT = t.rgb * 0.22;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
