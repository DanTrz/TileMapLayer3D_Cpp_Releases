shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform int filter_mode = 0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float inset_value = 0.5;
uniform float side_normal_y_threshold = 0.5;
uniform float animation_clock = 0.0;

const float ANIM_PACKED_MARKER = 262144.0;

varying flat vec4 uv_rect_data;
varying flat vec4 anim_data;
varying vec3 model_normal;
varying flat float inst_y_scale;
varying float side_depth;
varying float side_mask;

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
	inst_y_scale = length(MODEL_MATRIX[1].xyz);
	side_depth = UV2.x;
	side_mask = UV2.y;
}

void fragment() {
	vec2 uv_min = uv_rect_data.rg;
	vec2 uv_max = uv_rect_data.ba;
	bool mirror_texture = uv_rect_data.a >= 16.0;
	uv_max.y = uv_rect_data.a - (mirror_texture ? 16.0 : 0.0);

	bool is_side = side_mask > 0.5 && abs(model_normal.y) < side_normal_y_threshold;

	// Animation: packed runtime playback and legacy COLOR payloads are both supported.
	// COLOR = (frame_step_x, frame_step_y, total_frames, cols + speed/256); static = (1,1,1,1).
	float anim_total;
	float cols;
	float frame_index;
	decode_animation(anim_data, anim_total, cols, frame_index);
	if (anim_total > 1.0 && !is_side) {
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
	vec2 edge_uv = local_uv;

	if (is_side) {
		float depth_amount = side_depth * inst_y_scale;
		if (abs(model_normal.x) >= abs(model_normal.z)) {
			local_uv.x += model_normal.x > 0.0 ? -depth_amount : depth_amount;
		} else {
			local_uv.y += model_normal.z > 0.0 ? depth_amount : -depth_amount;
		}
	}
	if (mirror_texture) {
		local_uv.x = 1.0 - local_uv.x;
		edge_uv.x = 1.0 - edge_uv.x;
	}

	vec2 atlas_size = vec2(textureSize(albedo_texture, 0));
	vec2 cell_min = uv_min * atlas_size;
	vec2 cell_max = uv_max * atlas_size;
	float inset = is_side ? max(inset_value, 1.0) : inset_value;
	// Sides repeat the inset-trimmed cell. Derivatives use the unwrapped UV so fract() adds no mip seam.
	vec2 side_min = cell_min + inset;
	vec2 side_size = cell_max - cell_min - 2.0 * inset;
	vec2 texel_scale = is_side ? side_size : cell_max - cell_min;
	vec2 texel = is_side ? side_min + fract(local_uv) * side_size : mix(cell_min, cell_max, local_uv);
	vec2 texel_dx = dFdx(local_uv) * texel_scale;
	vec2 texel_dy = dFdy(local_uv) * texel_scale;
	vec2 edge_dx = dFdx(edge_uv) * side_size;
	vec2 edge_dy = dFdy(edge_uv) * side_size;
	vec4 tex_color = sample_tile(albedo_texture, atlas_size, texel, texel_dx, texel_dy,
			cell_min, cell_max, filter_mode, inset);

	if (is_side && tex_color.a < alpha_threshold) {
		vec2 edge_texel = side_min + clamp(edge_uv, vec2(0.0), vec2(1.0)) * side_size;
		tex_color = sample_tile(albedo_texture, atlas_size, edge_texel, edge_dx, edge_dy,
				cell_min, cell_max, filter_mode, inset);
	}

	if (!is_side && tex_color.a < alpha_threshold) {
		discard;
	}

	ALBEDO = albedo_color.rgb * tex_color.rgb;
}
