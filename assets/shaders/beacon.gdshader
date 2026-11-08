shader_type spatial;
// Additive light pillar above a goal; bright at the base, fading upwards,
// with bands rising so it reads as an active beacon from far away.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec3 beam_color : source_color = vec3(1.0, 0.78, 0.38);
uniform float strength = 1.0;
// 1.0 animates, 0.0 holds the bands still (setting "Rustige beelden").
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float height = 1.0 - UV.y;
	float fade = pow(1.0 - height, 1.6);
	float bands = 0.7 + 0.3 * sin(height * 40.0 - TIME * motion * 6.0);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.2);
	ALBEDO = beam_color * fade * bands * (0.7 + 0.8 * rim) * strength;
}
