# Vignette Radar

A compact, heading-up radar for the rare, treasure, event, and other vignettes that World of Warcraft already exposes on the minimap. It uses Blizzard's current vignette and map data; it does not reveal hidden objects or use a location database.

The small draggable launcher covers 150 yards. Click it to show or tuck away the full radar. The full radar has a category legend and a picker for focusing one current detection. Right-click the launcher for a layout preview.

## Install

Copy the `VignetteRadar` folder to `_retail_/Interface/AddOns/`, then reload the game. Waffle House and EllesmereUI are optional; neither is required for the radar to work. If Waffle House is installed, existing radar settings and positions are copied into Vignette Radar's own SavedVariables on first load.

## Commands

- `/vr` toggles the full radar.
- `/vr on`, `/vr off`, and `/vr preview` control visibility.
- `/vr config` opens the addon settings.
- `/vradar`, `/vignetteradar`, and `/whradar` remain aliases.

The addon also appears under the game's AddOns settings when the current Retail Settings API is available.
