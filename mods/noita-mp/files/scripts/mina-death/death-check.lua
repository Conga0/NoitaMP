
function damage_received( damage, desc, entity_who_caused, is_fatal )
    local entity_id = GetUpdatedEntityID()
    local isdead = check_death()

    if isdead ~= true then return end

    local comps = EntityGetComponentIncludingDisabled(VariableStorageComponent)

    for k=1, #comps
        do local v = comps[k];
            local compname = ComponentGetValue2(v,"name")
            if compname == "NoitaMP_deathscript_deathdata" then
                ComponentSetValue2(v,"value_bool",true)
            end
        end
    end
end


function check_death()
    local cpc = CustomProfiler.start("death-check.check_death")

	local comp = EntityGetFirstComponentIncludingDisabled( entity_id, "DamageModelComponent" )
    local isdead = false
	if( comp ~= nil ) then
		local hp = ComponentGetValueFloat( comp, "hp" )
		local max_hp = ComponentGetValueFloat( comp, "max_hp" )
        local pos_x, pos_y = EntityGetTransform( entity_id )

		-- check death
		if ( hp <= 0.0 ) and (is_dead ~= true) then

			isdead = true
		end
	end
    CustomProfiler.stop("death-check.check_death", cpc)
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