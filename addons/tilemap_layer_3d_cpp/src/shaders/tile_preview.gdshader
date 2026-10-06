shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

// Preview shader — UV region passed via uniforms (no INSTANCE_CUSTOM/COLOR tricks)
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 uv_region_min = vec2(0.0, 0.0);
uniform vec2 uv_region_max = vec2(1.0, 1.0);
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform int filter_mode = 0;
uniform bool mirror_texture = false;
uniform int uv_rotation = 0;

#include "res://addons/tilemap_layer_3d_cpp/src/shaders/tile_sampling.gdshaderinc"

void fragment() {
    vec2 flipped_uv = vec2(UV.x, 1.0 - UV.y);
    if (mirror_texture) {
        flipped_uv.x = 1.0 - flipped_uv.x;
    }
    // Same mirror-then-quarter-turn order as the MultiMesh shader and baking.
    if (uv_rotation == 1) {
        flipped_uv = vec2(flipped_uv.y, 1.0 - flipped_uv.x);
    } else if (uv_rotation == 2) {
        flipped_uv = vec2(1.0 - flipped_uv.x, 1.0 - flipped_uv.y);
    } else if (uv_rotation == 3) {
        flipped_uv = vec2(1.0 - flipped_uv.y, flipped_uv.x);
    }
    vec2 remapped_uv = mix(uv_region_min, uv_region_max, flipped_uv);

    vec2 atlas_size = vec2(textureSize(albedo_texture, 0));
    vec2 texel = remapped_uv * atlas_size;
    vec4 tex_color = sample_tile(albedo_texture, atlas_size, texel, dFdx(texel), dFdy(texel),
            uv_region_min * atlas_size, uv_region_max * atlas_size, filter_mode, 0.5);

    if (tex_color.a < alpha_threshold) {
        discard;
    }

    ALBEDO = albedo_color.rgb * tex_color.rgb;
}
