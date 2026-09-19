shader_type canvas_item;
render_mode unshaded;

// Ink enamel, faint checkerwork and brass inlays, below the text's value range.
// All decorative movement comes from TIME * speed; zero is a still picture.
uniform vec4 top_color : source_color = vec4(0.082353, 0.156863, 0.149020, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.035294, 0.058824, 0.082353, 1.0);
uniform vec4 glow_color : source_color = vec4(0.909804, 0.741176, 0.447059, 1.0);
uniform vec2 aspect = vec2(1.0, 1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.06;

float inlay(float distance_from_line, float width) {
	float edge = abs(distance_from_line);
	float aa = max(fwidth(edge), 0.0005);
	return 1.0 - smoothstep(width, width + aa, edge);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * aspect;
	float t = TIME * speed;
	vec3 col = mix(
		top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y)
	);

	vec2 lamp = vec2(
		-0.32 + sin(t * 0.31) * 0.014,
		-0.24 + cos(t * 0.27) * 0.009
	);
	vec2 light_offset = p - lamp;
	float pool = exp(-dot(light_offset, light_offset) * 3.4);
	float breath = 0.86 + 0.14 * sin(t * 0.45);
	col += glow_color.rgb * pool * breath * 0.028;

	// Square coordinates keep the floor tiles and wall arches undistorted.
	vec2 tile = vec2(p.x + p.y, p.y - p.x) * 7.778175;
	float checker = mod(floor(tile.x) + floor(tile.y), 2.0);
	float floor_mask = smoothstep(0.04, 0.70, p.y);
	float sides = smoothstep(0.15, 0.62, abs(p.x));
	col += vec3(0.014, 0.025, 0.021) * checker
		* floor_mask * (0.25 + sides * 0.75);

	vec2 arch = p - vec2(0.0, 0.13);
	float radius = length(arch);
	float arches = inlay(radius - 0.62, 0.0012)
		+ inlay(radius - 0.66, 0.0012)
		+ inlay(radius - 0.70, 0.0012);
	float wall_mask = (1.0 - smoothstep(0.03, 0.21, p.y))
		* smoothstep(0.16, 0.37, abs(p.x));
	col += glow_color.rgb * arches * wall_mask * 0.018;

	vec2 frame = abs(p) - (aspect * 0.5 - vec2(0.035));
	float outer = inlay(max(frame.x, frame.y), 0.0009);
	float inner = inlay(max(frame.x + 0.012, frame.y + 0.012), 0.0007);
	col += glow_color.rgb * (outer * 0.017 + inner * 0.007);

	float grain = fract(sin(dot(p * 480.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (grain - 0.5) * 0.003;
	col *= 1.0 - smoothstep(0.25, 1.25, length(p)) * 0.18;

	// Even overlapping inlays stay dark enough for the host's muted labels.
	col = clamp(col, vec3(0.0), vec3(0.16, 0.19, 0.18));
	COLOR = vec4(col, 1.0);
}
