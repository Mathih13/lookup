local _, ns = ...

local RANK = {
	panel = 1, addon = 1.5, setting = 2, zone = 3, quest = 4, collection = 5, spell = 6, macro = 7,
	item = 8, progress = 9, slash = 10, people = 11,
}
local GREEN = "|cff3fd13f"

local function label(global, command)
	local s = global and _G[global]
	if type(s) == "string" then return s end
	s = command and _G["BINDING_NAME_" .. command]
	return s and (s:gsub("^Toggle ", "")) or nil
end

local function paint(c, s)
	if not c then return s end
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), s)
end

local REP_ICON = "Interface/ICONS/INV_SideTab_Reputation2_c60"
local CURRENCY_ICON = "Interface/ICONS/INV_SideTab_Currency_c60"
local PANELS = {
	{ "CHARACTER_BUTTON", "TOGGLECHARACTER0", "CharacterMicroButton", "portrait" },
	{ "REPUTATION", "TOGGLECHARACTER2", "CharacterMicroButton", REP_ICON },
	{ "CURRENCY", "TOGGLECURRENCY", "CharacterMicroButton", CURRENCY_ICON },
	{ nil, "TOGGLECHARACTER4", "CharacterMicroButton", "pvp" },
	{ "SPELLBOOK_ABILITIES_BUTTON", "TOGGLESPELLBOOK", "SpellbookMicroButton", "SpellbookAbilities" },
	{ "PLAYERSPELLS_BUTTON", "TOGGLETALENTS", "TalentMicroButton", "SpecTalents" },
	{ "PROFESSIONS_BUTTON", "TOGGLEPROFESSIONBOOK", "ProfessionMicroButton", "Professions" },
	{ "LEGACY_BUTTON", "TOGGLELEGACYSYSTEM", "LegacyMicroButton", "Legacy" },
	{ "QUESTLOG_BUTTON", "TOGGLEQUESTLOG", "QuestLogMicroButton", "Questlog" },
	{ "WORLD_MAP", "TOGGLEWORLDMAP", nil, "Questlog" },
	{ "GUILD_AND_COMMUNITIES", "TOGGLEGUILDTAB", "GuildMicroButton", "GuildCommunities" },
	{ "DUNGEONS_BUTTON", "TOGGLEGROUPFINDER", "LFDMicroButton", "Groupfinder" },
	{ "COLLECTIONS", "TOGGLECOLLECTIONS", "CollectionsMicroButton", "Collections" },
	{ "MOUNTS", "TOGGLECOLLECTIONSMOUNTJOURNAL", "CollectionsMicroButton", "Collections" },
	{ "PETS", "TOGGLECOLLECTIONSPETJOURNAL", "CollectionsMicroButton", "Collections" },
	{ "TOYS", "TOGGLECOLLECTIONSTOYBOX", "CollectionsMicroButton", "Collections" },
	{ "WARDROBE", "TOGGLECOLLECTIONSWARDROBE", "CollectionsMicroButton", "Collections" },
	{ "FRIENDS", "TOGGLESOCIAL", nil, "GuildCommunities" },
	{ nil, "TOGGLEWHOTAB", nil, "GuildCommunities" },
	{ nil, "TOGGLERAIDTAB", nil, "GuildCommunities" },
	{ "BAGSLOTTEXT", "OPENALLBAGS", "MainMenuBarBackpackButton" },
	{ "MAINMENU_BUTTON", "TOGGLEGAMEMENU", nil, "GameMenu" },
}

local function inPanel(e, open, binding, button, select)
	if open then
		e.call = select
	else
		e.binding, e.button, e.after = binding, button, select
	end
	return e
end

local LEGACY_PAGES = { "LEGACY_REWARD_TRACK_TAB_TOOLTIP", "LEGACY_CHALLENGE_TAB_TOOLTIP", "LEGACY_TREE_TAB_TOOLTIP" }

local function legacyTab(text)
	for _, tab in ipairs(LegacySystemFrame and LegacySystemFrame.Tabs or {}) do
		if tab.tooltipText == text then return tab end
	end
end

local function selectLegacyPage(text)
	local tab = LegacySystemFrame and LegacySystemFrame:IsShown() and legacyTab(text)
	if tab then EventRegistry:TriggerEvent("Legacy.SelectPage", tab:GetID()) end
end

