shader_type spatial;
// Motion-blur disc for the spinning main rotor: faint dark streaks, so the
// rotor reads as fast-moving instead of two flickering sticks. Kept dark and
// subtle so it never looks like a goal ring.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 blade_color : source_color = vec3(0.1, 0.14, 0.17);
uniform float spin = 32.0;

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float streak = pow(0.5 + 0.5 * sin(a * 2.0 - TIME * spin * 0.2), 8.0);
	float body = smoothstep(0.12, 0.3, r) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = blade_color;
	ALPHA = body * (0.06 + streak * 0.16);
}
