-- Exporting several copies of an NPC whose equipment comes from a levelled list.
-- Lists resolve per reference, so every createReference is a fresh roll - but
-- only what the engine EQUIPS changes the mesh, so copies are decided by
-- comparing what each roll came out wearing.

local settings = require("ThumbnailGenerator.modules.thumbnail_settings")

local this = {}

-- Free negative test: no levelled entry means nothing can re-roll. Over-reports
-- (a levelled potion list counts); the signature comparison catches those.
function this.canVary(obj)
    if not obj or obj.objectType ~= tes3.objectType.npc then return false end
    local inventory = obj.inventory
    if not inventory then return false end
    local ok, found = pcall(function()
        for _, stack in pairs(inventory) do
            local item = stack and stack.object
            if item and item.objectType == tes3.objectType.leveledItem then
                return true
            end
        end
        return false
    end)
    return ok and found or false
end

-- Sorted ids of everything this instance has equipped. Equal signatures mean an
-- identical mesh; nil means it could not be read, so callers keep only the first.
function this.signature(ref)
    local actor = ref and ref.object
    local equipment = actor and actor.equipment
    if not equipment then return nil end
    local ok, sig = pcall(function()
        local ids = {}
        for _, stack in pairs(equipment) do
            local item = stack and stack.object
            if item and item.id then
                table.insert(ids, item.id:lower())
            end
        end
        table.sort(ids)
        return table.concat(ids, "|")
    end)
    return ok and sig or nil
end

-- Copies to attempt, and rolls to allow reaching them - rolls repeat often.
function this.plan(obj)
    local wanted = tonumber(settings.current.npcVariants) or 1
    if wanted <= 1 or not this.canVary(obj) then
        return 1, 1
    end
    return wanted, wanted * 3
end

-- Consecutive identical rolls before giving up, so a levelled list that never
-- changes the outfit does not cost an export's worth of work per attempt.
this.giveUpAfter = 3

-- "" for a single copy, so ordinary exports keep their plain filename.
function this.suffix(index, total)
    if total <= 1 then return "" end
    return string.format(" var%d", index)
end

return this
