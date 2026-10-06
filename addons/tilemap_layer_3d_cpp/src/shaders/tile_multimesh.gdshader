shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold = 0.5;
uniform int filter_mode = 0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool debug_show_backfaces = true;
uniform bool debug_show_transparent_tiles = false;
uniform float debug_transparent_tolerance = 0.0;
uniform float inset_value = 0.5; // Inset in pixels to prevent texture bleeding, can be adjusted based on texture resolution
uniform float animation_clock = 0.0;

const float ANIM_PACKED_MARKER = 262144.0;

varying flat vec4 uv_rect_data;
varying flat vec4 anim_data;

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

// Debug only: true when the cell's opaque texels are at most debug_transparent_tolerance (0-1) of it.
// Every texel is read; cells wider than 32 texels are strided to keep the scan bounded.
bool is_cell_transparent(vec2 cell_min, vec2 cell_max) {
    vec2 atlas_size = vec2(textureSize(albedo_texture, 0));
    ivec2 texel_min = ivec2(round(cell_min * atlas_size));
    ivec2 texel_max = ivec2(round(cell_max * atlas_size));
    ivec2 cell_size = max(texel_max - texel_min, ivec2(1));
    ivec2 stride = (cell_size + 31) / 32;
    ivec2 samples = (cell_size + stride - 1) / stride;
    int max_opaque = int(float(samples.x * samples.y) * debug_transparent_tolerance);
    int opaque = 0;
    for (int y = texel_min.y; y < texel_max.y; y += stride.y) {
        for (int x = texel_min.x; x < texel_max.x; x += stride.x) {
            if (texelFetch(albedo_texture, ivec2(x, y), 0).a >= alpha_threshold) {
                opaque++;
                if (opaque > max_opaque) {
                    return false;
                }
            }
        }
    }
    return true;
}

void vertex() {
    uv_rect_data = INSTANCE_CUSTOM;
    anim_data = COLOR;
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
    // Static tiles: default COLOR=(1,1,1,1), guard 1.0 > 1.0 = false - means it's skipped
    float frame_step_x = anim_data.r;
    float frame_step_y = anim_data.g;
    float anim_total;
    float cols;
    float frame_index;
    decode_animation(anim_data, anim_total, cols, frame_index);

    if (anim_total > 1.0) {
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
        // Integer math: float division may land just below a whole number on web GPUs (row 1 -> row 0).
        int frame_i = int(frame_index);
        int cols_i = int(cols);
        float col = float(frame_i % cols_i);
        float row = float(frame_i / cols_i);
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

    vec2 atlas_size = vec2(textureSize(albedo_texture, 0));
    vec2 texel = remapped_uv * atlas_size;
    vec4 tex_color = sample_tile(albedo_texture, atlas_size, texel, dFdx(texel), dFdy(texel),
            uv_min * atlas_size, uv_max * atlas_size, filter_mode, inset_value);

    if (tex_color.a < alpha_threshold) {
        if (!debug_show_transparent_tiles || !is_cell_transparent(uv_min, uv_max)) {
            discard;
        }
        tex_color = vec4(1.0, 0.0, 1.0, 1.0);
    }

    if (debug_show_backfaces && !FRONT_FACING) {
        ALBEDO = vec3(1.0, 0.0, 0.0);
    } else {
        ALBEDO = albedo_color.rgb * tex_color.rgb;
    }
}
