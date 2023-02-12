
local entity_id = GetUpdatedEntityID()
local x,y = EntityGetTransform(entity_id)

function revivecheck_scan()
    local plyrfound = false
    local players = EntityGetInRadiusWithTag(x,y,"player_unit")
    for k=1, #players
    do local v = players[k];
        if v ~= entity_id then

            local comps = EntityGetComponentIncludingDisabled(v, "VariableStorageComponent")
            for k=1, #comps
                do local v = comps[k];
                    local compname = ComponentGetValue2(v,"name")
                    if compname == "NoitaMP_deathscript_deathdata" then
                        local isdead = ComponentGetValue2(v,"value_bool")
                        if isdead ~= true then
                            plyrfound = true
                        end
                    end
                end
            end
        end
    end
    if plyrfound == true then return true else return false end
end

function revive()
    local comps = EntityGetComponentIncludingDisabled(entity_id, "LuaComponent")
    for k=1, #comps
    do local v = comps[k];
        local compname = ComponentGetValue2(v,"script_source_file")
        if compname == "mods/noita-mp/files/scripts/noita-components/mina-death/revive-check-nearby.lua" then
            EntitySetComponentIsEnabled(entity_id,v,false)
        end

        local compname = ComponentGetValue2(v,"script_source_file")
        if compname == "mods/noita-mp/files/scripts/noita-components/mina-death/revive-check-progress.lua" then
            EntitySetComponentIsEnabled(entity_id,v,false)
        end
    end

    local comps = EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent")
    for k=1, #comps
    do local v = comps[k];
        local compname = ComponentGetValue2(v,"name")
        if compname == "NoitaMP_deathscript_deathdata" then
            ComponentSetValue2(v,"value_bool",0)
            ComponentSetValue2(v,"value_int",0)
        end
    end

    local comps = EntityGetComponentIncludingDisabled(entity_id, "DamageModelComponent")
    for k=1, #comps
    do local v = comps[k]
        local max_hp = ComponentGetValue2(v,"max_hp")
        ComponentSetValue2(v,"hp",max_hp)
    end
end

if revivecheck_scan() == true then
    local entity_id = EntityGetWithTag("player_unit")[1]
    local comps = EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent")
    local progress = 0
    for k=1, #comps
    do local v = comps[k];
        local compname = ComponentGetValue2(v,"name")
        if compname == "NoitaMP_deathscript_deathdata" then
            progress = ComponentGetValue2(v,"value_int")
            ComponentSetValue2(v,"value_int",progress + 1)
        end
    end
    if progress >= 30 then
        revive()
    end
end