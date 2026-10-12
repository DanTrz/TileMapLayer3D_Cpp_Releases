#nullable enable
using System;
using System.Reflection;
using Godot;
using Godot.Collections;

namespace TML3D;

// Do not add [GlobalClass]: it would let the editor create a plain Node3D under this name.
/// <summary>C# entry point to a TileMapLayer3d_Cpp node and its runtime API.</summary>
/// <remarks>
/// Attach this script to a TileMapLayer3d_Cpp node; [Export] TileMapLayer3D fields then take it directly.
/// From code, use <see cref="From"/> or <see cref="Instantiate"/>.
/// Orientation and mesh-mode arguments are the C++ enum ints (TML3D_GlobalUtil.TileOrientation: 0 floor, 1 ceiling,
/// 2-5 walls N/S/E/W, 6-25 tilted). Data resources are plain Resource.
/// Anything not wrapped here: GetRuntimeApi().Call(...).
/// </remarks>
[Tool]
public partial class TileMapLayer3D : Node3D
{
    /// <summary>Pass as an orientation to search all base orientations.</summary>
    public const int AnyOrientation = -1;

    // Bound names; FacadeCheck verifies every table that declares a Class.
    static class TileMapNodeNames
    {
        public static readonly StringName Class = "TileMapLayer3d_Cpp";
        public static readonly StringName GetRuntimeApi = "get_runtime_api";
        public static readonly StringName TileMapData = "tile_map_data";
        public static readonly StringName Settings = "settings";
        public static readonly StringName CreateTileMapData = "create_tile_map_data";
        public static readonly StringName ReloadFromData = "reload_from_data";
        public static readonly StringName GetTileCount = "get_tile_count";
        public static readonly StringName HasTile = "has_tile";
        public static readonly StringName GetTileInfoFromKey = "get_tile_info_from_key";
        public static readonly StringName ClearAllTiles = "clear_all_tiles";
        public static readonly StringName HighlightTiles = "highlight_tiles";
        public static readonly StringName ClearHighlights = "clear_highlights";
    }

    static class ApiNames
    {
        public static readonly StringName Class = "TML3D_RuntimeAPI";
        public static readonly StringName AnyOrientation = "ANY_ORIENTATION";
        public static readonly StringName PlaceTile = "place_tile";
        public static readonly StringName EraseTile = "erase_tile";
        public static readonly StringName PlaceArea = "place_area";
        public static readonly StringName EraseArea = "erase_area";
        public static readonly StringName FindTile = "find_tile";
        public static readonly StringName GetFirstTileFromRaycast = "get_first_tile_from_raycast";
        public static readonly StringName WorldToGridSnapped = "world_to_grid_snapped";
        public static readonly StringName GridToWorldSnapped = "grid_to_world_snapped";
        public static readonly StringName HighlightTile = "highlight_tile";
        public static readonly StringName HighlightArea = "highlight_area";
        public static readonly StringName SetCollisionForRegion = "set_collision_for_region";
        public static readonly StringName GetDebugInfo = "get_debug_info";
        public static readonly StringName GetTileDataFromKey = "get_tile_data_from_key";
        public static readonly StringName GetTileset = "get_tileset";
        public static readonly StringName AtlasCoordToUvRect = "atlas_coord_to_uv_rect";
        public static readonly StringName SwapTileTexture = "swap_tile_texture";
        public static readonly StringName SwapTileCollectionTexture = "swap_tile_collection_texture";
        public static readonly StringName GetVariantTileData = "get_variant_tile_data";
        public static readonly StringName GetCollectionTileData = "get_collection_tile_data";
        public static readonly StringName GetAnimationGroupTileData = "get_animation_group_tile_data";
        public static readonly StringName GetAnimatedGroupTileKeys = "get_animated_group_tile_keys";
        public static readonly StringName GetAnimatedGroupPlaybackState = "get_animated_group_playback_state";
        public static readonly StringName PauseAnimatedGroup = "pause_animated_group";
        public static readonly StringName ResumeAnimatedGroup = "resume_animated_group";
        public static readonly StringName SetAnimatedGroupSpeed = "set_animated_group_speed";
        public static readonly StringName SetAnimatedGroupFrame = "set_animated_group_frame";
        public static readonly StringName BakeCompleted = "bake_completed";
        public static readonly StringName BakeFailed = "bake_failed";
    }

