ESX = exports["es_extended"]:getSharedObject()

local function Perf(key, default)
	if Config.Performance and Config.Performance[key] ~= nil then
		return Config.Performance[key]
	end
	return default
end

Citizen.CreateThread(function()
	Citizen.CreateThread(function()
		while not NetworkIsSessionStarted() do
			Citizen.Wait(100)
		end

		exports.spawnmanager:setAutoSpawn(false)
		DoScreenFadeOut(0)
		TriggerEvent("esx_multicharacter:SetupCharacters")
	end)

	local canRelog, cam, cam2, spawned, hidePlayers = false, nil, nil, nil, false
	local selectedSlot, maxSlots = nil, Config.Slots or 4
	local Characters = {}
	local isChoosing = false
	local uiReady = false
	local worldLoaded = false

	local function SerializeCharactersForNui(characters, slots)
		local serialized = {}
		for i = 1, slots do
			if characters[i] then
				serialized[i] = characters[i]
			end
		end
		return serialized
	end

	local function SetupSkyCamera()
		local sky = Config.SkyCam
		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", sky.x, sky.y, sky.z, 300.0, 0.0, 0.0, sky.w, false, 0)
		SetCamActive(cam, true)
		RenderScriptCams(true, false, 1, true, true)
	end

	local function DestroyCameras()
		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end
		if cam2 then
			SetCamActive(cam2, false)
			DestroyCam(cam2, true)
			cam2 = nil
		end
		RenderScriptCams(false, true, 500, true, true)
	end

	local function ToCoords(vec)
		return {
			x = vec.x,
			y = vec.y,
			z = vec.z,
			heading = vec.w,
			w = vec.w
		}
	end

	local function SetPlayerAt(vec)
		local playerPed = PlayerPedId()
		SetEntityCoordsNoOffset(playerPed, vec.x, vec.y, vec.z, false, false, false, true)
		SetEntityHeading(playerPed, vec.w)
	end

	local function EnsureMenuDefault()
		while GetResourceState('esx_menu_default') ~= 'started' do
			Citizen.Wait(50)
		end
	end

	local function SetupSkinCreatorCamera()
		local creator = Config.SkinCreator
		local playerPed = PlayerPedId()
		local offset = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.2, 0.6)

		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end

		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, 50.0, false, 0)
		PointCamAtCoord(cam, creator.x, creator.y, creator.z + 0.6)
		SetCamActive(cam, true)
		RenderScriptCams(true, false, 1, true, true)
	end

	local function ResetPlayerState()
		local playerId = PlayerId()
		local playerPed = PlayerPedId()

		ClearFocus()
		SetEntityCollision(playerPed, true, true)
		SetEntityInvincible(playerPed, false)
		SetPlayerInvincible(playerId, false)
		SetPedCanRagdoll(playerPed, true)
		FreezeEntityPosition(playerPed, false)
		SetEntityVisible(playerPed, true, false)
		MumbleSetVolumeOverride(playerId, -1.0)
	end

	local function WaitForWorldAtCoords(x, y, z, quick)
		if quick and worldLoaded then
			RequestCollisionAtCoord(x, y, z)
			return
		end

		local poll = quick and 10 or 25
		local collisionTimeout = quick and 2000 or 6000

		RequestCollisionAtCoord(x, y, z)
		SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)

		local timeout = GetGameTimer() + collisionTimeout
		while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < timeout do
			RequestCollisionAtCoord(x, y, z)
			Citizen.Wait(poll)
		end

		if not quick then
			NewLoadSceneStart(x, y, z, x, y, z, 80.0, 0)
			timeout = GetGameTimer() + 4000
			while IsNetworkLoadingScene() and GetGameTimer() < timeout do
				Citizen.Wait(poll)
			end
			NewLoadSceneStop()
		end

		local worldWait = Perf('WorldLoadWait', 500)
		if worldWait > 0 then
			Citizen.Wait(worldWait)
		end

		ClearFocus()
		worldLoaded = true
	end

	local function PlaySpawnCamera(spawn)
		local pos = {
			x = spawn.x or spawn[1] or Config.Spawn.x,
			y = spawn.y or spawn[2] or Config.Spawn.y,
			z = spawn.z or spawn[3] or Config.Spawn.z
		}
		local heading = spawn.heading or spawn.w or Config.Spawn.w
		local playerPed = PlayerPedId()
		local fadeIn = Perf('FadeInDuration', 500)

		hidePlayers = false
		SetEntityVisible(playerPed, true, false)
		SetEntityCoordsNoOffset(playerPed, pos.x, pos.y, pos.z, false, false, false, true)
		SetEntityHeading(playerPed, heading)

		WaitForWorldAtCoords(pos.x, pos.y, pos.z, false)

		if not Perf('SpawnCamera', true) then
			DestroyCameras()
			RenderScriptCams(false, false, 0, true, true)
			DoScreenFadeIn(fadeIn)
			return
		end

		DestroyCameras()
		SetupSkyCamera()
		RenderScriptCams(true, false, 0, true, true)

		local spawnFadeIn = Perf('SpawnCameraFast', false) and fadeIn or 500
		DoScreenFadeIn(spawnFadeIn)
		Citizen.Wait(spawnFadeIn)

		local sky = Config.SkyCam
		local camDuration = Perf('SpawnCameraFast', false) and 400 or 900
		local descendDuration = Perf('SpawnCameraFast', false) and 1200 or 3700

		cam2 = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", sky.x, sky.y, sky.z, 300.0, 0.0, 0.0, sky.w, false, 0)
		PointCamAtCoord(cam2, pos.x, pos.y, pos.z + 200.0)
		SetCamActiveWithInterp(cam2, cam, camDuration, true, true)
		Citizen.Wait(camDuration)

		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 200.0, 300.0, 0.0, 0.0, sky.w, false, 0)
		PointCamAtCoord(cam, pos.x, pos.y, pos.z + 2.0)
		SetCamActiveWithInterp(cam, cam2, descendDuration, true, true)
		Citizen.Wait(descendDuration)

		PlaySoundFrontend(-1, "Zoom_Out", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
		RenderScriptCams(false, true, 500, true, true)
		PlaySoundFrontend(-1, "CAR_BIKE_WHOOSH", "MP_LOBBY_SOUNDS", 1)

		Citizen.Wait(500)

		if cam2 then
			DestroyCam(cam2, true)
			cam2 = nil
		end
		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end

		ClearFocus()
	end

	local function ShowCharacterUI()
		if uiReady then
			return
		end

		uiReady = true
		SetNuiFocus(true, true)
		SendNUIMessage({
			action = "setupui",
			characters = SerializeCharactersForNui(Characters, maxSlots),
			slots = maxSlots,
			canDelete = Config.CanDelete,
			show = true
		})
	end

	Citizen.CreateThread(function()
		while true do
			if isChoosing then
				DisplayHud(false)
				DisplayRadar(false)
				Citizen.Wait(0)
			else
				Citizen.Wait(500)
			end
		end
	end)

	RegisterNetEvent('esx_multicharacter:SetupCharacters')
	AddEventHandler('esx_multicharacter:SetupCharacters', function()
		ESX.PlayerLoaded = false
		ESX.PlayerData = {}
		spawned = false
		canRelog = false
		isChoosing = true
		uiReady = false
		worldLoaded = false

		local fadeOut = Perf('FadeOutDuration', 500)
		DoScreenFadeOut(fadeOut)
		while not IsScreenFadedOut() do
			Citizen.Wait(0)
		end

		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		ClearTimecycleModifier()
		SetTimecycleModifier('hud_def_blur')

		local playerPed = PlayerPedId()
		FreezeEntityPosition(playerPed, true)
		SetEntityCollision(playerPed, false, false)
		SetEntityInvincible(playerPed, true)
		SetPedCanRagdoll(playerPed, false)
		SetEntityVisible(playerPed, false, false)
		SetEntityCoords(playerPed, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z, false, false, false, false)

		DestroyCameras()
		SetupSkyCamera()

		ESX.UI.Menu.CloseAll()
		StartLoop()
		TriggerServerEvent("esx_multicharacter:SetupCharacters")
	end)

	local hideLoopsReady = false

	StartLoop = function()
		hidePlayers = true
		MumbleSetVolumeOverride(PlayerId(), 0.0)

		if hideLoopsReady then
			return
		end

		hideLoopsReady = true

		Citizen.CreateThread(function()
			local keys = {18, 19, 21, 27, 61, 131, 172, 173, 155, 174, 175, 176, 177, 187, 188, 191, 201, 209, 254, 340, 352, 108, 109}
			while true do
				if hidePlayers then
					DisableAllControlActions(0)
					for i = 1, #keys do
						EnableControlAction(0, keys[i], true)
					end
					SetEntityVisible(PlayerPedId(), false, false)
					SetLocalPlayerVisibleLocally(1)
					SetPlayerInvincible(PlayerId(), 1)
					ThefeedHideThisFrame()
					HideHudComponentThisFrame(11)
					HideHudComponentThisFrame(12)
					HideHudComponentThisFrame(21)
					HideHudAndRadarThisFrame()
					Citizen.Wait(0)
				else
					Citizen.Wait(500)
				end
			end
		end)

		Citizen.CreateThread(function()
			local interval = Perf('HideLoopInterval', 250)
			while true do
				if hidePlayers then
					local vehicles = GetGamePool('CVehicle')
					for i = 1, #vehicles do
						SetEntityLocallyInvisible(vehicles[i])
					end
					Citizen.Wait(interval)
				else
					Citizen.Wait(500)
				end
			end
		end)

		Citizen.CreateThread(function()
			local playerPool = {}
			while true do
				if hidePlayers then
					local players = GetActivePlayers()
					for i = 1, #players do
						local player = players[i]
						if player ~= PlayerId() and not playerPool[player] then
							playerPool[player] = true
							NetworkConcealPlayer(player, true, true)
						end
					end
					Citizen.Wait(500)
				else
					for k in pairs(playerPool) do
						NetworkConcealPlayer(k, false, false)
						playerPool[k] = nil
					end
					Citizen.Wait(500)
				end
			end
		end)
	end

	RegisterNetEvent('esx_multicharacter:SetupUI')
	AddEventHandler('esx_multicharacter:SetupUI', function(data, slots)
		Characters = data or {}
		maxSlots = math.max(tonumber(slots) or Config.Slots or 4, Config.Slots or 4)
		spawned = false
		uiReady = false

		for _, v in pairs(Characters) do
			if not v.model and v.skin then
				if v.skin.model then
					v.model = v.skin.model
				elseif v.skin.sex == 1 then
					v.model = `mp_f_freemode_01`
				else
					v.model = `mp_m_freemode_01`
				end
			end
		end

		Citizen.CreateThread(function()
			local sky = Config.SkyCam
			local quickLoad = Perf('QuickRelog', true)

			if not cam or not IsCamActive(cam) then
				DestroyCameras()
				SetupSkyCamera()
			end

			WaitForWorldAtCoords(sky.x, sky.y, sky.z, quickLoad)

			ClearTimecycleModifier()
			SetTimecycleModifier('hud_def_blur')

			ShutdownLoadingScreen()
			ShutdownLoadingScreenNui()
			TriggerEvent('esx:loadingScreenOff')

			local fadeIn = Perf('FadeInDuration', 800)
			DoScreenFadeIn(fadeIn)
			while not IsScreenFadedIn() do
				Citizen.Wait(0)
			end

			if not Perf('FastLoad', true) then
				Citizen.Wait(400)
			end

			ShowCharacterUI()
		end)
	end)

	RegisterNUICallback('selectCharacter', function(data, cb)
		local slot = tonumber(data.slot)
		if not slot or slot < 1 or slot > maxSlots then
			return cb({})
		end
		selectedSlot = slot
		cb({})
	end)

	RegisterNUICallback('playCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not slot or not Characters[slot] then
			return cb({})
		end
		if Characters[slot].disabled then
			return cb({})
		end

		selectedSlot = slot
		spawned = slot
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		local fadeOut = Perf('FadeOutDuration', 500)
		DoScreenFadeOut(fadeOut)
		while not IsScreenFadedOut() do
			Citizen.Wait(0)
		end

		TriggerServerEvent('esx_multicharacter:CharacterChosen', slot, false)
		cb({})
	end)

	RegisterNUICallback('createCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not slot or Characters[slot] then
			return cb({})
		end

		selectedSlot = slot
		spawned = slot
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		local fadeOut = Perf('FadeOutDuration', 500)
		DoScreenFadeOut(fadeOut)
		while not IsScreenFadedOut() do
			Citizen.Wait(0)
		end

		TriggerServerEvent('esx_multicharacter:CharacterChosen', slot, true)
		DoScreenFadeIn(Perf('FadeInDuration', 500))
		Citizen.Wait(100)
		TriggerEvent('esx_identity:showRegisterIdentity')
		cb({})
	end)

	RegisterNUICallback('deleteCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not Config.CanDelete or not slot or not Characters[slot] then
			return cb('error')
		end

		selectedSlot = slot
		Characters[slot] = nil
		TriggerServerEvent('esx_multicharacter:DeleteCharacter', slot)
		cb('ok')
	end)

	RegisterNetEvent('esx:playerLoaded')
	AddEventHandler('esx:playerLoaded', function(playerData, isNew, skin)
		local playerPed = PlayerPedId()
		local fadeIn = Perf('FadeInDuration', 500)
		local fadeOut = Perf('FadeOutDuration', 500)

		ClearTimecycleModifier()
		SetTimecycleModifier('default')

		if isNew or not skin or (type(skin) == 'table' and not next(skin)) then
			local sex = skin and skin.sex or 0
			local model = sex == 0 and `mp_m_freemode_01` or `mp_f_freemode_01`
			RequestModel(model)
			while not HasModelLoaded(model) do
				Citizen.Wait(0)
			end
			SetPlayerModel(PlayerId(), model)
			SetModelAsNoLongerNeeded(model)
			skin = Config.Default
			skin.sex = sex
			playerPed = PlayerPedId()
		end

		SetEntityCollision(playerPed, true, true)
		FreezeEntityPosition(playerPed, true)
		SetEntityVisible(playerPed, true, false)

		if isNew then
			EnsureMenuDefault()
			DoScreenFadeIn(fadeIn)
			Citizen.Wait(100)

			SetPlayerAt(Config.SkinCreator)
			TriggerEvent('skinchanger:loadSkin', skin)
			SetupSkinCreatorCamera()

			local finished = false
			TriggerEvent('skinchanger:loadSkin', skin, function()
				SetPedAoBlobRendering(PlayerPedId(), true)
				ResetEntityAlpha(PlayerPedId())
				TriggerEvent('esx_skin:openSaveableMenu', function()
					finished = true
				end, function()
					finished = true
				end)
			end)
			repeat Citizen.Wait(100) until finished

			DoScreenFadeOut(fadeOut)
			while not IsScreenFadedOut() do
				Citizen.Wait(0)
			end

			PlaySpawnCamera(ToCoords(Config.Spawn))
		else
			local spawn = playerData.coords or ToCoords(Config.Spawn)

			local selectedCharacterSkin = spawned and Characters[spawned] and Characters[spawned].skin or nil
			TriggerEvent('skinchanger:loadSkin', skin or selectedCharacterSkin)

			DoScreenFadeOut(fadeOut)
			while not IsScreenFadedOut() do
				Citizen.Wait(0)
			end

			PlaySpawnCamera(spawn)
		end

		isChoosing = false
		DisplayHud(true)
		DisplayRadar(true)
		hidePlayers = false
		ResetPlayerState()

		TriggerServerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:onPlayerSpawn')
		TriggerEvent('playerSpawned')
		TriggerEvent('esx:restoreLoadout')
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })
		Characters = {}
		canRelog = true
		uiReady = false
	end)

	RegisterNetEvent('esx:onPlayerLogout')
	AddEventHandler('esx:onPlayerLogout', function()
		hidePlayers = false
		ResetPlayerState()

		DoScreenFadeOut(0)
		while not IsScreenFadedOut() do
			Citizen.Wait(0)
		end
		spawned = false
		canRelog = false
		TriggerEvent("esx_multicharacter:SetupCharacters")
		TriggerEvent('esx_skin:resetFirstSpawn')
	end)

	if Config.Relog then
		RegisterCommand('relog', function()
			if not canRelog then
				return ESX.ShowNotification('Bitte warte einen Moment...')
			end

			canRelog = false
			TriggerServerEvent('esx_multicharacter:relog')
			SetTimeout(Perf('RelogCooldown', 5000), function()
				canRelog = true
			end)
		end, false)

		TriggerEvent('chat:addSuggestion', '/relog', 'Zurück zur Charakterauswahl wechseln')
	end
end)
