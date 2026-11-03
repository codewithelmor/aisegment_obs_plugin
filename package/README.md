# AI_remove_bg – OBS Studio plugin

Blurs or replaces the background of portrait video with an AI segmentation model. No GPU required.

Package contents:

```
install.ps1                      automatic installer
obs-plugins/64bit/               wx_seg_obs.dll, wx_video_seg.dll
data/obs-plugins/wx_seg_obs/     bkg.jpg, obs.lic, locale/
```

**Close OBS Studio before installing.** Extract the whole zip first (do not run the script from inside the zip).

## Option 1 – Automatic (install.ps1)

1. Extract `AI_remove_bg.zip` to any folder.
2. Open PowerShell in that folder (Shift + right-click > *Open in Terminal*).
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

The script finds the OS drive and the OBS Studio directory (registry, then `Program Files` on the OS drive, then other fixed drives), asks for administrator rights if needed, and copies `data` and `obs-plugins` into it.

Options:

| Option | Meaning |
|---|---|
| `-ObsPath 'D:\Apps\obs-studio'` | Use this OBS directory instead of auto-detecting |
| `-Force` | Install even if OBS is running (files may be locked) |

## Option 2 – Manual copy

1. Extract the zip.
2. Find your OBS directory, the folder that contains `bin\64bit\obs64.exe`. Usually `C:\Program Files\obs-studio`.
3. Copy the `data` and `obs-plugins` folders into the OBS directory, merging with the existing folders and overwriting if asked. Administrator rights are required for `Program Files`.

   Or from an elevated PowerShell:

   ```powershell
   $obs = 'C:\Program Files\obs-studio'
   Copy-Item .\data, .\obs-plugins -Destination $obs -Recurse -Force
   ```

Resulting files:

```
<OBS>\obs-plugins\64bit\wx_seg_obs.dll
<OBS>\obs-plugins\64bit\wx_video_seg.dll
<OBS>\data\obs-plugins\wx_seg_obs\bkg.jpg
<OBS>\data\obs-plugins\wx_seg_obs\obs.lic
<OBS>\data\obs-plugins\wx_seg_obs\locale\en-US.ini, zh-CN.ini
```

## Verify

Start OBS, right-click a video source > *Filters* > add the AI background filter.

## Uninstall

Delete the `<OBS>\obs-plugins\64bit\wx_seg_obs.dll`, `<OBS>\obs-plugins\64bit\wx_video_seg.dll` and `<OBS>\data\obs-plugins\wx_seg_obs\` entries listed above.
