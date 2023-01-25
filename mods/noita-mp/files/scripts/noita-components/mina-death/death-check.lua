
function damage_received( damage, desc, entity_who_caused, is_fatal )
    local entity_id = GetUpdatedEntityID()
    local isdead = check_death()

    if isdead ~= true then return end

    --Set VSC data to say mina is dead and revive progress is 0
    local comps = EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent")
    for k=1, #comps
        do local v = comps[k];
            local compname = ComponentGetValue2(v,"name")
            if compname == "NoitaMP_deathscript_deathdata" then
                ComponentSetValue2(v,"value_bool",true)
                ComponentSetValue2(v,"value_int",0)
            end
        end
    end
    
    local comps = EntityGetComponentIncludingDisabled(entity_id, "LuaComponent")
    for k=1, #comps
        do local v = comps[k];
            local compname = ComponentGetValue2(v,"script_source_file")
            if compname == "mods/noita-mp/files/scripts/noita-components/mina-death/revive-check-nearby.lua" then
                EntitySetComponentIsEnabled(entity_id,v,true)
            end
        end
    end
end


function check_death()
	local comp = EntityGetFirstComponentIncludingDisabled( entity_id, "DamageModelComponent" )
    local isdead = false
	if( comp ~= nil ) then
		local hp = ComponentGetValueFloat( comp, "hp" )

		-- check death
		if ( hp <= 0.0 ) and (isdead ~= true) then

			isdead = true
		end
	end
    if isdead == true then
        return true
    else
        return false
    end
end






--[[
local hitboxcomp = EntityGetComponent(entity_id,HitboxComponent)
EntitySetComponentIsEnabled(entity_id,hitboxcomp,false)
]]--