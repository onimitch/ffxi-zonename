-- This is an addon for Ashita v4 that displays zone and region names
-- with fading effects. It is a port of Windowers zonename addon.
-- Original code by [sylandro].

-- Define addon information
addon.name = 'zonename'
addon.author = 'Xenonsmurf. Japanese support and other improvements by onimitch.'
addon.version = '2.1'
addon.desc = 'Displays the zone and region name for a short time while changing zones.'
addon.link = 'https://github.com/onimitch/ffxi-zonename'

-- Import necessary modules and libraries
require('common')  -- Import a common utility module
local chat = require("chat")
local settings = require('settings')  -- Module for managing settings
local gdi = require('gdifonts.include')
local encoding = require('gdifonts.encoding')

local scaling = require('scaling')
local screenCenter = {
    x = scaling.window.w / 2,
    y = scaling.window.h / 2,
}

-- Zone name settings and objects
local zonename = {
    visible = false,
    zone_name_text = nil,
    region_name_text = nil,
    lang_id = 'en',
    fade_start_time = nil,

    regions = require("regions"),
    region_zones = require("regionZones"),

    -- Settings defaults
    defaults = T{
        fade_after = 5,
        fade_duration = 1,
        zone_name = {
            font_alignment = gdi.Alignment.Center,
            font_color = 0xFFFFD700,
            font_family = 'Calibri', -- This could be Arial but we need to use a font that is most likely installed by default
            font_flags = gdi.FontFlags.Bold,
            font_height = 50,
            outline_color = 0xFF0041AB,
            outline_width = 2,
            position_x = screenCenter.x,
            position_y = screenCenter.y - 340,
        },
        region_name = {
            font_alignment = gdi.Alignment.Center,
            font_color = 0xFFFFD700,
            font_family = 'Calibri', -- This could be Arial but we need to use a font that is most likely installed by default
            font_flags = gdi.FontFlags.Bold,
            font_height = 20,
            outline_color = 0xFF0041AB,
            outline_width = 2,
            position_x = screenCenter.x,
            position_y = screenCenter.y - 370,
        },
    },
}

-- Function to get the region name by region ID
local function getRegionNameById(id)
    for _, region in pairs(zonename.regions) do
        if region.id == id then
            return region[zonename.lang_id]
        end
    end
    return nil
end

-- Function to get the region ID by zone ID
local function getRegionIDByZoneID(zoneID)
    for regionID, zoneIDs in pairs(zonename.region_zones.map) do
        for _, id in ipairs(zoneIDs) do
            if id == zoneID then
                return regionID
            end
        end
    end
    return nil
end

local function onZoneChange()
    local currentZoneID = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local currentZoneName = encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', currentZoneID), true)  -- Get the current zone name
    local regionID = getRegionIDByZoneID(currentZoneID)  -- Get the region ID based on the zone ID
    local currentRegionName = getRegionNameById(regionID)  -- Get the region name based on the region ID
    if currentRegionName then
        zonename.visible = true

        zonename.zone_name_text:set_text(currentZoneName)
        zonename.region_name_text:set_text(currentRegionName)
    else
        print(chat.header(addon.name):append(chat.error('Unrecognised region. RegionZones data may need to be updated. Region ID: "%s", Zone ID: "%s"'):format(regionID, currentZoneID)))
    end
end

