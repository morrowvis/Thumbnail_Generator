-- Exporting several copies of an NPC whose worn gear comes from a levelled list.
--
-- The lists are readable (tes3leveledItem.list), so the outfits are CHOSEN here
-- and forced onto each copy, rather than spawning the NPC repeatedly and hoping
-- the engine rolls something different. The number of files therefore always
-- matches the plan.

local settings = require("ThumbnailGenerator.modules.thumbnail_settings")

local this = {}

-- Equipped but never drawn on the body, so they cannot change the export.
local hiddenClothing = {
    [tes3.clothingSlot.ring] = true,
    [tes3.clothingSlot.amulet] = true,
}

local function isWorn(item)
    if not item then return false end
    local t = item.objectType
    if t == tes3.objectType.armor or t == tes3.objectType.weapon then
        return true
    end
    if t == tes3.objectType.clothing then
        return not hiddenClothing[item.slot]
    end
    return false
end

local function playerLevel()
    local level = 1
    pcall(function() level = tes3.player.object.level or 1 end)
    return level
end

-- Worn items a levelled list can yield at the player's level, following nested
-- lists. Entries above that level can never be drawn, so counting them would
-- promise variety that cannot be delivered.
local function gather(list, out, level, depth, seen)
    if not list or depth > 4 or seen[list] then return end
    seen[list] = true
    for _, node in pairs(list.list or {}) do
        local item = node and node.object
        if item and (node.levelRequired or 0) <= level then
            if item.objectType == tes3.objectType.leveledItem then
                gather(item, out, level, depth + 1, seen)
            elseif isWorn(item) and item.id then
                out[item.id:lower()] = true
            end
        end
    end
end

-- One sorted id list per levelled list the NPC carries, so the choice below is
-- stable between runs.
local function outcomeSets(obj)
    local sets = {}
    for _, stack in pairs(obj.inventory or {}) do
        local item = stack and stack.object
        if item and item.objectType == tes3.objectType.leveledItem then
            local out = {}
            gather(item, out, playerLevel(), 0, {})
            local ids = {}
            for id in pairs(out) do table.insert(ids, id) end
            if #ids > 1 then
                table.sort(ids)
                table.insert(sets, ids)
            end
        end
    end
    table.sort(sets, function(a, b) return a[1] < b[1] end)
    return sets
end

-- The outfits to export, as a list of item-id lists to force onto each copy.
-- Empty means this subject has nothing that can change its look, so it is
-- exported once, unchanged, exactly as before variants existed.
function this.plan(obj)
    local wanted = tonumber(settings.current.npcVariants) or 1
    if wanted <= 1 or not obj or obj.objectType ~= tes3.objectType.npc then
        return {}
    end

    local ok, sets = pcall(outcomeSets, obj)
    if not ok or #sets == 0 then return {} end

    local widest = 0
    for _, ids in ipairs(sets) do
        widest = math.max(widest, #ids)
    end
    local total = math.min(wanted, widest)
    if total < 2 then return {} end

    -- Copy i takes the i-th option from every list, wrapping on the short ones,
    -- so each copy differs in at least the list that has the most options.
    local picks = {}
    for i = 1, total do
        local pick = {}
        for _, ids in ipairs(sets) do
            table.insert(pick, ids[((i - 1) % #ids) + 1])
        end
        picks[i] = pick
    end
    return picks
end

-- Between builds, drop every handle to the previous scene and collect. A
-- detached clone left reachable while the next createReference runs is finalised
-- mid-build and takes the game down in NiObjectNET::dtor.
function this.releaseBetweenRolls()
    collectgarbage("collect")
end

-- No suffix for a single copy, so ordinary exports keep their plain filename.
function this.name(baseName, index, total)
    if total <= 1 then return baseName end
    return string.format("%s var%d", baseName, index)
end

return this
