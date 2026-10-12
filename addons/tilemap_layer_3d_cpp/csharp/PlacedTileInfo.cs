#nullable enable
using Godot;

namespace TML3D;

/// <summary>Typed C# view of one tile (TML3D_PlacedTileInfo).</summary>
/// <remarks>
/// Lookups return a new instance filled from storage. Editing it does not change the map; place it again to write it.
/// Int fields use the C++ enum values. Holds the native Resource and never attaches a script.
/// </remarks>
public sealed class PlacedTileInfo
{
    // Bound names; FacadeCheck verifies every table that declares a Class.
    static class Names
    {
        public static readonly StringName Class = "TML3D_PlacedTileInfo";
        public static readonly StringName VertexCorners = "vertex_corners";
        public static readonly StringName TileKey = "tile_key";
        public static readonly StringName GridPosition = "grid_position";
        public static readonly StringName UvRect = "uv_rect";
        public static readonly StringName Orientation = "orientation";
        public static readonly StringName MeshRotation = "mesh_rotation";
        public static readonly StringName MeshMode = "mesh_mode";
        public static readonly StringName IsFaceFlipped = "is_face_flipped";
        public static readonly StringName IsTextureMirrored = "is_texture_mirrored";
        public static readonly StringName TerrainId = "terrain_id";
        public static readonly StringName SpinAngleRad = "spin_angle_rad";
        public static readonly StringName TiltAngleRad = "tilt_angle_rad";
        public static readonly StringName DiagonalScale = "diagonal_scale";
        public static readonly StringName TiltOffsetFactor = "tilt_offset_factor";
        public static readonly StringName DepthScale = "depth_scale";
        public static readonly StringName TextureRepeatMode = "texture_repeat_mode";
        public static readonly StringName UvRotation = "uv_rotation";
        public static readonly StringName DepthGrowthMode = "depth_growth_mode";
        public static readonly StringName AnimStepX = "anim_step_x";
        public static readonly StringName AnimStepY = "anim_step_y";
        public static readonly StringName AnimTotalFrames = "anim_total_frames";
        public static readonly StringName AnimColumns = "anim_columns";
        public static readonly StringName AnimSpeedFps = "anim_speed_fps";
        public static readonly StringName AtlasSourceId = "atlas_source_id";
        public static readonly StringName AtlasCoords = "atlas_coords";
        public static readonly StringName CustomTransform = "custom_transform";
        public static readonly StringName HasCustomTransform = "has_custom_transform";
        public static readonly StringName SnappedGridPosition = "snapped_grid_position";
        public static readonly StringName WorldPosition = "world_position";
        public static readonly StringName GetTerrainRegionChunk = "get_terrain_region_chunk";
        public static readonly StringName Copy = "copy";
    }

    static class RegionNames
    {
        public static readonly StringName Class = "TML3D_TerrainRegionChunk";
        public static readonly StringName RegionKey = "region_key";
        public static readonly StringName TileKeys = "tile_keys";
    }

    /// <summary>The underlying TML3D_PlacedTileInfo resource, for signals or raw Get / Set.</summary>
    public Resource Native { get; }

    PlacedTileInfo(Resource native) => Native = native;

    /// <summary>Creates a new tile info, like TML3D_PlacedTileInfo.new(); unset fields keep their defaults.</summary>
    public PlacedTileInfo() : this((Resource)ClassDB.Instantiate(Names.Class).AsGodotObject()) { }

    /// <summary>Wraps an existing TML3D_PlacedTileInfo resource, or returns null if obj is not one.</summary>
    public static PlacedTileInfo? From(GodotObject? obj)
        => obj is Resource res && GodotObject.IsInstanceValid(res) && res.IsClass(Names.Class) ? new PlacedTileInfo(res) : null;

    internal static PlacedTileInfo? From(Variant value)
        => value.VariantType == Variant.Type.Object ? From(value.AsGodotObject()) : null;

    /// <summary>64-bit tile identity from grid position and orientation (-1 = unset); placement recomputes it.</summary>
    public long TileKey { get => Native.Get(Names.TileKey).AsInt64(); set => Native.Set(Names.TileKey, value); }

