-- OOP class definition is found here: Closure approach
-- http://lua-users.org/wiki/ObjectOrientationClosureApproach
-- Naming convention is found here:
-- http://lua-users.org/wiki/LuaStyleGuide#:~:text=Lua%20internal%20variable%20naming%20%2D%20The,but%20not%20necessarily%2C%20e.g.%20_G%20.

-----------------
--- MinaUtils:
-----------------
MinaUtils = {}

function privateLocalOne()
end

MinaUtils.globalOne = function()
end

MinaUtils.reviveMaxProgress = 20

-- HERE you can add you function for fetching VSC values and sending stuff

function MinaUtils.isKnockedOut(nuid)
    local comps = EntityGetComponentIncludingDisabled(nuid, "VariableStorageComponent")
    for k=1, #comps
        do local v = comps[k];
            local compname = ComponentGetValue2(v,"name")
            if compname == "NoitaMP_deathscript_deathdata" then
                local isdead = ComponentGetValue2(v,"value_bool")
                if isdead ~= true then
                    return true
                end
            end
        end
    end
end

function MinaUtils.getReviveProgress(nuid)
    local comps = EntityGetComponentIncludingDisabled(nuid, "VariableStorageComponent")
    for k=1, #comps
        do local v = comps[k];
            local compname = ComponentGetValue2(v,"name")
            if compname == "NoitaMP_deathscript_deathdata" then
                local progress = ComponentGetValue2(v,"value_int")
                return progress
            end
        end
    end
end

-- Because of stack overflow errors when loading lua files,
-- I decided to put Utils 'classes' into globals




_G.MinaUtils = MinaUtils

-- But still return for Noita Components,
-- which does not have access to _G,
-- because of own context/vm
return MinaUtils