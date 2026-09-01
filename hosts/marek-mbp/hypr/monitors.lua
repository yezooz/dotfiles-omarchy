-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- The AMD dGPU exposes a phantom "eDP-2" connector: it reports as connected but
-- has no EDID and no modes (it is the internal panel seen through the gmux, not
-- a real second screen). Hyprland treats it as a monitor and parks workspace 2
-- on it, which makes SUPER+2 focus an invisible display.
-- Disabling it by name is safe: eDP is embedded-only, so external monitors
-- (DP-*/HDMI-A-*) still get picked up by the catch-all rule above.
hl.monitor({ output = "eDP-2", disabled = true })
