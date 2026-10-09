# DRIVE 3D — Android prototype

A small Godot 4 3D driving-game starter project. It uses procedural meshes, so no external art assets are required.

## Features
- 3D road, stylized car, roadside trees, obstacles, checkpoints and finish gate
- Gas, brake, left and right touch buttons
- Keyboard controls for testing on PC
- Garage with five upgrade categories
- Upgrade prices: level 1→2 costs 1000 coins; level 2→3 costs 1800 coins
- Every third successful finish awards 5000 coins
- GitHub Actions workflow for Android APK export

## Build using GitHub
1. Create a new repository on GitHub.
2. Upload all files and folders from this project, including `.github/workflows/build.yml`.
3. In GitHub, open **Actions** and select **Build Android APK**.
4. Press **Run workflow**, or push a commit to `main`.
5. When the run completes, open it and download the `DRIVE3D-Android` artifact.

## Important
This is an early playable prototype with stylized procedural graphics and simplified driving, not a BeamNG-level vehicle simulation. Before exporting, open the project in Godot 4.3 and configure **Project → Export → Android** with the Android export preset named exactly `Android`. GitHub Actions requires a valid export preset in `export_presets.cfg`; create it in Godot and commit that file to the repository. Android export settings can vary by Godot version and SDK setup.

## Controls
- W / Up: gas
- S / Down: brake
- A / Left: steer left
- D / Right: steer right
- Touch controls are visible in game
