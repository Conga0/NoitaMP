
local entity_id = GetUpdatedEntityID()
local dmgcomp = EntityGetComponent(entity_id,DamageModelComponent)
ComponentSetValue2(dmgcomp,"wait_for_kill_flag_on_death",true)

EntityAddComponent2(entity_id,
"LuaComponent",
{
    script_damage_received  = "mods/noita-mp/files/scripts/mina-death/death-check.lua",
    execute_every_n_frame   = -1,
    execute_times           = -1,
})

--bool keeps track of if mina is dead or not
--int keeps track of current revive progress, 0 = 0%, 120 = 100%, measured in frames.
EntityAddComponent2(entity_id,
"VariableStorageComponent",
{
    name    = "NoitaMP_deathscript_deathdata",
    value_bool = false,
    value_int = 0,
})








--[[
local hitboxcomp = EntityGetComponent(entity_id,HitboxComponent)
EntitySetComponentIsEnabled(entity_id,hitboxcomp,false)
]]--