    /// <summary>Storage-grid position in grid units; placement overwrites it from the world position.</summary>
    public Vector3 GridPosition { get => Native.Get(Names.GridPosition).AsVector3(); set => Native.Set(Names.GridPosition, value); }

    /// <summary>Snapped grid position, filled by lookups; not saved.</summary>
    public Vector3 SnappedGridPosition => Native.Get(Names.SnappedGridPosition).AsVector3();

    /// <summary>
    /// World-space position, filled by lookups; not saved.
    /// To place at a world position, pass it to <see cref="TileMapLayer3D.PlaceTile"/>.
    /// </summary>
    public Vector3 WorldPosition => Native.Get(Names.WorldPosition).AsVector3();

    /// <summary>Surface the tile lies on: 0 floor, 1 ceiling, 2-5 walls N/S/E/W, 6-25 tilted.</summary>
    public int Orientation { get => Native.Get(Names.Orientation).AsInt32(); set => Native.Set(Names.Orientation, value); }

    /// <summary>Mesh shape: 0 flat square, 1 triangle, 2 box, 3 prism, 15 autoshape (values are sparse).</summary>
    public int MeshMode { get => Native.Get(Names.MeshMode).AsInt32(); set => Native.Set(Names.MeshMode, value); }

    /// <summary>Rotation within the surface in quarter turns (0-3).</summary>
    public int MeshRotation { get => Native.Get(Names.MeshRotation).AsInt32(); set => Native.Set(Names.MeshRotation, value); }

    /// <summary>Atlas pixel rectangle the tile samples; placement overwrites it from the call's uvRect.</summary>
    public Rect2 UvRect { get => Native.Get(Names.UvRect).AsRect2(); set => Native.Set(Names.UvRect, value); }

    /// <summary>TileSet atlas source the tile is bound to; -1 = freeform UVs.</summary>
    public int AtlasSourceId { get => Native.Get(Names.AtlasSourceId).AsInt32(); set => Native.Set(Names.AtlasSourceId, value); }

    /// <summary>TileSet atlas cell the tile is bound to; (-1, -1) = unset.</summary>
    public Vector2I AtlasCoords { get => Native.Get(Names.AtlasCoords).AsVector2I(); set => Native.Set(Names.AtlasCoords, value); }

    /// <summary>Autotile terrain id; -1 = not autotiled.</summary>
    public int TerrainId { get => Native.Get(Names.TerrainId).AsInt32(); set => Native.Set(Names.TerrainId, value); }

    /// <summary>Mirrors the geometry along local Z (flipped triangles and arches).</summary>
    public bool IsFaceFlipped { get => Native.Get(Names.IsFaceFlipped).AsBool(); set => Native.Set(Names.IsFaceFlipped, value); }

    /// <summary>Mirrors the texture horizontally without changing the geometry.</summary>
    public bool IsTextureMirrored { get => Native.Get(Names.IsTextureMirrored).AsBool(); set => Native.Set(Names.IsTextureMirrored, value); }

    /// <summary>Texture rotation inside the tile in quarter turns (0-3), applied after mirroring.</summary>
    public int UvRotation { get => Native.Get(Names.UvRotation).AsInt32(); set => Native.Set(Names.UvRotation, value); }

    /// <summary>Thickness of box, prism and autoshape meshes in grid cells (1.0 = one cell).</summary>
    public double DepthScale { get => Native.Get(Names.DepthScale).AsDouble(); set => Native.Set(Names.DepthScale, value); }

    /// <summary>Side texturing of depth meshes: 0 stretched edge stripe, 1 repeated tile texture.</summary>
    public int TextureRepeatMode { get => Native.Get(Names.TextureRepeatMode).AsInt32(); set => Native.Set(Names.TextureRepeatMode, value); }

    /// <summary>Extrusion direction of depth meshes: 0 outward, 1 inward.</summary>
    public int DepthGrowthMode { get => Native.Get(Names.DepthGrowthMode).AsInt32(); set => Native.Set(Names.DepthGrowthMode, value); }