    static class AreaNames
    {
        public static readonly StringName Class = "TML3D_RuntimeAreaOptions";
        public static readonly StringName Anchor = "anchor";
        public static readonly StringName Overwrite = "overwrite";
        public static readonly StringName TileInfo = "tile_info";
    }

    static class DataNames
    {
        public static readonly StringName Class = "TML3D_TileMapLayerData";
        public static readonly StringName RenderData = "render_data";
    }

    static class RenderDataNames
    {
        public static readonly StringName Class = "TML3D_TileMapLayerRenderData";
    }

    static class SettingsNames
    {
        public static readonly StringName Class = "TML3D_TileMapLayerSettings";
        public static readonly StringName GridSize = "grid_size";
    }

    static class ConstantsNames
    {
        public static readonly StringName Class = "TML3D_GlobalConstants";
        public static readonly StringName GetDefaultGridSize = "get_DEFAULT_GRID_SIZE";


    }

    static CSharpScript? _script;
    RefCounted? _api;

    // --- Getting the typed node ---

    /// <summary>Creates a new TileMapLayer3d_Cpp node with this script attached.</summary>
    public static TileMapLayer3D Instantiate() => From(ClassDB.Instantiate(TileMapNodeNames.Class).AsGodotObject())!;

    /// <summary>The typed view of a TileMapLayer3d_Cpp node (attaches this script if needed), or null if obj is not one.</summary>
    public static TileMapLayer3D? From(GodotObject? obj)
    {
        if (obj is TileMapLayer3D attached)
            return attached;
        if (obj is null || !IsInstanceValid(obj) || !obj.IsClass(TileMapNodeNames.Class))
            return null;

        _script ??= ResourceLoader.Load<CSharpScript>(typeof(TileMapLayer3D).GetCustomAttribute<ScriptPathAttribute>()!.Path);
        ulong id = obj.GetInstanceId();
        obj.SetScript(_script);
        // SetScript replaces the managed instance; fetch the new one.
        return InstanceFromId(id) as TileMapLayer3D;
    }

    /// <summary>The native TML3D_RuntimeAPI, for calls not wrapped here, e.g. GetRuntimeApi().Call("method", ...).</summary>
    public RefCounted GetRuntimeApi() => _api ??= (RefCounted)Call(TileMapNodeNames.GetRuntimeApi).AsGodotObject();

    static Variant Arg(GodotObject? obj)
    {
        if (obj is null)
            return default;
        return obj;
    }

    static T? Obj<T>(Variant value) where T : GodotObject
        => value.VariantType == Variant.Type.Object ? value.AsGodotObject() as T : null;

    // --- Data ---

    /// <summary>The node's TML3D_TileMapLayerData resource, or null.</summary>
    public Resource? GetTileMapData() => Obj<Resource>(Get(TileMapNodeNames.TileMapData));

    /// <summary>Assigns the node's TML3D_TileMapLayerData; other resource types are rejected with an error.</summary>
    public void SetTileMapData(Resource? data)
    {
        if (data is not null && !data.IsClass(DataNames.Class))
        {
            GD.PushError($"TML3D: SetTileMapData expects {DataNames.Class}, got {data.GetClass()}");
            return;
        }
        Set(TileMapNodeNames.TileMapData, Arg(data));
    }

    /// <summary>The tile rows (TML3D_TileMapLayerRenderData) of the current data, or null.</summary>
    public Resource? GetTileMapRenderData() => GetTileMapData() is { } data ? Obj<Resource>(data.Get(DataNames.RenderData)) : null;

    /// <summary>
    /// Replaces the tile rows with a TML3D_TileMapLayerRenderData (other types are rejected).
    /// Call <see cref="ReloadFromData"/> afterwards.
    /// </summary>
    public void SetTileMapRenderData(Resource renderData)
    {
        if (!renderData.IsClass(RenderDataNames.Class))
        {
            GD.PushError($"TML3D: SetTileMapRenderData expects {RenderDataNames.Class}, got {renderData.GetClass()}");
            return;
        }
        Resource data = (Resource)Call(TileMapNodeNames.CreateTileMapData).AsGodotObject();
        data.Set(DataNames.RenderData, renderData);
    }

    /// <summary>
    /// Rebuilds tiles, vertex tiles and scatter from the current data; call after swapping data. Collision is not rebuilt.
    /// Pass true only for legacy GDScript data.
    /// </summary>
    public void ReloadFromData(bool vertexCornersInWorldSpace = false) => Call(TileMapNodeNames.ReloadFromData, vertexCornersInWorldSpace);

