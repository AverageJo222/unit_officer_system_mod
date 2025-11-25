--------------------------------------------------------------------------------
-- SHOGUN 2 UNIT OFFICER SYSTEM DEMO
-- Features:
-- 1. Random names for player & AI units
-- 2. Officers assigned a tier (D → S) with random quality
-- 3. Officers gain XP from battle kills, level up
-- 4. Stat bonuses scale with tier & level (growth curves)
-- 5. Officer death handling
-- 6. Save/load persistence
--------------------------------------------------------------------------------

OUT("Officer System Loaded")

local officer_data = {}   -- stores officer stats per unit

-- Officer names (historical Japanese-style)
local name_pool = {
    "Hattori Saburo", "Nakamura Tetsuya", "Abe Kiyomasa", "Endo Haru",
    "Takeda Noboru", "Murata Keiji", "Sakai Yoshinobu", "Oda Rin",
    "Maeda Katsuo", "Shimazu Haruto"
}

-- Officer quality tiers with growth curves
local quality_tiers = {
    D = { xp_needed = 40, max_level = 3, base_bonus = 1 },
    C = { xp_needed = 35, max_level = 4, base_bonus = 2 },
    B = { xp_needed = 30, max_level = 5, base_bonus = 3 },
    A = { xp_needed = 25, max_level = 6, base_bonus = 4 },
    S = { xp_needed = 20, max_level = 7, base_bonus = 6 }
}

-- Utility functions
local function get_random_name()
    return name_pool[cm:random_number(#name_pool, 1)]
end

local function roll_quality()
    local r = cm:random_number(100)
    if r <= 5 then return "S"
    elseif r <= 20 then return "A"
    elseif r <= 50 then return "B"
    elseif r <= 80 then return "C"
    else return "D"
    end
end

-- Assign officer to unit
local function generate_officer_for_unit(unit)
    local id = unit:unique_ui_id()
    if officer_data[id] then return end

    local name = get_random_name()
    local quality = roll_quality()

    officer_data[id] = {
        name = name,
        quality = quality,
        level = 1,
        xp = 0
    }

    apply_officer_effect(unit)

    cm:show_message_event(
        cm:get_faction(unit:faction()):name(),
        "Officer Assigned",
        "Unit "..unit:unit_key().." is now led by Officer "..name.." (Quality: "..quality..")"
    )
end

-- Apply officer effect based on tier and level
function apply_officer_effect(unit)
    local id = unit:unique_ui_id()
    local data = officer_data[id]
    if not data then return end

    local tier = data.quality
    local level = math.min(data.level, quality_tiers[tier].max_level)
    local bonus = quality_tiers[tier].base_bonus * level

    -- Remove previous effect bundle if exists
    cm:remove_effect_bundle("officer_bonus_"..tier, unit)

    -- Apply dynamic stat bonuses
    cm:apply_custom_effect_bundle(unit, {
        { effect = "stat_morale", value = bonus },
        { effect = "stat_melee_attack", value = bonus },
        { effect = "stat_melee_defence", value = bonus }
    })
end

-- Recruitment listener
cm:add_unit_recruitment_listener(
    "OfficerRecruit",
    function(context)
        local unit = context:unit()
        generate_officer_for_unit(unit)
    end
)

-- Post-battle XP & promotion listener
core:add_listener(
    "OfficerBattleXP",
    "BattleCompleted",
    true,
    function(context)
        local battle = context:battle
        local defenders = battle:report_defender().units
        local attackers = battle:report_attacker().units

        local function process_units(unit_list)
            for i = 1, #unit_list do
                local u = unit_list[i]
                local unit_obj = u.unit
                local id = unit_obj:unique_ui_id()
                if officer_data[id] then
                    -- Gain XP based on kills
                    officer_data[id].xp = officer_data[id].xp + u.kills

                    local tier = officer_data[id].quality
                    if officer_data[id].xp >= quality_tiers[tier].xp_needed then
                        -- Level up
                        officer_data[id].level = officer_data[id].level + 1
                        officer_data[id].xp = 0
                        apply_officer_effect(unit_obj)

                        cm:show_message_event(
                            cm:get_faction(unit_obj:faction()):name(),
                            "Officer Promoted",
                            "Officer "..officer_data[id].name.." of unit "..unit_obj:unit_key().." has been promoted!"
                        )
                    end
                end
            end
        end

        process_units(defenders)
        process_units(attackers)
    end,
    true
)

-- Handle unit death
core:add_listener(
    "OfficerUnitDestroyed",
    "UnitDestroyed",
    true,
    function(context)
        local unit = context:unit()
        local id = unit:unique_ui_id()
        if officer_data[id] then
            cm:show_message_event(
                cm:get_faction(unit:faction()):name(),
                "Officer Killed",
                "Officer "..officer_data[id].name.." of unit "..unit:unit_key().." has died in battle!"
            )
            officer_data[id] = nil
        end
    end,
    true
)

-- SAVE / LOAD
cm:add_saving_game_callback(function(context)
    cm:save_named_value("officer_data", officer_data, context)
end)

cm:add_loading_game_callback(function(context)
    officer_data = cm:load_named_value("officer_data", {}, context)
end)
