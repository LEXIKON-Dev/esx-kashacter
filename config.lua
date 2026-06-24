Config = {}
Config.Locale = 'de'
Config.Slots = 4
Config.CanDelete = true

if IsDuplicityVersion() then
	Config.Prefix = 'char'
	Config.Identifier = 'license'
else
	-- Versteckte Position während der Charakterauswahl (UI + Himmelskamera)
	Config.HiddenCoords = vector4(-752.92, 318.97, 220.85, 89.56)
	Config.SkyCam = vector4(-1355.93, -1487.78, 520.75, 100.0)
	-- Position wo der Spieler seinen Charakter erstellt (Skin / Aussehen)
	Config.SkinCreator = vector4(-752.6023, 318.3079, 175.4010, 89.6304)
	-- Position wo der Spieler nach der Charaktererstellung spawnt
	Config.Spawn = vector4(-1102.8119, -2849.6484, 14.8826, 330.6558)
	Config.Relog = true

	-- Performance: schnelleres Laden, Relog und weniger Client-Last
	Config.Performance = {
		FastLoad = true,           -- Kürzere Fades und Wartezeiten (Char-Auswahl)
		SpawnCamera = true,        -- Kamerafahrt beim Charakter-Spielen
		SpawnCameraFast = false,   -- false = volle Spawn-Animation wie zuvor
		QuickRelog = true,         -- Beim Relog schwere World-Loads überspringen
		WorldLoadWait = 50,        -- ms nach Collision-Load (Standard war 500)
		FadeInDuration = 300,
		FadeOutDuration = 200,
		RelogCooldown = 1500,      -- ms bis /relog wieder erlaubt (Standard war 5000)
		HideLoopInterval = 250,    -- ms zwischen Fahrzeug-Versteck-Updates (Standard war jedes Frame)
	}

	Config.Default = {
		mom = 21,
		dad = 0,
		face_md_weight = 50,
		skin_md_weight = 50,
		nose_1 = 0,
		nose_2 = 0,
		nose_3 = 0,
		nose_4 = 0,
		nose_5 = 0,
		nose_6 = 0,
		cheeks_1 = 0,
		cheeks_2 = 0,
		cheeks_3 = 0,
		lip_thickness = 0,
		jaw_1 = 0,
		jaw_2 = 0,
		chin_1 = 0,
		chin_2 = 0,
		chin_13 = 0,
		chin_4 = 0,
		neck_thickness = 0,
		hair_1 = 0,
		hair_2 = 0,
		hair_color_1 = 0,
		hair_color_2 = 0,
		tshirt_1 = 0,
		tshirt_2 = 0,
		torso_1 = 0,
		torso_2 = 0,
		decals_1 = 0,
		decals_2 = 0,
		arms = 0,
		arms_2 = 0,
		pants_1 = 0,
		pants_2 = 0,
		shoes_1 = 0,
		shoes_2 = 0,
		mask_1 = 0,
		mask_2 = 0,
		bproof_1 = 0,
		bproof_2 = 0,
		chain_1 = 0,
		chain_2 = 0,
		helmet_1 = -1,
		helmet_2 = 0,
		glasses_1 = 0,
		glasses_2 = 0,
		watches_1 = -1,
		watches_2 = 0,
		bracelets_1 = -1,
		bracelets_2 = 0,
		bags_1 = 0,
		bags_2 = 0,
		eye_color = 0,
		eye_squint = 0,
		eyebrows_2 = 0,
		eyebrows_1 = 0,
		eyebrows_3 = 0,
		eyebrows_4 = 0,
		eyebrows_5 = 0,
		eyebrows_6 = 0,
		makeup_1 = 0,
		makeup_2 = 0,
		makeup_3 = 0,
		makeup_4 = 0,
		lipstick_1 = 0,
		lipstick_2 = 0,
		lipstick_3 = 0,
		lipstick_4 = 0,
		ears_1 = -1,
		ears_2 = 0,
		chest_1 = 0,
		chest_2 = 0,
		chest_3 = 0,
		bodyb_1 = -1,
		bodyb_2 = 0,
		bodyb_3 = -1,
		bodyb_4 = 0,
		age_1 = 0,
		age_2 = 0,
		blemishes_1 = 0,
		blemishes_2 = 0,
		blush_1 = 0,
		blush_2 = 0,
		blush_3 = 0,
		complexion_1 = 0,
		complexion_2 = 0,
		sun_1 = 0,
		sun_2 = 0,
		moles_1 = 0,
		moles_2 = 0,
		beard_1 = 0,
		beard_2 = 0,
		beard_3 = 0,
		beard_4 = 0
	}
end
