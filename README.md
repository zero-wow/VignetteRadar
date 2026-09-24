# Vignette Radar

A compact radar for the rare, treasure, event, and other vignettes that World of Warcraft already exposes on the minimap and world map. An optional HandyNotes layer can also show saved locations from one chosen map-data pack. Saved notes are clearly marked and never count as live detections.

The small draggable launcher covers 150 yards. Click it to show or tuck away the full radar. The full radar has a category legend and a picker for focusing one current detection. Right-click the launcher for a layout preview.

Click the small colored dot in the radar header to open **Radar Settings** beside the panel. Its ten compact tabs include **Map Data** alongside the radar, layout, Explore, alert, marker, guide, theme, behavior, and quest settings. The full AddOns settings panel has an Explore tab and a **Map data** shortcut. Click a checkbox label as well as its box to toggle it; the settings apply immediately. The Guides tab adjusts ring visibility, chevron and facing-line opacity, chevron distance from the player dot, facing-line length, and an optional animated sweep on the full radar. The Themes tab offers 32 palettes in a two-row scroll area with a slim scrollbar, plus a color picker for each radar element and marker type. Turn off **Use icons** there to display category-colored dots instead. Custom colors are saved; choosing a preset clears the custom colors.

In **Map Data**, choose **Auto**, **Off**, or one installed HandyNotes data pack. The picker lists only enabled packs with visible notes for your current map or its nearby parent zone. **Auto** selects one matching pack as you travel, favoring notes on the exact map and then the pack with more visible notes. It keeps that pack while you remain in the zone. A manual choice stays saved but shows no dots outside its covered zones. Filter treasure, mob, item, and other-note locations independently. These are small hollow dots colored with the current theme's treasure, rare, event, and other colors, respectively. Hover one for its name, source, type, and distance. They show a possible saved location, not a currently detected spawn, and never trigger live alerts or appear in the live target picker. New installations default to **Auto**; an existing **Off** choice stays off until you select Auto. It works without HandyNotes installed. RareScanner and Zygor do not currently expose their full location databases through the HandyNotes plugin API, so this picker lists HandyNotes-compatible packs only.

Choose a saved panel style under `/vr config` → Layout, or use `/vr layout` to cycle through them:

- **Classic:** the original portrait panel, with header buttons and details below the radar.
- **Squat:** a wider, shorter panel with the radar on the left, details on the right, and every button along the bottom. Focusing a target keeps the same panel height.
- **Compact:** a narrower radar with its range readout and all buttons underneath. Target details expand the panel when needed.

Styles preserve your range, filters, focus, and saved position. Switching closes open legend/target pickers; reopen them against the new panel edges. Enabling quest areas switches the radar surface to a square in every style; disabling them restores the circle. Distance rings remain circular. Drag any edge or corner of the full panel to scale it uniformly; the small bottom-right grip shows where to start. The size is saved and stays inside the screen. Use **Preview layout** on the Layout tab to try a style without enabling tracking.

Click the small, borderless chevron in the empty margin to the right of the radar to hide the outer frame and controls. The chevron reverses direction so you can restore the frame. Drag the radar surface to move it while in this view. The choice is saved and also appears as **Radar-only view** under Layout. Open settings stay open when you switch views; close them with × or Escape. Quest dots and area shading remain visible with the outer frame hidden. The square surface has subtly rounded corners. Blizzard's rectangular quest-area clip sits four pixels inside the surface, keeping shading clear of those corners and leaving the restore chevron outside the plot.

Squat automatically fills its right side with the nearest visible detection's name, type, distance, and available health. Click that readout to focus it; when tracking a specific target, the readout and action label change. When no detection is available, the panel shows a clear empty state.

Click the small **N** compass button to switch orientation. A small chevron tucked above your center dot and a short line show your facing. When the button is highlighted, north stays at the top and that cue turns as you turn. Click it again to restore the default facing-up radar. This choice is saved, applies to the small launcher too, and is also available as **Keep north at the top** on the Layout tab.

The small eye icon in the footer controls automatic fading and hiding. When it is bright, the radar and launcher stay fully visible both in combat and inside instances, and an empty radar stays open through zone or phase changes. It overrides **Hide when empty**, including while map data is temporarily unavailable. Click it again to allow automatic fading and hiding. The setting is saved and also appears as **Stay fully visible** under Behavior. You can still close the radar yourself or disable tracking. Alert muting remains a separate choice.

The short trail-mark icon in the footer is a quick travel-trail switch. Left-click to show or hide the trail; right-click to open a small picker with animated previews of **Dashes**, **Ticks**, and **Dots**. Choosing a style turns the trail on. Dashes are the default so the trail reads differently from quest dots. Both settings panels also offer the three styles in Explore.

