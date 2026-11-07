shader_type spatial;
// Expanding ring on the ground after a correct answer.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add, shadows_disabled;
uniform vec3 wave_color : source_color = vec3(1.0, 0.85, 0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float front = progress;
	float band = exp(-abs(r - front) * 28.0) + exp(-abs(r - front * 0.72) * 40.0) * 0.5;
	ALBEDO = wave_color * band * (1.0 - progress) * 1.4 * step(r, 1.0);
}
