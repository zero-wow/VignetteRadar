# Quest Tracker: 50 Features, 50 Controls, 50 Polish Passes

The tracker is a companion to the radar, not a second quest database. The diamond carries a quest's **radar identity color**; the title carries **Blizzard difficulty color**. These must never be conflated. A hollow diamond means unfinished, a full diamond means ready. The first implementation (dev.106) provides a visible tracker with local/watched/all scopes, populated quest-log headers, world/bonus task groups, objective summaries, click-to-focus, hover-to-highlight, foldable headers, radar-dot and number toggles, and two themed views: **Floating**, with its own saved position, and **Tray**, docked to a chosen Left, Right, Top, or Bottom radar edge. Tray chooses another edge when the requested one cannot fit and returns to the saved Floating position while the radar is hidden. The items below form the complete product design; unimplemented ideas are proposals, not claims about the current build.

Fifty controls belong in a compact toolbar, row interactions, contextual menus, and settings drawer. They should **not** appear as fifty permanent buttons.

## 50 Features

1. Show quests relevant to the player's current map by default.
2. Preserve the quest log's local, visible section headers.
3. Omit headers with no visible child quests.
4. Include local world quests absent from ordinary log rows.
5. Include local bonus objectives absent from ordinary log rows.
6. Keep watched quests available in a separate scope.
7. Offer the full quest log as an optional scope.
8. Match each quest diamond to the radar's exact color slot.
9. Separate difficulty title color from radar identity color.
10. Match the radar's hollow/solid quest-completion shapes.
11. Show the next unfinished objective and its count.
12. Show ready-to-turn-in status instead of an obsolete objective.
13. Focus the corresponding radar quest from a tracker row.
14. Highlight matching radar diamonds while hovering the row.
15. Persist tracker visibility and its independent Floating position.
16. Switch between Floating and edge-docked Tray views without changing quest state.
17. Assign unique short labels when more quests than palette colors are local.
18. Reserve a stable color for each active quest through objective updates.
19. Show distinct world-quest and bonus-objective type badges.
20. Identify warband-completed quest starts and respect their filter.
21. Show available quest starts as their own optional section.
22. Separate campaign, story, daily, weekly, and ordinary quests.
23. Show a compact objective checklist inside an expanded row.
24. Distinguish numeric, percentage, and binary objectives.
25. Surface quest item usage only when the item is available.
26. Show quest timers without a per-frame update loop.
27. Show the currently auto-routed quest and its next step.
28. Promote the active route objective without hiding other quests.
29. Distinguish focused quest from Blizzard super-tracked quest.
30. Identify quests that have no reliable local map point.
31. Show a subtle off-zone indicator for watched distant quests.
32. Explain missing locations in one concise status line.
33. Pin a quest to the world waypoint system from its row.
34. Send a quest into Quest Auto Route without changing other route modes.
35. Advance route selection after objective completion events.
36. Keep a current quest locked during combat unless its step completes.
37. Group nearby quests sharing an objective area.
38. Show distance only when a trustworthy map coordinate exists.
39. Mark cave entrance waypoints before underground objectives.
40. Show Zygor's active step as an optional, clearly labeled source.
41. Distinguish learned coordinates from live Blizzard points.
42. Offer a quest-only radar lens from the tracker.
43. Dock Tray to Left, Right, Top, or Bottom and fit it within the screen.
44. Retain context when a quest changes header or zone.
45. Handle phased maps without claiming a false local location.
46. Respect combat-safe updates and protected Blizzard frames.
47. Debounce quest events and reuse cached objective text.
48. Gracefully handle secret or temporarily unavailable API values.
49. Work without optional UI or guide addons installed.
50. Restore the same tracker state after reload.

## 50 UI Controls

