-- Personal keybindings, loaded after Omarchy's defaults.
--
-- Rebinding a key Omarchy already uses requires hl.unbind() first. Check with:
--   omarchy menu keybindings --print

-- Jump straight to an app: focus its window if one exists, launch it if not.
-- Ported from the Hammerspoon config that did the same on macOS with alt+1/2/3.
-- Plain ALT + digit is unused by Omarchy, so no unbind is needed.
o.bind("ALT + 1", "Terminal", "omarchy-launch-or-focus ghostty")
o.bind("ALT + 2", "Browser", "omarchy-launch-or-focus chromium")

-- Slack is not installed yet; this binding starts working once it is.
o.bind("ALT + 3", "Slack", "omarchy-launch-or-focus slack")
