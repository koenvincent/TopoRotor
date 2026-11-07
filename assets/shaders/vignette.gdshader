shader_type canvas_item;
// Cinematic edge darkening plus an optional coloured flash (red for a miss,
// gold for a hit). Purely visual; the rect ignores mouse and touch input.
uniform float strength = 0.55;
uniform vec4 flash_color : source_color = vec4(1.0, 0.1, 0.1, 0.0);

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.25;
	float d = length(p);
	float vig = smoothstep(0.38, 0.85, d) * strength;
	float edge_flash = smoothstep(0.15, 0.75, d) * flash_color.a;
	vec3 col = mix(vec3(0.0, 0.03, 0.05), flash_color.rgb, edge_flash / max(vig + edge_flash, 0.0001));
	COLOR = vec4(col, clamp(vig + edge_flash, 0.0, 0.92));
}