The full radar supports 150, 300, 450, 600, 1,200, 2,400, and 4,800-yard radii. Scroll down over it or click the borderless `−` icon to zoom out; scroll up or click `+` to zoom in. The `N` icon toggles north-up and glows when locked. Zoom, compass, focus, legend, and close controls use the same circular hover cue as the eye and settings dot. The range readout is the distance from you to the outer range ring. The launcher stays at 150 yards. Optional **Smart zoom** widens the view while moving quickly and chooses a close range around a focused target. Manual zoom takes control for 30 seconds.

Open the **Explore** tab in either settings panel for smart zoom, marker spreading, the travel trail, approach alerts, journal recording, distance, and hunting presets. **Saved presets, pins & journal** opens the management panel for named presets, pins, routes, and history. `/vr explore` remains an optional shortcut to that panel. Its four pages keep optional hunting tools off the radar face:

- **Modes:** Treasure, Rare, Questing, and Exploring presets change the range, layout, and filters together. Save up to eight named presets with your current colors and appearance; click a saved preset to load it or right-click it to delete it.
- **Tools:** Smart zoom, crowded-marker spreading, a travel trail, watched-target approach alerts, and the sightings journal can be switched independently. Set the approach distance from 25 to 600 yards. Watch or unwatch a live detection with Ctrl-Alt-click; entering the chosen radius pulses it and plays a sound when the existing alert-sound setting is on and alerts are not muted.
- **Pins:** Give your current location a name with **Add pin** or `/vr pin <name>`. Pins are saved and shown as gold dots on the same map once you move clear of the player marker. Click one to add a route stop or right-click it to remove it. The Pins page also lets you add or delete saved pins.
- **Journal:** When enabled, keeps the last 100 first sightings with their map coordinates and time. The journal records what the game exposed, not whether a creature was killed or loot was taken.

Ctrl-click a live detection or click a saved pin to add it to an eight-stop route. Numbered stops and connecting lines give straight-line guidance; **Next route stop** advances the queue and **Clear route** empties it. Routes and pins are saved. Stops from another map remain in the queue and appear when you return to that map. The optional trail draws short dashes, crosswise ticks, or dots behind you as you walk; it records recent movement only in memory and fades out after three minutes. Each style reuses a pool capped at 64 marks and keeps the newest part visible first.

When detections overlap, a single marker shows a count; hover it to spread the individual markers briefly, then choose one. Turn this off in Explore tools if you prefer every marker drawn at its exact position. Quest dots and hovered quest areas show objective completion when Blizzard provides it. Click a quest dot or area to spotlight its quest; click it again to restore all quest areas. Suggested group size appears on vignette tooltips when Blizzard supplies one.

World-map detections are included by default and can be disabled on the Radar settings tab. Only publicly exposed, unfogged map entries with usable positions are included; tooltips identify their source. Changing this option clears incompatible last-seen markers and seeds the new view silently. Increasing the displayed radius cannot make Blizzard supply hidden or unloaded spawns, so there is no guaranteed detection distance. The addon maintains up to 256 current/last-seen entries and draws up to 64 at once; crowded views show an explicit count and individual entries remain available in the target picker.

## Install

Copy the `VignetteRadar` folder to `_retail_/Interface/AddOns/`, then reload the game. Waffle House, EllesmereUI, and HandyNotes are optional; none is required for the radar to work. If Waffle House is installed, existing radar settings and positions are copied into Vignette Radar's own SavedVariables on first load.

## Commands

- `/vr` toggles the full radar.
- `/vr on`, `/vr off`, and `/vr preview` control visibility.
- `/vr config` opens the addon settings.
- `/vr explore` opens Explore tools; `/vr pin <name>` saves a pin at your current position.
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
- Optional quest dots use quest positions supplied by the game. Optional translucent quest areas use Blizzard's own shape when the radar is north-up and the map axes align; otherwise the area is hidden rather than shown inaccurately. Map projections retry when initially unavailable, and quest shapes redraw on quest updates and once per second so late data can appear without changing zones or reloading. Hover a shaded area to see its quest name.
- Combat fading, combat alert muting, and instance quiet mode can be adjusted under Behavior. Instance quiet mode mutes alerts and fades the radar and launcher unless **Stay fully visible** is enabled.

Preview samples support focus without changing favorites, ignores, or navigation. All live information still comes from Blizzard's exposed vignettes; the optional HandyNotes layer is saved map information and does not determine whether a location is active, killed, or looted.

## Development validation

Current development build: `0.1.0-dev.33` (base version `0.1.0`).

Run each `tests/*_test.lua` with Lua from the addon root and check Lua files with `luac -p`. The tests cover migration, radar projection, filters, target actions, alert/last-seen state, navigation fallbacks, quiet modes, mouse-wheel/button zoom, world-map visibility guards, and UI layout bounds using mocked game APIs. Layout checks exercise repeated style changes, automatic Squat details, focused and unfocused states, edge and corner resizing, pop-outs, resized rings and markers, and an 800×600 canvas. Orientation checks cover quarter turns, fixed markers/cardinals, the player direction line, both radars, preview, unknown facing, and out-of-range focus. These checks do not replace in-game validation of rendering, navigation, or API availability.