    /// <summary>The node's TML3D_TileMapLayerSettings resource, or null.</summary>
    public Resource? GetSettings() => Obj<Resource>(Get(TileMapNodeNames.Settings));

    /// <summary>Grid cell size from the node's settings (the default size when there are none).</summary>
    public float GetGridSize() => GetSettings() is { } settings
        ? settings.Get(SettingsNames.GridSize).AsSingle()
        : ClassDB.ClassCallStatic(ConstantsNames.Class, ConstantsNames.GetDefaultGridSize).AsSingle();

    /// <summary>Number of regular tiles; vertex-edited tiles are stored separately.</summary>
    public int GetTileCount() => Call(TileMapNodeNames.GetTileCount).AsInt32();

    /// <summary>True if a regular tile exists for tileKey.</summary>
    public bool HasTile(long tileKey) => Call(TileMapNodeNames.HasTile, tileKey).AsBool();

    /// <summary>The tile stored at tileKey, or null.</summary>
    public PlacedTileInfo? GetTileInfoFromKey(long tileKey) => PlacedTileInfo.From(Call(TileMapNodeNames.GetTileInfoFromKey, tileKey));

    /// <summary>Removes all regular tile storage. No undo.</summary>
    public void ClearAllTiles() => Call(TileMapNodeNames.ClearAllTiles);

    // --- Placement ---

    /// <summary>
    /// Places a tile in the grid cell containing worldPos; uvRect is in atlas pixels (see <see cref="AtlasCoordToUvRect"/>).
    /// A tileInfo supplies the other attributes and is copied; null uses the node's current settings.
    /// </summary>
    public bool PlaceTile(Vector3 worldPos, Rect2 uvRect, int orientation = 0, PlacedTileInfo? tileInfo = null)
        => GetRuntimeApi().Call(ApiNames.PlaceTile, worldPos, uvRect, orientation, Arg(tileInfo?.Native)).AsBool();

    /// <summary>Erases the tile at worldPos with that exact orientation; use <see cref="FindTile"/> when it is unknown.</summary>
    public bool EraseTile(Vector3 worldPos, int orientation = 0)
        => GetRuntimeApi().Call(ApiNames.EraseTile, worldPos, orientation).AsBool();

    /// <summary>
    /// Places a size.X by size.Y rectangle. anchor: "origin" (default) or "center"; overwrite false skips occupied cells;
    /// tileTemplate is copied per cell. Returns placed / skipped counts and tile_keys.
    /// </summary>
    public Dictionary PlaceArea(Vector3 anchorWorld, int orientation, Vector2I size, Rect2 uvRect,
        string? anchor = null, bool? overwrite = null, PlacedTileInfo? tileTemplate = null)
        => GetRuntimeApi().Call(ApiNames.PlaceArea, anchorWorld, orientation, size, uvRect,
            AreaOptions(anchor, overwrite, tileTemplate)).AsGodotDictionary();

    /// <summary>Erases a rectangle with the same anchor rules as <see cref="PlaceArea"/>. Returns erased / skipped counts and tile_keys.</summary>
    public Dictionary EraseArea(Vector3 anchorWorld, int orientation, Vector2I size, string? anchor = null)
        => GetRuntimeApi().Call(ApiNames.EraseArea, anchorWorld, orientation, size, AreaOptions(anchor, null, null)).AsGodotDictionary();

    static Variant AreaOptions(string? anchor, bool? overwrite, PlacedTileInfo? tileTemplate)
    {
        if (anchor is null && overwrite is null && tileTemplate is null)
            return default;
        var options = (RefCounted)ClassDB.Instantiate(AreaNames.Class).AsGodotObject();
        if (anchor is not null)
            options.Set(AreaNames.Anchor, anchor);
        if (overwrite is not null)
            options.Set(AreaNames.Overwrite, overwrite.Value);
        if (tileTemplate is not null)
            options.Set(AreaNames.TileInfo, tileTemplate.Native);
        return options;
    }

    // --- Queries ---

    /// <summary>
    /// The tile at worldPos, or null. <see cref="AnyOrientation"/> searches the base orientations;
    /// toleranceCells widens the search in whole cells.
    /// </summary>
    public PlacedTileInfo? FindTile(Vector3 worldPos, int orientation = AnyOrientation, int toleranceCells = 0)
        => PlacedTileInfo.From(GetRuntimeApi().Call(ApiNames.FindTile, worldPos, orientation, toleranceCells));

