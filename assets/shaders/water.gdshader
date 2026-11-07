shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec2 p = world_position.xz;
 float swell = sin(p.x * 0.065 + p.y * 0.043 + TIME * 0.35) * 0.5 + 0.5;
 float ripple = sin(p.x * 1.1 + p.y * 0.6 + sin(p.y * 0.2) + TIME * 0.7);
 float glint = smoothstep(0.92, 1.0, ripple * sin(p.y * 0.7 - TIME * 0.3)) * 0.028;
 ALBEDO = mix(vec3(0.10, 0.37, 0.46), vec3(0.17, 0.48, 0.55), swell * 0.35) + glint;
}
