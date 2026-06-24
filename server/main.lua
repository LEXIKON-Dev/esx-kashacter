local databaseConnected = false
local databaseFound = false
local oneSyncState = GetConvar("onesync", "off")

local DATABASE
do
	local connectionString = GetConvar("mysql_connection_string", "")

	if connectionString == "" then
		error(connectionString .. "\n^1Unable to start Multicharacter - unable to determine database from mysql_connection_string^0", 0)
	elseif connectionString:find("mysql://") then
		connectionString = connectionString:sub(9, -1)
		DATABASE = connectionString:sub(connectionString:find("/") + 1, -1):gsub("[%?]+[%w%p]*$", "")
		databaseFound = true
	else
		connectionString = { string.strsplit(";", connectionString) }

		for i = 1, #connectionString do
			local v = connectionString[i]
			if v:match("database") then
				DATABASE = v:sub(10, #v)
				databaseFound = true
				break
			end
		end
	end
end

local DB_TABLES = { users = "identifier" }
local SLOTS = Config.Slots or 4
local PREFIX = Config.Prefix or "char"
local PRIMARY_IDENTIFIER = ESX.GetConfig().Identifier or GetConvar("sv_lan", "") == "true" and "ip" or "license"
local PlayerCharacters = {}
local hasDisabledColumn = false
local USERS_QUERY = "SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, skin FROM users WHERE identifier LIKE ? OR identifier LIKE ?"

local function SafeJsonDecode(value, fallback)
	if not value or value == "" then
		return fallback
	end

	local ok, result = pcall(json.decode, value)
	return ok and result or fallback
end

local function GetCharSlot(ident, licenseHash)
	local slot = ident:match("^[Cc]har(%d+):")
	if slot then
		return tonumber(slot)
	end

	if not ident:find(":", 1, true) then
		slot = ident:match("^[Cc]har(%d+)")
		if slot and ident:sub(#("char" .. slot) + 1) == licenseHash then
			return tonumber(slot)
		end
	end
end

local function GetStandardIdentifier(charid, licenseHash)
	return ("%s%s:%s"):format(PREFIX, charid, licenseHash)
end

local function GetIdentifier(source)
	local fxDk = GetConvarInt("sv_fxdkMode", 0)
	if fxDk == 1 then
		return "ESX-DEBUG-LICENCE"
	end

	local identifier = GetPlayerIdentifierByType(source, PRIMARY_IDENTIFIER)
	return identifier and identifier:gsub(PRIMARY_IDENTIFIER .. ":", "")
end

if next(ESX.Players) then
	local players = table.clone(ESX.Players)
	table.wipe(ESX.Players)
	for _, v in pairs(players) do
		ESX.Players[GetIdentifier(v.source)] = true
	end
else
	ESX.Players = {}
end

local function SetupCharacters(source)
	while not databaseConnected do
		Wait(50)
	end

	local licenseHash = GetIdentifier(source)
	ESX.Players[licenseHash] = true

	local likePrefix = PREFIX .. "%:" .. licenseHash
	local likeLegacy = "Char%" .. licenseHash

	local slots, result = MySQL.scalar.await(
		"SELECT slots FROM multicharacter_slots WHERE identifier = ?",
		{ licenseHash }
	), MySQL.query.await(USERS_QUERY, { likePrefix, likeLegacy })

	slots = math.max(tonumber(slots) or SLOTS, SLOTS)
	PlayerCharacters[source] = {}

	local characters = {}

	if result then
		for i = 1, #result do
			local v = result[i]
			local id = GetCharSlot(v.identifier, licenseHash)

			if id and id >= 1 and id <= slots and not characters[id] then
				local job, grade = v.job or "unemployed", tostring(v.job_grade)

				if ESX.Jobs[job] and ESX.Jobs[job].grades[grade] then
					if job ~= "unemployed" then
						grade = ESX.Jobs[job].grades[grade].label
					else
						grade = ""
					end
					job = ESX.Jobs[job].label
				end

				local accounts = SafeJsonDecode(v.accounts, { bank = 0, money = 0 })
				PlayerCharacters[source][id] = v.identifier

				characters[id] = {
					id = id,
					bank = accounts.bank or 0,
					money = accounts.money or 0,
					job = job,
					job_grade = grade,
					firstname = v.firstname or "",
					lastname = v.lastname or "",
					dateofbirth = v.dateofbirth or "",
					skin = SafeJsonDecode(v.skin, {}),
					disabled = hasDisabledColumn and (v.disabled == 1 or v.disabled == true) or false,
					sex = v.sex == "m" and TranslateCap("male") or TranslateCap("female"),
				}
			end
		end
	end

	TriggerClientEvent("esx_multicharacter:SetupUI", source, characters, slots)
end

AddEventHandler("playerConnecting", function(_, _, deferrals)
	deferrals.defer()
	local identifier = GetIdentifier(source)
	if oneSyncState == "off" or oneSyncState == "legacy" then
		return deferrals.done(("[ESX] ESX Requires Onesync Infinity to work. This server currently has Onesync set to: %s"):format(oneSyncState))
	end

	if not databaseFound then
		deferrals.done("[ESX] Cannot Find the servers mysql_connection_string. Please make sure it is correctly configured in your server.cfg")
	end

	if not databaseConnected then
		deferrals.done("[ESX] OxMySQL Was Unable To Connect to your database. Please make sure it is turned on and correctly configured in your server.cfg")
	end

	if identifier then
		if not ESX.GetConfig().EnableDebug then
			if ESX.Players[identifier] then
				deferrals.done(("[ESX Multicharacter] A player is already connected to the server with this identifier.\nYour identifier: %s:%s"):format(PRIMARY_IDENTIFIER, identifier))
			else
				deferrals.done()
			end
		else
			deferrals.done()
		end
	else
		deferrals.done(("Unable to retrieve player identifier.\nIdentifier type: %s"):format(PRIMARY_IDENTIFIER))
	end
end)

local function DeleteCharacter(playerId, charid)
	local licenseHash = GetIdentifier(playerId)
	if not licenseHash then
		return
	end

	local identifier = GetStandardIdentifier(charid, licenseHash)
	local query = "DELETE FROM %s WHERE %s = ?"
	local queries = {}
	local count = 0

	for table, column in pairs(DB_TABLES) do
		count = count + 1
		queries[count] = { query = query:format(table, column), values = { identifier } }
	end

	MySQL.transaction(queries, function(result)
		if result then
			print(("[^2INFO^7] Player ^5%s %s^7 has deleted a character ^5(%s)^7"):format(GetPlayerName(playerId), playerId, identifier))
			SetupCharacters(playerId)
		else
			print(("[^1ERROR^7] Failed to delete character ^5%s^7"):format(identifier))
		end
	end)
end

MySQL.ready(function()
	local length = 42 + #PREFIX
	local DB_COLUMNS = MySQL.query.await(('SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = "%s" AND DATA_TYPE = "varchar" AND COLUMN_NAME IN (?)'):format(DATABASE, length), {
		{ "identifier", "owner" },
	})

	if DB_COLUMNS then
		local columns = {}
		local count = 0

		for i = 1, #DB_COLUMNS do
			local column = DB_COLUMNS[i]
			DB_TABLES[column.TABLE_NAME] = column.COLUMN_NAME

			if column?.CHARACTER_MAXIMUM_LENGTH ~= length then
				count = count + 1
				columns[column.TABLE_NAME] = column.COLUMN_NAME
			end
		end

		if next(columns) then
			local query = "ALTER TABLE `%s` MODIFY COLUMN `%s` VARCHAR(%s)"
			local queries = table.create(count, 0)

			for k, v in pairs(columns) do
				queries[#queries + 1] = { query = query:format(k, v, length) }
			end

			if MySQL.transaction.await(queries) then
				print(("[^2INFO^7] Updated ^5%s^7 columns to use ^5VARCHAR(%s)^7"):format(count, length))
			else
				print(("[^2INFO^7] Unable to update ^5%s^7 columns to use ^5VARCHAR(%s)^7"):format(count, length))
			end
		end

		for i = 1, #DB_COLUMNS do
			if DB_COLUMNS[i].TABLE_NAME == "users" and DB_COLUMNS[i].COLUMN_NAME == "disabled" then
				hasDisabledColumn = true
				break
			end
		end

		if not hasDisabledColumn then
			hasDisabledColumn = (MySQL.scalar.await(
				"SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users' AND COLUMN_NAME = 'disabled'",
				{ DATABASE }
			) or 0) > 0
		end

		USERS_QUERY = hasDisabledColumn
			and "SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, skin, disabled FROM users WHERE identifier LIKE ? OR identifier LIKE ?"
			or "SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, skin FROM users WHERE identifier LIKE ? OR identifier LIKE ?"

		databaseConnected = true

		while not next(ESX.Jobs) do
			Wait(100)
			ESX.Jobs = ESX.GetJobs()
		end
	end
end)

RegisterNetEvent("esx_multicharacter:SetupCharacters", function()
	SetupCharacters(source)
end)

local awaitingRegistration = {}

RegisterNetEvent("esx_multicharacter:CharacterChosen", function(charid, isNew)
	local playerId = source

	if type(charid) ~= "number" or charid < 1 or charid > 99 or type(isNew) ~= "boolean" then
		return
	end

	if isNew then
		awaitingRegistration[playerId] = charid
		return
	end

	local licenseHash = GetIdentifier(playerId)
	if not licenseHash then
		return DropPlayer(playerId, "Unable to retrieve player identifier.")
	end

	local standardIdentifier = GetStandardIdentifier(charid, licenseHash)

	if not ESX.GetConfig().EnableDebug and ESX.GetPlayerFromIdentifier(standardIdentifier) then
		return DropPlayer(playerId, "Your identifier " .. standardIdentifier .. " is already on the server!")
	end

	TriggerEvent("esx:onPlayerJoined", playerId, PREFIX .. charid)
	ESX.Players[licenseHash] = true
end)

AddEventHandler("esx_identity:completedRegistration", function(playerId, data)
	local src = playerId or source
	if not src or not awaitingRegistration[src] then
		return
	end

	TriggerEvent("esx:onPlayerJoined", src, PREFIX .. awaitingRegistration[src], data)
	awaitingRegistration[src] = nil

	local identifier = GetIdentifier(src)
	if identifier then
		ESX.Players[identifier] = true
	end
end)

AddEventHandler("playerDropped", function()
	local playerId = source
	if not playerId then
		return
	end

	awaitingRegistration[playerId] = nil
	PlayerCharacters[playerId] = nil

	local identifier = GetIdentifier(playerId)
	if identifier then
		ESX.Players[identifier] = nil
	end
end)

RegisterNetEvent("esx_multicharacter:DeleteCharacter", function(charid)
	local playerId = source
	charid = tonumber(charid)

	if not Config.CanDelete or not charid or charid < 1 or charid > 99 then
		return
	end

	DeleteCharacter(playerId, charid)
end)

RegisterNetEvent("esx_multicharacter:relog", function()
	TriggerEvent("esx:playerLogout", source)
end)
