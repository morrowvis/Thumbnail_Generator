local metadata = {}

metadata.PREFIX = "MWMETA:"

local function partId(part)
    return part and part.id or nil
end

local function findTextKeyData(node, depth)
    if not node or (depth or 0) > 3 then return nil end
    local e = node.extraData
    while e do
        local rtti = e.RTTI and e.RTTI.name
        if rtti == "NiTextKeyExtraData" and e.keys then return e end
        e = e.next
    end
    for _, child in ipairs(node.children or {}) do
        local found = findTextKeyData(child, (depth or 0) + 1)
        if found then return found end
    end
    return nil
end

local function sourceTextKeys(meshPath)
    if not meshPath or meshPath == "" then return nil end
    local ok, mesh = pcall(tes3.loadMesh, meshPath)
    if not ok or not mesh then return nil end
    return findTextKeyData(mesh, 0)
end

function metadata.forObject(obj)
    if not obj then return nil end

    local isNpc = obj.objectType == tes3.objectType.npc
    if not (isNpc or obj.objectType == tes3.objectType.creature) then return nil end

    local t = {
        id = obj.id,
        name = obj.name,
        objectType = isNpc and "npc" or "creature",
        mesh = obj.mesh,
        scale = obj.scale or 1.0,
    }
    if not isNpc then return t end

    t.female = obj.female and true or false
    t.class = obj.class and obj.class.id or nil
    t.head = partId(obj.head)
    t.hair = partId(obj.hair)
    t.height = obj.height
    t.weight = obj.weight

    local race = obj.race
    if race then
        t.race = race.id
        t.raceName = race.name
        t.isBeast = race.isBeast and true or false
    end

    t.animationBase = t.isBeast and "base_animkna.nif" or "base_anim.nif"
    if t.female and not t.isBeast then
        t.animationOverride = "base_anim_female.nif"
    end
    return t
end

function metadata.attach(obj, root)
    if not root then return false end
    local t = metadata.forObject(obj)
    if not t then return false end

    local source = t.animationBase or t.mesh
    pcall(function()
        local data = sourceTextKeys(source)
        if data then root:addExtraData(data:clone()) end
    end)

    local ok, err = pcall(function()
        root:addExtraData(niStringExtraData.new(metadata.PREFIX .. json.encode(t)))
    end)
    if not ok then
        mwse.log("[ThumbnailGenerator] metadata attach failed for %s: %s",
            tostring(t.id), tostring(err))
        return false
    end
    return true
end

return metadata
