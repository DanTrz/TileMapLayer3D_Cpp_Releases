shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
        specular_schlick_ggx;



group_uniforms Appearance;
/** Base color texture; sampled with nearest filtering for crisp pixels. */
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable,
        hint_default_white;
/** Multiplies the texture and vertex color. */
uniform vec4 albedo_color : source_color = vec4(1.0);
group_uniforms Appearance.AtlasRegion;
/** Enabled and maintained by TML3D_FoliageAtlasMaterial. */
uniform bool use_albedo_region = false;
/** Atlas region in pixels: x, y, width, height. */
uniform vec4 albedo_region_px = vec4(0.0);
group_uniforms Appearance;
/** Multiply the albedo by mesh or MultiMesh vertex colors. */
uniform bool use_vertex_color = true;
/** Convert vertex colors from sRGB to linear space. */
uniform bool vertex_color_is_srgb = false;
/** Controls reflection sharpness; 1 is fully rough. */
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
/** Controls dielectric reflectivity. */
uniform float specular : hint_range(0.0, 1.0) = 0.2;
/** Discard pixels with alpha below this value. */
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

group_uniforms Appearance.Emission;
/** Make the foliage self-lit. */
uniform bool use_emission = false;
/** Tints the emitted light. */
uniform vec3 emission_color : source_color = vec3(1.0);
/** Multiplies emission brightness. */
uniform float emission_energy : hint_range(0.0, 16.0, 0.01) = 1.0;

group_uniforms Geometry;
/** Rotate the foliage to face the camera while preserving scale. */
uniform bool billboard = true;
/** Light every surface using the world-up normal without rotating geometry. */
uniform bool force_normals_up = false;

group_uniforms Shadows;
/** Give each instance one shadow result sampled at its origin. */
uniform bool whole_instance_shadows = false;

group_uniforms Wind;
/** Enable animated wind sway. */
uniform bool wind_enabled = true;
/** Maximum horizontal sway distance. */
uniform float wind_sway_strength : hint_range(0.0, 1.0, 0.001) = 0.1;
/** Number of sway cycles over time. */
uniform float wind_sway_speed : hint_range(0.0, 10.0, 0.01) = 1.0;
/** Multiplies Godot's global time for this material. */
uniform float wind_time_scale : hint_range(0.0, 5.0, 0.01) = 1.0;
/** Adds a fixed offset to the sway phase. */
uniform float wind_time_offset = 0.0;
/** Maximum unique timing offset as a fraction of one sway cycle. */
uniform float sway_variation : hint_range(0.0, 1.0, 0.01) = 0.35;
/** Chance that an instance gets unique timing; 0 is none and 1 is all. */
uniform float sway_chance : hint_range(0.0, 1.0, 0.01) = 0.1;
/** Pin UV.y 1 as the base; disable to pin UV.y 0 instead. */
uniform bool sway_from_bottom = true;

varying vec3 instance_lighting_origin_view;

float random_from_position(vec2 position) {
    // A stable pseudo-random value derived from each instance's world X/Z.
    return fract(sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 srgb_to_linear(vec3 color) {
    bvec3 use_low = lessThanEqual(color, vec3(0.04045));
    vec3 low = color / 12.92;
    vec3 high = pow((color + 0.055) / 1.055, vec3(2.4));
    return mix(high, low, use_low);
}

vec2 get_albedo_uv(vec2 local_uv) {
    if (!use_albedo_region) {
        return local_uv;
    }

    vec2 atlas_size = max(vec2(textureSize(albedo_tex, 0)), vec2(1.0));
    vec2 region_size = max(albedo_region_px.zw, vec2(1.0));
    vec2 region_pixel = albedo_region_px.xy + vec2(0.5);
    region_pixel += clamp(local_uv, vec2(0.0), vec2(1.0)) *
            max(region_size - vec2(1.0), vec2(0.0));
    return region_pixel / atlas_size;
}

void vertex() {
    if (wind_enabled && wind_sway_strength > 0.0) {
        float sway_mask = sway_from_bottom ? (1.0 - UV.y) : UV.y;
        sway_mask = clamp(sway_mask, 0.0, 1.0);

        // MODEL_MATRIX includes the per-instance transform for MultiMeshes.
        vec2 instance_position = MODEL_MATRIX[3].xz;
        float instance_random = random_from_position(instance_position);

        // Remap the selected part of the random range back to 0..1 so the full
        // timing range remains available even when only a few instances vary.
        float safe_chance = max(sway_chance, 0.00001);
        float receives_unique_sway = step(instance_random, sway_chance);
        float unique_phase = clamp(instance_random / safe_chance, 0.0, 1.0);
        unique_phase *= TAU * sway_variation * receives_unique_sway;

        float phase = TIME * wind_time_scale * wind_sway_speed;
        phase += wind_time_offset + unique_phase;
        VERTEX.x += sin(phase) * wind_sway_strength * sway_mask;
    }

    if (billboard) {
        // MAIN_CAM_INV_VIEW_MATRIX keeps the billboard orientation consistent
        // in color and shadow passes. Preserve node/MultiMesh instance scale.
        vec3 model_scale = vec3(
                length(MODEL_MATRIX[0].xyz),
                length(MODEL_MATRIX[1].xyz),
                length(MODEL_MATRIX[2].xyz));
        model_scale = max(model_scale, vec3(0.00001));

        vec3 camera_right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
        vec3 camera_up = normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
        vec3 camera_forward = normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xyz);

        mat4 billboard_model_matrix = mat4(
                vec4(camera_right * model_scale.x, 0.0),
                vec4(camera_up * model_scale.y, 0.0),
                vec4(camera_forward * model_scale.z, 0.0),
                MODEL_MATRIX[3]);
        MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model_matrix;

        // This is the inverse-transpose of the billboard model basis, followed
        // by the view transform. It keeps normals correct with non-uniform scale.
        mat3 billboard_normal_matrix = mat3(
                camera_right / model_scale.x,
                camera_up / model_scale.y,
                camera_forward / model_scale.z);
        MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * billboard_normal_matrix;
    }

    // MODELVIEW_MATRIX contains the MultiMesh instance transform and any
    // billboard adjustment. Every vertex in one instance receives this same
    // view-space origin, so it remains constant after interpolation.
    instance_lighting_origin_view =
            (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
    vec4 texture_color = texture(albedo_tex, get_albedo_uv(UV));
    vec4 vertex_color = use_vertex_color ? COLOR : vec4(1.0);

    if (use_vertex_color && vertex_color_is_srgb) {
        vertex_color.rgb = srgb_to_linear(vertex_color.rgb);
    }

    vec4 surface_color = texture_color * vertex_color * albedo_color;
    ALBEDO = surface_color.rgb;
    ALPHA = surface_color.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
    ROUGHNESS = roughness;
    SPECULAR = specular;

    if (whole_instance_shadows) {
        LIGHT_VERTEX = instance_lighting_origin_view;
    }

    if (force_normals_up) {
        // NORMAL is in view space in fragment(), so transform world +Y to view.
        NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    }

    if (use_emission) {
        EMISSION = surface_color.rgb * emission_color * emission_energy;
    }
}
