-- OOP class definition is found here: Closure approach
-- http://lua-users.org/wiki/ObjectOrientationClosureApproach
-- Naming convention is found here:
-- http://lua-users.org/wiki/LuaStyleGuide#:~:text=Lua%20internal%20variable%20naming%20%2D%20The,but%20not%20necessarily%2C%20e.g.%20_G%20.

----------------------------------------
--- 'Imports'
----------------------------------------
local sock        = require("sock")
local util        = require("util")
local zstandard   = require("zstd")
local messagePack = require("MessagePack")

----------------------------------------------------------------------------------------------------
--- Client
----------------------------------------------------------------------------------------------------
Client            = {}

----------------------------------------
-- Global private variables:
----------------------------------------

----------------------------------------
-- Global private methods:
----------------------------------------

----------------------------------------
-- Access to global private variables
----------------------------------------

----------------------------------------
-- Global public variables:
----------------------------------------

----------------------------------------------------------------------------------------------------
--- Client constructor
----------------------------------------------------------------------------------------------------
--- Creates a new instance of client 'class'.
--- @param sockClient table sock.lua#newClient
--- @return table Client
function Client.new(sockClient)
    local self        = sockClient

    ------------------------------------
    --- Private variables:
    ------------------------------------

    ------------------------------------
    --- Public variables:
    ------------------------------------
    self.iAm          = "CLIENT"
    self.name         = tostring(ModSettingGet("noita-mp.name"))
    -- guid might not be set here or will be overwritten at the end of the constructor. @see setGuid
    self.guid         = tostring(ModSettingGet("noita-mp.guid"))
    self.nuid         = nil
    self.acknowledge  = {} -- sock.lua#Client:send -> self.acknowledge[packetsSent] = { event = event, data = data, entityId = data.entityId, status = NetworkUtils.events.acknowledgement.sent }
    self.transform    = { x = 0, y = 0 }
    self.health       = { current = 234, max = 2135 }
    self.serverInfo   = {}
    self.otherClients = {}
    self.entityCache  = {}

    ------------------------------------
    --- Private methods:
    ------------------------------------

    ------------------------------------------------------------------------------------------------
    --- Set clients settings
    ------------------------------------------------------------------------------------------------
    local function setConfigSettings()
        local serialize   = function(anyValue)
            --logger:debug(logger.channels.network, ("Serializing value: %s"):format(anyValue))
            local serialized      = messagePack.pack(anyValue)
            local zstd            = zstandard:new()
            --logger:debug(logger.channels.network, "Uncompressed size:", string.len(serialized))
            local compressed, err = zstd:compress(serialized)
            if err then
                logger:error(logger.channels.network, "Error while compressing: " .. err)
            end
            --logger:debug(logger.channels.network, "Compressed size:", string.len(compressed))
            --logger:debug(logger.channels.network, ("Serialized and compressed value: %s"):format(compressed))
            zstd:free()
            return compressed
        end

        local deserialize = function(anyValue)
            --logger:debug(logger.channels.network, ("Serialized and compressed value: %s"):format(anyValue))
            local zstd              = zstandard:new()
            --logger:debug(logger.channels.network, "Compressed size:", string.len(anyValue))
            local decompressed, err = zstd:decompress(anyValue)
            if err then
                logger:error(logger.channels.network, "Error while decompressing: " .. err)
            end
            --logger:debug(logger.channels.network, "Uncompressed size:", string.len(decompressed))
            local deserialized = messagePack.unpack(decompressed)
            logger:debug(logger.channels.network, ("Deserialized and uncompressed value: %s"):format(deserialized))
            zstd:free()
            return deserialized
        end

        self:setSerialization(serialize, deserialize)
        self:setTimeout(320, 50000, 100000)
    end

    ------------------------------------------------------------------------------------------------
    --- Set clients guid
    ------------------------------------------------------------------------------------------------
    local function setGuid()
        local guid = tostring(ModSettingGetNextValue("noita-mp.guid"))

        if guid == "" or Guid.isPatternValid(guid) == false then
            guid = Guid:getGuid()
            ModSettingSetNextValue("noita-mp.guid", guid, false)
            self.guid = guid
            logger:debug(logger.channels.network, "Clients guid set to " .. guid)
        else
            logger:debug(logger.channels.network, "Clients guid was already set to " .. guid)
        end

        if DebugGetIsDevBuild() then
            guid = guid .. self.iAm
        end
    end

    ------------------------------------------------------------------------------------------------
    --- Send acknowledgement
    ------------------------------------------------------------------------------------------------
    local function sendAck(networkMessageId)
        local data = { networkMessageId, NetworkUtils.events.acknowledgement.ack }
        self:send(NetworkUtils.events.acknowledgement.name, data)
        logger:debug(logger.channels.network, ("Sent ack with data = %s"):format(util.pformat(data)))
    end

    ------------------------------------------------------------------------------------------------
    --- onAcknowledgement
    ------------------------------------------------------------------------------------------------
    local function onAcknowledgement(data)
        logger:debug(logger.channels.network, "onAcknowledgement: Acknowledgement received.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onAcknowledgement data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if not data.networkMessageId then
            logger:error(logger.channels.network,
                         ("Unable to get acknowledgement with networkMessageId = %s, data = %s, peer = %s")
                                 :format(networkMessageId, util.pformat(data), util.pformat(peer)))
            return
        end

        if not self.acknowledge[data.networkMessageId] then
            self.acknowledge[data.networkMessageId] = {}
        end

        self.acknowledge[data.networkMessageId].status = data.status
    end

    ------------------------------------------------------------------------------------------------
    --- onConnect
    ------------------------------------------------------------------------------------------------
    --- Callback when connected to server.
    --- @param data number not in use atm
    local function onConnect(data)
        logger:debug(logger.channels.network, "Connected to server!", util.pformat(data))

        if util.IsEmpty(data) then
            error(("onConnect data is empty: %s"):format(data), 3)
        end

        -- sendAck(data.networkMessageId)
    end

    ------------------------------------------------------------------------------------------------
    --- onConnect2
    ------------------------------------------------------------------------------------------------
    --- Callback when one of the other clients connected.
    --- @param data table data = { "name", "guid" } @see NetworkUtils.events.connect2.schema
    local function onConnect2(data)
        logger:debug(logger.channels.network, "Another client connected.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onConnect2 data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.name) then
            error(("onConnect2 data.name is empty: %s"):format(data.name), 3)
        end

        if util.IsEmpty(data.guid) then
            error(("onConnect2 data.guid is empty: %s"):format(data.guid), 3)
        end

        sendAck(data.networkMessageId)

        table.insertIfNotExist(self.otherClients, { name = data.name, guid = data.guid })
    end

    ------------------------------------------------------------------------------------------------
    --- onDisconnect
    ------------------------------------------------------------------------------------------------
    --- Callback when disconnected from server.
    --- @param data number data(.code) = 0
    local function onDisconnect(data)
        logger:debug(logger.channels.network, "Disconnected from server!", util.pformat(data))

        if util.IsEmpty(data) then
            error(("onDisconnect data is empty: %s"):format(data), 3)
        end

        -- sendAck(data.networkMessageId)

        if self.serverInfo.nuid then
            EntityUtils.destroyByNuid(self.serverInfo.nuid)
        end

        -- TODO remove all NUIDS from entities. I now need a nuid-entityId-cache.
        local nuid, entityId = GlobalsUtils.getNuidEntityPair(self.nuid)
        NetworkVscUtils.addOrUpdateAllVscs(entityId, self.name, self.guid, nil)

        self.acknowledge  = {}
        self.nuid         = nil
        self.otherClients = {}
        self.serverInfo   = {}
    end

    ------------------------------------------------------------------------------------------------
    --- onDisconnect2
    ------------------------------------------------------------------------------------------------
    --- Callback when one of the other clients disconnected.
    --- @param data table data { "name", "guid" } @see NetworkUtils.events.disconnect2.schema
    local function onDisconnect2(data)
        logger:debug(logger.channels.network, "onDisconnect2: Another client disconnected.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onDisconnect2 data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.name) then
            error(("onDisconnect2 data.name is empty: %s"):format(data.name), 3)
        end

        if util.IsEmpty(data.guid) then
            error(("onDisconnect2 data.guid is empty: %s"):format(data.guid), 3)
        end

        sendAck(data.networkMessageId)

        for i = 1, #self.otherClients do
            -- table.insertIfNotExist(self.otherClients, { name = data.name, guid = data.guid })
        end
    end

    ------------------------------------------------------------------------------------------------
    --- onPlayerInfo
    ------------------------------------------------------------------------------------------------
    --- Callback when Server sent his playerInfo to the client
    --- @param data table data { networkMessageId, name, guid }
    local function onPlayerInfo(data)
        logger:debug(logger.channels.network, "onPlayerInfo: Player info received.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onPlayerInfo data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.name) then
            error(("onPlayerInfo data.name is empty: %s"):format(data.name), 3)
        end

        if util.IsEmpty(data.guid) then
            error(("onPlayerInfo data.guid is empty: %s"):format(data.guid), 3)
        end

        if util.IsEmpty(data.nuid) then
            error(("onPlayerInfo data.nuid is empty: %s"):format(data.nuid), 3)
        end

        if util.IsEmpty(data.version) then
            error(("onPlayerInfo data.version is empty: %s"):format(data.version), 3)
        end

        if data.guid == self.guid then
            logger:error(logger.channels.network,
                         "onPlayerInfo: Clients GUID isn't unique! Server will fix this!")
            --self.guid = Guid:getGuid({ self.guid })
            --logger:info(logger.channels.network, "onPlayerInfo: New clients GUID: %s", self.guid)
            self:disconnect()
        end

        if _G.NoitaMPVersion ~= tostring(data.version) then
            error(("Version mismatch: NoitaMP version of Server: %s and your version: %s")
                          :format(data.version, _G.NoitaMPVersion), 3)
            self:disconnect()
        end

        sendAck(data.networkMessageId)

        self.serverInfo.name = data.name
        self.serverInfo.guid = data.guid
        self.serverInfo.nuid = data.nuid
    end

    ------------------------------------------------------------------------------------------------
    --- onNewGuid
    ------------------------------------------------------------------------------------------------
    --- Callback when Server sent a new GUID for a specific client.
    --- @param data table data { "networkMessageId", "oldGuid", "newGuid" }
    local function onNewGuid(data)
        logger:debug(logger.channels.network, "onNewGuid: New GUID from server received.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onNewGuid data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.oldGuid) then
            error(("onNewGuid data.oldGuid is empty: %s"):format(data.oldGuid), 3)
        end

        if util.IsEmpty(data.newGuid) then
            error(("onNewGuid data.newGuid is empty: %s"):format(data.newGuid), 3)
        end

        sendAck(data.networkMessageId)

        if data.oldGuid == self.guid then
            local entityId = util.getLocalPlayerInfo().entityId
            local compOwnerName, compOwnerGuid, compNuid = NetworkVscUtils.getAllVcsValuesByEntityId(entityId)

            self.guid = data.newGuid
            ModSettingSet("noita-mp.guid", self.guid)
            ModSettingSet("noita-mp.guid_readonly", self.guid)

            NetworkVscUtils.addOrUpdateAllVscs(entityId, compOwnerName, self.guid, compNuid)
        else
            for i = 1, #self.otherClients do
                if self.otherClients[i].guid == data.oldGuid then
                    self.otherClients[i].guid = data.newGuid
                end
            end
        end
    end

    ------------------------------------------------------------------------------------------------
    --- onSeed
    ------------------------------------------------------------------------------------------------
    --- Callback when Server sent his seed to the client
    --- @param data table data { networkMessageId, seed }
    local function onSeed(data)
        logger:debug(logger.channels.network, "onSeed: Seed from server received.", util.pformat(data))

        if util.IsEmpty(data.networkMessageId) then
            error(("onSeed data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.seed) then
            error(("onSeed data.seed is empty: %s"):format(data.seed), 3)
        end

        sendAck(data.networkMessageId)

        local serversSeed = tonumber(data.seed)
        logger:info(logger.channels.network,
                    "Client received servers seed (%s) and stored it. Reloading map with that seed!", serversSeed)

        local localSeed = tonumber(StatsGetValue("world_seed"))
        if localSeed ~= serversSeed then
            --util.reloadMap(serversSeed) TODO enable again, when custom map/biome isnt used anymore
        end

        local localPlayerInfo = util.getLocalPlayerInfo()
        local name            = localPlayerInfo.name
        local guid            = localPlayerInfo.guid
        local nuid            = localPlayerInfo.nuid -- Could be nil. Timing issue. Will be set after this.
        local entityId        = localPlayerInfo.entityId

        self:send(NetworkUtils.events.playerInfo.name,
                  { NetworkUtils.getNextNetworkMessageId(), name, guid, nuid, _G.NoitaMPVersion })

        if not NetworkVscUtils.hasNetworkLuaComponents(entityId) then
            NetworkVscUtils.addOrUpdateAllVscs(entityId, name, guid, nil)
        end

        if not NetworkVscUtils.hasNuidSet(entityId) then
            self.sendNeedNuid(name, guid, entityId)
        end
    end

    ------------------------------------------------------------------------------------------------
    --- onNewNuid
    ------------------------------------------------------------------------------------------------
    --- Callback when Server sent a new nuid to the client
    --- @param data table data { networkMessageId, owner { name, guid }, localEntityId, newNuid, x, y, rotation,
    --- velocity { x, y }, filename }
    local function onNewNuid(data)
        logger:debug(logger.channels.network, ("Received a new nuid! data = %s"):format(util.pformat(data)))

        if util.IsEmpty(data.networkMessageId) then
            error(("onNewNuid data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.owner) then
            error(("onNewNuid data.owner is empty: %s"):format(util.pformat(data.owner)), 3)
        end

        if util.IsEmpty(data.localEntityId) then
            error(("onNewNuid data.localEntityId is empty: %s"):format(data.localEntityId), 3)
        end

        if util.IsEmpty(data.newNuid) then
            error(("onNewNuid data.newNuid is empty: %s"):format(data.newNuid), 3)
        end

        if util.IsEmpty(data.x) then
            error(("onNewNuid data.x is empty: %s"):format(data.x), 3)
        end

        if util.IsEmpty(data.y) then
            error(("onNewNuid data.y is empty: %s"):format(data.y), 3)
        end

        if util.IsEmpty(data.rotation) then
            error(("onNewNuid data.rotation is empty: %s"):format(data.rotation), 3)
        end

        if util.IsEmpty(data.velocity) then
            error(("onNewNuid data.velocity is empty: %s"):format(util.pformat(data.velocity)), 3)
        end

        if util.IsEmpty(data.filename) then
            error(("onNewNuid data.filename is empty: %s"):format(data.filename), 3)
        end

        if util.IsEmpty(data.health) then
            error(("onNewNuid data.health is empty: %s"):format(data.health), 3)
        end

        if util.IsEmpty(data.isPolymorphed) then
            error(("onNewNuid data.isPolymorphed is empty: %s"):format(data.isPolymorphed), 3)
        end

        sendAck(data.networkMessageId)

        local owner         = data.owner
        local localEntityId = data.localEntityId
        local newNuid       = data.newNuid
        local x             = data.x
        local y             = data.y
        local rotation      = data.rotation
        local velocity      = data.velocity
        local filename      = data.filename
        local health        = data.health
        local isPolymorphed = data.isPolymorphed

        if owner.guid == util.getLocalPlayerInfo().guid then
            if localEntityId == util.getLocalPlayerInfo().entityId then
                self.nuid = newNuid
            end
        end

        EntityUtils.SpawnEntity(owner, newNuid, x, y, rotation, velocity, filename, localEntityId, health,
                                isPolymorphed)
    end

    local function onEntityData(data)
        logger:debug(logger.channels.network, ("Received entityData for nuid = %s! data = %s")
                :format(data.nuid, util.pformat(data)))

        if util.IsEmpty(data.networkMessageId) then
            error(("onNewNuid data.networkMessageId is empty: %s"):format(data.networkMessageId), 3)
        end

        if util.IsEmpty(data.owner) then
            error(("onNewNuid data.owner is empty: %s"):format(util.pformat(data.owner)), 3)
        end

        --if util.IsEmpty(data.localEntityId) then
        --    error(("onNewNuid data.localEntityId is empty: %s"):format(data.localEntityId), 3)
        --end

        if util.IsEmpty(data.nuid) then
            error(("onNewNuid data.nuid is empty: %s"):format(data.nuid), 3)
        end

        if util.IsEmpty(data.x) then
            error(("onNewNuid data.x is empty: %s"):format(data.x), 3)
        end

        if util.IsEmpty(data.y) then
            error(("onNewNuid data.y is empty: %s"):format(data.y), 3)
        end

        if util.IsEmpty(data.rotation) then
            error(("onNewNuid data.rotation is empty: %s"):format(data.rotation), 3)
        end

        if util.IsEmpty(data.velocity) then
            error(("onNewNuid data.velocity is empty: %s"):format(util.pformat(data.velocity)), 3)
        end

        if util.IsEmpty(data.health) then
            error(("onNewNuid data.health is empty: %s"):format(data.health), 3)
        end

        -- sendAck(data.networkMessageId) do not send ACK for position data, network will explode

        local owner                = data.owner
        local nnuid, localEntityId = GlobalsUtils.getNuidEntityPair(data.nuid)
        local nuid                 = data.nuid
        local x                    = data.x
        local y                    = data.y
        local rotation             = data.rotation
        local velocity             = data.velocity
        local health               = data.health

        NoitaComponentUtils.setEntityData(localEntityId, x, y, rotation, velocity, health)
    end

    local function onDeadNuids(data)
        local deadNuids = data.deadNuids or data or {}
        for i = 1, #deadNuids do
            local deadNuid = deadNuids[i]
            if util.IsEmpty(deadNuid) or deadNuid == "nil" then
                logger:error(logger.channels.network, ("onDeadNuids deadNuid is empty: %s"):format(deadNuid), 3)
            else
                EntityUtils.destroyByNuid(deadNuid)
                GlobalsUtils.removeDeadNuid(deadNuid)
            end
        end
    end

    -- self:on(
    --     "entityAlive",
    --     function(data)
    --         logger:debug(util.pformat(data))

    --         em:DespawnEntity(data.owner, data.localEntityId, data.nuid, data.isAlive)
    --     end
    -- )

    -- self:on(
    --     "entityState",
    --     function(data)
    --         logger:debug(util.pformat(data))

    --         local nc = em:GetNetworkComponent(data.owner, data.localEntityId, data.nuid)
    --         if nc then
    --             EntityApplyTransform(nc.local_entity_id, data.x, data.y, data.rot)
    --         else
    --             logger:warn(logger.channels.network,
    --                 "Got entityState, but unable to find the network component!" ..
    --                 " owner(%s, %s), localEntityId(%s), nuid(%s), x(%s), y(%s), rot(%s), velocity(x %s, y %s), health(%s)",
    --                 data.owner.name,
    --                 data.owner.guid,
    --                 data.localEntityId,
    --                 data.nuid,
    --                 data.x,
    --                 data.y,
    --                 data.rot,
    --                 data.velocity.x,
    --                 data.velocity.y,
    --                 data.health
    --             )
    --         end
    --     end
    -- )

    ------------------------------------------------------------------------------------------------
    --- setCallbackAndSchemas
    ------------------------------------------------------------------------------------------------
    --- Sets callbacks and schemas of the client.
    local function setCallbackAndSchemas()
        --self:setSchema(NetworkUtils.events.connect, { "code" })
        self:on(NetworkUtils.events.connect.name, onConnect)

        self:setSchema(NetworkUtils.events.connect2.name, NetworkUtils.events.connect2.schema)
        self:on(NetworkUtils.events.connect2.name, onConnect2)

        --self:setSchema(NetworkUtils.events.disconnect, { "code" })
        self:on(NetworkUtils.events.disconnect.name, onDisconnect)

        self:setSchema(NetworkUtils.events.disconnect2.name, NetworkUtils.events.disconnect2.schema)
        self:on(NetworkUtils.events.disconnect2.name, onDisconnect2)

        self:setSchema(NetworkUtils.events.acknowledgement.name, NetworkUtils.events.acknowledgement.schema)
        self:on(NetworkUtils.events.acknowledgement.name, onAcknowledgement)

        self:setSchema(NetworkUtils.events.seed.name, NetworkUtils.events.seed.schema)
        self:on(NetworkUtils.events.seed.name, onSeed)

        self:setSchema(NetworkUtils.events.playerInfo.name, NetworkUtils.events.playerInfo.schema)
        self:on(NetworkUtils.events.playerInfo.name, onPlayerInfo)

        self:setSchema(NetworkUtils.events.newGuid.name, NetworkUtils.events.newGuid.schema)
        self:on(NetworkUtils.events.newGuid.name, onNewGuid)

        self:setSchema(NetworkUtils.events.newNuid.name, NetworkUtils.events.newNuid.schema)
        self:on(NetworkUtils.events.newNuid.name, onNewNuid)

        self:setSchema(NetworkUtils.events.entityData.name, NetworkUtils.events.entityData.schema)
        self:on(NetworkUtils.events.entityData.name, onEntityData)

        self:setSchema(NetworkUtils.events.deadNuids.name, NetworkUtils.events.deadNuids.schema)
        self:on(NetworkUtils.events.deadNuids.name, onDeadNuids)

        -- self:setSchema("duplicatedGuid", { "newGuid" })
        -- self:setSchema("worldFiles", { "relDirPath", "fileName", "fileContent", "fileIndex", "amountOfFiles" })
        -- self:setSchema("worldFilesFinished", { "progress" })
        -- self:setSchema("seed", { "seed" })
        -- self:setSchema("clientInfo", { "name", "guid" })
        -- self:setSchema("needNuid", { "owner", "localEntityId", "x", "y", "rot", "velocity", "filename" })
        -- self:setSchema("newNuid", { "owner", "localEntityId", "nuid", "x", "y", "rot", "velocity", "filename" })
        -- self:setSchema("entityAlive", { "owner", "localEntityId", "nuid", "isAlive" })
        -- self:setSchema("entityState", { "owner", "localEntityId", "nuid", "x", "y", "rot", "velocity", "health" })
    end

    local function updateVariables()
        local entityId = util.getLocalPlayerInfo().entityId
        if entityId then
            local compOwnerName, compOwnerGuid, compNuid, filename, health, rotation, velocity, x, y = NoitaComponentUtils.getEntityData(entityId)
            self.health                                                                              = health
            self.transform                                                                           = { x = math.floor(x), y = math.floor(y) }

            if not compNuid then
                self.sendNeedNuid(compOwnerName, compOwnerGuid, entityId)
            end
        end
    end

    ------------------------------------
    -- Public methods:
    ------------------------------------

    --#region Connect and disconnect

    --- Some inheritance: Save parent function (not polluting global 'self' space)
    local sockClientConnect = sockClient.connect
    --- Connects to a server on ip and port. Both can be nil, then ModSettings will be used.
    --- @param ip string localhost or 127.0.0.1 or nil
    --- @param port number port number from 1 to max of 65535 or nil
    --- @param code number connection code 0 = connecting first time, 1 = connected second time with loaded seed
    function self.connect(ip, port, code)

        if self:isConnecting() or self:isConnected() then
            logger:warn(logger.channels.network, "Client is still connected to %s:%s. Disconnecting!",
                        self:getAddress(), self:getPort())
            self:disconnect()
        end

        if not ip then
            ip = tostring(ModSettingGet("noita-mp.connect_server_ip"))
        end

        if not port then
            port = tonumber(ModSettingGet("noita-mp.connect_server_port"))
        end

        port = tonumber(port)

        self.disconnect()
        _G.Client.disconnect() -- stop if any server is already running

        logger:info(logger.channels.network, "Connecting to server on %s:%s", ip, port)
        if not self.host then
            self:establishClient(ip, port)
        end

        GamePrintImportant("Client is connecting..",
                           "You are trying to connect to " .. self:getAddress() .. ":" .. self:getPort() .. "!",
                           ""
        )

        sockClientConnect(self, code)

        -- FYI: If you want to send data after connected, do it in the "connect" callback function
    end

    --- Some inheritance: Save parent function (not polluting global 'self' space)
    local sockClientDisconnect = sockClient.disconnect
    function self.disconnect()
        if self.isConnected() then
            sockClientDisconnect(self)
        else
            logger:info(logger.channels.network, "Client isn't connected, no need to disconnect!")
        end
    end

    --#endregion

    --#region Additional methods

    local sockClientIsConnected = sockClient.isConnected
    function self.isConnected()
        return sockClientIsConnected(self)
    end

    --local lastFrames = 0
    --local diffFrames = 0
    --local fps30 = 0
    local prevTime         = 0
    --- Some inheritance: Save parent function (not polluting global 'self' space)
    local sockClientUpdate = sockClient.update
    --- Updates the Client by checking for network events and handling them.
    function self.update()
        if not self.isConnected() and not self:isConnecting() or self:isDisconnected() then
            return
        end

        EntityUtils.destroyClientEntities()
        EntityUtils.initNetworkVscs()

        local nowTime     = GameGetRealWorldTimeSinceStarted() * 1000 -- *1000 to get milliseconds
        local elapsedTime = nowTime - prevTime
        local oneTickInMs = 1000 / tonumber(ModSettingGet("noita-mp.tick_rate"))
        if elapsedTime >= oneTickInMs then
            prevTime = nowTime
            updateVariables()

            --EntityUtils.destroyClientEntities()
            EntityUtils.syncEntityData()
            EntityUtils.syncDeadNuids()
        end

        sockClientUpdate(self)
    end

    --- Some inheritance: Save parent function (not polluting global 'self' space)
    local sockClientSend = sockClient.send

    function self:send(event, data)
        if type(data) ~= "table" then
            error("", 3)
        end

        if NetworkUtils.alreadySent(event, data) then
            logger:info(logger.channels.network, ("Network message for %s for data %s already was acknowledged.")
                    :format(event, util.pformat(data)))
            return
        end

        local networkMessageId = sockClientSend(self, event, data)

        if not self.acknowledge then
            self.acknowledge = {}
        end

        if event ~= NetworkUtils.events.acknowledgement.name then
            if not self.acknowledge[networkMessageId] then
                self.acknowledge[networkMessageId] = {}
            end

            self.acknowledge[networkMessageId] = { event  = event, data = data, entityId = data.entityId,
                                                   status = NetworkUtils.events.acknowledgement.sent, sentAt = os.time() }
        end
    end

    function self.sendNeedNuid(ownerName, ownerGuid, entityId)
        if not EntityUtils.isEntityAlive(entityId) then
            return
        end

        local compOwnerName, compOwnerGuid, compNuid, filename, health, rotation, velocity, x, y = NoitaComponentUtils.getEntityData(entityId)
        local data                                                                               = {
            NetworkUtils.getNextNetworkMessageId(), { ownerName, ownerGuid }, entityId, x, y, rotation, velocity,
            filename, health, EntityUtils.isEntityPolymorphed(entityId)--EntityUtils.isPlayerPolymorphed()
        }

        self:send(NetworkUtils.events.needNuid.name, data)
    end

    function self.sendLostNuid(nuid)
        local data = { NetworkUtils.getNextNetworkMessageId(), nuid }
        self:send(NetworkUtils.events.lostNuid.name, data)
    end

    function self.sendEntityData(entityId)
        if not EntityUtils.isEntityAlive(entityId) then
            return
        end

        --local compOwnerName, compOwnerGuid, compNuid     = NetworkVscUtils.getAllVcsValuesByEntityId(entityId)
        local compOwnerName, compOwnerGuid, compNuid, filename, health, rotation, velocity, x, y = NoitaComponentUtils.getEntityData(entityId)
        local data                                                                               = {
            NetworkUtils.getNextNetworkMessageId(), { compOwnerName, compOwnerGuid }, compNuid, x, y, rotation, velocity, health
        }

        if util.IsEmpty(compNuid) then
            -- this can happen, when entity spawned on client and network is slow
            logger:error(logger.channels.network, "Unable to send entity data, because nuid is empty.")
            self.sendNeedNuid(compOwnerName, compOwnerGuid, entityId)
            return
        end

        if util.getLocalPlayerInfo().guid == compOwnerGuid then
            self:send(NetworkUtils.events.entityData.name, data)
        end
    end

    function self.sendDeadNuids(deadNuids)
        local data = {
            NetworkUtils.getNextNetworkMessageId(), deadNuids
        }
        self:send(NetworkUtils.events.deadNuids.name, data)
        onDeadNuids(deadNuids)
    end

    --- Checks if the current local user is a client
    --- @return boolean iAm true if client
    function self.amIClient()
        if not _G.Server.amIServer() then
            return true
        end
        return false
    end

    --#endregion

    ------------------------------------
    -- Apply some private methods
    ------------------------------------
    setGuid()
    setConfigSettings()
    setCallbackAndSchemas()

    return self
end

------------------------------------
-- Init this object:
------------------------------------

-- Because of stack overflow errors when loading lua files,
-- I decided to put Utils 'classes' into globals
_G.ClientInit = Client
_G.Client     = Client.new(sock.newClient())

-- But still return for Noita Components,
-- which does not have access to _G,
-- because of own context/vm
return Client
