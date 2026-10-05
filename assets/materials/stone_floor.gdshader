shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
float tile_hash(vec2 cell) {
 return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 grid = world_position.xz / vec2(0.8, 0.55);
 grid.x += mod(floor(grid.y), 2.0) * 0.5;
 vec2 local = fract(grid);
 vec2 edge = min(local, 1.0 - local);
 float seam = 1.0 - smoothstep(0.012, 0.025, min(edge.x, edge.y));
 float variation = tile_hash(floor(grid));
 float grain = tile_hash(floor(world_position.xz * 120.0));
 vec3 stone = mix(vec3(0.34, 0.35, 0.30), vec3(0.54, 0.53, 0.44), variation);
 ALBEDO = mix(stone + (grain - 0.5) * 0.035, vec3(0.18, 0.20, 0.17), seam);
 ROUGHNESS = 0.92;
}