ns.provide("panels", RANK.panel, function(add)
	local pvpIcon = "Interface/ICONS/INV_SideTab_Honor_" .. (UnitFactionGroup("player") or "Alliance") .. "_c60"
	for _, p in ipairs(PANELS) do
		local name = label(p[1], p[2])
		if name and _G["BINDING_NAME_" .. p[2]] then
			local icon, atlas, portrait = p[4] --[[@as string?]], nil, nil
			if icon == "portrait" then
				icon, portrait = nil, "player"
			elseif icon == "pvp" then
				icon = pvpIcon
			elseif icon and not icon:find("/") then
				icon, atlas = nil, "UI-HUD-MicroMenu-" .. icon .. "-Up"
			end
			add({
				name = name, cat = "Panel", key = "panel:" .. p[2],
				icon = icon or 133633, atlas = atlas, portrait = portrait,
				binding = p[2], button = p[3],
			})
		end
	end
	local modeTabs = CharacterFrame and CharacterFrame.ModeTabs
	local characterOpen = CharacterFrame and CharacterFrame:IsShown()
	for _, key in ipairs({ "SkillsTab", "StatisticsTab" }) do
		local tab = modeTabs and modeTabs[key]
		if tab and tab:IsShown() and type(tab.tooltipText) == "string" then
			add(inPanel({ name = tab.tooltipText, cat = "Panel", key = "panel:" .. key, icon = tab.iconTexture or 133633 },
				characterOpen, "TOGGLECHARACTER2", "CharacterMicroButton", function()
					if CharacterFrame:IsShown() and tab:IsShown() then CharacterFrame:OnModeTabClicked(tab) end
				end))
		end
	end
	if _G["BINDING_NAME_TOGGLELEGACYSYSTEM"] then
		local legacyOpen = LegacySystemFrame and LegacySystemFrame:IsShown()
		for _, global in ipairs(LEGACY_PAGES) do
			local text = _G[global]
			if type(text) == "string" then
				local tab = legacyTab(text)
				add(inPanel({ name = text, cat = "Panel", key = "panel:" .. global, icon = tab and tab.iconTexture,
					atlas = not (tab and tab.iconTexture) and "UI-HUD-MicroMenu-Legacy-Up" or nil },
					legacyOpen, "TOGGLELEGACYSYSTEM", "LegacyMicroButton", function() selectLegacyPage(text) end))
			end
		end
	end
	add({ name = MACROS or "Macros", cat = "Panel", key = "panel:macros",
		icon = 136377, line = "/macro" })
	local stopwatch, editMode = _G["SLASH_STOPWATCH1"], _G["SLASH_EDITMODE1"]
	for _, p in ipairs({
		{ "CALENDAR", "Calendar", _G["GameTimeFrame"] and "/click GameTimeFrame", nil, "ui-hud-calendar-1-up" },
		{ "STOPWATCH_TITLE", "Stopwatch", type(stopwatch) == "string" and stopwatch,
			"Interface/Icons/INV_Misc_PocketWatch_01" },
		{ "TIMEMANAGER_TITLE", "Clock", _G["TimeManagerClockButton"] and "/click TimeManagerClockButton",
			"Interface/Icons/INV_Misc_PocketWatch_02" },
		{ "HUD_EDIT_MODE_MENU", "Edit Mode", type(editMode) == "string" and editMode, "Interface/Icons/INV_Misc_Wrench_01" },
	}) do
		if p[3] then
			local name = _G[p[1]]
			add({ name = type(name) == "string" and name or p[2], cat = "Panel", key = "panel:" .. p[2]:lower(),
				icon = p[4], atlas = p[5], action = "Open", line = p[3] })
		end
	end
	add({ name = SETTINGS or "Settings", cat = "Panel", key = "panel:settings",
		atlas = "UI-HUD-MicroMenu-GameMenu-Up", call = function() Settings.OpenToCategory() end })
	add({ name = KEY_BINDINGS or "Key Bindings", cat = "Panel", key = "panel:keybindings",
		atlas = "UI-HUD-MicroMenu-GameMenu-Up",
		call = function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end })
end)

local function toggle(add, name, sub, key, get, set)
	add({
		name = name, cat = "Setting", sub = sub, key = key, icon = 136243,
		toggle = { get = get, set = set },
		action = function() return get() and "Turn off" or "Turn on" end,
	})
end