    /// <summary>Angle of one <see cref="MeshRotation"/> step; 0 renders as 90°. Set it yourself for tilted orientations (6-25).</summary>
    public double SpinAngleRad { get => Native.Get(Names.SpinAngleRad).AsDouble(); set => Native.Set(Names.SpinAngleRad, value); }

    /// <summary>Slope angle of tilted orientations; 0 renders as 45°. Set it yourself for tilted orientations.</summary>
    public double TiltAngleRad { get => Native.Get(Names.TiltAngleRad).AsDouble(); set => Native.Set(Names.TiltAngleRad, value); }

    /// <summary>Stretch along the slope of tilted orientations (about 1.414 in the editor); 0 keeps the built-in scale.</summary>
    public double DiagonalScale { get => Native.Get(Names.DiagonalScale).AsDouble(); set => Native.Set(Names.DiagonalScale, value); }

    /// <summary>Cell-centring offset of tilted orientations as a fraction of grid size; 0 renders as 0.5.</summary>
    public double TiltOffsetFactor { get => Native.Get(Names.TiltOffsetFactor).AsDouble(); set => Native.Set(Names.TiltOffsetFactor, value); }

    /// <summary>Width of one animation frame as a fraction of the atlas width.</summary>
    public double AnimStepX { get => Native.Get(Names.AnimStepX).AsDouble(); set => Native.Set(Names.AnimStepX, value); }

    /// <summary>Height of one animation frame as a fraction of the atlas height.</summary>
    public double AnimStepY { get => Native.Get(Names.AnimStepY).AsDouble(); set => Native.Set(Names.AnimStepY, value); }

    /// <summary>Number of animation frames; 1 = static.</summary>
    public int AnimTotalFrames { get => Native.Get(Names.AnimTotalFrames).AsInt32(); set => Native.Set(Names.AnimTotalFrames, value); }

    /// <summary>Frames per atlas row before the sequence wraps.</summary>
    public int AnimColumns { get => Native.Get(Names.AnimColumns).AsInt32(); set => Native.Set(Names.AnimColumns, value); }

    /// <summary>Authored animation speed in FPS; 0 = paused. Runtime speed overrides do not change it.</summary>
    public double AnimSpeedFps { get => Native.Get(Names.AnimSpeedFps).AsDouble(); set => Native.Set(Names.AnimSpeedFps, value); }

    /// <summary>Exact node-local transform for off-grid tiles; used only when <see cref="HasCustomTransform"/> is true.</summary>
    public Transform3D CustomTransform { get => Native.Get(Names.CustomTransform).AsTransform3D(); set => Native.Set(Names.CustomTransform, value); }

    /// <summary>Whether <see cref="CustomTransform"/> replaces the grid-built transform.</summary>
    public bool HasCustomTransform { get => Native.Get(Names.HasCustomTransform).AsBool(); set => Native.Set(Names.HasCustomTransform, value); }

    /// <summary>Four node-local corners for a vertex tile; empty for regular tiles. Not saved on this resource.</summary>
    public Vector3[] VertexCorners { get => Native.Get(Names.VertexCorners).AsVector3Array(); set => Native.Set(Names.VertexCorners, value); }

    /// <summary>The terrain region (TML3D_TerrainRegionChunk) this tile belongs to, or null.</summary>
    public Resource? RegionChunk
    {
        get
        {
            Variant chunk = Native.Call(Names.GetTerrainRegionChunk);
            return chunk.VariantType == Variant.Type.Object ? chunk.AsGodotObject() as Resource : null;
        }
    }

    /// <summary>Key of the tile's terrain region, or null.</summary>
    public Vector3I? RegionKey => RegionChunk is { } chunk ? chunk.Get(RegionNames.RegionKey).AsVector3I() : null;

    /// <summary>Keys of every tile in the same terrain region; empty if none.</summary>
    public long[] RegionTileKeys => RegionChunk is { } chunk ? chunk.Get(RegionNames.TileKeys).AsInt64Array() : [];

    /// <summary>A new tile info with the same values; use it before changing a tile you got from a lookup.</summary>
    public PlacedTileInfo Copy() => From(Native.Call(Names.Copy))!;
}
