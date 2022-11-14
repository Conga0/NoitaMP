-- https://subscription.packtpub.com/book/game-development/9781849515504/1/ch01lvl1sec10/preparing-a-basic-file-structure-for-the-game-engine

--[[ NoitaMP additions ]]
return function(destination_path)
    if destination_path then
        print("init_package_loading.lua: destination_path = " .. tostring(destination_path))
    end

    local default_package_path = package.path
    package.path               = package.path ..
            ";./noita-mp/files/lib/external/?.lua;" ..
            "./noita-mp/files/scripts/util/?.lua;" ..
            "mods/noita-mp/files/lib/external/?.lua;" ..
            "mods/noita-mp/files/scripts/util/?.lua;"

    if destination_path then
        package.path = package.path .. ";" ..
                destination_path .. "/noita-mp/files/lib/external/?.lua;" ..
                destination_path .. "/noita-mp/files/scripts/util/?.lua;" ..
                destination_path .. "/mods/noita-mp/files/lib/external/?.lua;" ..
                destination_path .. "/mods/noita-mp/files/scripts/util/?.lua;"
    end

    package.cpath = package.cpath ..
            ";./noita-mp/files/lib/external/dlls/?.dll;" ..
            ";mods/noita-mp/files/lib/external/dlls/?.dll;"

    if destination_path then
        package.cpath = package.cpath .. ";" ..
                destination_path .. "/noita-mp/files/lib/external/dlls/?.dll;" ..
                destination_path .. "mods/noita-mp/files/lib/external/dlls/?.dll;"
    end

    local fu    = require("file_util")
    --[[ NoitaMP additions ]]
    -- A list of paths to lua script modules
    local paths = {
        "mods/noita-mp/files/{module}",
        "mods/noita-mp/files/lib/{module}",
        "mods/noita-mp/files/lib/external/{module}",
        "mods/noita-mp/files/lib/external/dlls/{module}",
        "mods/noita-mp/files/scripts/{module}",
        "mods/noita-mp/files/scripts/components/{module}",
        "mods/noita-mp/files/scripts/init/{module}",
        "mods/noita-mp/files/scripts/net/{module}",
        "mods/noita-mp/files/scripts/util/{module}"
    }

    if destination_path then
        paths = {
            destination_path .. "/mods/noita-mp/files/{module}",
            destination_path .. "/mods/noita-mp/files/lib/{module}",
            destination_path .. "/mods/noita-mp/files/lib/external/{module}",
            destination_path .. "/mods/noita-mp/files/lib/external/dlls/{module}",
            destination_path .. "/mods/noita-mp/files/scripts/{module}",
            destination_path .. "/mods/noita-mp/files/scripts/components/{module}",
            destination_path .. "/mods/noita-mp/files/scripts/init/{module}",
            destination_path .. "/mods/noita-mp/files/scripts/net/{module}",
            destination_path .. "/mods/noita-mp/files/scripts/util/{module}"
        }
    end

    -- A list of paths to binary Lua modules
    local module_paths = {
        "?.{extension}",
        "?/init.{extension}",
        "?/core.{extension}",
    }

    -- List of supported OS paired with binary file extension name
    local extensions                             = {
        Windows = "dll",
        Linux   = "so",
        Mac     = "dylib"
    }

    -- os_name is a supplemental module for
    -- OS and CPU architecture detection
    local os_name                                = require("os_name")

    --[[ NoitaMP additions ]]
    package.path                                 = default_package_path
    --[[ NoitaMP additions ]]
    -- A dot character represent current working directory
    local root_dir                               = "."
    local current_platform, current_architecture = os_name.getOS()

    local cpaths, lpaths                         = {}, {}
    local current_clib_extension                 = extensions[current_platform]

    --[[ NoitaMP additions ]]
    _G.os_name                                   = current_platform
    _G.os_arch                                   = current_architecture

    -- https://stackoverflow.com/a/14425862/3493998
    _G.path_separator                            = tostring(package.config:sub(1, 1))

    if _G.os_name == "Windows" then
        _G.is_windows = true
    end
    if _G.os_name == "Linux" then
        _G.is_linux = true
    end

    print("init_package_loading.lua | Detected OS " .. _G.os_name ..
                  "(" .. _G.os_arch .. ") with path separator '" .. _G.path_separator .. "'.")

    --[[ NoitaMP additions ]]
    if current_clib_extension then
        -- now you can process each defined path for module.
        for _, path in ipairs(paths) do
            local path = path:gsub("{(%w+)}", { root = root_dir, platform = current_platform })
            -- skip empty path entries
            if #path > 0 then
                -- make a substitution for each module file path.
                for _, raw_module_path in ipairs(module_paths) do
                    local module_path   = path:gsub(
                            "{(%w+)}",
                            {
                                module = raw_module_path
                            }
                    )
                    -- add path for binary module
                    cpaths[#cpaths + 1] = module_path:gsub(
                            "{(%w+)}",
                            {
                                extension = current_clib_extension
                            }
                    )
                    -- add paths for platform independent lua and luac modules
                    lpaths[#lpaths + 1] = module_path:gsub(
                            "{(%w+)}",
                            {
                                extension = "lua"
                            }
                    )
                    lpaths[#lpaths + 1] = module_path:gsub(
                            "{(%w+)}",
                            {
                                extension = "luac"
                            }
                    )
                end
            end
        end
        -- build module path list delimited with semicolon.
        --package.path = table.concat(lpaths, ";")
        --package.cpath = table.concat(cpaths, ";")

        --[[ NoitaMP additions ]]
        package.path  = fu.ReplacePathSeparator(table.concat(lpaths, ";"))
        package.cpath = fu.ReplacePathSeparator(table.concat(cpaths, ";"))

        if destination_path then
            print("destination_path was set to export LPATH and CPATH!")

            local lua_path_file          = fu.RemoveTrailingPathSeparator(destination_path) .. _G.path_separator .. "lua_path.txt"
            local lua_path_file_content  = ";" .. package.path

            local lua_cpath_file         = fu.RemoveTrailingPathSeparator(destination_path) .. _G.path_separator .. "lua_cpath.txt"
            local lua_cpath_file_content = ";" .. package.cpath

            fu.WriteFile(lua_path_file, lua_path_file_content)

            print("init_package_loading.lua | File (" .. lua_path_file ..
                          ") created with content: " .. lua_path_file_content)

            fu.WriteFile(lua_cpath_file, lua_cpath_file_content)
            print("init_package_loading.lua | File (" .. lua_cpath_file ..
                          ") created with content: " .. lua_cpath_file_content)
        else
            print("destination_path was not set. Export LPATH and CPATH will be skipped!")
        end

        print("init_package_loading.lua | package.path set to " .. package.path .. " .")
        print("init_package_loading.lua | package.cpath set to " .. package.cpath .. " .")
    else
        --[[ NoitaMP additions ]]
        error("Unable to detect OS!", 2)
    end
end