    /// <summary>The first tile hit by a world-space ray, or null.</summary>
    public PlacedTileInfo? GetFirstTileFromRaycast(Vector3 rayOrigin, Vector3 rayDir, double maxDistance = double.PositiveInfinity)
        => PlacedTileInfo.From(GetRuntimeApi().Call(ApiNames.GetFirstTileFromRaycast, rayOrigin, rayDir, maxDistance));

    /// <summary>The whole grid cell containing worldPos.</summary>
    public Vector3 WorldToGridSnapped(Vector3 worldPos, int orientation = AnyOrientation)
        => GetRuntimeApi().Call(ApiNames.WorldToGridSnapped, worldPos, orientation).AsVector3();

    /// <summary>The world placement position of a grid cell for that orientation.</summary>
    public Vector3 GridToWorldSnapped(Vector3 snappedGridPos, int orientation = AnyOrientation)
        => GetRuntimeApi().Call(ApiNames.GridToWorldSnapped, snappedGridPos, orientation).AsVector3();

    /// <summary>Runtime diagnostics, plus per-orientation lookup info when worldPos is given.</summary>
    public Dictionary GetDebugInfo(Vector3? worldPos = null)
        => GetRuntimeApi().Call(ApiNames.GetDebugInfo, worldPos is null ? default(Variant) : worldPos.Value).AsGodotDictionary();

    // --- Highlights ---

    /// <summary>Highlights the tile at worldPos; returns true if one was found.</summary>
    public bool HighlightTile(Vector3 worldPos, int orientation = AnyOrientation)
        => GetRuntimeApi().Call(ApiNames.HighlightTile, worldPos, orientation).AsBool();

    /// <summary>Highlights the cells of a rectangle (same anchor rules as <see cref="PlaceArea"/>); returns the number of keys highlighted.</summary>
    public int HighlightArea(Vector3 anchorWorld, int orientation, Vector2I size, string? anchor = null)
        => GetRuntimeApi().Call(ApiNames.HighlightArea, anchorWorld, orientation, size, AreaOptions(anchor, null, null)).AsInt32();

    /// <summary>Highlights the given tile keys.</summary>
    public void HighlightTiles(long[] tileKeys) => Call(TileMapNodeNames.HighlightTiles, tileKeys);

    /// <summary>Clears all tile highlights.</summary>
    public void ClearHighlights() => Call(TileMapNodeNames.ClearHighlights);

    // --- Collision ---

    /// <summary>
    /// Rebakes collision for the region containing tileInfo; alphaAware ignores transparent pixels.
    /// Returns a request id; the result arrives through <see cref="BakeCompleted"/> or <see cref="BakeFailed"/>.
    /// </summary>
    public int SetCollisionForRegion(PlacedTileInfo tileInfo, bool alphaAware = false, bool backfaceCollision = false)
        => GetRuntimeApi().Call(ApiNames.SetCollisionForRegion, tileInfo.Native, alphaAware, backfaceCollision).AsInt32();

    /// <summary>Raised when a region bake finishes: region key, request id, and the attached collision shape (null if the region became empty).</summary>
    public event Action<Vector3I, long, Variant> BakeCompleted
    {
        add => GetRuntimeApi().Connect(ApiNames.BakeCompleted, Callable.From(value));
        remove => GetRuntimeApi().Disconnect(ApiNames.BakeCompleted, Callable.From(value));
    }

    /// <summary>Raised when a region bake cannot complete: region key, request id, reason.</summary>
    public event Action<Vector3I, long, string> BakeFailed
    {
        add => GetRuntimeApi().Connect(ApiNames.BakeFailed, Callable.From(value));
        remove => GetRuntimeApi().Disconnect(ApiNames.BakeFailed, Callable.From(value));
    }

    // --- TileSet data ---

    /// <summary>The TileData of the tile's atlas cell (terrain, custom data), or null for freeform UVs.</summary>
    public TileData? GetTileDataFromKey(long tileKey) => Obj<TileData>(GetRuntimeApi().Call(ApiNames.GetTileDataFromKey, tileKey));

    /// <summary>The TileSet used by this tile map, or null.</summary>
    public TileSet? GetTileset() => Obj<TileSet>(GetRuntimeApi().Call(ApiNames.GetTileset));

