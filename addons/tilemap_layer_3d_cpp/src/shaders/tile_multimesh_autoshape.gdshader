shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform int filter_mode = 0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float inset_value = 0.5;
// Front/back faces (silhouette) have a vertical normal (|n.y| >= this); thin extrusion sides
// have a horizontal normal. Animation is applied to front/back faces only.
uniform float side_normal_y_threshold = 0.5;
uniform float animation_clock = 0.0;

const float ANIM_PACKED_MARKER = 262144.0;

varying flat vec4 uv_rect_data;
varying flat vec4 anim_data;
varying vec3 model_normal;

#include "res://addons/tilemap_layer_3d_cpp/src/shaders/tile_sampling.gdshaderinc"

void decode_animation(vec4 data, out float total, out float cols, out float frame_index) {
	if (data.b >= ANIM_PACKED_MARKER) {
		float packed_b = round(data.b - ANIM_PACKED_MARKER);
		total = floor(packed_b / 512.0);
		float cols_and_pause = mod(packed_b, 512.0);
		cols = max(floor(cols_and_pause / 2.0), 1.0);
		bool paused = mod(cols_and_pause, 2.0) >= 1.0;
		float packed_a = round(data.a);
		float phase_or_frame = floor(packed_a / 32768.0);
		float speed = mod(packed_a, 32768.0) / 100.0;
		frame_index = paused
			? phase_or_frame
			: min(floor(mod(animation_clock * speed + phase_or_frame, total) + 0.001), total - 1.0);
		return;
	}
	total = round(data.b);
	cols = max(floor(data.a), 1.0);
	float speed = fract(data.a) * 256.0;
	frame_index = min(floor(mod(TIME * speed, total) + 0.001), total - 1.0);
}

void vertex() {
	uv_rect_data = INSTANCE_CUSTOM;
	anim_data = COLOR;
	model_normal = NORMAL;
}

void fragment() {
	vec2 uv_min = uv_rect_data.rg;
	vec2 uv_max = uv_rect_data.ba;
	bool mirror_texture = uv_rect_data.a >= 16.0;
	uv_max.y = uv_rect_data.a - (mirror_texture ? 16.0 : 0.0);

	// Animation: packed runtime playback and legacy COLOR payloads are both supported.
	// COLOR = (frame_step_x, frame_step_y, total_frames, cols + speed/256); static = (1,1,1,1).
	bool is_front_back = abs(model_normal.y) >= side_normal_y_threshold;
	float anim_total;
	float cols;
	float frame_index;
	decode_animation(anim_data, anim_total, cols, frame_index);
	bool is_animated = anim_total > 1.0 && is_front_back;
	if (is_animated) {
		float frame_step_x = anim_data.r;
		float frame_step_y = anim_data.g;
		// Integer math: float division may land just below a whole number on web GPUs (row 1 -> row 0).
		int frame_i = int(frame_index);
		int cols_i = int(cols);
		float col = float(frame_i % cols_i);
		float row = float(frame_i / cols_i);
		vec2 offset = vec2(col * frame_step_x, row * frame_step_y);
		uv_min += offset;
		uv_max += offset;
	}

	vec2 local_uv = vec2(UV.x, 1.0 - UV.y);
	if (mirror_texture) {
		local_uv.x = 1.0 - local_uv.x;
	}
	vec2 atlas_size = vec2(textureSize(albedo_texture, 0));
	vec2 cell_min = uv_min * atlas_size;
	vec2 cell_max = uv_max * atlas_size;
	vec2 texel = mix(cell_min, cell_max, local_uv);
	vec4 tex_color = sample_tile(albedo_texture, atlas_size, texel, dFdx(texel), dFdy(texel),
			cell_min, cell_max, filter_mode, inset_value);

	if (tex_color.a < alpha_threshold) {
		discard;
	}

	ALBEDO = albedo_color.rgb * tex_color.rgb;
}
