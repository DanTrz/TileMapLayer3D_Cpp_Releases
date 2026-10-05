shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform bool use_nearest_texture = true;
uniform sampler2D albedo_texture_nearest : source_color, filter_nearest, repeat_disable;
uniform sampler2D albedo_texture_linear : source_color, filter_linear, repeat_disable;
uniform float inset_value = 0.5; // Inset in pixels to prevent texture bleeding, can be adjusted based on texture resolution
// Side faces have a horizontal local normal (|n.y| < this); top/bottom (front/back) have |n.y| ~= 1.
// Animation is applied ONLY to front/back faces so the side stripes stay static. Mirrors box_repeat.
uniform float side_normal_y_threshold = 0.5;
uniform float animation_clock = 0.0;
uniform bool debug_show_transparent_tiles = false;

const float ANIM_PACKED_MARKER = 262144.0;

varying flat vec4 uv_rect_data;
varying flat vec4 anim_data;
varying vec3 model_normal;

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

// Debug only: true when no sample on an 8x8 grid of the atlas cell is opaque. Explicit LOD because
// it runs inside per-pixel control flow.
bool is_cell_transparent(vec2 cell_min, vec2 cell_max) {
	for (int y = 0; y < 8; y++) {
		for (int x = 0; x < 8; x++) {
			vec2 uv = mix(cell_min, cell_max, (vec2(float(x), float(y)) + 0.5) / 8.0);
			if (textureLod(albedo_texture_nearest, uv, 0.0).a >= alpha_threshold) {
				return false;
			}
		}
	}
	return true;
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
	float packed_alpha = uv_rect_data.a - (mirror_texture ? 16.0 : 0.0);
	uv_max.y = packed_alpha;

	// Decode freeze-UV rotation from packed custom_data.a
	// Values < 2.0 = no freeze (backward compatible), >= 2.0 = freeze with encoded rotation
	int freeze_rot = int(floor(packed_alpha / 2.0));
	if (freeze_rot > 0) {
		uv_max.y = packed_alpha - float(freeze_rot) * 2.0;
	}

	// New COLOR.b/a values carry pause/phase/speed; decode_animation also accepts legacy payloads.
	// Static tiles: default COLOR=(1,1,1,1), guard 1.0 > 1.0 = false → skipped
	float frame_step_x = anim_data.r;
	float frame_step_y = anim_data.g;
	float anim_total;
	float cols;
	float frame_index;
	decode_animation(anim_data, anim_total, cols, frame_index);

	// Front/back faces only (vertical normal); side faces keep their static stripe UV.
	bool is_front_back = abs(model_normal.y) >= side_normal_y_threshold;

	if (anim_total > 1.0 && is_front_back) {
		// ORIGINAL: +0.001 biases up to prevent float imprecision from rounding down
		// at frame boundaries (e.g., floor(1.9999) -> 1 instead of 2).
		// BUG: When mod() returns a value in [total - 0.001, total), adding 0.001
		// pushes it to >= total, making floor() produce `total` — an out-of-bounds
		// frame index. This samples past the animation strip (blank/ghost frame).
		// More frequent on AMD GPUs due to different mod() precision characteristics.
		// float frame_index = floor(mod(TIME * speed, total) + 0.001);

		// FIX: min() clamps frame_index to [0, total-1], preventing OOB access.
		// Keeps the +0.001 bias (still needed to avoid rounding-down stutter).
		// Uses min() instead of a second mod() because mod() would wrap to frame 0
		// causing a visible flash, while clamping to last frame is imperceptible.
		float col = mod(frame_index, cols);
		float row = floor(frame_index / cols);
		// Offset tile's base UV to the current animation frame
		vec2 offset = vec2(col * frame_step_x, row * frame_step_y);
		uv_min += offset;
		uv_max += offset;
	}

	vec2 flipped_uv = vec2(UV.x, 1.0 - UV.y);
	if (mirror_texture) {
		flipped_uv.x = 1.0 - flipped_uv.x;
	}

	// Counter-rotate UV to cancel mesh rotation when freeze-UV is active
	if (freeze_rot > 0) {
		int rot_steps = freeze_rot - 1;
		if (rot_steps == 1) flipped_uv = vec2(flipped_uv.y, 1.0 - flipped_uv.x);
		else if (rot_steps == 2) flipped_uv = vec2(1.0 - flipped_uv.x, 1.0 - flipped_uv.y);
		else if (rot_steps == 3) flipped_uv = vec2(1.0 - flipped_uv.y, flipped_uv.x);
	}

	vec2 remapped_uv = mix(uv_min, uv_max, flipped_uv);

    vec2 final_uv;
    if (use_nearest_texture) {
        // Nearest: no interpolation might not even need to apply a pixel inset
        // final_uv = remapped_uv;

        vec2 texel_inset = inset_value / vec2(textureSize(albedo_texture_linear, 0));
        final_uv = clamp(remapped_uv, uv_min + texel_inset, uv_max - texel_inset);
    } else {
        // final_uv = remapped_uv; //

        // Linear: half-texel inset to prevent bilinear bleed
        vec2 texel_inset = inset_value / vec2(textureSize(albedo_texture_linear, 0));
        final_uv = clamp(remapped_uv, uv_min + texel_inset, uv_max - texel_inset);
    }


	
	// Sample texture with correct filter mode (nearest or linear)
	// Animated tiles: force mip level 0 to prevent cross-frame mipmap bleeding (front/back only)
	vec4 tex_color;
	if (anim_total > 1.0 && is_front_back) {
		tex_color = use_nearest_texture
			? textureLod(albedo_texture_nearest, final_uv, 0.0)
			: textureLod(albedo_texture_linear, final_uv, 0.0);
	} else {
		tex_color = use_nearest_texture
			? texture(albedo_texture_nearest, final_uv)
			: texture(albedo_texture_linear, final_uv);
	}

	// discard must happen BEFORE any other assignments
	if (tex_color.a < alpha_threshold) {
		if (!debug_show_transparent_tiles || !is_cell_transparent(uv_min, uv_max)) {
			discard;  // ← This is what makes shadows work!
		}
		tex_color = vec4(1.0, 0.0, 1.0, 1.0);
	}

	// Always renders both faces without backface debug (cull_disabled)
	ALBEDO = albedo_color.rgb * tex_color.rgb;
}
