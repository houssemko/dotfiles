-- battery-profile.lua
-- Auto-applies low-power settings when running on battery, restores the
-- full settings when plugged in. Mirrors the [Battery] profile in
-- ~/.config/mpv/profiles.conf (that one is for manual use via
-- `mpv --profile=Battery`).
--
-- Change BATTERY_STATUS_FILE if your battery is not named BAT0
-- (check /sys/class/power_supply/).

local BATTERY_STATUS_FILE = "/sys/class/power_supply/BAT0/status"
local POLL_INTERVAL = 10 -- seconds

local battery_values = {
    { "glsl-shaders", {} },          -- remove NVScaler & friends
    { "dither", "ordered" },         -- error-diffusion is heavy on the GPU
    { "temporal-dither", false },
    { "scale", "bilinear" },
    { "cscale", "bilinear" },
    { "dscale", "bilinear" },
    { "framedrop", "vo" },
    { "blend-subtitles", false },
    { "demuxer-readahead-secs", 3 },
    { "demuxer-max-bytes", 64 * 1024 * 1024 },
    { "audio-samplerate", 44100 },
    { "ytdl-format", "bestvideo[height<=?1080][vcodec~=av01]+bestaudio[format_id!*=-drc]/bestvideo[height<=?1080][vcodec*=vp9]+bestaudio[format_id!*=-drc]/bestvideo[height<=?1080]+bestaudio[format_id!*=-drc]/best[height<=?1080]" },
}

local saved = {}
local on_battery = nil
local timer_handle = nil

local function is_on_battery()
    local f = io.open(BATTERY_STATUS_FILE, "r")
    if not f then return nil end
    local status = f:read("*l")
    f:close()
    return status == "Discharging"
end

local function apply(list)
    for _, pair in ipairs(list) do
        mp.set_property_native(pair[1], pair[2])
    end
end

local function check()
    local battery = is_on_battery()
    if battery == nil then
        if timer_handle then
            timer_handle:stop()
            timer_handle = nil
        end
        return
    end
    if battery and not on_battery then
        on_battery = true
        apply(battery_values)
        mp.osd_message("On battery: power-saver settings applied", 2)
    elseif not battery and on_battery then
        on_battery = false
        apply(saved)
        mp.osd_message("On AC: full settings restored", 2)
    end
end

mp.add_timeout(1, function()
    if is_on_battery() == nil then return end
    for _, pair in ipairs(battery_values) do
        local v = mp.get_property_native(pair[1])
        if v ~= nil then
            saved[#saved + 1] = { pair[1], v }
        end
    end
    check()
    timer_handle = mp.add_periodic_timer(POLL_INTERVAL, check)
end)
