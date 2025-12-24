addon.name = 'switchcharacter'
addon.version = '0.01'
addon.author = 'looney'

require 'common'
local imgui = require('imgui')
local chat = require('chat')
local account = require('ffxi.account')
local jobs = require('data.jobs')
local zones = require('data.zones')

local characters = {}
local ui = {
    visible = { false },
}

local function loadCharacters()
    characters = {}
    local count = account.get_character_count()

    for i = 0, count - 1 do
        local id = account.get_login_ffxi_id(i)
        local name = account.get_login_character_name(i)
        local world = account.get_login_world_name(i)
        local cinfo = account.get_login_character_info(i)

        local job = jobs[cinfo.mjob_no] or 'UNK'
        local level = cinfo.mjob_level
        local zone = zones[cinfo.zone_no].en or 'Unknown'
        local playtime = cinfo.PlayTime
        local days = math.floor(playtime / 86400)
        local hours = math.floor((playtime % 86400) / 3600)

        table.insert(characters, {
            id = id,
            name = name,
            world = world or 'Unknown',
            job = job,
            level = level,
            zone = zone,
            playtime_str = string.format('%dd %dh', days, hours)
        })
    end
end

local function switchCharacter(index)
    local tblIndex = (index or 0) + 1
    local c = characters and characters[tblIndex] or nil
    if c ~= nil then
        print(chat.header(addon.name):append(chat.color2(200, (string.format(
            'Switching to character %d : %s (%s)', index, c.name, c.world)))))
    end

    AshitaCore:GetChatManager():QueueCommand(1, string.format('/autologin %d', index))
    AshitaCore:GetChatManager():QueueCommand(1, string.format('/logout', index))
end

local function drawUI()
    if not ui.visible[1] then
        return
    end

    local center = imgui.GetMainViewport():GetCenter()
    imgui.SetNextWindowPos({ center.x, center.y }, ImGuiCond_Always, { 0.5, 0.5 })
    imgui.SetNextWindowSizeConstraints({ 300, 100 }, { 300, 400 })

    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0)
    local windowFlags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground)
    if imgui.Begin('Switch character', ui.visible, windowFlags) then
        local buttonHeight = 60
        local spacing = 4
        local closeButtonHeight = 32
        local maxWindowHeight = 400
        local totalButtonsHeight = (#characters * buttonHeight) + ((#characters - 1) * spacing) + 10
        local maxListHeight = maxWindowHeight - closeButtonHeight - 30
        local listHeight = math.min(maxListHeight, math.max(70, totalButtonsHeight))

        if imgui.BeginChild('CharList', { -1, listHeight }, ImGuiChildFlags_None, ImGuiWindowFlags_NoBackground) then
            imgui.PushStyleVar(ImGuiStyleVar_CellPadding, { 0, 0 })
            imgui.PushStyleColor(ImGuiCol_Header, { 0.1, 0.1, 0.1, 0.8 })
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.15, 0.15, 0.15, 0.6 })
            imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.15, 0.15, 0.15, 0.9 })
            imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.8 })
            imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1.0)

            for i, character in ipairs(characters) do
                if imgui.Selectable(string.format('##character%d', i), true, ImGuiSelectableFlags_None, { 0, buttonHeight }) then
                    switchCharacter(i - 1)
                    ui.visible[1] = false
                end

                imgui.SameLine(8)
                imgui.BeginGroup()
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
                imgui.Text(character.name)
                imgui.PopStyleColor(1)
                imgui.SameLine()
                imgui.PushStyleColor(ImGuiCol_Text, { 0.7, 0.7, 0.7, 1.0 })
                imgui.Text(string.format('- %s', character.world))
                imgui.PopStyleColor(1)

                imgui.PushStyleColor(ImGuiCol_Text, { 0.6, 0.6, 0.6, 1.0 })
                imgui.Text(string.format('%s Lv.%d', character.job, character.level))
                imgui.PopStyleColor(1)

                imgui.PushStyleColor(ImGuiCol_Text, { 0.5, 0.5, 0.5, 1.0 })
                imgui.Text(string.format('%s | %s', character.zone, character.playtime_str))
                imgui.PopStyleColor(1)
                imgui.EndGroup()
            end

            imgui.PopStyleVar(2)
            imgui.PopStyleColor(4)
        end
        imgui.EndChild()

        local availX = imgui.GetContentRegionAvail()
        if imgui.Button('Close', { availX, 28 }) then
            ui.visible[1] = false
        end
    end
    imgui.PopStyleVar(1)
    imgui.End()
end

ashita.events.register('command', 'command_cb', function(cmd, nType)
    if (cmd == nil or cmd.command == nil) then
        return false
    end

    local args = cmd.command:args()
    if (#args == 0) then
        return false
    end

    local command = string.lower(args[1])
    if (command == '/switchcharacter' or command == '/sw') then
        if args[2] == nil then
            ui.visible[1] = not ui.visible[1]
            return true
        else
            local charIndex = tonumber(args[2])
            if charIndex ~= nil and charIndex >= 0 and charIndex <= (#characters - 1) then
                switchCharacter(charIndex)
                return true
            else
                print(chat.header(addon.name):append(chat.error('Invalid character index')))
                return true
            end
        end
    end

    return false
end)

ashita.events.register('load', 'load_cb', function()
    loadCharacters()
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function()
    drawUI()
end)

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if e.id == 0x00A then
        loadCharacters()
    end
end)