-- Update the fade effect
local function updateFade()
    local maxAlpha = 1 -- Set the maximum alpha to fully visible
    local minAlpha = 0 -- Set the minimum alpha to fully transparent
    local fadeDuration = zonename.settings.fade_duration -- Total duration for fading out in seconds
    local fadeAfter = zonename.settings.fade_after

    if zonename.fade_start_time == nil then
        zonename.fade_start_time = os.clock() -- Record the start time of the fade
        zonename.zone_name_text:set_visible(true)
        zonename.region_name_text:set_visible(true)
    end

    local elapsed = math.max(0, os.clock() - zonename.fade_start_time - fadeAfter)
    local alpha = maxAlpha - (maxAlpha * (elapsed / fadeDuration))

    -- Ensure alpha doesn't go below the minimum value
    alpha = math.max(alpha, minAlpha)

    -- Set the updated alpha
    zonename.zone_name_text:set_opacity(alpha)
    zonename.region_name_text:set_opacity(alpha)

    -- Reset fading when it's fully faded out
    if alpha == minAlpha then
        zonename.fade_start_time = nil
        zonename.visible = false
        zonename.zone_name_text:set_visible(false)
        zonename.region_name_text:set_visible(false)
    end
end

local function initialise()
    if zonename.zone_name_text ~= nil then
        gdi:destroy_object(zonename.zone_name_text)
    end
    if zonename.region_name_text ~= nil then
        gdi:destroy_object(zonename.region_name_text)
    end

    zonename.zone_name_text = gdi:create_object(zonename.settings.zone_name)  -- Create a font object for zone name display
    zonename.region_name_text = gdi:create_object(zonename.settings.region_name)  -- Create a font object for region name display

    -- Check if font is available, otherwise it won't render
    local zone_font_family = zonename.settings.zone_name.font_family
    if not gdi:get_font_available(zone_font_family) then
        zonename.zone_name_text:set_font_family('Arial')
        print(chat.header(addon.name):append(chat.error('Font not available: %s, reverting to Arial.'):format(zone_font_family)))
    end
    local region_font_family = zonename.settings.region_name.font_family
    if not gdi:get_font_available(region_font_family) then
        zonename.region_name_text:set_font_family('Arial')
        if zone_font_family ~= region_font_family then
            print(chat.header(addon.name):append(chat.error('Font not available: %s, reverting to Arial.'):format(region_font_family)))
        end
    end

    zonename.zone_name_text:set_visible(false)
    zonename.region_name_text:set_visible(false)
end

-- Register events to load and unload the addon
ashita.events.register('load', 'zonename_load', function()
    zonename.settings = settings.load(zonename.defaults)  -- Load settings with default values

    -- Get language
    local lang = AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2)
    zonename.lang_id = 'en'
    if lang == 1 then
        zonename.lang_id = 'ja'

    end

    initialise()
end)

ashita.events.register('unload', 'zonename_unload', function()
    gdi:destroy_interface()
end)

-- Register a packet_in event to handle zone change information
ashita.events.register('packet_in', 'zonename_packet_in', function(event)
    if event.id == 0x0A then  -- Check if it's a zone change packet
        local moghouse = struct.unpack('b', event.data, 0x80 + 1)
        if moghouse ~= 1 then
            coroutine.sleep(1)
            onZoneChange()
        end
    end
end)

ashita.events.register('command', 'zonename_command', function (e)
    -- Parse the command arguments..
    local args = e.command:args()
    if (#args == 0 or args[1] ~= '/zonename') then
        return
    end

    -- Block all zonename related commands..
    e.blocked = true

    -- Handle: /zonename (reload | rl) - Reloads the settings from disk.
    if (#args == 2 and args[2]:any('reload', 'rl')) then
        settings.reload()
        print(chat.header(addon.name):append(chat.message('Settings reloaded from disk.')))
        onZoneChange()
        return
    end

    -- Handle: /zonename test - Force display the zone info.
    if (#args == 2 and args[2]:any('test')) then
        onZoneChange()
        return
    end
end)

-- Register a d3d_present event to display the OSD elements
ashita.events.register('d3d_present', 'zonename_present', function()
    if zonename.visible then
        updateFade()
    end
end)

local function update_settings(s)
    if (s ~= nil) then
        zonename.settings = s
    end
    settings.save()
    initialise()
end

-- Registers a callback for the settings to monitor for character switches.
settings.register('settings', 'settings_update', update_settings)
