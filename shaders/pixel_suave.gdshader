shader_type canvas_item;
render_mode unshaded;

uniform sampler2D original_tex : filter_nearest;
uniform sampler2D smooth_tex : filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	COLOR = mix(texture(original_tex, UV), texture(smooth_tex, UV), amount);
}
