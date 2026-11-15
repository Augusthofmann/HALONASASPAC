# Junior Astronaut Mission Trainer

An offline, browser-ready Godot 4 learning game for the NASA Space Apps Challenge **Junior Astronaut Mission Trainer** challenge. It is made for explorers aged 7–12.

## The mission

Keep a small lunar outpost going for 30 mission days. The player makes quick engineering choices instead of answering a quiz:

- **Power** runs the base and the life-support machine.
- **Life support** means oxygen, water, food, and a healthy crew.
- **Radiation shield** helps during solar events, but spending battery power on it can leave less power for oxygen.

Dust can cover solar panels. A leak can waste water or oxygen. Solar events send the crew inside. The goal is not to pick a magic button: it is to notice what each choice costs.

## Features

- Complete loop: new mission → real-time decisions → win/lose explanation → immediate restart.
- Random solar alerts, dust storms, power faults, water leaks, and oxygen leaks.
- Per-action cooldowns and delayed crew commands to prevent score farming.
- Automatic save/load, pause menu, English/Russian interface, and a short first-play onboarding.
- Large resource bars with critical-state color feedback and a storm shake.
- Offline NASA archive badge and an in-game **About the Mission / Data Sources** panel.
- Konami-code Sudoku easter egg.

## Run locally

1. Install **Godot 4.7**.
2. Import `project.godot` in Godot.
3. Press **F6** to run the main scene, or **F5** to run the project.
4. Choose **New Game**.

The project uses the Compatibility renderer, so it is suitable for Web export.

## Export for the web

1. In Godot, install export templates: **Editor → Manage Export Templates**.
2. Open **Project → Export**, choose the `Web` preset, and export to `build/web/index.html`.
3. Upload all generated files in `build/web/` to the web server directory. The server must serve `.wasm` as `application/wasm`.

## NASA data and science note

The game deliberately uses the local file [`data/nasa_space_weather_archive.json`](data/nasa_space_weather_archive.json), not a live API. This makes classroom/web play reliable and avoids presenting live weather as a safety warning.

The archive is a child-friendly, offline adaptation of event *types* from these NASA sources:

- [NASA CCMC DONKI](https://ccmc.gsfc.nasa.gov/DONKI/) — solar flares (FLR), coronal mass ejections (CME), and solar energetic particles (SEP).
- [NASA Apollo lunar-radiation learning resource](https://www.nasa.gov/wp-content/uploads/static/history/alsj/WOTM/WOTM-Radiation.html) — why the Moon has less natural shielding than Earth.
- [NASA Open APIs: DONKI](https://api.nasa.gov/) — API documentation for the underlying event catalogue.

Dates and event labels in the local file provide context only. The mission timers, resource quantities, risk meter, and win/lose thresholds are intentionally simplified gameplay values. They are **not** a real-time forecast, a radiation calculation, or medical advice.

## Project layout

```text
scenes/main/main.tscn              Main 3D scene and HUD anchors
scripts/core/game_manager.gd       Clock, save/load, mission state, ending
scripts/simulation/resource_manager.gd  Power, life support, crew health
scripts/simulation/base_simulation.gd   Events, radiation, base actions
scripts/ui/hud.gd                  Kid-friendly interface, menus, onboarding
data/nasa_space_weather_archive.json    Offline science context
```

## Controls

## Live demo

Play the web version: [game.haloteam.my.id](https://game.haloteam.my.id)

## Super Intelligence disclosure

Super Intelligence tools were used for coding assistance, debugging, troubleshooting, interface text drafting, and documentation support. The HALO team directed the game design, selected the final implementation, reviewed all generated code, and integrated NASA data sources.

No SI-generated images, video, audio, NASA logos, NASA flags, or NASA mission identifiers are used in this project. NASA data references are used only as cited educational context in the local offline archive.

- Click the right-side action buttons to send a crew task.
- Use the small speed buttons at the top to change simulation speed.
- Open **Pause Menu** for save, language, credits, or a new mission.
- Press `C` to request solar-panel service.
- The Konami code `↑ ↑ ↓ ↓ ← → ← → B A` opens the optional Sudoku puzzle.