1. Close/reopen tracker button.
2. Drag handle on the tracker title.
3. Local scope button.
4. Watched scope button.
5. All scope button.
6. Radar quest dots toggle.
7. Radar quest-label toggle.
8. Fold all headers button.
9. Expand all headers button.
10. Per-header fold toggle.
11. Per-quest focus click.
12. Per-quest focus-clear click when already focused.
13. Per-quest hover identity preview.
14. Mouse-wheel list scroll.
15. Visible scroll thumb for long lists.
16. Quest search field.
17. Search-clear button.
18. Sort by quest-log order.
19. Sort by distance.
20. Sort by readiness.
21. Sort by difficulty.
22. Campaign-only filter.
23. World-quest filter.
24. Bonus-objective filter.
25. Daily/weekly filter.
26. Quest-start filter.
27. Hide-completed filter.
28. Warband-completed toggle.
29. Expand one quest's objectives.
30. Collapse one quest's objectives.
31. Pin waypoint action.
32. Clear waypoint action.
33. Set Quest Auto Route action.
34. Pause Auto Route action.
35. Previous route step action.
36. Next route step action.
37. Open quest details action.
38. Open quest's map action.
39. Use quest item action where Blizzard allows it.
40. Show quest sharing menu action.
41. Floating/Tray view selector.
42. Tray edge selector: Left, Right, Top, Bottom.
43. Row density choice.
44. Objective line limit choice.
45. Font-size choice.
46. Tracker opacity choice.
47. Anchor-to-radar choice.
48. Lock-position toggle.
49. Reset-position button.
50. Restore tracker defaults button.

## 50 Polish Passes

1. Verify every displayed header has a local visible child.
2. Verify map changes remove stale local rows immediately.
3. Verify watched distant quests never masquerade as local.
4. Verify world and bonus quests are never counted twice.
5. Verify difficulty color changes correctly with player level.
6. Verify identity diamond color matches every radar marker for that quest.
7. Verify identity labels remain distinguishable after eight quests.
8. Verify hollow and filled diamonds align at the same optical center.
9. Verify focus and hover states remain visually distinct.
10. Verify selected glow never animates the quest blob.
11. Verify the tracker title uses the active theme accent.
12. Verify the background and border match radar popup surfaces.
13. Remove any left accent bar from the tracker and dialogs.
14. Keep all settings labels in Title Case.
15. Reserve visible gutters around borders and dividers.
16. Check controls at the smallest supported UI scale.
17. Check all four Tray edges at 720p, 1080p, and ultrawide sizes.
18. Check panel height when every header is folded.
19. Check panel height with a full list and footer.
20. Check long translated quest titles for clipping.
21. Check wide objective counts for overlap.
22. Check objective text wrapping at each density.
23. Use readable contrast in every built-in theme.
24. Keep world quest type distinct from difficulty color.
25. Keep bonus objective type distinct from radar identity.
26. Keep disabled buttons legible and obviously disabled.
27. Make click targets larger than their tiny glyphs.
28. Provide concise tooltips only where an action needs explanation.
29. Prevent header and row hover targets from overlapping.
30. Restore hover highlighting on mouse leave and frame hide.
31. Preserve focus when the tracker refreshes.
32. Preserve scroll position on minor objective updates.
33. Reset scroll only when scope or zone changes materially.
34. Preserve header folds and Floating position across view changes and reload.
35. Keep moved position inside the visible screen.
36. Avoid touching Blizzard's protected objective tracker in combat.
37. Batch bursty quest events into one refresh.
38. Cap quest-log and map scans to bounded counts.
39. Reuse row frames and textures rather than rebuilding them.
40. Avoid per-frame timers for quest text or route updates.
41. Avoid repeated objective API calls during mouse motion.
42. Check secret values before comparison, arithmetic, or formatting.
43. Verify fallback fonts contain every glyph used.
44. Keep the addon usable without EllesmereUI or Zygor.
45. Keep Blizzard's quest log usable when the tracker is hidden.
46. Preserve all pre-existing SavedVariables and bindings.
47. Test quest acceptance, objective completion, and turn-in events.
48. Test a zone with no quests and an empty quest log.
49. Test a zone with many quests and overlapping radar points.
50. Confirm in-game visuals and CPU use before declaring the tracker finished.