local foundDamageMeter
local function addSetting(add, category, path, initializer)
	local setting = initializer.GetSetting and initializer:GetSetting()
	local name = initializer.GetName and initializer:GetName()
	if not setting or type(name) ~= "string" or name == "" then return end
	local variable = setting:GetVariable()
	if variable == "damageMeterEnabled" then foundDamageMeter = true end
	local categoryID = category:GetID()
	if setting:GetVariableType() == "boolean" then
		toggle(add, name, path, "setting:" .. variable,
			function() return setting:GetValue() end,
			function(v) setting:SetValue(v, true) end)
	else
		add({
			name = name, cat = "Setting", sub = path, key = "setting:" .. variable,
			icon = 136243, action = "Open settings",
			call = function() Settings.OpenToCategory(categoryID, name) end,
		})
	end
end

local function walkCategory(add, category, parentName)
	local target = category.redirectCategory or category
	local id = target:GetID()
	local name = category:GetName()
	local path = parentName and parentName .. " > " .. name or name
	add({ name = name, cat = "Settings", sub = parentName, key = "settings:" .. tostring(id),
		icon = 136243, action = "Open settings", call = function() Settings.OpenToCategory(id) end })
	local layout = SettingsPanel:GetLayout(category)
	if layout and layout:IsVerticalLayout() then
		for _, initializer in layout:EnumerateInitializers() do
			if not initializer:IsSearchIgnoredInLayout(layout) and initializer:ShouldShow() then
				addSetting(add, target, path, initializer)
			end
		end
	end
end

local function trackingIndex(name)
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local t = C_Minimap.GetTrackingInfo(i)
		if t and t.name == name then return i, t end
	end
end

ns.provide("tracking", RANK.setting, function(add)
	local setTracking = MinimapUtil and MinimapUtil.SetTrackingFilterByFilterIndex or C_Minimap.SetTracking
	local sub = type(_G["TRACKING"]) == "string" and _G["TRACKING"] or "Tracking"
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local t = C_Minimap.GetTrackingInfo(i)
		if t and type(t.name) == "string" and t.name ~= "" then
			local name = t.name
			local function get()
				local _, now = trackingIndex(name)
				return now ~= nil and now.active == true
			end
			add({
				name = name, cat = "Tracking", key = "tracking:" .. (t.spellID or name), icon = t.texture,
				toggle = { get = get, set = function(on)
					local index = trackingIndex(name)
					if index then setTracking(index, on) end
				end },
				action = function() return get() and "Stop tracking" or "Track" end,
			})
		end
	end
	if C_Minimap.GetNumTrackingTypes() > 0 and type(_G["UNCHECK_ALL"]) == "string" then
		add({ name = sub .. ": " .. _G["UNCHECK_ALL"], cat = "Tracking", key = "tracking:none", icon = 136243,
			action = "Stop all tracking", call = function() C_Minimap.ClearAllTracking() end })
	end
end)

ns.provide("settings", RANK.setting, function(add)
	foundDamageMeter = false
	for _, category in ipairs(SettingsPanel:GetAllCategories()) do
		walkCategory(add, category)
		for _, sub in ipairs(category:GetSubcategories()) do walkCategory(add, sub, category:GetName()) end
	end
	if not foundDamageMeter and C_CVar.GetCVar("damageMeterEnabled") then
		toggle(add, "Damage Meter", nil, "setting:damageMeterEnabled",
			function() return C_CVar.GetCVarBool("damageMeterEnabled") end,
			function(v) C_CVar.SetCVar("damageMeterEnabled", v and "1" or "0") end)
	end
end)

ns.provide("bindings", RANK.setting, function(add)
	for _, b in ipairs(ns.discover.bindings()) do
		local key = "binding:" .. b.command
		if b.title and not b.command:find("^CLICK ") then
			add({ name = b.name, cat = "Key binding", sub = b.header or b.title, key = key, icon = 136243,
				binding = b.command, action = "Run" })
		else
			add({ name = b.name, cat = "Key binding", sub = b.header, key = key, icon = 136243, shortcut = b.command,
				value = not b.bound and "Not bound" or nil, action = "Open key bindings",
				call = function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end })
		end
	end
end)

local MAP_KIND = { [Enum.UIMapType.Continent] = "Continent", [Enum.UIMapType.Zone] = "Zone",
	[Enum.UIMapType.Dungeon] = "Dungeon" }

