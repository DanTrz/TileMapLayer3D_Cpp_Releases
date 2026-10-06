// Every texture_filter_mode is built from one linear+mipmap sampler, so Forward+ and Compatibility
// (which keeps filter state per texture, not per uniform) use the same filtering.
// 0 Nearest, 1 Nearest Mipmap, 2 Linear, 3 Linear Mipmap, 4 Smooth Pixel.
// texel, cell_min and cell_max are in atlas texels; texel_dx/dy must come from uniform control flow.
vec4 sample_tile(sampler2D atlas, vec2 atlas_size, vec2 texel, vec2 texel_dx, vec2 texel_dy,
		vec2 cell_min, vec2 cell_max, int mode, float inset) {
	// Box-filtered mips never mix two cells while a mip texel stays inside the cell's power-of-two alignment.
	ivec2 o = ivec2(round(cell_min));
	ivec2 s = ivec2(round(cell_max - cell_min));
	int bits = o.x | o.y | s.x | s.y;
	float max_lod = max(log2(float(max(bits & -bits, 1))) - 2.0, 0.0);
	float lod = 0.0;
	if (mode == 1 || mode == 3 || mode == 4) {
		float footprint_sq = max(max(dot(texel_dx, texel_dx), dot(texel_dy, texel_dy)), 1e-8);
		lod = clamp(0.5 * log2(footprint_sq), 0.0, max_lod);
	}
	if (mode == 1) {
		lod = round(lod);
	}
	vec2 t = texel;
	if (mode == 4) {
		// Anti-aliased point sampling: flat texels, each seam blended over one screen pixel. On the full-res
		// grid, so any axis where texels are smaller than a pixel has a footprint >= 1 and is left unchanged.
		vec2 seam = floor(t + 0.5);
		vec2 footprint = max(abs(texel_dx) + abs(texel_dy), vec2(1e-4));
		t = seam + clamp((t - seam) / footprint, -0.5, 0.5);
	}
	// The inset (pixel_inset_value, in sampled-mip texels) is how far filtering may read into the neighbouring
	// cell. Below 0.5 it bleeds slightly, which keeps multi-tile objects seamless where atlas neighbours connect.
	float m = exp2(ceil(lod));
	t = clamp(t, cell_min + inset * m, cell_max - inset * m);
	if (mode <= 1) {
		t = (floor(t / m) + 0.5) * m;
	}
	return textureLod(atlas, t / atlas_size, lod);
}
