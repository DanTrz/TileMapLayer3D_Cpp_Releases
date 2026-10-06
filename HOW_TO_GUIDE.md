# TileMapLayer3D How-To Guide

TileMapLayer3D is a Godot editor plugin for building 3D, grid-based levels from 2D tilesheets and Godot `TileSet` resources. It is inspired by Crocotile-style tile painting, but it works directly inside the Godot 3D editor.

Use it to build entire levels, or to block out rooms, floors, walls, slopes, ramps, stairs, platforms, terrain, pixel-art 3D environments, or runtime-interactive tile worlds without leaving Godot.

> **This guide covers the C++ / GDExtension edition (2.x).** The node is called **`TileMapLayer3d_Cpp`** and the plugin is listed as **TileMapLayer3D (C++)**. The GDScript plugin (1.x) is no longer supported. If you have 1.x scenes, read the **[Migration Guide](MIGRATION_GUIDE.md)** first and back up your project.

## Contents

1. [Basic Concepts](#1-basic-concepts)
2. [Installation and Setup](#2-installation-and-setup)
3. [Main Toolbar and Navigation](#3-main-toolbar-and-navigation)
4. [Manual Mode](#4-manual-mode)
5. [Tile Mesh Types](#5-tile-mesh-types)
6. [The TileSet Resource and Custom Data](#6-the-tileset-resource-and-custom-data)
7. [AutoTile Mode](#7-autotile-mode)
8. [Smart Operations Mode](#8-smart-operations-mode)
9. [Sculpt Mode](#9-sculpt-mode)
10. [Animated Tiles](#10-animated-tiles)
11. [Vertex Edit Mode](#11-vertex-edit-mode)
12. [Scatter Mode](#12-scatter-mode)
13. [Settings Mode: Collision, Baking and Rendering](#13-settings-mode-collision-baking-and-rendering)
14. [Runtime API](#14-runtime-api)
15. [Key Shortcuts Reference](#15-key-shortcuts-reference)
16. [Limits and Performance Notes](#16-limits-and-performance-notes)
17. [Troubleshooting](#17-troubleshooting)
18. [Migrating from the GDScript Version (1.x)](#18-migrating-from-the-gdscript-version-1x)

---

## 1. Basic Concepts

You select one tile, or a group of tiles, and paint them into the 3D viewport. It works like Godot's built-in `TileMapLayer` (2D), but in 3D.

Key elements:

| Object/Element | Where it appears | What you use it for |
| --- | --- | --- |
| `TileMapLayer3d_Cpp` node | Scene tree | The main node. It owns the placed tiles and runs all plugin operations. Use several nodes to create separate layers or zones in your levels. |
| Main toolbar | Left side of the 3D viewport | Turns tiling **On**, selects the active mode, and sets **Grid Snap** and **Cursor Step**. |
| Context toolbar | Bottom of the 3D viewport | Shows the controls for the current mode. |
| **TileMapLayer3D_CPP** bottom panel | Godot's bottom panel | Shows the details for each mode: picking tiles, AutoTile terrains, animation definitions, patterns, scatter items and settings. |
| Inspector | Godot's Inspector | Shows the node's two resources, `tile_map_data` and `settings`, plus a few node-level options (Decal Mode, Debug). |

Each `TileMapLayer3d_Cpp` node owns two resources:

| Resource | Class | What it stores |
| --- | --- | --- |
| `tile_map_data` | `TML3D_TileMapLayerData` | The placed tiles, the `TileSet`, the pattern library and the scatter items and instances. |
| `settings` | `TML3D_TileMapLayerSettings` | Grid size, texture filter, collision layer/mask, render priority, animation definitions and the editor tool state (current mode, mesh type, brush, and so on). |

Both can stay embedded in the scene, or you can save them as external `.tres` / `.res` files from the Inspector (useful for large maps, to keep the `.tscn` small).

<img width="480" height="360" alt="Main toolbar modes" src="https://github.com/user-attachments/assets/200fd05a-5cdb-4e22-a7ff-7fc09926d9a0" />

*Main toolbar (screenshot from 1.x). Version 2.x adds the **Scatter** mode and the **Grid Snap** / **Cursor Step** dropdowns at the bottom of the toolbar.*

## 2. Installation and Setup

### Install and enable the plugin

1. Download the repository and copy `addons/tilemap_layer_3d_cpp` into your project's `res://addons/` folder.
2. Open the project in Godot 4.5 or newer. If the editor was already open, restart it so the native library loads.
3. Enable **TileMapLayer3D (C++)** via `Project -> Project Settings -> Plugins`.
4. Add a `TileMapLayer3d_Cpp` node under a `Node3D` in your scene.
5. Select the node. The toolbars and the **TileMapLayer3D_CPP** bottom panel appear.
6. Turn on the **On** toggle at the top of the main toolbar before painting.

The plugin UI is shown only while a `TileMapLayer3d_Cpp` node is selected.

> **Updating the addon:** close Godot first, replace the `addons/tilemap_layer_3d_cpp` folder, then reopen the project. On Windows the library file is locked while the editor is running.

### Supported platforms

Prebuilt debug and release libraries are included for **Windows x86_64**, **Linux x86_64**, **macOS (universal)** and **Web (wasm32, no threads)**.

## 3. Main Toolbar and Navigation

### On toggle

**On** enables painting for the selected node. While it is off, mouse input in the viewport goes to Godot as usual (useful for right-mouse freelook).

### Modes

The main toolbar lives on the left of the 3D viewport. Only one mode is active at a time.

| Mode | Use it for |
| --- | --- |
| Manual | Paint selected tiles directly in 3D. Also where you load your texture or TileSet and set the tile size. |
| AutoTile | Paint terrain that automatically chooses the right atlas tile from Godot terrain data. |
| Smart Operations | Select, replace or delete existing tiles; build ramps and stairs; save and stamp patterns. |
| Animated Tiles | Define and paint shader-driven animated tiles. |
| Sculpt | Brush-paint footprints and extrude them into volumes. |
| Vertex Edit | Convert flat square tiles into editable quads with draggable corners. |
| Scatter | Paint meshes (grass, rocks, props) onto the grid or onto collision surfaces. |
| Settings | Grid, collision, baking, export, texture filtering and other utilities. |

Changing modes clears the current tile selection and resets mode-specific state (sculpt strokes, smart fills, vertex selections). This is intentional: each mode has its own workflow.

### Grid Snap and Cursor Step

The two dropdowns at the bottom of the main toolbar are always visible:

| Dropdown | Options | What it controls |
| --- | --- | --- |
| Grid Snap | `1.0`, `0.5`, `0.25` | How finely tile positions snap when you place tiles. |
| Cursor Step | `0.25`, `0.5`, `1.0`, `2.0` | How far the 3D cursor moves per `W`/`A`/`S`/`D` step. |

Both values are in grid units and are saved per node. `0.25` is the minimum because of the coordinate system's precision.

## 4. Manual Mode

Manual mode lets you paint freely. It is also where you set up your texture, TileSet and tile size.

### Load a texture or TileSet

1. Select your `TileMapLayer3d_Cpp` node.
2. Click **Manual** mode in the main toolbar.
3. Open the **TileMapLayer3D_CPP** bottom panel.
4. Click **Load Texture** to choose an image (`.png`, `.jpg`, `.jpeg`).
5. Set **Tile Set Size** to the atlas cell size, for example `32 x 32`.
6. Set **picker_tile_size** if you want the picker grid to differ from the TileSet cell size.
7. Click a tile in the texture preview.
8. Turn **On** in the main toolbar.
9. Move the mouse in the 3D viewport and left-click to paint.

| Button | What it does |
| --- | --- |
| **Load Texture** | Creates a new `TileSet` from the image. If the image was imported with VRAM compression, the plugin switches its import setting to Lossless and reimports it automatically. |
| **Load TileSet** | Loads an existing `.tres` or `.res` TileSet. |
| **Save TileSet** | Saves the current TileSet as a reusable resource (`.res` if you don't type an extension). |
| **Tileset Editor** | Opens Godot's native TileSet editor for terrains, custom data, physics and more. |

> Loading a new texture while the current TileSet has AutoTile terrains shows a **Clear Auto-Tile TileSet?** warning. Continuing removes the terrain configuration; tiles you already placed stay, but they won't auto-update anymore.

### Texture size settings

There are two size controls that sound similar but do different jobs:

| Setting | Meaning |
| --- | --- |
| **Tile Set Size** | The real Godot TileSet atlas cell size. |
| **picker_tile_size** | The grid used when you select tiles in the texture preview. |

Usually they should match. Keep them different only when you intentionally want to select freeform regions without changing the TileSet cell size. Tiles painted from a picker cell that doesn't line up with a TileSet cell are stored as plain UVs. They have no atlas binding, so TileSet custom data and `get_tile_data_from_key()` won't work for them.

### Selecting tiles in the texture preview

| Action | Result |
| --- | --- |
| Left click | Select one tile |
| Left drag | Select a rectangle of tiles (up to 48 cells), painted as one multi-tile stamp |
| Mouse wheel / zoom slider | Zoom the preview |
| Middle mouse drag | Pan the preview |

### Paint and erase controls

| Action | Result |
| --- | --- |
| Left click | Paint one tile |
| Left click and drag | Paint a stroke |
| Right click | Erase one tile |
| Right click and drag | Erase a stroke |
| Shift + left drag | Fill a rectangular area |
| Shift + right drag | Erase a rectangular area |
| Esc during area selection | Cancel the area operation |

- A whole drag, from press to release, is **one undo step**.
- Fast drags fill the cells you skipped over, so strokes have no holes.
- Area fill has a safety limit of **10,000 tiles**, and is not available in Animated Tiles mode.
- Middle mouse, the mouse wheel and Alt + click are left to Godot for camera navigation. Turn **On** off to use right-mouse freelook.
- Placing a tile on a cell that already holds a tile with the same orientation replaces it.
- A cell outside the supported coordinate range shows a red "blocked" highlight and nothing is placed.

### Navigating the 3D grid and virtual cursor for tile placement

TileMapLayer3D uses a 3D cursor and an active placement plane. Think of the cursor as the point you are working from, and the active plane as the floor, wall or ceiling grid that your mouse is currently painting on.

<img width="640" height="360" alt="3dGrid" src="https://github.com/user-attachments/assets/98d8eacd-d211-4d4b-bca5-5e91d8016f6c" />

The editor camera is part of this workflow. TileMapLayer3D looks at the direction of the editor camera and picks the grid plane that best matches your view. If you look down at the scene, you work on the floor grid. If you rotate the camera toward a wall, placement shifts to that wall's grid. This lets you paint floors, walls and ceilings without a separate wall/floor button.

Use `W`/`A`/`S`/`D` to move the 3D cursor relative to the current editor camera view.

| Key | Result |
| --- | --- |
| W | Move the cursor forward relative to the editor camera |
| A | Move the cursor left relative to the editor camera |
| S | Move the cursor backward relative to the editor camera |
| D | Move the cursor right relative to the editor camera |
| Shift + W | Move the cursor up relative to the editor camera |
| Shift + S | Move the cursor down relative to the editor camera |

- Movement snaps to the nearest world axis, so the cursor stays aligned to the grid instead of drifting.
- Each tap moves one **Cursor Step**. Holding a key repeats the move and smoothly accelerates to 4x speed over two seconds.
- The base speed is **Cursor Speed** in Settings mode (1–60 steps per second, default 30).
- Cursor keys are ignored while Ctrl, Alt or Meta is held.

Use this pattern when building in 3D:

1. Rotate the editor camera toward the floor, wall or ceiling you want to work on.
2. Move the cursor with `W`/`A`/`S`/`D` or `Shift + W`/`S` until it is where you want to work from.
3. Paint, erase, fill, sculpt or select, depending on your current mode.

#### FastMove

Hold **`Shift + Space`** and left-click any tile in the viewport. The 3D cursor and its grid jump to that tile, so you can continue painting from there. This is much faster than stepping the cursor across a large scene.

FastMove only accepts tiles that lie on the plane you are currently facing (or the back face of that plane). Releasing `Shift` or `Space` ends FastMove.

> **Grid snapping:** the tool is designed around full-grid (`1.0`) snapping. Finer snapping (`0.5`, `0.25`) is there for precise placement. If a tool behaves unexpectedly at a finer snap, switch back to `1.0`.

### Manual Mode - Context Toolbar Options

Some options are only available for specific mesh types.

| Option | What it does |
| --- | --- |
| Rotate counter-clockwise | Rotates the tile 90 degrees. Shortcut: `Q`. |
| Rotate clockwise | Rotates the tile 90 degrees the other way. Shortcut: `E`. |
| Freeze UV (pin icon) | Keeps the texture direction fixed while you rotate the tile with `Q`/`E`. See [Texture rotation, Mirror and Freeze UV](#texture-rotation-mirror-and-freeze-uv). |
| Tilt | Cycles the tile through its tilted orientations, for example 45° ramps. Shortcut: `R`, or `Shift + R` to cycle backward. |
| Reset orientation | Returns the tile to flat, with rotation, mirror and texture rotation reset. Shortcut: `T`. |
| Mirror | Mirrors the tile texture horizontally, without changing the geometry. Shortcut: `F`. |
| Texture rotation (`UV 0°` button) | Turns the texture inside the tile by 90°. Shortcut: `G`, or `Shift + G` to turn the other way. Disabled while Freeze UV is on. |
| Status readout | Shows what you are about to paint, for example `90° T1 M UV180` = rotated 90°, tilt step 1, mirrored, texture turned 180°. |
| Create SpriteMesh | Creates a `SpriteMesh` node from the selected tiles at the cursor position: a mesh with real depth, cut from the texture's pixels. These are expensive to render and are not aligned to the grid. |
| Mesh Type | Chooses the 3D shape used when placing new tiles. See [Tile Mesh Types](#5-tile-mesh-types). |
| Double Flat Tile | Also places the back face of every new flat tile. See [Double Flat Tile](#double-flat-tile-back-faces). |
| UV Only | Repaints the texture of existing tiles instead of placing new ones. See [UV Only](#uv-only-painting). |
| Arc | Adjusts the arch angle for arch mesh types (`0.1`–`0.5`). Only appears when an arch mesh type is selected. |
| Box/Prism options: Depth | How deep Box, Prism and AutoShape tiles extend (`0.05`–`1.0`). |
| Box/Prism options: Texture Repeat | Repeats the texture across all Box/Prism faces instead of stretching it. The side faces are mapped in proportion to the tile's Depth, so a thin box no longer squashes the full texture onto its short side. |
| Box/Prism options: Depth Inwards | Makes the depth grow into the painted surface instead of outward from it. |
| World / Grid position | Shows the current mouse target in world and grid coordinates. |

The rotation, tilt, mirror and texture-rotation controls are available in Manual mode only. Their shortcuts do nothing in AutoTile, Animated Tiles and Vertex Edit modes.

### Texture rotation, Mirror and Freeze UV

A tile's texture direction comes from three things:

- **Rotation** (`Q`/`E`) turns the whole tile, geometry and texture together.
- **Mirror** (`F`) flips the texture horizontally inside the tile.
- **Texture rotation** (`G`) turns only the texture inside the tile, in 90° steps.

**Freeze UV** is a placement-time option. When it is on, rotating with `Q`/`E` keeps the texture pointing the same way, so only the shape turns. Toggling it never changes tiles you have already placed. Turning Freeze UV on also resets Texture rotation to 0°, and the Texture rotation button stays disabled until you turn Freeze UV off again.

### Double Flat Tile (back faces)

With **Double Flat Tile** checked, every new flat tile (flat squares, triangles and arch pieces) is placed together with its back face, so the surface is visible from both sides. While it is enabled, erasing a face also erases its back face.

Box, Prism and AutoShape tiles are skipped because they already have volume. The option is available in Manual, AutoTile, Animated Tiles and Sculpt modes.

### UV Only painting

**UV Only** repaints the texture of tiles that already exist, without touching their geometry. Mesh type, rotation, depth and orientation stay exactly as they were.

- Empty cells are skipped; no new tiles are created.
- It works with single clicks, drag strokes and Shift area fill.
- In **Manual** mode, the tile selected in the texture preview is applied. Painting over an AutoTile tile turns it into a manual tile, and its neighbours re-resolve.
- In **AutoTile** mode, the existing tile is marked with the active terrain and the AutoTile solver resolves its texture, including the neighbouring tiles. Right-click removes the terrain mark instead of deleting the tile.
- In Manual mode, right-click still erases tiles normally.

> Limitations: repainting an animated tile makes it static. AutoShape tiles regenerate their silhouette from the new atlas tile, because their geometry comes from the texture's alpha. Vertex-edited tiles and Smart Fill ramp/stair pieces are not repainted.

## 5. Tile Mesh Types

In Manual, AutoTile and Animated Tiles mode you can choose the mesh type for new tiles.

| Mesh type | Use it for | Available in |
| --- | --- | --- |
| `FLAT_SQUARE` | A normal flat square tile for floors, walls and most simple painting | All painting modes |
| `FLAT_TRIANGULE` | A flat triangle tile for diagonal cuts and triangular surface pieces | Manual, AutoTile |
| `BOX_MESH` | A box with depth, for blocks, ledges and thick wall pieces | Manual, AutoTile, Animated Tiles |
| `PRISM_MESH` | A prism with depth, for sloped or wedge-like pieces | Manual, AutoTile, Animated Tiles |
| `AUTOSHAPE_MESH` | A 3D mesh extruded from the tile's non-transparent pixels | Manual, AutoTile, Animated Tiles |
| `FLAT_ARCH` and variants | Curved arch pieces using the Arc setting (**experimental**) | Manual, AutoTile |

- Smart Select's **Replace Mesh Type** can convert existing tiles to Flat Square, Flat Triangle, Box, Prism or AutoShape.
- Vertex Edit only converts Flat Square tiles.

### Arch tiles (experimental)

Arch mesh types are hidden by default. To use them, go to **Settings** mode and enable both:

- **Enable Arch tiles (Experimental)**: turns on the arch features, including the **Arched Rect** brush in Sculpt mode.
- **Show Arch Tiles (Manual Mode)**: adds the arch mesh types to the Mesh Type dropdown.

Arch tiles are experimental and may have breaking changes in future versions. Don't rely on them in production yet.

### AutoShape Mesh

`AUTOSHAPE_MESH` builds an extruded 3D mesh from the non-transparent silhouette of the selected atlas tile. Use it for pixel-art props, foliage, fences or signs that should have real thickness.

- The plugin reads the tile's alpha channel, generates and caches a mesh for that atlas region, and renders it in regional MultiMesh chunks.
- **Depth**, **Texture Repeat** and **Depth Inwards** work as for Box and Prism.
- Fully opaque tiles automatically use a Box mesh instead, because their silhouette is a square.
- **Freeze UV is always off** for AutoShape. Texture rotation (`G`) turns the mesh as well, because the geometry is cut from the texture.
- **Mirror is not supported for non-solid AutoShape tiles.** The mesh is generated from the original, unmirrored silhouette, so mirrored asymmetric tiles no longer line up with their geometry. Fully opaque tiles (Box fallback) are unaffected.

### Decal Mode (rendering tiles on top of another layer)

Decal Mode lets one `TileMapLayer3d_Cpp` node act as an overlay on top of another. Use it for details such as cracks, stains, posters or moss painted over a base layer without Z-fighting.

Enable it in the Inspector on the overlay node: **`enable_decal_mode`**.

- Flat tiles on that node get a small extra offset along their facing direction, so they sit just in front of tiles painted at the same position on the base layer.
- Shadow casting is turned off for that node.
- Paint the overlay tiles on the decal node exactly as you would in Manual mode.
- If overlays still draw behind the base layer, raise **render_priority** in the decal node's settings (`settings -> Rendering`) above the base layer's value.

Decal Mode only affects flat tiles (flat squares, triangles and arch pieces).

## 6. The TileSet Resource and Custom Data

TileMapLayer3D uses one unified Godot `TileSet`, the same resource used by Godot's built-in `TileMapLayer` (2D) node. Not every TileSet option applies to this plugin, but terrain configuration, AutoTile setup and custom data work exactly the same way. Godot's documentation is the right reference: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html

The same TileSet provides:

- AutoTile terrain data (used by AutoTile mode).
- Godot `TileData` lookups at runtime, for atlas, terrain and custom data. See https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html
- The plugin's custom data layers, described below.

Custom data is extra information you attach to individual tiles inside the `TileSet`:

- A `TileSet` can define custom data layers, which are named fields such as `VariantTile` or `Collision`.
- A `TileSetAtlasSource` is the atlas image inside the TileSet. Each atlas tile stores its own values for those layers.
- TileMapLayer3D reads the values from the placed tile's atlas coordinate, so the same painted tile can carry gameplay meaning at runtime.
- You edit the values in Godot's TileSet editor (**Tileset Editor** button). The plugin uses them while painting, querying, swapping and generating collision.

### Custom data layers created by the plugin

When you load a texture or a TileSet, TileMapLayer3D adds any of these layers that are missing:

| Layer | Type | Default | Used for |
| --- | --- | --- | --- |
| `VariantTile` | `Vector2i` | `Vector2i(-1, -1)` | The atlas coordinate of this tile's alternate version, for example a closed door tile pointing to its open door tile. Used by `swap_tile_texture()`. |
| `CollectionTiles` | `PackedVector2Array` | empty | The atlas coordinates of all tiles that together form the same multi-tile object (door, bridge, switch, destructible group). Used by `swap_tile_collection_texture()`. |
| `Collision` | `bool` | `true` | Set to `false` for tiles that collision generation should skip, such as grass or decoration. |
| `Animated` | `bool` | `false` | Set automatically on every cell of an animation when you create an animation definition. |
| `AnimatedGroup` | `PackedVector2Array` | empty | Set automatically when you create an animation definition. It lists the frame-zero cells of the whole animated object, so the runtime API can control the group. |

#### VariantTile

Set `VariantTile` to the atlas coordinates of the tile this tile should swap into. Think of it as the "alternate version" of a tile: the original is "Door Closed" and the `VariantTile` points to "Door Open".

At runtime, call `swap_tile_texture(tile_info)` to swap to the `VariantTile` target. See the [Runtime API](#14-runtime-api).

#### CollectionTiles

Set `CollectionTiles` to the list of atlas coordinates that form a related group. This tells the plugin that a tile is a member of a larger object. The runtime collection swap uses the atlas-coordinate offsets to find the matching placed tiles in the world.

Each tile in the collection should also have a valid `VariantTile` if it needs to change.

#### Collision

Use `Collision = false` for tiles that collision generation should ignore. Both **Create Collision** in the editor and `set_collision_for_region()` at runtime respect it. The visual **Bake Mesh to Scene** includes every tile regardless.

### Example: a door using `VariantTile`, `CollectionTiles` and `Collision`

1. In the TileSet editor, set each closed door tile's `VariantTile` to the atlas coordinate of its open door version.
2. For every tile that belongs to the door, set `CollectionTiles` to the atlas coordinates that make up the whole door.
3. When the player interacts with the door, use a raycast to find one placed door tile.
4. Call `tile_map.runtime_api.swap_tile_collection_texture(tile_info)`. TileMapLayer3D uses `CollectionTiles` to find the other placed tiles of the same door, and each tile's `VariantTile` to swap it to its alternate version.
5. If the open and closed door tiles have different `Collision` values, rebuild collision for the affected region with `set_collision_for_region(tile_info)`.

The demo scene includes a working version of this setup: see `demo_scene/tile_detector_area_3d.gd` and `demo_scene/door_body.gd`.

Save your TileSet resource when you are done editing it.

## 7. AutoTile Mode

AutoTile mode paints **terrain** instead of individual tiles. It uses Godot's native TileSet terrain system and places the resolved tile in 3D.

### Set up AutoTile terrain

1. In **Manual** mode, load a texture or TileSet first.
2. Switch to **AutoTile** mode.
3. Type a terrain name, pick a color and click **Add Terrain**. The first terrain also creates terrain set 0 in **Match Corners and Sides** mode.
4. Click **Tileset Editor** to open Godot's TileSet editor.
5. Paint your terrain peering bits with Godot's built-in terrain tools.

> For full terrain coverage, use a complete Godot terrain layout such as the 47-tile 3x3 template. This is exactly the same process as setting up auto-tiling for Godot's built-in `TileMapLayer` (2D), so any Godot tutorial about terrains and TileSet setup applies.

Step-by-step guide with screenshots: **[SETTING_UP_AUTOTILE.md](SETTING_UP_AUTOTILE.md)**

### Paint with AutoTile

1. Select a terrain in the **Select Terrain** list.
2. Paint, erase and area-fill exactly as in Manual mode. The preview shows the terrain's color.

- **Mesh Type**, **Depth**, **Double Flat Tile** and **UV Only** are available. Rotation, tilt, mirror and texture rotation are reset when you enter AutoTile mode or pick a terrain, because the solver decides each tile's orientation.
- AutoTile works on the floor, the ceiling and the four walls. Tilted orientations are not supported.
- Multi-tile selections from the texture preview are ignored in AutoTile mode.
- AutoTile recalculates neighbouring tiles after every placement and erase, including manual painting, sculpting, Smart Operations, and undo/redo.
- If no terrain is selected, or the terrain has no tiles configured yet, nothing is painted.

## 8. Smart Operations Mode

Smart Operations works on tiles already placed in the 3D scene. Choose the main mode in the **Smart Mode** dropdown of the context toolbar:

- **Smart Select**: select existing tiles and operate on them.
- **Smart Fill**: build ramps and staircases between two existing tiles.
- **Patterns**: save a group of tiles and stamp copies of it.

### Smart Select

Smart Select lets the plugin detect and highlight tiles from your clicks, so you can change them in one go.

| Select type | What it selects |
| --- | --- |
| Single Pick | The clicked tile. Left-drag adds every tile the cursor passes over. |
| Connected UV | Connected neighbours on the same plane that use the same texture (UV) |
| Connected Neighbor | Connected neighbours on the same plane, regardless of texture |
| Connected Tile Type | Connected neighbours on the same plane with the exact same mesh type |
| Horizontal Loop | A horizontal band of tiles at the same grid height, turning corners across orientations (useful for a full wall ring or strip) |

Use it like this:

1. Switch to **Smart Operations** and choose **SMART SELECT**.
2. Choose a select type.
3. Left-click a tile in the viewport.
4. Use the operation buttons:
   - **Replace UV** swaps the selected tiles' texture to the tile currently selected in the texture preview, keeping position, orientation and mesh type. Replaced tiles leave their AutoTile terrain.
   - **Replace Mesh Type** changes the selected tiles to the **Target Type**, keeping their texture, position and orientation. For Box, Prism and AutoShape targets you can set **Depth**, **Texture Repeat** and **Depth Inwards**. Vertex-edited tiles are skipped.
   - **Delete** removes the selected tiles.
   - **Clear** clears the selection without changing tiles.

**Selection behaviour:**

- **Additive** (the **Add** toggle, or `Z`): when on, clicks add to the current selection across all select types. Clicking a tile that is already selected removes that group again. Changing the select type keeps the selection.
- Right-click, or clicking empty space, clears the selection.

#### Smart Select - Context Toolbar Options

| Option | What it does |
| --- | --- |
| Smart Mode | Switches between Smart Select, Smart Fill and Patterns. |
| Select Type | Single Pick, Connected UV, Connected Neighbor, Connected Tile Type or Horizontal Loop. |
| Add | Additive selection. Shortcut: `Z`. |
| Clear | Clears the selection without changing tiles. |
| Replace UV | Swaps the selected tiles' texture to the tile selected in the texture preview. |
| Delete | Deletes all selected tiles. |
| Replace Mesh Type | Changes the selected tiles' mesh type to the Target Type. |
| Target Type | The destination mesh type: Flat Square, Flat Triangle, Box, Prism or AutoShape. |
| Depth / Texture Repeat / Depth Inwards | Options for Box, Prism and AutoShape targets. |

### Smart Fill

Smart Fill creates new geometry between two tiles that already exist. It uses the tile currently selected in the texture preview.

| Fill type | What it builds |
| --- | --- |
| **FILL RAMP** | A sloped surface between the two tiles. |
| **FILL STAIRS** | A complete staircase between the two tiles: treads, risers, side panels and the fillers below them. |

Use it like this:

1. Choose **SMART FILL** in the Smart Mode dropdown, then a **Fill type**.
2. Select a tile in the texture preview.
3. Set **Width** and the other options.
4. Click an existing tile to set the **start** point. It is highlighted.
5. Move the mouse to preview the result, then click a different existing tile to set the **end** point. The ramp or staircase is placed as one undo step.
6. Right-click to cancel.

#### Smart Fill - Context Toolbar Options

| Option | What it does |
| --- | --- |
| Fill type | FILL RAMP or FILL STAIRS. |
| Width | How many tiles wide the result is (1–10). |
| Steps (stairs only) | **Auto** derives the step count from the length and height of the staircase. Uncheck **Auto** to set the total number of steps from the lower landing to the upper landing, in multiples of four. More steps make each riser shorter and each tread shallower. |
| Align | Builds the result centered on the start tile, or to its left or right. |
| Sides | Fills the two outer sides of the ramp or staircase down to the lower landing. |
| Freeze UV (stairs only, on by default) | Keeps the texture aligned with the working-plane grid in quarter turns; diagonal stairs use the nearest quarter turn. With it off, the texture follows the staircase. Either way, side panels and fillers stay aligned with each other. |

> Stair textures use the selected atlas tile with its default mapping, so treads and risers may look stretched depending on the staircase proportions. Ramp and stair pieces are placed off-grid with exact transforms; the stair step meshes are internal and are not offered in the Mesh Type menu.

### Patterns

Patterns is a reusable copy-and-stamp library for complete tile arrangements. A pattern can mix different textures, mesh types, orientations, ramp and stair pieces, and vertex-edited tiles.

1. Choose **PATTERNS** in the Smart Mode dropdown. The bottom panel shows the Patterns library.
2. Select the tiles you want to reuse. Selection works exactly like Smart Select, including the select types and **Add** (`Z`) to build a selection over several clicks.
3. Click **New** in the bottom panel to save the selection as a pattern. A card with a thumbnail appears.
4. To place it, click the pattern card. A preview follows the mouse; left-click to stamp a copy. You can stamp as many copies as you like.
5. Right-click, or click the selected card again, to stop placing.

- The pattern's reference point is the tile nearest the centre of the saved selection.
- Stamping replaces tiles that occupy the same cells and orientations. Each stamp is one undo step.
- AutoTile tiles inside a pattern re-resolve to fit where they land.
- Patterns are stored in the node's `tile_map_data`, so each node has its own library.
- Creating and deleting patterns is not undoable.
- Patterns are stamped exactly as saved; rotating a pattern is not supported yet.

## 9. Sculpt Mode

Sculpt mode is for quickly building volumes such as buildings, hills, pits and platforms. It works on the floor, the ceiling and the four walls: the working plane follows your camera like normal painting, and locks once you start drawing.

The workflow is:

1. Select the tile you want in the texture preview.
2. Choose the brush and brush options.
3. **Draw:** left-click and drag to paint the footprint. Release to finish the footprint.
4. **Extrude:** left-click *inside* the footprint and drag up or down to raise or lower the volume. Release to build it.
5. Right-click or `Esc` cancels the current sculpt operation.

Sculpting always places tiles with their texture locked to the plane (Freeze UV), and every sculpt operation is one undo step.

### Sculpt - Context Toolbar Options

| Option | What it does |
| --- | --- |
| Brush Type | **Diamond**, **Square**, **Erase** (removes the tiles inside the volume you draw and extrude) or **Arched Rect** (only when arch tiles are enabled in Settings). |
| Brush Size | Brush radius (1–4). |
| Draw Tiles: Top | Adds the top tiles to the volume. |
| Draw Tiles: Base | Adds the bottom/base tiles to the volume. |
| Flip Textures: Side / Top / Base | Mirrors the side, top or base tile textures horizontally, without changing geometry. |
| Double Flat Tile | Also places the back face of every flat tile. |
| Arch Angle | The arch angle used by the Arched Rect brush. |
| Box/Prism (Depth) + Depth | Square and Diamond brushes only. Builds the volume from inward-growing Box and Prism meshes with repeated textures, instead of flat tiles. The Flip Textures options are ignored. |

## 10. Animated Tiles

Animated Tiles are shader-driven UV animations: the tile's texture cycles through frames on the GPU. Animation works on **Flat Square**, **Box**, **Prism** and **AutoShape** tiles; the other mesh types are disabled in the Mesh Type dropdown while you are in this mode. The panel is labelled **Alpha Feature: Animated Tiles**.

This feature works with the concept of an **animation frame**. A frame is not a single tile; it is a region of your tileset that can span several tiles. You select the entire area of your animation in the texture preview, then tell the plugin how to subdivide it into frames using **Row** and **Col**.

For example, your tileset has a 4×4 tree texture that animates across 6 frames, organized into 3 columns and 2 rows:

<img width="600" height="300" alt="image" src="https://github.com/user-attachments/assets/391a0da4-357b-43f9-8aad-70a0992d7f1d" />

The settings would be **Col = 3**, **Row = 2**, **Frames = 6**. Each frame is a 4×4 block of tiles, and the animation cycles through these frames automatically.

How to use it:

1. Switch to **Animated Tiles** mode (your texture must already be loaded in Manual mode).
2. Select the full region in the texture preview that contains all animation frames.
3. Set **Row** and **Col** to define how the region is divided into frames.
4. Set **Frames** (the number of frames to play) and **Speed** (frames per second).
5. Type a display name and click **New** to save the animation definition.
6. Select it in the list. Its first frame is selected in the preview automatically.
7. Choose a mesh type and paint in the 3D viewport.

- Painting uses click and drag; area fill is not available in this mode. Rotation, tilt and mirror shortcuts are disabled here.
- New definitions support up to 255 frames and 255 columns.
- **Delete** removes a definition from the list. Tiles you already placed keep their animation.
- Creating a definition writes `Animated` and `AnimatedGroup` custom data into the TileSet and marks both the scene and the TileSet as modified. Save normally (`Ctrl+S`) to keep them.
- Animation definitions are stored in the node's `settings` resource.

Runtime playback control (pause, resume, speed, frame) is covered in the [Runtime API](#animated-group-playback). It is not available with the Compatibility renderer, which all Web exports use; there, animated tiles play at their authored speed.

## 11. Vertex Edit Mode

Vertex Edit converts flat square tiles into individually editable quads. Use it when a tile should become an organic, custom-shaped surface, such as a sloped roof or uneven ground. Only `FLAT_SQUARE` tiles can be converted.

Use Vertex Edit like this:

1. Paint one or more `FLAT_SQUARE` tiles.
2. Switch to **Vertex Edit** mode.
3. Left-click tiles to select them (they are highlighted). Click again to deselect.
4. Click **Convert** in the context toolbar.
5. Click a converted tile to select it for editing.
6. Drag the corner handles in the 3D viewport.
7. Release the mouse to commit the corner move.
8. Press `Delete`, or click the **Delete** button, to remove the selected tiles.
9. Right-click to clear the selection.

- Corner movement snaps to half-grid positions.
- Converting tiles and moving corners are undoable.
- Vertex tiles are stored separately from regular tiles. Each one is its own mesh, so they are much more expensive to render than regular tiles: use them for special shapes rather than thousands of repeated tiles. The plugin prints a warning once a node has 100 or more vertex tiles.
- Vertex tiles can be saved in Patterns.

<img width="600" height="300" alt="image" src="https://github.com/user-attachments/assets/e3dd0fd2-cc6d-40a9-bdc7-5fefc8951dff" />

## 12. Scatter Mode

Scatter mode paints meshes, such as grass, plants, rocks and props, alongside your tiles. Scatter objects are stored separately from tiles, but they use the same coordinate, grid and region systems and render efficiently through regional `RenderingServer` MultiMesh chunks.

### Scatter items

Each kind of object is a **Scatter Item** (`TML3D_ScatterItemDefinition`), managed in the **Scatter** tab of the bottom panel:

- **New** creates an item with a placeholder `QuadMesh` and opens it in the Inspector. Replace the mesh with your own.
- Click an item card to select it and edit it in the Inspector.
- The **Enabled** checkbox on each card decides whether the brush uses that item. All enabled items are mixed by the brush.
- The delete button on a card removes the item **and every placed instance of it**.
- **Clear All** removes every placed scatter instance (the items themselves stay).

Scatter item properties (Inspector):

| Property | What it does |
| --- | --- |
| `item_name`, `mesh`, `material_override` | What is placed. |
| `probability_weight` | How often this item is picked relative to the other enabled items. |
| `minimum_spacing`, `spacing_randomness` | Minimum distance between instances, and how much it varies. |
| `visual_offset` | Offset applied to each instance. |
| `align_to_surface_normal` | Tilts instances to match the surface. |
| `rotation_mode` | None, Random Around Normal, or Align Stroke. |
| `base_scale`, `minimum_scale`, `maximum_scale` | Instance scale and random scale range. |
| `shadow_casting_setting`, `visibility_range` | Rendering options. |
| `paint_enabled` | Same as the card's **Enabled** checkbox. |

### Painting scatter

| Option | What it does |
| --- | --- |
| Mode | **Paint** places and erases instances; **Scale** resizes existing instances. |
| Surface | **Grid** paints on the active grid plane, like tiles. **Collision** paints on physics surfaces, using **Col.Mask**. |
| Col.Mask | Physics collision mask used by the Collision surface. |
| Size | Brush radius. |
| Density | How densely instances are placed (placement attempts per square unit of brush area; `minimum_spacing` can reject some). |
| Str | Strength of the Scale mode. |

- **Paint mode:** left-click or drag to scatter the enabled items. Right-click or drag removes instances of the enabled items inside the brush.
- **Scale mode:** left-drag grows instances, `Shift` + left-drag or right-drag shrinks them, and `Ctrl` + left-drag resets their scale.
- Each stroke is one undo step.
- The **Collision** surface needs colliders to paint on. For tiles, run **Create Collision** in Settings mode first.
- Scatter instances are saved in the node's `tile_map_data`. **Clear all tiles** in Settings mode does not remove them; use **Clear All** in the Scatter tab.

## 13. Settings Mode: Collision, Baking and Rendering

The last button on the main toolbar is **Settings** mode. It shows the following groups in the bottom panel.

### Grid and Tiles

| Option | What it does |
| --- | --- |
| GridSize | World size of one grid cell (`0.1`–`2.0`). Changing it asks for confirmation, rebuilds all tiles at the new size and **clears collision shapes**; regenerate collision afterwards. |
| ShowGrid | Shows or hides the placement plane grids. |
| Cursor Speed | Base speed of the 3D cursor in steps per second (1–60). Holding a key accelerates to 4x. |
| Clear all tiles | Removes every tile from this node after a confirmation. **This cannot be undone.** Scatter instances are not removed. |
| Enable Arch tiles (Experimental) | Turns on the experimental arch features. |
| Show Arch Tiles (Manual Mode) | Adds arch mesh types to the Mesh Type dropdown. |

### Collision

| Option | What it does |
| --- | --- |
| Create Collision | Generates collision shapes for every region of the node, replacing any existing ones. Tiles whose `Collision` custom data is `false` are skipped. |
| AlphaAware | Uses alpha-aware collision generation (see below). |
| Backface Collision | Includes backfaces in the generated collision. |
| Save as external .res | Saves each region's collision shape as a `.res` file in a `<scene name>_SavedData` folder next to your scene, instead of embedding it in the `.tscn`. Save the scene at least once first. |
| Clear Collisions | Removes the generated collision shapes, including their external `.res` files for this node. |

Collision layer and mask are set in the Inspector: `settings -> Collision`.

### Export/Bake

| Option | What it does |
| --- | --- |
| Bake Mesh to Scene | Merges the node's tiles into a single `MeshInstance3D` named `<node name>_Baked`, added next to the node (undoable). Every tile is included, regardless of `Collision` custom data. |
| AlphaAware | Uses alpha-aware mesh baking (see below). |
| SpriteMeshes | Also merges the visible SpriteMesh nodes that are direct children of this node. |
| Create SpriteMesh | Creates a SpriteMesh object from the tiles selected in the texture preview. |

### Other options

| Option | What it does |
| --- | --- |
| Show Debug Info | Prints a report about the node's current state to the Output panel. |
| Auto Z-Fight Fix (Box/Prism) | Gives Box, Prism and AutoShape tiles a tiny offset along their surface normal to prevent Z-fighting where their geometry overlaps. On by default. |
| Filter | Texture filter for the tiles (see table below). |
| Pixel Inset | How far, in atlas texels, filtering may read into the neighbouring atlas cell (default `0.25`). See [Textures bleed at tile edges](#textures-bleed-at-tile-edges). |

Texture filters:

| Filter | Best for |
| --- | --- |
| Nearest | Crisp pixel art (default). |
| Nearest Mipmap | Pixel art seen from far away. |
| Linear | Smooth, non-pixel-art textures. |
| Linear Mipmap | Smooth textures seen from far away. |
| Smooth Pixel | Pixel art that stays crisp but stable: texels stay sharp and only their edges are blended over about one screen pixel, which avoids shimmering at non-integer scales and during camera motion. |

The filters are computed in the tile shader, so they look the same in Forward+ and Compatibility. The mipmap modes and Smooth Pixel only use mipmaps when the atlas texture is imported with mipmaps. Baked meshes and SpriteMeshes render Smooth Pixel as Nearest.

### Alpha-aware option (for transparent textures)

**AlphaAware** (collision) and **AlphaAware** (bake) enable alpha-aware generation. Use them when your tiles have transparent regions (cut-out pixel art, foliage, fences, decals):

- With AlphaAware **off**, the full tile quad is treated as solid: collision and baked geometry include the transparent corners.
- With AlphaAware **on**, the generator inspects the texture's alpha channel and skips fully transparent areas. This produces tighter collision shapes and cleaner baked meshes for cut-out tiles.

AlphaAware takes more time to bake.

### Tile visibility, culling and regional chunks

TileMapLayer3D splits the world into **30-unit cubic regions**. Tiles are partitioned into these regions, and each region owns its own render chunks plus its own collision shape:

- **Rendering:** tiles are drawn through per-region chunks of up to 1,000 tiles, sent directly to Godot's `RenderingServer` as MultiMesh batches, without per-chunk scene-tree nodes. Adding or erasing one tile only updates the chunks of that region, not the whole map.
- **Visibility:** each region's chunks are culled independently, so off-screen regions don't contribute to draw calls.
- **Collision:** **Create Collision** generates one collision shape per region. At runtime, `set_collision_for_region(tile_info)` rebuilds only the affected region's shape instead of the whole map.

This is why large maps stay responsive: edits, collision rebuilds and bake operations are all scoped to the region under the change.

### Node and settings options in the Inspector

A few options are only available in the Inspector:

| Where | Option | What it does |
| --- | --- | --- |
| Node | `enable_decal_mode` | See [Decal Mode](#decal-mode-rendering-tiles-on-top-of-another-layer). |
| `settings -> Rendering` | `render_priority` | Material render priority for this node's tiles. |
| `settings -> Collision` | `collision_layer`, `collision_mask` | Physics layer and mask of the generated collision. |
| Node -> Debug | `show_transparent_tiles`, `transparent_tiles_tolerance` | Shows tiles whose atlas cell is (almost) fully transparent in magenta, so you can find invisible tiles. |
| Node -> Debug | `print_tile_info`, `print_smartselect_info`, `print_plane_orientation` | Print diagnostic information to the Output panel. |

## 14. Runtime API

The Runtime API lets gameplay scripts place, erase, query, highlight and swap tiles, rebuild collision and control animated tiles while the game is running.

Two data objects are involved:

- **`TML3D_PlacedTileInfo`** describes a tile placed in the 3D world: its unique `tile_key`, grid and world position, orientation, mesh type, UV rectangle, atlas source id and atlas coordinates, animation data and other placement details.
- **`TileData`** is Godot's built-in object from the `TileSet`. It describes the source atlas tile: terrain data, custom data layers and other TileSet information configured in Godot's TileSet editor.

Use `TML3D_PlacedTileInfo` when you work with a placed tile in the world. Use `TileData` when you need the TileSet data attached to that tile's atlas coordinate.

Every `TileMapLayer3d_Cpp` node exposes the API as:

```gdscript
tile_map.runtime_api
```

### How positions work

- World-space positions select the **whole grid cell** that contains them, in the node's local space and using its `grid_size`. Moved, rotated and scaled nodes are handled.
- The editor's Grid Snap setting does not affect the Runtime API.
- Runtime changes are not added to the editor's undo history, and collision is not rebuilt automatically: call `set_collision_for_region()` when needed.

### Orientations

| Value | Constant | Surface |
| --- | --- | --- |
| `0` | `TML3D_GlobalUtil.FLOOR` | Floor |
| `1` | `TML3D_GlobalUtil.CEILING` | Ceiling |
| `2` | `TML3D_GlobalUtil.WALL_NORTH` | North wall |
| `3` | `TML3D_GlobalUtil.WALL_SOUTH` | South wall |
| `4` | `TML3D_GlobalUtil.WALL_EAST` | East wall |
| `5` | `TML3D_GlobalUtil.WALL_WEST` | West wall |
| `6`–`25` | | Tilted orientations |
| `-1` | `TML3D_RuntimeAPI.ANY_ORIENTATION` | Lookups only: search all six base orientations |

### Key methods

| Method | Use |
| --- | --- |
| `place_tile(world_pos, uv_rect, orientation = 0, tile_info = null) -> bool` | Place one tile. `uv_rect` is in atlas pixels; use `atlas_coord_to_uv_rect()` to get it. With `tile_info = null`, the node's current placement settings are used (mesh type, depth, and so on). Pass a `TML3D_PlacedTileInfo` to control mesh type, depth and other attributes yourself. |
| `erase_tile(world_pos, orientation = 0) -> bool` | Erase one tile (regular or vertex-edited). |
| `place_area(anchor_world, orientation, size, uv_rect, options = null) -> Dictionary` | Place a rectangle of tiles. Returns counts such as `placed` and `skipped`, plus `tile_keys` and `tiles`. |
| `erase_area(anchor_world, orientation, size, options = null) -> Dictionary` | Erase a rectangle. Returns `erased`, `skipped` and `tile_keys`. |
| `find_tile(world_pos, orientation = ANY_ORIENTATION, tolerance_cells = 0) -> TML3D_PlacedTileInfo` | Find a tile at a world point, or `null`. `tolerance_cells` widens the search by whole cells. |
| `get_first_tile_from_raycast(ray_origin, ray_dir, max_distance = INF) -> TML3D_PlacedTileInfo` | Pick the first tile hit by a world-space ray, or `null`. Useful for mouse picking from a camera. |
| `world_to_grid_snapped(world_pos, orientation = ANY_ORIENTATION) -> Vector3` | Convert a world position to its grid cell. |
| `grid_to_world_snapped(snapped_grid_pos, orientation = ANY_ORIENTATION) -> Vector3` | Convert a grid cell back to a world placement position. |
| `highlight_tile(world_pos, orientation = ANY_ORIENTATION) -> bool` | Highlight the tile at a world point. |
| `highlight_area(anchor_world, orientation, size, options = null) -> int` | Highlight a rectangle; returns the number of highlighted keys. |
| `clear_highlights()` | Remove all highlights. |
| `set_collision_for_region(tile_info, alpha_aware = false, backface_collision = false) -> int` | Rebuild collision for the region containing the tile. Returns a request id; the result arrives through the `bake_completed` or `bake_failed` signal. |
| `get_tile_data_from_key(tile_key) -> TileData` | Godot `TileData` for a placed tile, or `null` for freeform UVs. Get the key from `find_tile()` or `get_first_tile_from_raycast()` (`tile_info.tile_key`). |
| `get_tileset() -> TileSet` | The node's TileSet. |
| `atlas_coord_to_uv_rect(atlas_coords, source_id = -1) -> Rect2` | Convert TileSet atlas coordinates to the pixel `Rect2` used for placement. `-1` uses the active source. |
| `swap_tile_texture(tile_info, use_default_data_variant = true, custom_atlas_coords = Vector2i(-1, -1)) -> bool` | Swap one tile to its `VariantTile`, or pass `false` and `custom_atlas_coords` to swap to any atlas cell. |
| `swap_tile_collection_texture(tile_info, follow_chain = false, max_chain_steps = -1, step_change_time = 1.5) -> bool` | Swap every tile in the `CollectionTiles` group to its `VariantTile`. With `follow_chain = true` and `max_chain_steps` greater than 1, it keeps swapping to the next variant every `step_change_time` seconds, for multi-step sequences. Returns immediately; no `await` needed. |
| `get_variant_tile_data(tile_key) -> Vector2i` | Read `VariantTile` custom data, or `Vector2i(-1, -1)`. |
| `get_collection_tile_data(tile_key) -> PackedVector2Array` | Read `CollectionTiles` custom data. |
| `get_debug_info(world_pos = null) -> Dictionary` | Runtime diagnostics. |

Signals:

| Signal | When |
| --- | --- |
| `bake_completed(region_key, request_id, result)` | Collision for a region finished. `result` is the new shape, or `null` if the region became empty. |
| `bake_failed(region_key, request_id, reason)` | Collision could not be generated. Listen for it too, so your code never waits forever. |

### Area options

`place_area`, `erase_area` and `highlight_area` accept a `TML3D_RuntimeAreaOptions`:

| Property | Default | Meaning |
| --- | --- | --- |
| `anchor` | `"origin"` | `"origin"` starts the rectangle at the anchor cell; `"center"` centres it on the anchor. |
| `overwrite` | `true` | When `false`, cells that already hold a tile are skipped. |
| `tile_info` | `null` | Template tile copied into every cell (mesh type, depth, and so on). |

### Example 1 - Query a tile and read its custom data

```gdscript
var api := tile_map.runtime_api
var tile_info: TML3D_PlacedTileInfo = api.get_first_tile_from_raycast(
	player.global_position, Vector3.DOWN, 1.0
)

if tile_info:
	var tile_data: TileData = api.get_tile_data_from_key(tile_info.tile_key)
	if tile_data:
		var variant: Vector2i = api.get_variant_tile_data(tile_info.tile_key)
		var collection: PackedVector2Array = api.get_collection_tile_data(tile_info.tile_key)
		print("Variant: ", variant, " Collection: ", collection)
```

### Example 2 - Swap a tile group and refresh collision

```gdscript
func _ready() -> void:
	tile_map.runtime_api.bake_completed.connect(_on_bake_completed)
	tile_map.runtime_api.bake_failed.connect(_on_bake_failed)


func open_door(ray_origin: Vector3, ray_dir: Vector3) -> void:
	var api := tile_map.runtime_api
	var tile_info: TML3D_PlacedTileInfo = api.get_first_tile_from_raycast(ray_origin, ray_dir, 5.5)
	if tile_info:
		api.swap_tile_collection_texture(tile_info)
		api.set_collision_for_region(tile_info, true, true)


func _on_bake_completed(region_key: Vector3i, request_id: int, result: Variant) -> void:
	print("Collision rebuilt for region ", region_key)


func _on_bake_failed(region_key: Vector3i, request_id: int, reason: String) -> void:
	push_warning("Collision rebuild failed: " + reason)
```

### Example 3 - Place and erase tiles at runtime

```gdscript
var api := tile_map.runtime_api
var floor_uv: Rect2 = api.atlas_coord_to_uv_rect(Vector2i(9, 2))
var pos: Vector3 = player.global_position + Vector3(0, 2, 0)

# One floor tile, using the node's current placement settings.
api.place_tile(pos, floor_uv, TML3D_GlobalUtil.FLOOR)

# A 4x4 floor centred on the player, keeping tiles that already exist.
var options := TML3D_RuntimeAreaOptions.new()
options.anchor = "center"
options.overwrite = false
var result: Dictionary = api.place_area(pos, TML3D_GlobalUtil.FLOOR, Vector2i(4, 4), floor_uv, options)
print(result.placed, " placed, ", result.skipped, " skipped")

# A box tile on the north wall, with explicit mesh settings.
var box_info := TML3D_PlacedTileInfo.new()
box_info.mesh_mode = TML3D_GlobalConstants.BOX_MESH
box_info.depth_scale = 0.5
api.place_tile(pos, floor_uv, TML3D_GlobalUtil.WALL_NORTH, box_info)

# Erase the floor tile again.
api.erase_tile(pos, TML3D_GlobalUtil.FLOOR)
```

When you pass your own `tile_info` for a tilted orientation (6–25), you must also set its `spin_angle_rad`, `tilt_angle_rad`, `diagonal_scale` and `tilt_offset_factor`. Placing onto a cell that holds a vertex-edited tile is refused.

### Animated group playback

Animated tiles created with a new animation definition can be controlled as a whole object at runtime: pause the complete object on its current frame, resume without jumping, change its speed, or show a specific frame. Pass a `TML3D_PlacedTileInfo` of any placed tile of the group (a raycast or `find_tile()` result works whatever frame is currently visible).

| Method | Use |
| --- | --- |
| `pause_animated_group(tile_info) -> bool` | Freeze the group on the frame currently visible. |
| `resume_animated_group(tile_info) -> bool` | Continue from the held frame. Returns `false` if the animation has no positive speed. |
| `set_animated_group_speed(tile_info, fps) -> bool` | Set a runtime speed from `0.0` to `255.0` FPS. `0.0` pauses; a positive value continues from the visible frame without jumping. |
| `set_animated_group_frame(tile_info, frame, keep_playing = false) -> bool` | Show a zero-based frame. With `keep_playing = true`, playback continues from it. |
| `get_animated_group_playback_state(tile_info) -> Dictionary` | Returns `valid`, `current_frame`, `effective_speed`, `paused`, `total_frames` and `tile_keys`. |
| `get_animated_group_tile_keys(tile_info) -> PackedInt64Array` | Keys of the placed tiles in the group. |
| `get_animation_group_tile_data(tile_info) -> PackedVector2Array` | The group's `AnimatedGroup` custom data. |

```gdscript
var tile_info: TML3D_PlacedTileInfo = tile_map.runtime_api.get_first_tile_from_raycast(
	ray_origin, ray_direction, 5.5
)
if tile_info:
	tile_map.runtime_api.pause_animated_group(tile_info)
	tile_map.runtime_api.set_animated_group_frame(tile_info, 2)
	tile_map.runtime_api.set_animated_group_speed(tile_info, 8.0)

	var state: Dictionary = tile_map.runtime_api.get_animated_group_playback_state(tile_info)
	print(state.current_frame, state.effective_speed, state.paused)
```

- Runtime playback state belongs to the running node and is not saved. The authored speed stays unchanged.
- The methods return `false` without changing anything when the group metadata is missing. Definitions created with older builds have no group metadata: recreate them to enable group control. Tiles you already placed keep animating.
- **Not available with the Compatibility renderer**, which every Web export uses. There, animated tiles play at their authored speed, `get_animated_group_playback_state()` reports `valid = false`, and the other group methods return `false`.

### Demo scripts

The demo scene in `addons/tilemap_layer_3d_cpp/demo_scene/` contains working examples:

- `runtime_api_test.gd`: querying the tile under the player, reading custom data and terrain names, and placing/erasing tiles at runtime.
- `tile_detector_area_3d.gd`: swapping tiles and collections, rebuilding collision, and controlling animated groups.
- `door_body.gd`: reacting to a tile swap.

The full API reference is available in Godot's built-in help: search for `TML3D_RuntimeAPI`.

## 15. Key Shortcuts Reference

Shortcuts are active only while a `TileMapLayer3d_Cpp` node is selected and the 3D viewport has focus. They use physical key positions, so they work the same on every keyboard layout, and they never fire while Ctrl, Alt or Meta is held, so Godot's own shortcuts keep working.

| Keys | Action | Where |
| --- | --- | --- |
| `W` / `S` / `A` / `D` | Move the 3D cursor forward / backward / left / right, relative to the camera | All modes that use the cursor |
| `Shift + W` / `Shift + S` | Move the 3D cursor up / down | All modes that use the cursor |
| `Q` / `E` | Rotate the tile 90° counter-clockwise / clockwise | Manual |
| `R` / `Shift + R` | Tilt the tile forward / backward | Manual |
| `F` | Mirror the texture | Manual |
| `G` / `Shift + G` | Rotate the texture inside the tile by 90° (disabled while Freeze UV is on) | Manual |
| `T` | Reset rotation, tilt, mirror and texture rotation | Manual |
| `Z` | Toggle **Additive** selection | Smart Select, Patterns |
| `Delete` | Delete the selected tiles | Vertex Edit |
| `Esc` | Cancel the current area selection or sculpt operation | Painting modes, Sculpt |
| `Shift + Space` + left click | FastMove: jump the cursor and grid to the clicked tile | When the 3D cursor is in use |

The rotation, tilt, mirror and texture-rotation keys do nothing in AutoTile, Animated Tiles and Vertex Edit modes.

Mouse controls:

| Action | Manual / AutoTile / Animated | Smart Select / Patterns | Smart Fill | Sculpt | Vertex Edit | Scatter |
| --- | --- | --- | --- | --- | --- | --- |
| Left click / drag | Paint | Select / stamp pattern | Set start, then end | Draw footprint, then extrude | Select / drag corners | Paint or grow |
| Right click / drag | Erase | Clear selection / stop stamping | Cancel | Cancel | Clear selection | Erase or shrink |
| Shift + left / right drag | Area fill / erase | | | | | Shrink (Scale mode) |

## 16. Limits and Performance Notes

| Limit or behaviour | Value |
| --- | --- |
| Recommended max tiles per node | 50,000 (a warning appears at 95%) |
| Texture preview multi-selection | 48 cells |
| Max area fill operation | 10,000 tiles |
| Finest Grid Snap / Cursor Step | 0.25 |
| Coordinate precision | 0.05 grid units |
| Coordinate range | about ±13,107 grid units per axis |
| Tiles per MultiMesh chunk | 1,000 |
| Spatial region size | 30 units |
| Animation frames / columns per definition | 255 / 255 |
| Runtime animation speed | 0–255 FPS |
| Vertex tile warning | 100 per node |

For large maps, split the work across several `TileMapLayer3d_Cpp` nodes. This keeps editor interaction, culling, collision and runtime updates easier to manage.

## 17. Troubleshooting

### I do not see the TileMapLayer3D UI

Select a `TileMapLayer3d_Cpp` node in the scene tree. The toolbars and bottom panel are shown only for the selected node. Also check that **TileMapLayer3D (C++)** is enabled in `Project -> Project Settings -> Plugins`.

### The `TileMapLayer3d_Cpp` node type is missing

The native library did not load. Check the Output panel for errors such as "Can't open dynamic library". Make sure the addon lives at `res://addons/tilemap_layer_3d_cpp/`, that your platform is supported (see [Supported platforms](#supported-platforms)), and restart the editor.

### I cannot paint

Check:

1. The main toolbar **On** toggle is enabled.
2. You are in a painting mode (Manual, AutoTile, Animated Tiles, Sculpt or Scatter).
3. A texture or TileSet is loaded.
4. A tile, terrain or animation is selected. In Animated Tiles mode, an animation must be selected in the list.
5. In AutoTile mode, the selected terrain has tiles configured in the TileSet editor.
6. **UV Only** is not enabled (it only repaints existing tiles).
7. The target position is within the supported coordinate range (a red "blocked" highlight means it is not).

### AutoTile paints the wrong tiles

Check the TileSet terrain setup:

1. The correct terrain is selected.
2. Terrain peering bits are painted in Godot's TileSet editor.
3. The TileSet is saved.
4. Your atlas layout contains all required terrain cases.

### Vertex Convert does nothing

Only `FLAT_SQUARE` tiles can be converted. In Vertex Edit mode, click the placed flat square tiles to select them first, then click **Convert**.

### Textures bleed at tile edges

- Make sure **Tile Set Size** matches your tilesheet's cell size.
- For pixel art, use the **Nearest** or **Smooth Pixel** filter (Settings mode).
- Adjust **Pixel Inset** (Settings mode, default `0.25`). It is measured in atlas texels: `0.5` stops all bleeding but shows a hard line at every tile seam with the Linear, Linear Mipmap and Smooth Pixel filters; values below `0.5` let edges blend slightly with their atlas neighbour, which keeps multi-tile objects seamless.

### Pixel art shimmers or looks blurry

Use the **Smooth Pixel** filter. It keeps texels sharp while blending their edges over about one screen pixel, so pixel art stays stable at non-integer scales and during camera movement.

### Collision disappeared after changing the grid size

Changing **GridSize** clears all collision shapes (the confirmation dialog warns about this). Run **Create Collision** again.

### "Save as external .res" does not create files

The files are saved in a `<scene name>_SavedData` folder next to the scene, so the scene must be saved to disk first.

### Animated group methods always return `false`

- The project uses the Compatibility renderer (all Web exports do). Runtime playback control is not available there.
- The animation definition was created with an older build and has no `AnimatedGroup` data. Recreate the definition.

### Light leaks through wall and floor seams

This comes from real-time shadow mapping in general, not from the plugin: flat tiles have no thickness, and the light's shadow bias can push shadows past the corner where a wall meets a floor. Use one of these fixes:

- **Add thickness:** build structural walls and floors from Box tiles (or Sculpt with **Box/Prism (Depth)**) instead of flat tiles.
- **Tune the light:** lower the light's shadow **Max Distance**, lower **Bias** (for example `0.02`–`0.05`) and **Normal Bias** (for example `0.5`–`1.0`), and enable **Reverse Cull Face** in the light's shadow settings.
- **Invisible shadow blockers:** place a thin, hidden `BoxMesh` behind the seam with **Cast Shadow** set to **On**.

### The editor viewport jitters (Windows, Direct3D 12)

This has been seen with the Godot 4.6 editor using the Direct3D 12 driver. Switch the rendering driver to Vulkan: `Project Settings -> Rendering -> Rendering Device -> Driver.windows`.

### Known limitations

- Animation definitions live in the node's `settings` resource and are not imported by the 1.x migration; placed animated tiles are.
- UV Only painting cannot repaint Smart Fill ramp and stair pieces.
- Patterns cannot be rotated when stamping.
- FastMove only jumps to tiles on the plane you are facing.
- Horizontal Loop selection on walls follows the camera's horizontal, which can look vertical relative to the wall.
- With **Box/Prism (Depth)** in Sculpt mode, corners line up perfectly from one side of the wall only.

## 18. Migrating from the GDScript Version (1.x)

The C++ edition uses a new node type (`TileMapLayer3d_Cpp`) and its own data format. Your 1.x tile data can be imported once, manually, with the **Load Legacy Data** button on the node's data resource.

Follow the **[Migration Guide](MIGRATION_GUIDE.md)** for the step-by-step process, what is and isn't migrated, and the list of features that are new in 2.x. Back up your project before migrating.
