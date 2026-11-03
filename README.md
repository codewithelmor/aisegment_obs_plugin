# AI Remove Background – OBS Studio Plugin

[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](LICENSE)
![Platform: Windows x64](https://img.shields.io/badge/platform-Windows%20x64-lightgrey)
![OBS Studio](https://img.shields.io/badge/OBS%20Studio-video%20filter-302E31)

An OBS Studio video filter that blurs or replaces the background behind a person in real time, using an AI portrait-segmentation model. **No GPU required.** It runs at about 25 FPS on an ordinary computer.

![Plugin screenshot](obs.jpg)

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Filter settings](#filter-settings)
- [Building from source](#building-from-source)
- [Project structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [My improvements](#my-improvements)
- [Contributing](#contributing)
- [License and credits](#license-and-credits)

## Features

- AI portrait segmentation on the CPU, no GPU needed.
- Background modes: raw video (filter off), blurred background, custom image, solid colour, or looping video.
- Silhouette controls: threshold, feather blend, smoothing and contour filter.
- English and Simplified Chinese interface.
- Windows installer script (`install.ps1`) that finds OBS automatically.

## Requirements

| Item | Requirement |
|---|---|
| OS | Windows 10/11, 64-bit |
| OBS Studio | 64-bit build (install directory contains `bin\64bit\obs64.exe`) |
| Hardware | Any modern multi-core CPU. No GPU required |
| Permissions | Administrator rights when OBS is under `Program Files` |

## Installation

Download `AI_remove_bg.zip` from [`dist/`](dist/AI_remove_bg.zip). **Close OBS Studio first**, and extract the whole zip before installing.

### Option 1 – Automatic (recommended)

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script looks for OBS in the registry, then in `Program Files` on the OS drive, then on other fixed drives. It asks for administrator rights if needed and copies `data` and `obs-plugins` into the OBS directory.

| Option | Meaning |
|---|---|
| `-ObsPath 'D:\Apps\obs-studio'` | Use this OBS directory instead of auto-detecting |
| `-Force` | Install even if OBS is running (files may be locked) |

### Option 2 – Manual

Copy the `data` and `obs-plugins` folders into your OBS directory, merging with the existing folders:

```powershell
$obs = 'C:\Program Files\obs-studio'
Copy-Item .\data, .\obs-plugins -Destination $obs -Recurse -Force
```

Installed files:

```
<OBS>\obs-plugins\64bit\wx_seg_obs.dll
<OBS>\obs-plugins\64bit\wx_video_seg.dll
<OBS>\data\obs-plugins\wx_seg_obs\bkg.jpg, obs.lic, locale\
```

### Uninstall

Delete the two DLLs and the `<OBS>\data\obs-plugins\wx_seg_obs\` folder listed above.

## Usage

1. Start OBS Studio and add a camera source (for example *Video Capture Device*).
2. Right-click the source and choose **Filters**.
3. Under **Effect Filters**, click **+** and add the AI background filter.
4. Pick a background mode (see [Filter settings](#filter-settings)).
5. Adjust the silhouette sliders until the edge around the person looks clean.

### Choosing a background

| Goal | What to enable |
|---|---|
| Blur the room behind you | **Blur Background** |
| Use a picture | **Virtual Background**, then pick an image under *choose background* |
| Use a flat colour (green screen look) | **Virtual Background**, then set *Background Color* |
| Use a looping video | **Video Background**, then pick a file in its file picker |
| Turn the effect off | **Raw Video** |

The background options are mutually exclusive. Enabling one disables the others.

## Filter settings

| Setting | Description |
|---|---|
| Raw Video | Pass the camera image through without segmentation |
| Blur Background | Blur everything except the person |
| Virtual Background | Replace the background with an image or a solid colour |
| Video Background | Replace the background with a looping video file |
| Threshold | Confidence cut-off for what counts as the person |
| Feather blend silhouette | Softens the edge between person and background |
| Smooth silhouette | Reduces flicker on the outline between frames |
| ContourFilter (% of image) | Removes small stray regions below this share of the image |
| Background Color | Colour used when no image is chosen |

## Building from source

The plugin depends on libobs, the vendor segmentation SDK in `3rd/lh320_windows_1.2.2` and OpenCV in `3rd/opencv`. It is built from inside an OBS plugin template tree.

```powershell
# Package an already compiled plugin
.\build.ps1 -PluginDll C:\path\to\wx_seg_obs.dll

# Configure and build with CMake first
.\build.ps1 -Build -CMakeArgs '-DCMAKE_PREFIX_PATH=C:/obs-deps'
```

`build.ps1` writes `dist\AI_remove_bg.zip` with this layout:

```
obs-plugins/64bit/    wx_seg_obs.dll, wx_video_seg.dll
data/obs-plugins/wx_seg_obs/    bkg.jpg, obs.lic, locale/
install.ps1
README.md
```

## Project structure

```
src/             plugin source (wxsegobs.cpp, plugin-main.cpp)
data/locale/     en-US.ini, zh-CN.ini
3rd/             vendor SDK and OpenCV
package/         README shipped inside the zip
dist/            built AI_remove_bg.zip
build.ps1        packaging script
install.ps1      installer script
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Filter is not listed in OBS | Check the DLLs are in `obs-plugins\64bit` of the OBS you actually run, and restart OBS |
| Install fails with "access denied" | Run PowerShell as administrator, or close OBS and use `-Force` |
| Black output with a custom background | Make sure the image path is valid. The filter now falls back to the original frame if blending fails |
| Low frame rate | Lower the source resolution or close other CPU-heavy apps |

## My improvements

Changes I made on top of the original [aisegmentcn/aisegment_obs_plugin](https://github.com/aisegmentcn/aisegment_obs_plugin):

### Video background (`872104e`)
- New **Video Background** checkbox with its own video file picker.
- The video is decoded on a worker thread with OpenCV, looped, and blended behind the person in place of the still image, so the render path is not blocked by decoding.
- Mutually exclusive with the blur, image and colour options, like the existing modes.
- Added the locale strings for en-US and zh-CN.

### Reliability fix: virtual background after OBS restart (`5d00dee`)
- **Root cause:** custom image and solid colour modes sized the background with an empty blur buffer, so blending failed after a restart and the uninitialised output showed as black.
- Use the real background dimensions when blending.
- Pass the original frame through when blending fails, so the output is never a black buffer.
- Rebuild scalers and buffers when the frame size or pixel format changes.
- Handle a missing or unreadable background image safely, with bounds-checked file reads instead of unchecked allocation.
- Fixed `resizeAndCrop` to crop the resized image instead of the original.
- Clearer checkbox labels: *Raw Video*, *Blur Background*, *Virtual Background* (en-US and zh-CN).

### Packaging and installation (`5d00dee`, `1c93e78`)
- `build.ps1` builds a ready-to-extract zip with the correct OBS directory layout.
- `install.ps1` detects the OBS directory (registry, then OS drive, then other drives), elevates when needed, and supports `-ObsPath` and `-Force`.
- A package-level `README.md` inside the zip with automatic and manual install steps.
- Prebuilt `dist/AI_remove_bg.zip` kept in the repository and rebuilt with each plugin change.

## Contributing

1. Fork the repository and create a branch: `git switch -c feat/my-change`.
2. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`), as in the existing history.
3. Test the filter in OBS with each background mode before opening a pull request.
4. Describe what changed and how you tested it in the pull request.

## License and credits

Released under the [GNU General Public License v2](LICENSE).

The segmentation engine is provided by [aisegment.cn](https://www.aisegment.cn) and ships with its own licence file (`obs.lic`). Original plugin: [aisegmentcn/aisegment_obs_plugin](https://github.com/aisegmentcn/aisegment_obs_plugin).