local mapNames = {}
ns.provide("zones", RANK.zone, function(add)
	local seen = {}
	local maps = C_Map.GetMapChildrenInfo(C_Map.GetFallbackWorldMapID(), nil, true) or {}
	for _, m in ipairs(maps) do mapNames[m.mapID] = m.name end
	for _, m in ipairs(maps) do
		local kind = MAP_KIND[m.mapType]
		if kind and bit.band(m.flags or 0, Enum.UIMapFlag.IsCityMap) ~= 0 then kind = "City" end
		if kind and not seen[m.name .. kind] then
			seen[m.name .. kind] = true
			local mapID = m.mapID
			local low, high = C_Map.GetMapLevels(mapID)
			local levels
			if low and low > 0 then levels = low == high and "Lvl " .. low or "Lvl " .. low .. "-" .. high end
			add({ name = m.name, cat = kind, sub = mapNames[m.parentMapID], key = "zone:" .. mapID,
				icon = 137176, value = levels, action = "Open map",
				call = function() OpenWorldMap(mapID) end })
		end
	end
end)

local function questProgress(questID)
	if C_QuestLog.IsComplete(questID) then return GREEN .. "Complete|r" end
	local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
	if #objectives == 0 then return nil end
	local done = 0
	for _, o in ipairs(objectives) do
		if o.finished then done = done + 1 end
	end
	return done .. "/" .. #objectives
end

ns.provide("quests", RANK.quest, function(add)
	local perMap, header = {}, nil
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local q = C_QuestLog.GetInfo(i)
		if q and q.isHeader then
			header = q.title
		elseif q and not q.isHidden then
			local questID = q.questID
			local sub = paint(GetQuestDifficultyColor(q.level), "Lvl " .. q.level)
			if header then sub = sub .. " · " .. header end
			add({ name = q.title, cat = "Quest", sub = sub, key = "quest:" .. questID,
				atlas = C_QuestLog.IsComplete(questID) and "QuestTurnin" or "Quest-In-Progress-Icon-yellow",
				value = function() return questProgress(questID) end, action = "Show in quest log",
				call = function() QuestMapFrame_OpenToQuestDetails(questID) end })
			---@diagnostic disable-next-line: redundant-parameter -- the annotation lacks the questID parameter
			local mapID = GetQuestUiMapID(questID)
			if mapID and mapID > 0 then perMap[mapID] = (perMap[mapID] or 0) + 1 end
		end
	end
	for mapID, n in pairs(perMap) do
		local info = mapNames[mapID] and { name = mapNames[mapID] } or C_Map.GetMapInfo(mapID)
		if info then
			add({ name = "Quests in " .. info.name, cat = "Quests", value = tostring(n),
				key = "questzone:" .. mapID, icon = 136797, shortcut = "TOGGLEQUESTLOG", action = "Open quest log",
				call = function() OpenQuestLog(mapID) end })
		end
	end
end)

ns.provide("collections", RANK.collection, function(add)
	for _, id in ipairs(C_MountJournal.GetMountIDs()) do
		local name, spellID, icon, _, _, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(id)
		if collected and not hidden then
			add({ name = name, cat = "Mount", key = "mount:" .. id, icon = icon,
				action = "Show in mount journal",
				call = function()
					SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS)
					MountJournal_SelectByMountID(id)
				end,
				drag = function() C_Spell.PickupSpell(spellID) end })
		end
	end
	for i = 1, (C_PetJournal.GetNumPets()) do
		local petID, _, owned, customName, level, _, _, speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)
		if petID and owned then
			add({ name = customName or speciesName, cat = "Pet", sub = customName and speciesName or nil,
				key = "pet:" .. petID, icon = icon,
				value = level and "Lvl " .. level or nil, action = "Show in pet journal",
				call = function()
					SetCollectionsJournalShown(true, COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
					PetJournal_SelectPet(PetJournal, petID)
				end,
				drag = function() C_PetJournal.PickupPet(petID) end })
		end
	end
	for i = 1, C_ToyBox.GetNumToys() do
		local itemID = C_ToyBox.GetToyFromIndex(i)
		if itemID and itemID > 0 and PlayerHasToy(itemID) then
			local _, name, icon = C_ToyBox.GetToyInfo(itemID)
			if name then
				add({ name = name, cat = "Toy", key = "toy:" .. itemID, icon = icon,
					action = "Show in toy box",
					call = function() ToggleToyCollection(itemID) end,
					drag = function() C_ToyBox.PickupToyBoxItem(itemID) end })
			end
		end
	end
end)

local function spellTab(skillLine)
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	for _, category in ipairs(book and book.categoryMixins or {}) do
		if category.skillLineIndex == skillLine then
			return book.CategoryTabSystem:GetTabButton(category:GetTabID())
		end
	end
end

