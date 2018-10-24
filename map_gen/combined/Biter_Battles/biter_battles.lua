-- Factorio Biter Battles -- mewmew made this --

--[[
To do(maybe):
flamethrower things
]]--

local biter_battles_terrain = require 'map_gen.combined.Biter_Battles.biter_battles_terrain'
local Event = require 'utils.event'

local round = math.round
local random = math.random
local ceil = math.ceil
local floor = math.floor
local insert = table.insert

local enemy_force
local north_team
local south_team

local battle_surface

local function get_border_cords(enemy_team, surface)
    local area = {{-1000, -1000}, {1000, -10}}
    if enemy_team == "south" then area = {{-1000, 10}, {1000, 1000}} end

    local entities = surface.find_entities_filtered{ area=area, force=enemy_team }

    if not entities then return end

    local first_entity_position = entities[1].position

    local x_top = first_entity_position.x;
    local y_top = first_entity_position.y;
    local x_bot = first_entity_position.x;
    local y_bot = first_entity_position.y

    for _, e in pairs(entities) do
        local x = e.position.x
        local y = e.position.y
        if x < x_top then x_top = x end
        if y < y_top then y_top = y end
        if x > x_bot then x_bot = x end
        if y > y_bot then y_bot = y end
    end

    global.force_area[enemy_team] = {
        x_top = x_top,
        y_top = y_top,
        x_bot = x_bot,
        y_bot = y_bot,
    }
end

local function create_biter_battle_sprite_button(player)
    local top_gui = player.gui.top
    if not top_gui.biter_battle_toggle_menu_button then
        local button = top_gui.add { name = "biter_battle_toggle_menu_button", type = "sprite-button", sprite = "entity/behemoth-spitter" }
        button.style.font = "default-bold"
        button.style.minimal_height = 38
        button.style.minimal_width = 38
        button.style.top_padding = 2
        button.style.left_padding = 4
        button.style.right_padding = 4
        button.style.bottom_padding = 2
    end
end

local function create_join_button(frame, team)
    local team_name = team.name
    local caption = "JOIN " .. team_name:upper()
    local font_color = { r=0.98, g=0.0, b=0.0}
    if global.game_lobby_active then
        local time_seconds = round( (global.game_lobby_timeout - game.tick) / 60,0)
        font_color = { r=0.7, g=0.7, b=0.7}
        caption = string.format("%s (waiting for players... %s)", caption, time_seconds)
    end
    local tbl = frame.add  { type = "table", column_count = 4 }
    for _, player in pairs(team.connected_players) do
        local color = {}
        color = player.color
        color.r = color.r * 0.6 + 0.4
        color.g = color.g * 0.6 + 0.4
        color.b = color.b * 0.6 + 0.4
        color.a = 1
        local label = tbl.add  { type = "label", caption = player.name }
        label.style.font_color = color
    end
    local button = frame.add  { type = "button", name = "join_"  ..  team.name .. "_button", caption = caption }
    button.style.font = "default-frame"
    button.style.font_color = font_color
    button.style.minimal_width = 320
end

