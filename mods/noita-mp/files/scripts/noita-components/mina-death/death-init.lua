
local entity_id = GetUpdatedEntityID()
local dmgcomp = EntityGetComponent(entity_id,DamageModelComponent)
ComponentSetValue2(dmgcomp,"wait_for_kill_flag_on_death",true)

EntityAddComponent2(entity_id,
"LuaComponent",
{
    script_damage_received  = "mods/noita-mp/files/scripts/noita-components/mina-death/death-check.lua",
    execute_every_n_frame   = -1,
    execute_times           = -1,
})

--bool keeps track of if mina is dead or not
--int keeps track of current revive progress, 0 = 0%, 20 = 100%, measured in frames. add 1 to value every 10 frames until 20 is reached
-- 20/6 = 3.33 seconds to revive
EntityAddComponent2(entity_id,
"VariableStorageComponent",
{
    name    = "NoitaMP_deathscript_deathdata",
    value_bool = false,
    value_int = 0,
})

EntityAddComponent2(entity_id,
"LuaComponent",
{
    _enabled                = false,
    script_source_file      = "mods/noita-mp/files/scripts/noita-components/mina-death/revive-check-nearby.lua",
    execute_every_n_frame   = 30,
    execute_times           = -1,
})

EntityAddComponent2(entity_id,
"LuaComponent",
{
    _enabled                = false,
    script_source_file      = "mods/noita-mp/files/scripts/noita-components/mina-death/revive-check-progress.lua",
    execute_every_n_frame   = 10,
    execute_times           = -1,
})








--[[
local hitboxcomp = EntityGetComponent(entity_id,HitboxComponent)
EntitySetComponentIsEnabled(entity_id,hitboxcomp,false)
]]--