ns.provide("spells", RANK.spell, function(add)
	local bank = Enum.SpellBookSpellBank.Player
	local best, order = {}, {}
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info and not info.shouldHide then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local s = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if s and s.spellID and s.itemType ~= Enum.SpellBookItemType.FutureSpell and not s.isOffSpec then
					local rank = tonumber(s.subName and s.subName:match("%d+")) or 0
					local old = best[s.name]
					if not old then order[#order + 1] = s.name end
					if not old or rank > old.rankNumber then
						best[s.name] = { s = s, slot = slot, line = line, lineName = info.name, rankNumber = rank }
					end
				end
			end
		end
	end
	for _, name in ipairs(order) do
		local b = best[name]
		local s, slot, line = b.s, b.slot, b.line
		local rankText = s.subName ~= "" and s.subName or nil
		local book = { action = "Open spellbook", binding = "TOGGLESPELLBOOK", button = "SpellbookMicroButton",
			tab = function() return spellTab(line) end }
		local e = { name = name, cat = s.isPassive and "Passive" or "Spell", sub = b.lineName,
			key = "spell:" .. name, icon = s.iconID, value = rankText,
			dragHint = rankText and rankText .. " to your bars",
			drag = not s.isPassive and function() C_SpellBook.PickupSpellBookItem(slot, bank) end or nil }
		if s.isPassive then
			for k, v in pairs(book) do e[k] = v end
		else
			e.line, e.action, e.alt = "/cast " .. name, "Cast", book
		end
		add(e)
	end
end)

ns.provide("macros", RANK.macro, function(add)
	local account, character = GetNumMacros()
	local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
	local function addMacro(index, tab, tabIndex)
		local name, icon = GetMacroInfo(index)
		if not name then return end
		add({ name = name, cat = "Macro", sub = tab == 1 and "Account" or "Character",
			key = "macro:" .. name, icon = icon, action = "Open macros",
			line = "/macro",
			after = function()
				if MacroFrame and MacroFrame:IsShown() then
					MacroFrame:ChangeTab(tab)
					MacroFrame:SelectMacro(tabIndex, true)
				end
			end,
			drag = function() PickupMacro(index) end })
	end
	for i = 1, account do addMacro(i, 1, i) end
	for i = 1, character do addMacro(base + i, 2, i) end
end)

local bagSearchSet = false
for _, name in ipairs({ "ContainerFrameCombinedBags", "ContainerFrame1" }) do
	local bagFrame = _G[name]
	if bagFrame then
		bagFrame:HookScript("OnHide", function()
			if bagSearchSet then
				bagSearchSet = false
				C_Container.SetItemSearch("")
			end
		end)
	end
end

ns.provide("items", RANK.item, function(add)
	local seen = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local name = info and info.hyperlink and info.hyperlink:match("%[(.-)%]")
			if name and not seen[info.itemID] then
				seen[info.itemID] = true
				local n = C_Item.GetItemCount(info.itemID)
				add({ name = name, cat = "Item", key = "item:" .. info.itemID,
					icon = info.iconFileID, value = n > 1 and "×" .. n or nil, action = "Show in bags",
					binding = "OPENALLBAGS", button = "MainMenuBarBackpackButton",
					after = function()
						C_Container.SetItemSearch(name)
						bagSearchSet = true
					end,
					drag = function() C_Container.PickupContainerItem(bag, slot) end })
			end
		end
	end
end)

ns.provide("currencies", RANK.progress, function(add)
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local c = C_CurrencyInfo.GetCurrencyListInfo(i)
		if c and not c.isHeader and c.name then
			add({ name = c.name, cat = "Currency", key = "currency:" .. (c.currencyID or c.name),
				icon = c.iconFileID or CURRENCY_ICON, value = c.quantity and "|cffffffff" .. c.quantity .. "|r",
				action = "Open currency", binding = "TOGGLECURRENCY", button = "CharacterMicroButton" })
		end
	end
end)

ns.provide("reputations", RANK.progress, function(add)
	for i = 1, C_Reputation.GetNumFactions() do
		local f = C_Reputation.GetFactionDataByIndex(i)
		if f and f.name and (not f.isHeader or f.isHeaderWithRep) then
			local standing = f.reaction and _G["FACTION_STANDING_LABEL" .. f.reaction]
			add({ name = f.name, cat = "Reputation", key = "rep:" .. f.factionID,
				icon = REP_ICON, value = type(standing) == "string" and paint(FACTION_BAR_COLORS[f.reaction], standing) or nil,
				action = "Open reputation", binding = "TOGGLECHARACTER2", button = "CharacterMicroButton" })
		end
	end
end)

local function selectChallenge(id)
	local frame = LegacySystemFrame
	if not (frame and frame:IsShown()) then return end
	selectLegacyPage(_G["LEGACY_CHALLENGE_TAB_TOOLTIP"])
	local find = AchievementFrame_FindDisplayedAchievement
	frame:SelectChallenge(find and find(id) or id)
end

ns.provide("legacy", RANK.progress, function(add)
	local open = LegacySystemFrame and LegacySystemFrame:IsShown()
	for _, category in ipairs(GetCategoryList() or {}) do
		for i = 1, GetCategoryNumAchievements(category) do
			local id, name, _, completed, _, _, _, _, _, icon = GetAchievementInfo(category, i)
			if id then
				add(inPanel({ name = name, cat = "Legacy Challenge", key = "ach:" .. id, icon = icon,
					value = completed and GREEN .. "Complete|r" or nil, action = "Open challenge" },
					open, "TOGGLELEGACYSYSTEM", "LegacyMicroButton", function() selectChallenge(id) end))
			end
		end
	end
end)

ns.provide("commands", RANK.slash, function(add)
	for _, r in ipairs(ns.discover.slash()) do
		local also = #r.aliases > 0 and "also " .. table.concat(r.aliases, ", ") or nil
		add({
			name = r.command, cat = "Command", sub = r.title and (also and r.title .. " · " .. also or r.title) or also,
			key = "slash:" .. r.command, slash = r.command, aliases = r.aliases, addon = r.title,
			icon = r.icon or (r.folder and 136243 or "Interface/Icons/UI_Chat"), atlas = r.atlas,
			action = "Run " .. r.command, line = r.command,
		})
	end
end)

local launcherAnchor
local function anchorFor(name)
	local button = ns.discover.minimapButton(name)
	if button and button:IsVisible() then return button end
	if not launcherAnchor then
		launcherAnchor = CreateFrame("Frame", nil, UIParent)
		launcherAnchor:SetSize(1, 1)
		launcherAnchor:SetPoint("TOP", LookupFrame, "TOP")
	end
	return launcherAnchor
end

ns.provide("launchers", RANK.addon, function(add)
	for _, r in ipairs(ns.discover.launchers()) do
		add({ name = r.label, cat = "Addon", sub = r.title ~= r.label and r.title or nil, key = "ldb:" .. r.name,
			icon = r.icon or 136243, atlas = r.atlas, action = "Open",
			call = function() r.onClick(anchorFor(r.name), "LeftButton") end })
	end
end)

local classFiles
local function classFile(localized)
	if not classFiles then
		classFiles = {}
		for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
			for file, name in pairs(names) do classFiles[name] = file end
		end
	end
	return localized and classFiles[localized]
end

local function who(level, className, file, area)
	local s = className and paint(file and RAID_CLASS_COLORS[file], className) or ""
	if level and level > 0 then s = level .. " " .. s end
	if area and area ~= "" then s = s .. " · " .. area end
	return s ~= "" and s or nil
end

local function whisper(add, name, key, cat, sub, file, send)
	add({ name = name, cat = cat, sub = sub, key = key,
		icon = not file and 132200 or nil, atlas = file and "groupfinder-icon-class-" .. file:lower(),
		action = "Whisper", call = send })
end

ns.provide("people", RANK.people, function(add)
	for i = 1, C_FriendList.GetNumFriends() do
		local f = C_FriendList.GetFriendInfoByIndex(i)
		if f and f.connected and f.name then
			local name, file = f.name, classFile(f.className)
			whisper(add, name, "friend:" .. name, "Friend", who(f.level, f.className, file, f.area), file,
				function() ChatFrameUtil.SendTell(name) end)
		end
	end
	for i = 1, BNGetNumFriends() do
		local a = C_BattleNet.GetFriendAccountInfo(i)
		if a and a.accountName and not issecretvalue(a.accountName) and a.gameAccountInfo.isOnline then
			local account = a.accountName
			whisper(add, account, "bnet:" .. a.battleTag, "Friend", "Battle.net", nil,
				function() ChatFrameUtil.SendBNetTell(account) end)
		end
	end
	if IsInGuild() then
		C_GuildInfo.GuildRoster()
		for i = 1, GetNumGuildMembers() do
			local full, _, _, level, className, zone, _, _, online, _, file = GetGuildRosterInfo(i)
			if full and online then
				whisper(add, Ambiguate(full, "guild"), "guild:" .. full, "Guild", who(level, className, file, zone), file,
					function() ChatFrameUtil.SendTell(full) end)
			end
		end
	end
end)