local function create_team_info_labels(frame, team, player_index, show_info)
    local tbl = frame.add { type = "table", column_count = 3 }
    local team_name = team.name
    local capital_team_name = team_name:gsub("^%l", string.upper)
    local team_name_label = tbl.add  { type = "label", caption = "Team " .. capital_team_name}
    team_name_label.style.font = "default-bold"
    team_name_label.style.font_color = { r=0.98, g=0.66, b=0.22}
    tbl.add  { type = "label", caption = "  -  "}
    local player_n_label = tbl.add  { type = "label", caption = #team.connected_players .. " Players "}
    player_n_label.style.font_color = { r=0.22, g=0.88, b=0.22}

    if show_info then
        if global.biter_battle_view_players[player_index]  then
            local tbl = frame.add  { type = "table", column_count = 4 }
            for _, p in pairs(team.connected_players) do
                game.print(p.name)
                local color = {}
                color = p.color
                color.r = color.r * 0.6 + 0.4
                color.g = color.g * 0.6 + 0.4
                color.b = color.b * 0.6 + 0.4
                color.a = 1
                local label = tbl.add  { type = "label", caption = p.name }
                label.style.font_color = color
            end
        end

        local tbl = frame.add { type = "table", column_count = 4 }
        local nerf_label = tbl.add  { type = "label", caption = "Nerf: "}
        nerf_label.tooltip = "Damage nerf of the team."
        nerf_label.style.minimal_width = 25
        local nerf_amount_label = tbl.add  { type = "label", caption = round(global.team_nerf[team_name]*100,1) .. " "}
        nerf_amount_label.style.minimal_width = 40
        nerf_amount_label.style.font_color = { r=0.90, g=0.1, b=0.1}
        nerf_amount_label.style.font = "default-bold"
        local rage_label = tbl.add  { type = "label", caption = " Biter Rage: "}
        rage_label.style.minimal_width = 25
        rage_label.tooltip = "Increases damage and the amount of angry biters."
        local rage_amount_label = tbl.add  { type = "label", caption = round(global.biter_rage[team_name], 0)}
        rage_amount_label.style.font_color = { r=0.90, g=0.1, b=0.1}
        rage_amount_label.style.font = "default-bold"
        rage_amount_label.style.minimal_width = 25
    end
end

local function create_biter_battle_menu(player)
    local left_gui = player.gui.left
    if global.rocket_silo_destroyed then
        local frame = left_gui.add { type = "frame", name = "victory_popup", direction = "vertical" }
        local label = frame.add { type = "label", caption = global.rocket_silo_destroyed , single_line = false, name = "victory_caption" }
        label.style.font = "default-frame"
        label.style.font_color = { r=0.98, g=0.66, b=0.22}
        label.style.top_padding = 10
        label.style.left_padding = 20
        label.style.right_padding = 20
        c.style.bottom_padding = 10
        return
    end

    local force_name = player.force.name
    local player_name = player.name
    local player_index = player.index
    local frame = left_gui.add { type = "frame", name = "biter_battle_menu", direction = "vertical" }

    if force_name == "north" or force_name == "south" then
        frame.add { type = "table", name = "biter_battle_table", column_count = 4 }
        local t = frame.biter_battle_table
        local foods = {"science-pack-1","science-pack-2","military-science-pack","science-pack-3","production-science-pack","high-tech-science-pack","space-science-pack","raw-fish"}
        local food_tooltips = {"1 Calorie","3 Calories", "20 Calories", "38 Calories", "80 Calories", "210 Calories", "420 Calories", "Send spy"}
        local x = 1
        for _, f in pairs(foods) do
            local s = t.add { type = "sprite-button", name = f, sprite = "item/" .. f }
            s.tooltip = {"",food_tooltips[x]}
            x = x + 1
        end
    end
    if force_name == "player" then
        local b = frame.add  { type = "label", caption = "Defend your team´s rocket silo!" }
        b.style.font = "default-bold"
        b.style.font_color = { r=0.98, g=0.66, b=0.22}
        local b = frame.add  { type = "label", caption = "Feed the enemy team´s biters to gain advantage!" }
        b.style.font = "default-bold"
        b.style.font_color = { r=0.98, g=0.66, b=0.22}
        frame.add  { type = "label", caption = "--------------------------------------------------"}
    end

    create_team_info_labels(frame, north_team, player_index, force_name ~= "player")

    if force_name == "player" then
        create_join_button(frame, north_team)
        frame.add  { type = "label", caption = "--------------------------------------------------"}
    else
        frame.add  { type = "label", caption = "--------------------------"}
    end

    create_team_info_labels(frame, south_team, player_index, force_name ~= "player")

    if force_name == "player" then
        create_join_button(frame, south_team)
    end

    if global.team_chosen[player_index] then
        local t = frame.add  { type = "table", column_count = 2 }
        if force_name == "spectator" then
            local b = t.add  { type = "button", name = "biter_battle_leave_spectate", caption = "Leave spectating" }
            b.style.font = "default-bold"
            b.style.font_color = { r=0.98, g=0.66, b=0.22}
            b.style.top_padding = 1
            b.style.left_padding = 1
            b.style.right_padding = 1
            b.style.bottom_padding = 1
        else
            local b = t.add  { type = "button", name = "biter_battle_spectate", caption = "Spectate" }
            b.style.font = "default-bold"
            b.style.font_color = { r=0.98, g=0.66, b=0.22}
            b.style.top_padding = 1
            b.style.left_padding = 1
            b.style.right_padding = 1
            b.style.bottom_padding = 1
        end

        if global.biter_battle_view_players[player_index]  then
            local b = t.add  { type = "button", name = "biter_battle_hide_players", caption = "Hide players" }
            b.style.font = "default-bold"
            b.style.font_color = { r=0.98, g=0.66, b=0.22}
            b.style.top_padding = 1
            b.style.left_padding = 1
            b.style.right_padding = 1
            b.style.bottom_padding = 1
        else
            local b = t.add  { type = "button", name = "biter_battle_view_players", caption = "View players" }
            b.style.font = "default-bold"
            b.style.font_color = { r=0.98, g=0.66, b=0.22}
            b.style.top_padding = 1
            b.style.left_padding = 1
            b.style.right_padding = 1
            b.style.bottom_padding = 1
        end
    end
end

local function refresh_gui()
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.left["biter_battle_menu"]
        if (frame) then
            frame.destroy()
            create_biter_battle_menu(player)
        end
    end
end

local function join_team(player, team)
    local player_name = player.name
    local player_index = player.index
    local enemy_team = "south"
    if team == "south" then
        enemy_team = "north"
    end

    if team == "north" or team == "south" then
        if #game.forces[team].connected_players > #game.forces[enemy_team].connected_players and not global.team_chosen[player_index] then
            player.print("Team " .. team .. " has too many players currently.", { r=0.98, g=0.66, b=0.22})
        else
            player.teleport(battle_surface.find_non_colliding_position("player", game.forces[team].get_spawn_position(battle_surface), 3, 1))
            player.force=game.forces[team]
            if global.team_chosen[player_index] then
                local p = game.permissions.get_group("Default")
                p.add_player(player_name)
                game.print("Team " .. player.force.name .. " player " .. player_name .. " is no longer spectating.", { r=0.98, g=0.66, b=0.22})
            else
                game.print(player_name .. " has joined team " .. player.force.name .. "!", { r=0.98, g=0.66, b=0.22})
                local main_inventory = player.get_inventory(defines.inventory.player_main)
                main_inventory.clear()
                local quick_bar = player.get_inventory(defines.inventory.player_quickbar)
                quick_bar.clear()
                player.insert {name = 'pistol', count = 1}
                player.insert {name = 'raw-fish', count = 3}
                player.insert {name = 'firearm-magazine', count = 16}
                player.insert {name = 'iron-gear-wheel', count = 4}
                player.insert {name = 'iron-plate', count = 8}
                global.team_chosen[player_index] = team
            end
        end
    end

    if team == "spectator" then
        player.teleport(battle_surface.find_non_colliding_position("player", {0,0}, 2, 1))
        player.force=game.forces[team]
        game.print(player_name .. " is spectating.", { r=0.98, g=0.66, b=0.22})
        local permission_group = game.permissions.get_group("spectator")
        if not permission_group then
            permission_group = game.permissions.create_group("spectator")
            for action_name, _ in pairs(defines.input_action) do
                permission_group.set_allows_action(defines.input_action[action_name], false)
            end
            permission_group.set_allows_action(defines.input_action.write_to_console, true)
            permission_group.set_allows_action(defines.input_action.gui_click, true)
            permission_group.set_allows_action(defines.input_action.start_walking, true)
            permission_group.set_allows_action(defines.input_action.open_kills_gui, true)
            permission_group.set_allows_action(defines.input_action.open_character_gui, true)
            permission_group.set_allows_action(defines.input_action.open_equipment_gui, true)
            permission_group.set_allows_action(defines.input_action.edit_permission_group, true)
            permission_group.set_allows_action(defines.input_action.edit_permission_group, true)
            permission_group.set_allows_action(defines.input_action.toggle_show_entity_info, true)
        end
        permission_group.add_player(player_name)
        global.spectator_spam_protection[player_name] = game.tick
    end
    refresh_gui()
end

local function reveal_team(f)
    local m = 32
    if f == "north" then
        south_team.chart(battle_surface, {{x = global.force_area[f].x_top-m, y = global.force_area[f].y_top-m}, {x = global.force_area[f].x_bot+m, y = global.force_area[f].y_bot+m}})
    else
        north_team.chart(battle_surface, {{x = global.force_area[f].x_top-m, y = global.force_area[f].y_top-m}, {x = global.force_area[f].x_bot+m, y = global.force_area[f].y_bot+m}})
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    if not global.horizontal_border_width then global.horizontal_border_width = 16 end
    if not global.biter_battles_init_done then
        local map_gen_settings = {}
        map_gen_settings.water = "none"
        map_gen_settings.cliff_settings = {cliff_elevation_interval = 18, cliff_elevation_0 = 18}
        map_gen_settings.autoplace_controls = {
            ["coal"] = {frequency = "normal", size = "normal", richness = "normal"},
            ["stone"] = {frequency = "normal", size = "normal", richness = "normal"},
            ["copper-ore"] = {frequency = "high", size = "very-big", richness = "normal"},
            ["iron-ore"] = {frequency = "high", size = "very-big", richness = "normal"},
            ["crude-oil"] = {frequency = "very-high", size = "very-big", richness = "good"},
            ["trees"] = {frequency = "normal", size = "small", richness = "normal"},
            ["enemy-base"] = {frequency = "normal", size = "very-big", richness = "good"}
        }
        battle_surface = game.create_surface("battle_surface", map_gen_settings)

        game.map_settings.enemy_evolution.time_factor = 0.000005
        game.map_settings.enemy_evolution.destroy_factor = 0.004
        game.map_settings.enemy_evolution.pollution_factor = 0.000025
        game.map_settings.enemy_expansion.enabled = true
        game.map_settings.enemy_expansion.min_expansion_cooldown = 14400
        game.map_settings.enemy_expansion.max_expansion_cooldown = 72000

        local create_force = game.create_force
        enemy_force = game.forces.enemy
        north_team = create_force("north")
        south_team = create_force("south")
        local spectator_team = create_force("spectator")

        --game.create_force("map_pregen")
        global.game_lobby_active = true
        global.game_lobby_timeout = 599940
        global.biter_battle_view_players = {}
        global.spectator_spam_protection = {}
        global.force_area = {}

        north_team.technologies["artillery-shell-range-1"].enabled = false
        south_team.technologies["artillery-shell-range-1"].enabled = false
        north_team.technologies["artillery-shell-speed-1"].enabled = false
        south_team.technologies["artillery-shell-speed-1"].enabled = false
        north_team.technologies["atomic-bomb"].enabled = false
        south_team.technologies["atomic-bomb"].enabled = false
        game.forces["spectator"].technologies["toolbelt"].researched=true

        global.team_chosen = {}
        global.team_nerf = {
            ["north"] = 0,
            ["south"] = 0,
        }
        global.biter_rage = {
            ["north"] = 0,
            ["south"] = 0,
        }
        global.biter_fragmentation = {
            [1] = {"medium-biter","small-biter",3,5},
            [2] = {"big-biter","medium-biter",2,2},
            [3] = {"behemoth-biter","big-biter",2,2},
        }
        global.biter_building_inhabitants = {
            [1] = {{"small-biter",8,16}},
            [2] = {{"small-biter",12,24}},
            [3] = {{"small-biter",8,16},{"medium-biter",1,2}},
            [4] = {{"small-biter",4,8},{"medium-biter",4,8}},
            [5] = {{"small-biter",3,5},{"medium-biter",8,12}},
            [6] = {{"small-biter",3,5},{"medium-biter",5,7},{"big-biter",1,2}},
            [7] = {{"medium-biter",6,8},{"big-biter",3,5}},
            [8] = {{"medium-biter",2,4},{"big-biter",6,8}},
            [9] = {{"medium-biter",2,3},{"big-biter",7,9}},
            [10] = {{"big-biter",4,8},{"behemoth-biter",3,4}},
        }

        north_team.set_turret_attack_modifier("flamethrower-turret", -0.75)
        south_team.set_turret_attack_modifier("flamethrower-turret", -0.75)
        north_team.set_ammo_damage_modifier("artillery-shell", -0.95)
        south_team.set_ammo_damage_modifier("artillery-shell", -0.95)
        north_team.set_ammo_damage_modifier("shotgun-shell", 0.5)
        south_team.set_ammo_damage_modifier("shotgun-shell", 0.5)

        global.food_names = {
            ["science-pack-1"] = "red science",
            ["science-pack-2"] = "green science",
            ["military-science-pack"] = "military science",
            ["science-pack-3"] = "blue science",
            ["production-science-pack"] = "production science",
            ["high-tech-science-pack"] = "high tech science",
            ["space-science-pack"] = "space science",
        }

        global.food_values = {
            ["science-pack-1"] = 0.00000100,
            ["science-pack-2"] = 0.00000292,
            ["military-science-pack"] = 0.00001950,
            ["science-pack-3"] = 0.00003792,
            ["production-science-pack"] = 0.00008000,
            ["high-tech-science-pack"] = 0.00021000,
            ["space-science-pack"] = 0.00042000,
        }

        global.spy_fish_timeout = {}

        north_team.set_cease_fire('player', true)
        north_team.set_friend('spectator', true)
        north_team.share_chart = true
        north_team.set_spawn_position({0,-26},battle_surface)

        south_team.set_cease_fire('player', true)
        south_team.set_friend('spectator', true)
        south_team.share_chart = true
        south_team.set_spawn_position({0,26},battle_surface)

        spectator_team.set_spawn_position({0,0},battle_surface)
        spectator_team.set_friend('north', true)
        spectator_team.set_friend('south', true)

        game.forces['player'].set_spawn_position({0,0},battle_surface)

        global.biter_battles_init_done = true
    end
    if global.game_lobby_active then
        if #game.connected_players > 1 then global.game_lobby_timeout = game.tick + 9000 end
    end

    if player.online_time < 5 and battle_surface.is_chunk_generated({0,0}) then
        player.teleport(battle_surface.find_non_colliding_position("player", {0,0}, 2, 1), battle_surface)
    else
        if not global.team_chosen[player.index] then player.teleport({0,0}, battle_surface) end
    end

    global.biter_battle_view_players[player.index] = false
    create_biter_battle_sprite_button(player)
    create_biter_battle_menu(player)
    refresh_gui()
end

local function on_player_left_game(event)
    if game.connected_players == 1 and global.game_lobby_active  then
        global.game_lobby_timeout = game.tick + 599940
    end
    refresh_gui()
end

local function spy_fish(player)
    local duration_per_unit = 1800
    local get_inventory = player.get_inventory
    local quick_bar = get_inventory(defines.inventory.player_quickbar)
    local main_inventory = get_inventory(defines.inventory.player_main)
    local owned_fishes = quick_bar.get_item_count("raw-fish")
    owned_fishes = owned_fishes + main_inventory.get_item_count("raw-fish")

    if owned_fishes == 0 then
        player.print("You have no fish in your inventory.",{ r=0.98, g=0.66, b=0.22})
        return
    end

    local x = quick_bar.remove({ name="raw-fish", count=1})
    if x == 0 then main_inventory.remove({ name="raw-fish", count=1}) end
    local enemy_team = "south"
    local force_name = player.force.name
    if force_name == "south" then enemy_team = "north" end
    if global.spy_fish_timeout[force_name] then
        global.spy_fish_timeout[force_name] = global.spy_fish_timeout[force_name] + duration_per_unit
        player.print(round((global.spy_fish_timeout[force_name] - game.tick)/60, 0) .. " seconds of enemy vision left.",{ r=0.98, g=0.66, b=0.22})
    else
        get_border_cords(enemy_team, player.surface)
        local msg = string.format("%s sent a  fish to spy on %s team!", player.name, enemy_team)
        game.print(msg,{ r=0.98, g=0.66, b=0.22})
        global.spy_fish_timeout[force_name] = game.tick + duration_per_unit
    end
end

local function feed_the_biters(food_type, player)
    local player_force_name = player.force.name
    if player_force_name == "player" then return end
    if player_force_name == "spectator" then return end

    local enemy_team_name = ""
    if player_force_name == "south" then enemy_team_name = "north" end
    if player_force_name == "north" then enemy_team_name = "south" end

    local main_inventory = player.get_main_inventory()
    local food_amount = main_inventory.remove(food_type)
    local get_item_count = main_inventory.get_item_count
    local remove = main_inventory.remove(food_type)
    while get_item_count(food_type) ~= 0 do
        food_amount = food_amount + remove(food_type)
    end

    if food_amount == 0 then
        local msg = string.format("You have no %s flask in your inventory.", global.food_names[food_type])
        player.print(msg,{ r=0.98, g=0.66, b=0.22})
    else
        local print
        local feeder
        local flask_s = "flasks"
        if food_amount >= 20 then
            feeder = player.name
            print = game.print
        else
            if food_amount == 1 then
                flask_s = "flask"
            end
            feeder = "You"
            print = player.print
        end
        local msg = string.format("%s fed %s %s of %s juice to team %s´s biters!", feeder, food_amount, flask_s, global.food_names[food_type], enemy_team_name)
        print(msg, { r=0.98, g=0.66, b=0.22})
    end

    local nerf_gain = 0
    local food_values = global.food_values
    if food_amount > 0 then
        nerf_gain = food_values[food_type] * food_amount

        --change these two numbers to your liking nerf and rage
        local nerf_multiplier = 1
        local rage_food_value = food_values[food_type] * 12500000  --10000000
        --biter rage calculation
        local current_biter_rage = global.biter_rage[enemy_team_name]
        for x = 0, food_amount, 1 do
            local rage_diminish_multiplier = 1/(((current_biter_rage^2.9)+8000)/500)
            current_biter_rage = current_biter_rage + (rage_food_value*rage_diminish_multiplier)
        end

        global.biter_rage[enemy_team_name] = current_biter_rage
        global.team_nerf[enemy_team_name] = global.team_nerf[enemy_team_name] + (nerf_gain*nerf_multiplier)

        local lowest_possible_modifier = -0.95

        local ammo_types = {"grenade", "bullet", "artillery-shell", "flamethrower", "cannon-shell", "shotgun-shell", "rocket", "electric"}
        local ammo_modifier = {0.2, 0.8, 0, 0.8, 0.2, 0.2, 0.2, 0.2}
        local turret_types = {"laser-turret", "flamethrower-turret", "gun-turret"}
        local turret_modifier = {0.9, 1, 0.8}
        local ammo_speed = {"bullet", "cannon-shell", "shotgun-shell", "rocket", "laser-turret"}
        local ammo_speed_modifier = {0.3, 0.3, 0.3, 0.3, 0.3}

        -------------
        local enemy_team = game.forces[enemy_team_name]
        -----------                   -!!!!!--------------
        local modified_nerf_gain = nerf_gain

        local x = 1
        local get_ammo_damage_modifier = enemy_team.get_ammo_damage_modifier
        local set_ammo_damage_modifier = enemy_team.set_ammo_damage_modifier
        for _, w in pairs(ammo_types) do
            if get_ammo_damage_modifier(w) - (nerf_gain * ammo_modifier[x]) < lowest_possible_modifier then
                modified_nerf_gain = lowest_possible_modifier
            else
                modified_nerf_gain = get_ammo_damage_modifier(w) - (nerf_gain * ammo_modifier[x])
            end
            set_ammo_damage_modifier(w, modified_nerf_gain)
            x = x + 1
        end

        local x = 1
        local get_turret_attack_modifier = enemy_team.get_turret_attack_modifier
        local set_turret_attack_modifier = enemy_team.set_turret_attack_modifier
        for _, w in pairs(turret_types) do
            if get_turret_attack_modifier(w) - (nerf_gain * ammo_modifier[x]) < lowest_possible_modifier then
                modified_nerf_gain = lowest_possible_modifier
            else
                modified_nerf_gain = get_turret_attack_modifier(w) - (nerf_gain * turret_modifier[x])
            end
            set_turret_attack_modifier(w, modified_nerf_gain)
            x = x + 1
        end

        local x = 1
        local get_gun_speed_modifier = enemy_team.get_gun_speed_modifier
        local set_gun_speed_modifier = enemy_team.set_gun_speed_modifier
        for _, w in pairs(ammo_speed) do
            if get_gun_speed_modifier(w) - (nerf_gain * ammo_speed_modifier[x]) < lowest_possible_modifier then
                modified_nerf_gain = lowest_possible_modifier
            else
                modified_nerf_gain = get_gun_speed_modifier(w) - (nerf_gain * ammo_speed_modifier[x])
            end
            set_gun_speed_modifier(w, modified_nerf_gain)
            x = x + 1
        end

        refresh_gui()
    end
end

local function on_gui_click(event)
    if not (event and event.element and event.element.valid) then return end
    local player = game.players[event.element.player_index]
    local name = event.element.name
    if (name == "biter_battle_toggle_menu_button") then
        local frame = player.gui.left["biter_battle_menu"]
        if (frame) then
            frame.destroy()
        else
            create_biter_battle_menu(player)
        end
    end
    if (name == "science-pack-1") then feed_the_biters(name,player) end
    if (name == "science-pack-2") then feed_the_biters(name,player) end
    if (name == "military-science-pack") then feed_the_biters(name,player) end
    if (name == "science-pack-3") then feed_the_biters(name,player) end
    if (name == "production-science-pack") then feed_the_biters(name,player) end
    if (name == "high-tech-science-pack") then feed_the_biters(name,player) end
    if (name == "space-science-pack") then feed_the_biters(name,player) end
    if (name == "raw-fish") then spy_fish(player) end
    if (name == "biter_battle_spectate") then
        if player.position.y < 100 and player.position.y > -100 and player.position.x < 100 and player.position.x > -100 then
            join_team(player, "spectator")
        else
            player.print("You are too far away from spawn to spectate.",{ r=0.98, g=0.66, b=0.22})
        end
    end
    if (name == "biter_battle_leave_spectate") then
        local game_tick = game.tick
        if game_tick - global.spectator_spam_protection[player.name] > 1800 then
            join_team(player, global.team_chosen[player.index])
        elseif game_tick - global.spectator_spam_protection[player.name] < 1800 then
            player.print("Not ready to return to your team yet. Please wait " .. 30-(round((game_tick - global.spectator_spam_protection[player.name])/60,0)) .. " seconds.", { r=0.98, g=0.66, b=0.22})
        end
    end

    if (name == "biter_battle_hide_players") then
        global.biter_battle_view_players[player.index] = false
        refresh_gui()
    end
    if (name == "biter_battle_view_players") then
        global.biter_battle_view_players[player.index] = true
        refresh_gui()
    end

    if name == "join_north_button" then
        local game_lobby_active = global.game_lobby_active
        if game_lobby_active == false then
            join_team(player, "north")
        elseif player.admin  then
            join_team(player, "north")
            game.print("Lobby disabled, admin override.", { r=0.98, g=0.66, b=0.22})
            global.game_lobby_active = false
        else
            player.print("Waiting for more players to join the game.", {r=0.98, g=0.66, b=0.22})
        end
    end

    if name == "join_south_button" then
        local game_lobby_active = global.game_lobby_active
        if game_lobby_active == false then
            join_team(player, "south")
        elseif player.admin  then
            join_team(player, "south")
            game.print("Lobby disabled, admin override.", { r=0.98, g=0.66, b=0.22})
            global.game_lobby_active = false
        else
            player.print("Waiting for more players to join the game.", {r=0.98, g=0.66, b=0.22})
        end
    end
end

local function on_entity_died(event)
    if not global.rocket_silo_destroyed then
        if event.entity == global.rocket_silo["south"] or event.entity == global.rocket_silo["north"] then
            if event.entity == global.rocket_silo["south"] then global.rocket_silo_destroyed = "North Team Won!" else global.rocket_silo_destroyed = "South Team Won!" end
            for _, player in pairs(game.connected_players) do
                player.play_sound{path="utility/game_won", volume_modifier=1}
            end
            refresh_gui()
        end
    end
    if event.entity.name == "medium-biter" then
        local conveyor = battle_surface.find_entities_filtered{area={{event.entity.position.x-1,event.entity.position.y-1},{event.entity.position.x+1,event.entity.position.y+1}}, name={"transport-belt", "fast-transport-belt", "express-transport-belt"}, limit=1}
        if conveyor[1] then
            conveyor[1].health = conveyor[1].health - 57
            if conveyor[1].health <= 0 then conveyor[1].die("enemy") end
        end
    end
    for _, fragment in pairs(global.biter_fragmentation) do
        if event.entity.name == fragment[1] then
            for x=1,random(fragment[3],fragment[4]),1 do
                local p = battle_surface.find_non_colliding_position(fragment[2] , event.entity.position, 2, 1)
                if p then battle_surface.create_entity {name=fragment[2], position=p} end
                p = nil
            end
            return
        end
    end

    if event.entity.name == "biter-spawner" or event.entity.name == "spitter-spawner" then
        local e = ceil(enemy_force.evolution_factor*10, 0)
        for _, t in pairs (global.biter_building_inhabitants[e]) do
            for x = 1, random(t[2],t[3]), 1 do
                local p = battle_surface.find_non_colliding_position(t[1] , event.entity.position, 6, 1)
                if p then battle_surface.create_entity {name=t[1], position=p} end
            end
        end
    end
end

local function get_valid_biters(requested_amount, y_modifier, pos_x, pos_y, radius_inc)
    if not requested_amount then return end
    if not y_modifier then return end
    if not pos_x then pos_x = 0 end
    if not pos_y then pos_y = 150*y_modifier end
    local biters_found = {}
    local valid_biters = {}
    if not radius_inc then radius_inc = 100 end

    for radius = radius_inc,2000,radius_inc do
        biters_found = battle_surface.find_enemy_units({pos_x,pos_y}, radius, "player")
        local x = 1
        if y_modifier == -1 then
            for _, biter in pairs(biters_found) do
                if biter.position.y < 0 then
                    valid_biters[x] = biter
                    x = x + 1
                end
            end
        else
            for _, biter in pairs(biters_found) do
                if biter.position.y > 0 then
                    valid_biters[x] = biter
                    x = x + 1
                end
            end
        end
        if #valid_biters >= requested_amount or radius == 2000 then
            break
        else
            valid_biters = {}
        end
    end
    radius_inc = nil
    pos_x = nil
    pos_y = nil
    return valid_biters
end

local function biter_attack_silo(team, requested_amount, mode)
    if not requested_amount or not team then return end
    local count_entities_filtered = battle_surface.count_entities_filtered
    local attack_target = global.biter_attack_main_target[team]
    local attack_area = defines.command.attack_area
    local by_enemy = defines.distraction.by_enemy
    local by_anything = defines.distraction.by_anything

    local y_modifier = 1
    if team == "south" then y_modifier = 1 end
    if team == "north" then y_modifier = -1 end

    local biters_selected_for_attack = {}

    if not mode then
        local modes = {"spread", "ball", "line"}
        mode = modes[random(1,3)]
    end

    if mode == "spread" then
        local valid_biters = get_valid_biters(requested_amount, y_modifier, 0, 150*y_modifier, 500)
        if #valid_biters < requested_amount then
            valid_biters = get_valid_biters(requested_amount, y_modifier, 0, 1500*y_modifier, 500)
        end
        local counted_biters = #valid_biters
        local f = floor(counted_biters/requested_amount,0)
        if f < 1 then f = 1 end
        local x = 0
        for y = f, counted_biters, f do
            x = x + 1
            if not valid_biters[y] then break end
            if #biters_selected_for_attack >= requested_amount then break end
            biters_selected_for_attack[x] = valid_biters[y]
        end

        if random(1,3) == 1 then
            local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_anything}
            for _, biter in pairs(biters_selected_for_attack) do
                biter.set_command(command)
            end
        else
            local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_enemy}
            for _, biter in pairs(biters_selected_for_attack) do
                biter.set_command(command)
            end
        end
        if global.biter_battles_debug then
            game.players[1].print(counted_biters .. " valid biters found.")
            game.players[1].print(#biters_selected_for_attack .. " biter going for a spread attack")
        end
    end

    if mode == "line" then
        local valid_biters = get_valid_biters(requested_amount, y_modifier, 0, 150*y_modifier, 500)
        if #valid_biters < requested_amount then
            valid_biters = get_valid_biters(requested_amount, y_modifier, 0, 1500*y_modifier, 500)
        end
        local counted_biters = #valid_biters

        local array_start = 1
        local f = floor(counted_biters/requested_amount,0)
        if f >= 2 then
            array_start = requested_amount * random(1,f-1)
            if random(1,f) == 1 then array_start = 1 end
        end
        local x = 0
        for y = array_start, counted_biters, 1 do
            x = x + 1
            if not valid_biters[y] then break end
            if #biters_selected_for_attack >= requested_amount then break end
            biters_selected_for_attack[x] = valid_biters[y]
        end

        if random(1,3) == 1 then
            local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_anything}
            for _, biter in pairs(biters_selected_for_attack) do
                biter.set_command(command)
            end
        else
            local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_enemy}
            for _, biter in pairs(biters_selected_for_attack) do
                biter.set_command(command)
            end
        end

        if global.biter_battles_debug then
            game.players[1].print(#valid_biters .. " valid biters found.")
            game.players[1].print(#biters_selected_for_attack .. " going for a line attack, table start = " .. array_start)
        end
    end

    if mode == "ball" then
        local height = 0
        local c = 0
        local tolerance = 5
        local distance_to_base_modifier = 2.6
        local additional_empty_space_checks = 4
        local additional_checks = additional_empty_space_checks
        local gathering_point_x = 0
        local gathering_point_y = 0
        local r = random(1,3) --pick a random side
        if r == 1 or r == 2 then
            --- determine base height
            for pos_y = 0, 8192*y_modifier, 32*y_modifier do
                if y_modifier == -1 then
                    c = count_entities_filtered{area={{-1024,pos_y-32},{1024,pos_y}},force=team}
                else
                    c = count_entities_filtered{area={{-1024,pos_y},{1024,pos_y+32}},force=team}
                end
                if c <= tolerance then
                    additional_checks = additional_checks - 1
                    if additional_checks == 0 then
                        height = pos_y - (32*(additional_empty_space_checks)*y_modifier) + (32*y_modifier)
                        break
                    end
                else
                    additional_checks = additional_empty_space_checks
                end
            end

            if height ~= 0 then
                if y_modifier == -1 then
                    gathering_point_y = random(height, -32)
                else
                    gathering_point_y = random(32, height)
                end
            else
                if y_modifier == -1 then
                    gathering_point_y = random(-128, -32)
                else
                    gathering_point_y = random(32, 128)
                end
            end

            additional_empty_space_checks = 32
            if r == 1 then
                --west attack
                local additional_checks = additional_empty_space_checks
                for x = 0, -8192, -32 do
                    c = count_entities_filtered{area={{x-32,gathering_point_y-48},{x,gathering_point_y+48}},force=team}
                    if c <= tolerance then
                        additional_checks = additional_checks - 1
                        if additional_checks == 0 then
                            gathering_point_x = x + (32*(additional_empty_space_checks-distance_to_base_modifier))
                            break
                        end
                    else
                        additional_checks = additional_empty_space_checks
                    end
                end
            end

            if r == 2 then
                --east attack
                local additional_checks = additional_empty_space_checks
                for x = 32, 8192, 32 do
                    c = count_entities_filtered{area={{x-32,gathering_point_y-48},{x,gathering_point_y+48}},force=team}
                    if c <= tolerance then
                        additional_checks = additional_checks - 1
                        if additional_checks == 0 then
                            gathering_point_x = x - (32*(additional_empty_space_checks-distance_to_base_modifier))
                            break
                        end
                    else
                        additional_checks = additional_empty_space_checks
                    end
                end
            end
        end

        --vertical attack
        if r == 3 then
            --- determine base width
            additional_checks = additional_empty_space_checks
            local width_east = 0
            for pos_x = 32, 4096, 32 do
                if y_modifier == -1 then
                    c = count_entities_filtered{area={{pos_x - 32, -2048},{pos_x, 0}},force=team}
                else
                    c = count_entities_filtered{area={{pos_x - 32, 0},{pos_x, 2048}},force=team}
                end
                if c <= tolerance then
                    additional_checks = additional_checks - 1
                    if additional_checks == 0 then
                        width_east = pos_x - 32*additional_empty_space_checks
                        break
                    end
                else
                    additional_checks = additional_empty_space_checks
                end
            end

            additional_checks = additional_empty_space_checks
            local width_west = 0
            for pos_x = 0, -4096, -32 do
                if y_modifier == -1 then
                    c = count_entities_filtered{area={{pos_x - 32, -2048},{pos_x, 0}},force=team}
                else
                    c = count_entities_filtered{area={{pos_x - 32, 0},{pos_x, 2048}},force=team}
                end
                if c <= tolerance then
                    additional_checks = additional_checks - 1
                    if additional_checks == 0 then
                        width_west = (pos_x + 32*additional_empty_space_checks) - 32
                        break
                    end
                else
                    additional_checks = additional_empty_space_checks
                end
            end

            if width_west ~= 0 and width_east ~= 0 then
                gathering_point_x = random(width_west, width_east)
            else
                gathering_point_x = random(-64,64)
            end
            additional_empty_space_checks = 32

            --vertical attack --
            local c = 0
            local additional_checks = additional_empty_space_checks
            for pos_y = 0, 8192*y_modifier, 32*y_modifier do
                c = count_entities_filtered{area={{gathering_point_x-48, pos_y-32},{gathering_point_x+48, pos_y}},force=team}
                if c <= tolerance then
                    additional_checks = additional_checks - 1
                    if additional_checks == 0 then
                        gathering_point_y = pos_y - ((32*(additional_empty_space_checks-distance_to_base_modifier))*y_modifier)
                        break
                    end
                else
                    additional_checks = additional_empty_space_checks
                end
            end
        end

        valid_biters = get_valid_biters(requested_amount, y_modifier, gathering_point_x, gathering_point_y)
        local counted_biters = #valid_biters

        local f = floor(counted_biters/requested_amount,0)
        if f < 1 then f = 1 end
        local x = 0
        for y = f, counted_biters, f do
            x = x + 1
            if not valid_biters[y] then break end
            if #biters_selected_for_attack >= requested_amount then break end
            biters_selected_for_attack[x] = valid_biters[y]
        end

        --alternate attack if there is water
        local t = count_tiles_filtered{area={{gathering_point_x - 8, gathering_point_y - 8}, {gathering_point_x + 8, gathering_point_y + 8}}, name={"deepwater","water", "water-green"}}
        if t > 8 then
            if random(1,2) == 1 then
                local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_enemy}
                for _, biter in pairs(biters_selected_for_attack) do
                    biter.set_command(command)
                end
            else
                local command = {type=attack_area, destination=attack_target, radius=12, distraction=by_anything}
                for _, biter in pairs(biters_selected_for_attack) do
                    biter.set_command(command)
                end
            end
            if global.biter_battles_debug then
                game.players[1].print("water found, doing alternate spread attack")
            end
        else
            local biter_attack_group = battle_surface.create_unit_group({position={gathering_point_x,gathering_point_y}})
            for _, biter in pairs(biters_selected_for_attack) do
                biter_attack_group.add_member(biter)
            end
            biter_attack_group.set_command({type=attack_area, destination=attack_target, radius=12, distraction=by_anything})
            if global.biter_battles_debug then
                game.players[1].print(#valid_biters .. " valid biters found.")
                game.players[1].print(#biters_selected_for_attack .. " gathering at (x: " .. gathering_point_x .. "  y: " .. gathering_point_y .. ")")
            end
        end
    end
    mode = nil
end

local function on_tick(event)
    local game_tick = game.tick
    local south_fish_timeout = global.spy_fish_timeout["south"]
    if south_fish_timeout then
        if (south_fish_timeout - game_tick) % 300 == 0 then
            reveal_team("north")
        end
        if game_tick - south_fish_timeout > 0 then
            south_fish_timeout = nil
        end
    end

    local north_fish_timeout = global.spy_fish_timeout["north"]
    if north_fish_timeout then
        if (north_fish_timeout - game_tick) % 300 == 0 then
            reveal_team("south")
        end
        if game_tick - north_fish_timeout > 0 then
            north_fish_timeout = nil
        end
    end

    if game_tick % 12600 == 6300 then
        local north_biter_rage = global.biter_rage["north"]
        if north_biter_rage >= 1 then
            local c = round(north_biter_rage, 0)
            if c > 999 then c = 999 end
            biter_attack_silo("north", c)
        end
        refresh_gui()
        return
    end
    if game_tick % 12600 == 0 then
        local south_biter_rage = global.biter_rage["south"]
        if south_biter_rage >= 1 then
            local c = round(south_biter_rage, 0)
            if c > 999 then c = 999 end
            biter_attack_silo("south", c)
        end
        refresh_gui()
        return
    end
    if not global.terrain_init_done then
        if game_tick == 240 then
            local create_entity = battle_surface.create_entity
            local silos = {
                ["north"] = create_entity {name="rocket-silo", position={0,(global.horizontal_border_width*3.8)*-1}, force="north"},
                ["south"] = create_entity {name="rocket-silo", position={0,global.horizontal_border_width*3.8}, force="south"},
            }
            silos["north"].minable=false
            silos["south"].minable=false

            global.rocket_silo = silos

            global.biter_attack_main_target = {
                ["north"] = silos["north"].position,
                ["south"] = silos["south"].position,
            }

            biter_battles_terrain.clear_spawn_ores()
            biter_battles_terrain.generate_spawn_water_pond()
            biter_battles_terrain.generate_spawn_ores("windows")
            biter_battles_terrain.generate_market()
            global.terrain_init_done = true

            battle_surface.regenerate_decorative()
            battle_surface.regenerate_entity({"tree-01", "tree-02","tree-03","tree-04","tree-05","tree-06","tree-07","tree-08","tree-09","dead-dry-hairy-tree","dead-grey-trunk","dead-tree-desert","dry-hairy-tree","dry-tree","rock-big","rock-huge"})
            local entities = battle_surface.find_entities({{-10,-10},{10,10}})
            for _, e in pairs(entities) do
                if e.type == "simple-entity" or e.type == "resource" or e.type == "tree" then e.destroy() end
            end
            battle_surface.destroy_decoratives({{-10,-10},{10,10}})
            game.print("Spawn generation done.")
        end
    end
    if game_tick % 60 == 0 and global.game_lobby_active then
        if global.game_lobby_timeout - game_tick <= 0 then
            global.game_lobby_active = false
        end
        refresh_gui()
    end
end

----------share chat with player and spectator force-------------------
local function on_console_chat(event)
    if not event.message then return end
    if not event.player_index then return end
    local player = game.players[event.player_index]
    local player_force = player.force
    local player_force_name = player_force.name
    local player_force_print_name = string.gsub(player_force_name, "player", "spawn")

    local color = {}
    color = player.color
    color.r = color.r * 0.6 + 0.35
    color.g = color.g * 0.6 + 0.35
    color.b = color.b * 0.6 + 0.35
    color.a = 1

    local message = string.format("%s (%s): %s", player.name, player_force_print_name, event.message)
    if player_force_name == "north" or player_force_name == "south" then
        game.forces.spectator.print(message, color)
        game.forces.player.print(message, color)
    else
        for name, force in pairs(game.forces) do
            if index ~= player_force_name then
                force.print(msg, color)
            end
        end
    end
end
--------------------------------------

--Silo grief prevention--
local function on_entity_damaged(event)
    local entity = event.entity
    local entity_force_name = entity.force.name
    local force_name = event.force.name
    local entity_name = entity.name

    --biter rage damage modifier
    if force_name == "enemy" then
        local additional_damage = event.final_damage_amount  * round((global.biter_rage[entity_force_name]/3)/100, 2)
        entity.health = entity.health - additional_damage
        return
    end

    if entity_name == "biter-spawner" or entity_name == "spitter-spawner" then
        if entity.health - event.final_damage_amount <= 0 then
            entity.die(force_name)
         end
        entity.health = entity.health + event.final_damage_amount * (enemy_force.evolution_factor * 0.8)
        return
    end

    if entity == global.rocket_silo[force_name] then
        global.rocket_silo[force_name].health = global.rocket_silo[force_name].health + event.final_damage_amount
        return
    end

    if entity_force_name == "spectator" then
        entity.health = entity.health + event.final_damage_amount
        return
    end
end

--anti construction robot cheese
local function on_robot_built_entity(event)
    if event.robot.force.name == "north" and event.created_entity.position.y >= -global.horizontal_border_width / 2 then
        local x = event.created_entity.position.x
        local y = event.created_entity.position.y
        event.created_entity.die("south")
        search_for_ghost = battle_surface.find_entities({{x, y}, {x+1, y+1}})
        for _, e in pairs(search_for_ghost) do
            if e.type == "entity-ghost" then e.time_to_live = 1 end
        end
        event.robot.die("south")
        game.print("Team north´s drone had an accident.",{ r=0.98, g=0.66, b=0.22})
    end
    if event.robot.force.name == "south" and event.created_entity.position.y <= global.horizontal_border_width/2 then
        local x = event.created_entity.position.x
        local y = event.created_entity.position.y
        event.created_entity.die("north")
        search_for_ghost = battle_surface.find_entities({{x, y}, {x+1, y+1}})
        for _, e in pairs(search_for_ghost) do
            if e.type == "entity-ghost" then e.time_to_live = 1 end
        end
        event.robot.die("north")
        game.print("Team south´s drone had an accident.",{ r=0.98, g=0.66, b=0.22})
    end
end

local function on_marked_for_deconstruction(event)
    if event.entity.name == "fish" then
        event.entity.cancel_deconstruction(game.players[event.player_index].force.name)
    end
end

local function on_rocket_launched(event)
    local team = event.rocket_silo.force.name
    if team == "south" then
        team = "north"
    elseif team == "north" then
        team = "south"
    end
    biter_attack_silo(team,250,"ball")
    biter_attack_silo(team,250,"ball")
    biter_attack_silo(team,250,"ball")
    local str = string.format("A rocket launch scared the biters and triggered a huge attack on team %s´s silo!", team)
    game.print(str,{ r=0.98, g=0.01, b=0.01})
end

local function on_player_built_tile(event)
    local placed_tiles = event.tiles
    local player = game.players[event.player_index]
    local tiles = {}
    for _, t in pairs(placed_tiles) do
        if t.old_tile.name == "deepwater" and t.position.y <= global.horizontal_border_width*2 and t.position.y >= global.horizontal_border_width*-1*2 then
            local str = string.format("Team %s´s landfill vanished into the depths of the marianna trench.", player.force.name)
            game.print(str,{ r=0.98, g=0.66, b=0.22})

            insert(tiles, {name = "deepwater", position = t.position})
        end
    end
    battle_surface.set_tiles(tiles)
end

local function on_player_died(event)
    if not event.cause then return end

    local player = game.players[event.player_index]
    local force_name = player.force.name
    local message = string.format("%s(%s) was killed by %s", player.name, force_name, event.cause.name)

    if player.force == north_team then
        south_team.print(message, { r=0.99, g=0.0, b=0.0})
    end
    if player.force == south_team then
        north_team.print(message, { r=0.99, g=0.0, b=0.0})
    end
end

Event.add(defines.events.on_player_died, on_player_died)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_player_built_tile, on_player_built_tile)
Event.add(defines.events.on_rocket_launched, on_rocket_launched)
Event.add(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)
Event.add(defines.events.on_player_left_game, on_player_left_game)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_player_created, refresh_gui)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_console_chat, on_console_chat)
