# Setting Up AutoTile

This guide walks through preparing a TileSet for **AutoTile** mode. AutoTile uses Godot's native terrain system, so the terrain setup is exactly the same as for Godot's built-in `TileMapLayer` (2D). For the rest of the plugin, see the [How-To Guide](HOW_TO_GUIDE.md#7-autotile-mode).

> Screenshots in this guide come from the GDScript version (1.x). The steps are the same in 2.x except where noted.

## Step 1: Load a texture in Manual mode first

<img width="480" height="240" alt="image" src="https://github.com/user-attachments/assets/ac54144f-1030-48e9-9114-610b98e87c67" />

- Select your `TileMapLayer3d_Cpp` node, switch to **Manual** mode and click **Load Texture** (or **Load TileSet**). Set **Tile Set Size** to your tile size.
- You need, at a minimum, a tileset texture that follows one of the recommended Auto-tile terrain templates.
- For TileMapLayer3D, use the full **47-tile template in the 3x3 format**:
- <img width="480" height="160" alt="image" src="https://github.com/user-attachments/assets/63e5e44e-fa73-4403-b5a3-9c51149aaa47" />
- The best explanation of Auto-tile terrain templates is still the Godot 3.4 documentation; the concepts apply unchanged to Godot 4.
See: https://docs.godotengine.org/en/3.4/tutorials/2d/using_tilemaps.html

> Loading a **new** texture later clears the AutoTile terrain configuration of the current TileSet (Godot asks you to confirm first). Set up your texture before creating terrains.

## Step 2: Switch to AutoTile mode

<img width="480" height="160" alt="image" src="https://github.com/user-attachments/assets/0cb29931-50f2-47b1-b6ce-c767ab2e1556" />

- Click **AutoTile** in the main toolbar. The bottom panel switches to the AutoTile tab, which works on the TileSet you loaded in Manual mode.
- *Changed in 2.x:* there is no **Create New** button any more (it still appears in the screenshot above). The TileSet from Manual mode is used directly.

## Step 3: Add some Terrains (based on your loaded texture and TileSet)

<img width="480" height="160" alt="image" src="https://github.com/user-attachments/assets/05d4cb3e-81fc-42dd-922c-d268476d5aa0" />

- Type a name, choose a color and click **Add Terrain**. These terrains are what you "paint" with.
- The first terrain also creates **Terrain Set 0** in the TileSet, using the **Match Corners and Sides** mode that the 47-tile template needs.
- To delete a terrain, select it in the list and click **Remove**.

## Step 4: Click the "Tileset Editor" button

This opens the TileSet in Godot's TileSet editor (a tab in the bottom panels of the editor).

<img width="480" height="200" alt="image" src="https://github.com/user-attachments/assets/c6d16e8f-d5e7-420e-84e9-30fe9e74fa43" />

- Choose the **Paint** (Paint Properties) option, then set:
- Paint Properties = "Terrains"
- Terrain set = "Terrain Set 0"
- Terrain = the terrain you want to set up for AutoTile.

## Step 5: Activate all base tiles that are part of that terrain by clicking on them

<img width="360" height="120" alt="image" src="https://github.com/user-attachments/assets/c3fece39-bbc5-4d6f-9efd-362fd500430f" />

## Step 6: Paint which areas of each tile belong to the terrain

Paint the terrain color over the texture tiles, following Godot's predefined Auto-tile terrain templates.

<img width="360" height="120" alt="image" src="https://github.com/user-attachments/assets/1a20c0c1-dbe6-4551-be15-d51f7dde2c42" />

- For TileMapLayer3D, use the full **47-tile template in the 3x3 format**.
- This video explains how to define the terrain tiles and paint terrain properties (from minute 3:00): https://youtu.be/LrsfgDyOAJs?si=vWavZWXs3REXc87E&t=181
- <img width="360" height="120" alt="image" src="https://github.com/user-attachments/assets/63e5e44e-fa73-4403-b5a3-9c51149aaa47" />
- The best explanation of Auto-tile terrain creation is still the Godot 3.4 documentation; the concepts apply unchanged to Godot 4.
See: https://docs.godotengine.org/en/3.4/tutorials/2d/using_tilemaps.html

- Make sure you **SAVE** everything (`Ctrl+S`). If your TileSet is an external resource, save it too.

## After the Auto-Tile terrain is created, go back to the TileMapLayer3D panel

<img width="360" height="120" alt="image" src="https://github.com/user-attachments/assets/73a9b78b-5eb5-4385-8d94-019e7235742d" />

- Select the terrain in the **Select Terrain** list.
- Turn **On** in the main toolbar and start painting. Left-click paints, right-click erases, and `Shift` + drag fills or erases an area, just like Manual mode.

### Tips

- AutoTile works on the floor, the ceiling and the four walls. Rotation, tilt and mirror are not used: the terrain solver chooses each tile.
- You can still pick a **Mesh Type** (for example Box tiles with depth) and use **Double Flat Tile** while painting terrain.
- With **UV Only** enabled, painting marks *existing* tiles with the terrain and re-textures them without changing their mesh. Right-click then removes the terrain mark instead of deleting the tile.
- Neighbouring AutoTile tiles update automatically after every change, including manual painting, sculpting, Smart Operations and undo/redo.
- If AutoTile paints the wrong tiles, check that the correct terrain is selected, the peering bits are painted, the TileSet is saved, and the atlas contains every terrain case.
