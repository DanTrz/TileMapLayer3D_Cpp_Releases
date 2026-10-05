shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 brush_color : source_color = vec4(1.0, 0.7, 0.0, 0.9);
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float rim_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float band_opacity : hint_range(0.0, 1.0) = 0.95;

varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.2);
	float center_band = 1.0 - smoothstep(0.025, 0.085, abs(local_height));
	float opacity = max(fill_opacity, max(rim * rim_opacity, center_band * band_opacity));

	ALBEDO = brush_color.rgb;
	EMISSION = brush_color.rgb * 0.18;
	ALPHA = opacity * brush_color.a;
}
