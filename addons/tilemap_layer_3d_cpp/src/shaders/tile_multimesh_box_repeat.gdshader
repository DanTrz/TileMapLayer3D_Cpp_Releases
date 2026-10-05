shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

// Dedicated shader for BOX_MESH / PRISM_MESH chunks in REPEAT texture mode ONLY.
// Mirrors tile_multimesh_doubleface.gdshader (atlas remap + inset + alpha discard, double-sided
// via cull_disabled, AND the texture-turn decode packed into INSTANCE_CUSTOM.a) EXCEPT it
// depth-corrects the side faces:
//
//   The box/prism mesh is baked once at depth_scale = 1.0 and the real depth is applied as a
//   per-instance local-Y scale (build_tile_transform -> get_scale_for_orientation). The side faces
//   bake a full 0->1 texture across their depth, so a thin box would squash the whole texture into
//   the short side. Here we recover the per-instance Y scale from MODEL_MATRIX and shrink the
//   depth axis to match, so the side shows a depth_scale slice at top-face texel density.
//
//   Side UVs continue the top face's texture across each edge (create_box_mesh_repeat). UV2 names
//   the axis that runs through the depth and its value at the top-face seam (-1 = none). The
//   correction runs before mirror and texture turn, so every face mirrors and turns with the top.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform bool use_nearest_texture = true;
uniform sampler2D albedo_texture_nearest : source_color, filter_nearest, repeat_disable;
uniform sampler2D albedo_texture_linear : source_color, filter_linear, repeat_disable;
uniform float inset_value = 0.5; // Inset in pixels to prevent texture bleeding
// Side faces have a horizontal local normal (|n.y| < this); top/bottom/caps have |n.y| ~= 1.
// Mirrors GlobalConstants.BOX_SIDE_NORMAL_Y_THRESHOLD.
uniform float side_normal_y_threshold = 0.5;
uniform float animation_clock = 0.0;
uniform bool debug_show_transparent_tiles = false;

const float ANIM_PACKED_MARKER = 262144.0;

varying flat vec4 uv_rect_data;
varying flat vec4 anim_data;         // per-instance animation (front/back faces only)
varying vec3 model_normal;          // local-space normal (pre-orientation) — side detection
varying flat float inst_y_scale;    // recovered per-instance local-Y scale == depth_scale
varying flat vec2 depth_seam;       // UV2: per axis, the UV at the top-face seam when it runs through the depth; -1 = none

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
	// Local Y axis of the instance carries depth_scale (applied before orientation rotation).
	inst_y_scale = length(MODEL_MATRIX[1].xyz);
	depth_seam = UV2;
}

void fragment() {
	vec2 uv_min = uv_rect_data.rg;
	vec2 uv_max = uv_rect_data.ba;
	bool mirror_texture = uv_rect_data.a >= 16.0;
	float packed_alpha = uv_rect_data.a - (mirror_texture ? 16.0 : 0.0);
	uv_max.y = packed_alpha;

	// Decode freeze-UV rotation from packed custom_data.a (must match the shared tile shader):
	// values < 2.0 = no freeze; >= 2.0 = freeze with encoded rotation, where the real uv_max.y
	// is recovered by removing the rotation multiples of 2.0. Without this, freeze-UV box/prism
	// tiles carry uv_max.y >= 2.0 and sample garbage (noise) outside the atlas cell.
	int freeze_rot = int(floor(packed_alpha / 2.0));
	if (freeze_rot > 0) {
		uv_max.y = packed_alpha - float(freeze_rot) * 2.0;
	}

	// Animation: offset the atlas cell per frame, FRONT/BACK faces only (vertical normal).
	// Side faces keep their static stripe UV. Packed runtime playback and legacy animation
	// (frame_step_x, frame_step_y, total_frames, cols + speed/256). Static tiles = (1,1,1,1).
	bool is_front_back = abs(model_normal.y) >= side_normal_y_threshold;
	float anim_total;
	float cols;
	float frame_index;
	decode_animation(anim_data, anim_total, cols, frame_index);
	bool is_animated = anim_total > 1.0 && is_front_back;
	if (is_animated) {
		float frame_step_x = anim_data.r;
		float frame_step_y = anim_data.g;
		float col = mod(frame_index, cols);
		float row = floor(frame_index / cols);
		vec2 offset = vec2(col * frame_step_x, row * frame_step_y);
		uv_min += offset;
		uv_max += offset;
	}

	vec2 flipped_uv = vec2(UV.x, 1.0 - UV.y);

	// Depth-correct side faces in the mesh frame, BEFORE mirror and turn: the depth axis shrinks by
	// depth_scale around its seam value. depth == 1.0 is a no-op; top/bottom faces carry -1.
	if (depth_seam.x >= 0.0) {
		flipped_uv.x = depth_seam.x + (flipped_uv.x - depth_seam.x) * inst_y_scale;
	}
	if (depth_seam.y >= 0.0) {
		flipped_uv.y = depth_seam.y + (flipped_uv.y - depth_seam.y) * inst_y_scale;
	}

	if (mirror_texture) {
		flipped_uv.x = 1.0 - flipped_uv.x;
	}

	// Counter-rotate UV to cancel mesh rotation when freeze-UV is active (matches shared shader).
	if (freeze_rot > 0) {
		int rot_steps = freeze_rot - 1;
		if (rot_steps == 1) flipped_uv = vec2(flipped_uv.y, 1.0 - flipped_uv.x);
		else if (rot_steps == 2) flipped_uv = vec2(1.0 - flipped_uv.x, 1.0 - flipped_uv.y);
		else if (rot_steps == 3) flipped_uv = vec2(1.0 - flipped_uv.y, flipped_uv.x);
	}

	vec2 remapped_uv = mix(uv_min, uv_max, flipped_uv);

	// Half-texel inset to prevent bleed/bilinear bleed at the atlas-cell edges.
	vec2 texel_inset = inset_value / vec2(textureSize(albedo_texture_linear, 0));
	vec2 final_uv = clamp(remapped_uv, uv_min + texel_inset, uv_max - texel_inset);

	// Animated front/back faces: force mip 0 to prevent cross-frame mipmap bleeding.
	vec4 tex_color;
	if (is_animated) {
		tex_color = use_nearest_texture
			? textureLod(albedo_texture_nearest, final_uv, 0.0)
			: textureLod(albedo_texture_linear, final_uv, 0.0);
	} else {
		tex_color = use_nearest_texture
			? texture(albedo_texture_nearest, final_uv)
			: texture(albedo_texture_linear, final_uv);
	}

	// discard must happen BEFORE any other assignments (keeps shadows correct).
	if (tex_color.a < alpha_threshold) {
		if (!debug_show_transparent_tiles || !is_cell_transparent(uv_min, uv_max)) {
			discard;
		}
		tex_color = vec4(1.0, 0.0, 1.0, 1.0);
	}

	ALBEDO = albedo_color.rgb * tex_color.rgb;
}
