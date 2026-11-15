# Junior Astronaut Mission Trainer — Beta 0.2

A short, playable lunar-outpost management demo made with Godot 4. The goal is to keep a small Moon base powered, supplied, and safe through a 30-day mission.

## Play loop

- Start or continue from the mission briefing; progress auto-saves every 12 seconds and when the game is paused.
- Use **SOLAR SERVICE** to clean and repair `SolarArraySouth` with one crew action.
- **WATER**, **O₂**, **FOOD +1**, and **SCIENCE** deploy workers at `WaterStorage`, `CargoDepot`, `HydroponicsFarm`, and `ScienceDome`; powered life support automatically recovers water and oxygen.
- Use **RADIATION** to trigger a solar-flare drill and verify shelter behavior.
- Watch radiation alerts, repair faults, and launch rover expeditions for research.
- Survive all 30 mission days to complete the mission.

## Run locally

Open `project.godot` with Godot 4.7, then run the main scene (`F6`). The Windows export preset writes to `build/JuniorAstronautMissionTrainer-Beta-0.2.exe` once exported from a Godot editor with Windows export templates installed.

## Beta notes

This beta focuses on a polished playable loop rather than final content: crew work is intentionally staged at visible task locations, the mission is single-player, and all space-weather values are fictional gameplay data.