    /// <summary>Converts a TileSet atlas coordinate to the pixel UV rect used for placement; sourceId -1 uses the active source.</summary>
    public Rect2 AtlasCoordToUvRect(Vector2I atlasCoords, int sourceId = -1)
        => GetRuntimeApi().Call(ApiNames.AtlasCoordToUvRect, atlasCoords, sourceId).AsRect2();

    /// <summary>The tile's VariantTile custom-data atlas coordinate, or (-1, -1).</summary>
    public Vector2I GetVariantTileData(long tileKey) => GetRuntimeApi().Call(ApiNames.GetVariantTileData, tileKey).AsVector2I();

    /// <summary>The atlas coordinates in the tile's CollectionTiles custom data; empty if none.</summary>
    public Vector2[] GetCollectionTileData(long tileKey) => GetRuntimeApi().Call(ApiNames.GetCollectionTileData, tileKey).AsVector2Array();

    // --- Texture swaps ---

    /// <summary>Switches a placed tile to another atlas cell: its VariantTile target when useDefaultDataVariant, otherwise customAtlasCoords.</summary>
    public bool SwapTileTexture(PlacedTileInfo tileInfo, bool useDefaultDataVariant = true, Vector2I? customAtlasCoords = null)
        => GetRuntimeApi().Call(ApiNames.SwapTileTexture, tileInfo.Native, useDefaultDataVariant,
            customAtlasCoords ?? new Vector2I(-1, -1)).AsBool();

    /// <summary>Swaps every tile in the tile's CollectionTiles group; followChain repeats it, waiting stepChangeTime seconds per step.</summary>
    public bool SwapTileCollectionTexture(PlacedTileInfo tileInfo, bool followChain = false, int maxChainSteps = -1, double stepChangeTime = 1.5)
        => GetRuntimeApi().Call(ApiNames.SwapTileCollectionTexture, tileInfo.Native, followChain, maxChainSteps, stepChangeTime).AsBool();

    // --- Animated groups ---

    /// <summary>Frame-zero atlas coordinates of the tile's AnimatedGroup; empty if none.</summary>
    public Vector2[] GetAnimationGroupTileData(PlacedTileInfo tileInfo)
        => GetRuntimeApi().Call(ApiNames.GetAnimationGroupTileData, tileInfo.Native).AsVector2Array();

    /// <summary>Tile keys of the placed members of the tile's AnimatedGroup.</summary>
    public long[] GetAnimatedGroupTileKeys(PlacedTileInfo tileInfo)
        => GetRuntimeApi().Call(ApiNames.GetAnimatedGroupTileKeys, tileInfo.Native).AsInt64Array();

    /// <summary>Playback state of the tile's animated group: valid, current_frame, effective_speed, paused, total_frames, tile_keys.</summary>
    public Dictionary GetAnimatedGroupPlaybackState(PlacedTileInfo tileInfo)
        => GetRuntimeApi().Call(ApiNames.GetAnimatedGroupPlaybackState, tileInfo.Native).AsGodotDictionary();

    /// <summary>Freezes the tile's animated group on its current frame.</summary>
    public bool PauseAnimatedGroup(PlacedTileInfo tileInfo) => GetRuntimeApi().Call(ApiNames.PauseAnimatedGroup, tileInfo.Native).AsBool();

    /// <summary>Resumes the tile's animated group from the held frame.</summary>
    public bool ResumeAnimatedGroup(PlacedTileInfo tileInfo) => GetRuntimeApi().Call(ApiNames.ResumeAnimatedGroup, tileInfo.Native).AsBool();

    /// <summary>Sets the group's runtime speed (0-255 FPS; 0 pauses). The authored speed is unchanged.</summary>
    public bool SetAnimatedGroupSpeed(PlacedTileInfo tileInfo, double fps)
        => GetRuntimeApi().Call(ApiNames.SetAnimatedGroupSpeed, tileInfo.Native, fps).AsBool();

    /// <summary>Shows a zero-based frame of the group; keepPlaying continues from it, otherwise the frame is held.</summary>
    public bool SetAnimatedGroupFrame(PlacedTileInfo tileInfo, int frame, bool keepPlaying = false)
        => GetRuntimeApi().Call(ApiNames.SetAnimatedGroupFrame, tileInfo.Native, frame, keepPlaying).AsBool();
}
