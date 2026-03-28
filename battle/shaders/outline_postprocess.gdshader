shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.2, 0.95, 0.35, 1.0);
uniform float thickness = 1.0;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * thickness;
	float center = texture(TEXTURE, UV).a;

	float max_neighbor = 0.0;
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(texel.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(0.0, texel.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(0.0, -texel.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(texel.x, texel.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-texel.x, texel.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(texel.x, -texel.y)).a);
	max_neighbor = max(max_neighbor, texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a);

	float edge = clamp(max_neighbor - center, 0.0, 1.0);
	COLOR = vec4(outline_color.rgb, outline_color.a * edge);
}
