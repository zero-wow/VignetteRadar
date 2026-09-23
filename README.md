# Vignette Radar

A compact radar for the rare, treasure, event, and other vignettes that World of Warcraft already exposes on the minimap and world map. It uses Blizzard's current vignette and map data; it does not reveal hidden objects or use a location database.

The small draggable launcher covers 150 yards. Click it to show or tuck away the full radar. The full radar has a category legend and a picker for focusing one current detection. Right-click the launcher for a layout preview.

Click the small colored dot in the radar header to open **Radar Settings** beside the panel. Its eight compact tabs cover detection, layouts, alerts, markers, guides, themes, behavior, and quests. Click a checkbox label as well as its box to toggle it; the settings apply immediately. The Guides tab adjusts ring visibility, chevron and facing-line opacity, chevron distance from the player dot, and facing-line length. The Themes tab offers eight palettes and a color picker for each radar element and marker type. Turn off **Use icons** there to display category-colored dots instead. Custom colors are saved; choosing a preset clears the custom colors.

Choose a saved panel style under `/vr config` → Layout, or use `/vr layout` to cycle through them:

- **Classic:** the original portrait panel, with header buttons and details below the radar.
- **Squat:** a wider, shorter panel with the radar on the left, details on the right, and every button along the bottom. Focusing a target keeps the same panel height.
- **Compact:** a narrower radar with its range readout and all buttons underneath. Target details expand the panel when needed.

Styles preserve your range, filters, focus, and saved position. Switching closes open legend/target pickers; reopen them against the new panel edges. The radar stays circular in every style. Drag any edge or corner of the full panel to scale it uniformly; the small bottom-right grip shows where to start. The size is saved and stays inside the screen. Use **Preview layout** on the Layout tab to try a style without enabling tracking.

Squat automatically fills its right side with the nearest visible detection's name, type, distance, and available health. Click that readout to focus it; when tracking a specific target, the readout and action label change. When no detection is available, the panel shows a clear empty state.

Click the small **N** compass button to switch orientation. A small chevron tucked above your center dot and a short line show your facing. When the button is highlighted, north stays at the top and that cue turns as you turn. Click it again to restore the default facing-up radar. This choice is saved, applies to the small launcher too, and is also available as **Keep north at the top** on the Layout tab.

The full radar supports 150, 300, 450, 600, 1,200, 2,400, and 4,800-yard radii. Scroll down over it or click `-` to zoom out; scroll up or click `+` to zoom in. The range readout is the distance from you to the outer range ring. The launcher stays at 150 yards.

World-map detections are included by default and can be disabled on the Radar settings tab. Only publicly exposed, unfogged map entries with usable positions are included; tooltips identify their source. Changing this option clears incompatible last-seen markers and seeds the new view silently. Increasing the displayed radius cannot make Blizzard supply hidden or unloaded spawns, so there is no guaranteed detection distance. The addon maintains up to 256 current/last-seen entries and draws up to 64 at once; crowded views show an explicit count and individual entries remain available in the target picker.

## Install

Copy the `VignetteRadar` folder to `_retail_/Interface/AddOns/`, then reload the game. Waffle House and EllesmereUI are optional; neither is required for the radar to work. If Waffle House is installed, existing radar settings and positions are copied into Vignette Radar's own SavedVariables on first load.

## Commands

- `/vr` toggles the full radar.
- `/vr on`, `/vr off`, and `/vr preview` control visibility.
- `/vr config` opens the addon settings.
- `/vr layout` cycles styles; `/vr layout classic`, `/vr layout squat`, and `/vr layout compact` select one directly.
- `/vradar`, `/vignetteradar`, and `/whradar` remain aliases.

The addon also appears under the game's AddOns settings when the current Retail Settings API is available.

## Detection and navigation

- New rare and treasure detections pulse briefly. Sound is off by default; enable it and select categories or a repeat cooldown under `/vr config` → Alerts. Initial login/zone scans are silent, and rapid changes are throttled.
- Click a marker or target-list row to focus it; click it again to show all. The focused readout shows its name, distance, direction, and rare health when the game supplies it. A rim arrow points toward a live focused target outside the selected range.
- Shift-left-click a live marker, row, or focused readout to activate Blizzard navigation. A supported map waypoint is used if direct vignette tracking is unavailable.
- Alt-left-click to toggle a saved favorite. Favorites have a star, sort first, and use a distinct sound when sound alerts are enabled.
- Right-click to ignore a vignette for the current login session. Shift-right-click saves that ignore across logins. The Behavior page can clear both lists. Favorites and ignores apply to a vignette type when Blizzard provides a stable ID.
- Lost detections become fading hollow markers for 10 seconds by default. They are explicitly labeled as last seen, cannot trigger live navigation, and expire automatically. Zone changes clear them.
- Rares use silver-blue skulls; confirmed world bosses use larger red skulls. The small launcher also says `RARE` or `BOSS` for nearby live enemies. Target rows and tooltips spell out the type, and both enemy types use the Rare / Boss filter. Boss identification uses Blizzard's reward-quest metadata; unavailable metadata keeps the normal rare treatment rather than guessing.
- Treasures and other detections use Blizzard's own icons when available, with simple fallback markers. Marker size and recognizable icons are configurable.
- Optional quest dots use quest positions supplied by the game. Optional translucent quest areas use Blizzard's own shape when the radar is north-up and the map axes align; otherwise the area is hidden rather than shown inaccurately.
- Combat and instance quiet modes fade the radar and launcher and suppress alerts, restoring them automatically afterward. Both modes can be disabled in Behavior.

Preview samples support focus without changing favorites, ignores, or navigation. All live information still comes from Blizzard's exposed vignettes; the addon does not discover hidden objects or determine whether a missing detection was killed or looted.

## Development validation

Current development build: `0.1.0-dev.13` (base version `0.1.0`).

Run each `tests/*_test.lua` with Lua from the addon root and check Lua files with `luac -p`. The tests cover migration, radar projection, filters, target actions, alert/last-seen state, navigation fallbacks, quiet modes, mouse-wheel/button zoom, world-map visibility guards, and UI layout bounds using mocked game APIs. Layout checks exercise repeated style changes, automatic Squat details, focused and unfocused states, edge and corner resizing, pop-outs, resized rings and markers, and an 800×600 canvas. Orientation checks cover quarter turns, fixed markers/cardinals, the player direction line, both radars, preview, unknown facing, and out-of-range focus. These checks do not replace in-game validation of rendering, navigation, or API availability.
