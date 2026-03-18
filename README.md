# "Hypr"LongShot 

This is my custom-built scrolling screenshot tool designed specifically for `Hyprland`. 

This tool combines a `bash` script for workflow management, a `C` program (`raylib`) for drawing the recording overlay, and a `Python` program (OpenCV) for stitching the video frames into a signle long image.

## Disclaimer

This is NOT a universal, plug-and-play `Wayland` tool. I built this primarily to suit my personal `archlinux` + `Hyprland` setup. Please read the following before `git clone`.

1. **Hyprland Exclusive:** Parts of the program relie on `hyprctl` commands to position the recording overlay (`longshot_overlay`). It will not originally work on `Sway`, `Niri`, `GNOME` or `KDE Wayland`.
2. **Waybar Integration:** The `bash` scripts `longshot.sh` contains hardcoded signals (`pkill -RTMIN+8 waybar`) to update `waybar` modules. **You may need to comment out or modify these lines in `longshot.sh` if you don't use this specific Waybar setup.**
3. **Hardcoded Paths:** Captured images are saved to `$HOME/Pictures/longshots/`. Ensure this path works for you.

## Dependencies

Before installing, make sure you have the following system packages installed (names may vary depending on your distro, below are for `archlinux`):

* `slurp` (selecting the area)
* `wf-recorder` (capturing the scrolling video)
* `libnotify` (for `notify-send` notifications)
* `raylib` (required to compile `C` overlay)
* `python`, `python-pip`, `python-venv` (for the stitching logic)

## Installation and setup

### Clone the repository

```bash
git clone https://github.com/Horizon0427/hypr-longshot.git
cd hypr-longshot
``` 
### Compile the C Overlay

```bash
gcc overlay.c -o longshot_overlay -lraylib -lGL -lm -lpthread -ldl -lrt -lX11
```
### Set up Python Virtual Environment
The image stitching uses OpenCV. To keep your system clean, the script is configured to use a local `.venv`:
```bash
python -m venv .venv
```
```bash
source .venv/bin/activate
```
### Make the script exeutable
```bash
chmod +x longshot.sh
```

## Usage

add this in `~/.config/hypr/hyprland.conf`:
```
windowrule {
    name = longshot-overlay-rules
    match:class = ^(longshot_overlay)$
    float = true
    border_size = 0
    rounding = 0
    no_blur = true
    no_shadow = true
    no_initial_focus = true
    no_focus = true
    pin = true
    suppress_event = activatefocus maximize fullscreen
}
```
to activate `waybar`, check my configuration in the repository `Arch-config`.

**How to capture:**
1. run `longshot.sh`
2. select the area you want to capture
3. Slowly scroll down the page you want to capture.
4. Click the button in `waybar` or press any key in the running terminal to stop
5. wait a seconds for the stitching work.

**How it works**
1. `longshot.sh` triggers `slurp` to get geometry.
2. It starts `wf-recorder` to record that specific region into a temporary `/tmp/longshot_temp.mp4`.
3. It dispatches a `raylib` C window (`longshot_overlay`) via `hyprctl` to strictly cover the selected area with a blinking red border.
4. Once recording stops, the Python script (`stitcher.py`) reads the video, analyzes frame movements using OpenCV's template matching (`cv2.matchTemplate`), and perfectly stitches the unique parts together into a `PNG`.

## Known Bugs & Quirks

**Waybar Cold Start Issue**
When triggering the screenshot tool via a custom Waybar module right after a system boot or a Waybar "cold start", the script might occasionally misbehave on the very first attempt.

* **Symptoms:** The red recording overlay window might spawn out of place , or the left-click action to stop the recording might become unresponsive.
* **Workaround:** Simply reload/refresh Waybar or try triggering the script one more time. The tool typically stabilizes and works after this initial hiccup.

https://github.com/user-attachments/assets/76bef915-ea18-46d6-a734-45ba7eff75c2
