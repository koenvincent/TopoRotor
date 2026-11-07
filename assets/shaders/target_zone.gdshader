shader_type spatial;
// Ground circle that shows the exact answer range around a goal. Drawn over
// scenery so the edge stays readable inside a dense city.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform vec3 zone_color : source_color = vec3(1.0, 0.70, 0.18);
uniform vec3 inside_color : source_color = vec3(0.25, 1.0, 0.45);
uniform float inside : hint_range(0.0, 1.0) = 0.0;
// Mesh half-size relative to the answer radius (room for the outer glow).
uniform float extent = 1.3;
// Edge width in radius units; set per frame so the line stays a few pixels.
uniform float edge_width = 0.05;
// 1.0 animates, 0.0 holds the pattern still (setting "Rustige beelden").
uniform float motion : hint_range(0.0, 1.0) = 1.0;

float band(float r, float at, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(r - at));
}

void fragment() {
	vec2 c = (UV - 0.5) * 2.0 * extent;
	float r = length(c);
	float a = atan(c.y, c.x) / 6.28318;
	vec3 col = mix(zone_color, inside_color, inside);
	float inner = 1.0 - step(1.0, r);
	float w = edge_width;
	// Thick bright edge with a dark outline so it reads on yellow fields too.
	// Inside the zone the edge gets thicker and the inner dashed ring turns solid,
	// so "inside" shows in the shape too and not only in the orange-to-green colour.
	float ew = w * (1.0 + 0.8 * inside);
	float edge = band(r, 1.0, ew);
	float outline = band(r, 1.0, ew * 1.7) - edge;
	float halo = exp(-max(r - 1.0, 0.0) / (w * 2.0)) * (1.0 - inner) * 0.4;
	// Two dashed rings turning in opposite directions.
	float dash_in = max(step(0.42, fract(a * 48.0 + TIME * motion * 0.12)), inside) * band(r, 1.0 - w * 2.4, w * 0.8);
	float dash_out = step(0.6, fract(a * 24.0 - TIME * motion * 0.07)) * band(r, 1.0 + w * 2.6, w * 0.6);
	// Radar sweep and waves rolling to the centre.
	float sweep = exp(-fract(a - TIME * motion * 0.22) * 14.0) * inner * (0.28 + 0.2 * inside) * smoothstep(0.05, 0.5, r);
	float wave = smoothstep(0.84, 1.0, fract(r * 2.0 + TIME * motion * (0.6 + inside * 1.0))) * inner * 0.25 * r;
	float fill = inner * (0.13 + 0.12 * inside);
	float cross_hair = band(min(abs(c.x), abs(c.y)), 0.0, w * 0.7) * step(r, 0.2) * step(0.06, r);
	float bright = edge + dash_in * 0.85 + dash_out * 0.7 + cross_hair;
	float alpha = bright + outline * 0.45 + halo + sweep + wave + fill;
	vec3 shade = mix(col * 0.75, col, bright);
	ALBEDO = mix(shade, vec3(0.08, 0.05, 0.0), outline * (1.0 - bright));
	ALPHA = clamp(alpha, 0.0, 1.0) * (1.0 - smoothstep(extent - 0.12, extent, r));
}
