shader_type spatial;
// Ground sight straight below the helicopter: the exact point the game
// checks when the pilot presses "Hier is het!".
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform vec3 sight_color : source_color = vec3(1.0, 1.0, 0.92);
// 1.0 animates, 0.0 holds the sight still (setting "Rustige beelden").
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float ring = 1.0 - smoothstep(0.04, 0.09, abs(r - 0.78));
	float gaps = step(0.22, abs(fract(a / 6.28318 * 4.0 + 0.125) - 0.5));
	float dot_core = 1.0 - smoothstep(0.1, 0.16, r);
	float outline = (1.0 - smoothstep(0.1, 0.16, abs(r - 0.78))) * 0.5;
	float spin = 0.5 + 0.5 * sin(TIME * motion * 5.0);
	ALBEDO = mix(vec3(0.02, 0.06, 0.07), sight_color, max(ring * gaps, dot_core));
	ALPHA = clamp(max(ring * gaps, dot_core) * (0.85 + 0.15 * spin) + outline * gaps * 0.6, 0.0, 0.95) * step(r, 1.0);
}
