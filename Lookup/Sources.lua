-- Entry sources, one per category in docs/design.md. Each runs on every open.
--
-- Panel opens must not run from plain addon code (they taint the action bars).
-- `command` runs a Blizzard key binding command through an override binding on
-- Enter, which is secure. `secure` is the mouse path (and Enter when there is
-- no command). `run` runs after them as plain code: only calls proven clean.
local _, ns = ...
local add -- set by each source call

local RANK = {
	panel = 1, setting = 2, zone = 3, quest = 4, collection = 5, spell = 6, macro = 7,
	item = 8, progress = 9, slash = 10, people = 11,
}
local GREEN = "|cff3fd13f"

local function src(f)
	ns.sources[#ns.sources + 1] = function(a)
		add = a
		f()
	end
end

-- Display name: a global string if it exists, else the binding name without "Toggle ".
local function label(global, command)
	local s = global and _G[global]
	if type(s) == "string" then return s end
	s = command and _G["BINDING_NAME_" .. command]
	return s and (s:gsub("^Toggle ", "")) or nil
end

local function click(button) return { type = "macro", macrotext = "/click " .. button } end

---Text in a colour from a Blizzard colour table ({r, g, b}).
local function paint(c, s)
	if not c then return s end
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), s)
end

-- 1. Panels and tabs -----------------------------------------------------------

-- { name global, binding command, mouse fallback button, icon }
-- Icon: a micro menu atlas name, a texture path (the character frame's side tabs), or "portrait".
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

src(function()
	local pvpIcon = "Interface/ICONS/INV_SideTab_Honor_" .. (UnitFactionGroup("player") or "Alliance") .. "_c60"
	for _, p in ipairs(PANELS) do
		local name = label(p[1], p[2])
		if name and _G["BINDING_NAME_" .. p[2]] then -- the command exists on this client
			local icon, atlas, portrait = p[4] --[[@as string?]], nil, nil
			if icon == "portrait" then
				icon, portrait = nil, "player"
			elseif icon == "pvp" then
				icon = pvpIcon
			elseif icon and not icon:find("/") then
				icon, atlas = nil, "UI-HUD-MicroMenu-" .. icon .. "-Up"
			end
			add({
				name = name, cat = "Panel", rank = RANK.panel, key = "panel:" .. p[2],
				icon = icon or 133633, atlas = atlas, portrait = portrait,
				command = p[2], binding = p[2], secure = p[3] and click(p[3]),
			})
		end
	end
	add({ name = MACROS or "Macros", cat = "Panel", rank = RANK.panel, key = "panel:macros",
		icon = 136377, secure = { type = "macro", macrotext = "/macro" } })
	add({ name = SETTINGS or "Settings", cat = "Panel", rank = RANK.panel, key = "panel:settings",
		atlas = "UI-HUD-MicroMenu-GameMenu-Up", run = function() Settings.OpenToCategory() end })
	add({ name = KEY_BINDINGS or "Key Bindings", cat = "Panel", rank = RANK.panel, key = "panel:keybindings",
		atlas = "UI-HUD-MicroMenu-GameMenu-Up",
		run = function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end })
end)

-- 2. Settings and key bindings -------------------------------------------------

local function onOff(v) return v and "On" or "Off" end

---A boolean setting: the row shows a checkbox, Enter flips it and prints the new state.
local function toggle(name, sub, key, get, set)
	add({
		name = name, cat = "Setting", sub = sub, rank = RANK.setting, key = key, icon = 136243,
		check = get,
		action = function() return get() and "Turn off" or "Turn on" end,
		run = function()
			local v = not get()
			set(v)
			print(name .. ": " .. onOff(v))
		end,
	})
end

local foundDamageMeter
local function addSetting(category, path, initializer)
	local setting = initializer.GetSetting and initializer:GetSetting()
	local name = initializer.GetName and initializer:GetName()
	if not setting or type(name) ~= "string" or name == "" then return end
	local variable = setting:GetVariable()
	if variable == "damageMeterEnabled" then foundDamageMeter = true end
	local categoryID = category:GetID()
	if setting:GetVariableType() == "boolean" then
		toggle(name, path, "setting:" .. variable,
			function() return setting:GetValue() end,
			function(v) setting:SetValue(v, true) end)
	else
		add({
			name = name, cat = "Setting", sub = path, rank = RANK.setting, key = "setting:" .. variable,
			icon = 136243, action = "Open settings",
			run = function() Settings.OpenToCategory(categoryID, name) end,
		})
	end
end

local function walkCategory(category, parentName)
	local target = category.redirectCategory or category
	local id = target:GetID()
	local name = category:GetName()
	local path = parentName and parentName .. " > " .. name or name
	add({ name = name, cat = "Settings", sub = parentName, rank = RANK.setting, key = "settings:" .. tostring(id),
		icon = 136243, action = "Open settings", run = function() Settings.OpenToCategory(id) end })
	local layout = SettingsPanel:GetLayout(category)
	if layout and layout:IsVerticalLayout() then
		for _, initializer in layout:EnumerateInitializers() do
			if not initializer:IsSearchIgnoredInLayout(layout) and initializer:ShouldShow() then
				addSetting(target, path, initializer)
			end
		end
	end
end

src(function()
	foundDamageMeter = false
	for _, category in ipairs(SettingsPanel:GetAllCategories()) do
		walkCategory(category)
		for _, sub in ipairs(category:GetSubcategories()) do walkCategory(sub, category:GetName()) end
	end
	-- ponytail: the damage meter setting registers only on standard realms; keep the CVar reachable.
	if not foundDamageMeter and C_CVar.GetCVar("damageMeterEnabled") then
		toggle("Damage Meter", nil, "setting:damageMeterEnabled",
			function() return C_CVar.GetCVarBool("damageMeterEnabled") end,
			function(v) C_CVar.SetCVar("damageMeterEnabled", v and "1" or "0") end)
	end
end)

src(function()
	for i = 1, GetNumBindings() do
		local command, header, key1 = GetBinding(i)
		local name = command and _G["BINDING_NAME_" .. command]
		-- CLICK bindings press another addon's secure button (use an item, target): not run from here.
		local by = name and not command:find("^CLICK ") and ns.addonOf(_G, "BINDING_NAME_" .. command)
		local headerName = header and _G[header]
		if by then
			-- ponytail: a runOnUp binding misses its release (the box closes first); handle it if an addon needs it.
			add({
				name = name, cat = "Key binding", sub = type(headerName) == "string" and headerName or by,
				rank = RANK.setting, key = "binding:" .. command, icon = 136243, binding = command,
				command = command, action = "Run",
			})
		elseif name then
			add({
				name = name, cat = "Key binding", sub = type(headerName) == "string" and headerName or nil,
				rank = RANK.setting, key = "binding:" .. command, icon = 136243, binding = command,
				value = not key1 and "Not bound" or nil, action = "Open key bindings",
				run = function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end,
			})
		end
	end
end)

-- 3. Zones, cities, dungeons ---------------------------------------------------

local MAP_KIND = { [Enum.UIMapType.Continent] = "Continent", [Enum.UIMapType.Zone] = "Zone",
	[Enum.UIMapType.Dungeon] = "Dungeon" }

local mapNames = {}
src(function()
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
			add({ name = m.name, cat = kind, sub = mapNames[m.parentMapID], rank = RANK.zone, key = "zone:" .. mapID,
				icon = 137176, value = levels, action = "Open map",
				run = function() OpenWorldMap(mapID) end })
		end
	end
end)

-- 4. Quests in the log ---------------------------------------------------------

-- "1/3": finished objectives of all, or "Complete".
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

src(function()
	local perMap, header = {}, nil
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local q = C_QuestLog.GetInfo(i)
		if q and q.isHeader then
			header = q.title
		elseif q and not q.isHidden then
			local questID = q.questID
			local sub = paint(GetQuestDifficultyColor(q.level), "Lvl " .. q.level)
			if header then sub = sub .. " · " .. header end
			add({ name = q.title, cat = "Quest", sub = sub, rank = RANK.quest, key = "quest:" .. questID,
				atlas = C_QuestLog.IsComplete(questID) and "QuestTurnin" or "Quest-In-Progress-Icon-yellow",
				value = function() return questProgress(questID) end, action = "Show in quest log",
				run = function() QuestMapFrame_OpenToQuestDetails(questID) end })
			---@diagnostic disable-next-line: redundant-parameter -- the annotation lacks the questID parameter
			local mapID = GetQuestUiMapID(questID)
			if mapID and mapID > 0 then perMap[mapID] = (perMap[mapID] or 0) + 1 end
		end
	end
	for mapID, n in pairs(perMap) do
		local info = mapNames[mapID] and { name = mapNames[mapID] } or C_Map.GetMapInfo(mapID)
		if info then
			add({ name = "Quests in " .. info.name, cat = "Quests", rank = RANK.quest, value = tostring(n),
				key = "questzone:" .. mapID, icon = 136797, binding = "TOGGLEQUESTLOG", action = "Open quest log",
				run = function() OpenQuestLog(mapID) end })
		end
	end
end)

-- 5. Mounts, pets, toys --------------------------------------------------------

src(function()
	for _, id in ipairs(C_MountJournal.GetMountIDs()) do
		local name, spellID, icon, _, _, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(id)
		if collected and not hidden then
			add({ name = name, cat = "Mount", rank = RANK.collection, key = "mount:" .. id, icon = icon,
				action = "Show in mount journal",
				run = function()
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
				rank = RANK.collection, key = "pet:" .. petID, icon = icon,
				value = level and "Lvl " .. level or nil, action = "Show in pet journal",
				run = function()
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
				add({ name = name, cat = "Toy", rank = RANK.collection, key = "toy:" .. itemID, icon = icon,
					action = "Show in toy box",
					run = function() ToggleToyCollection(itemID) end,
					drag = function() C_ToyBox.PickupToyBoxItem(itemID) end })
			end
		end
	end
end)

-- 6. Spells ----------------------------------------------------------------------

-- The school tab for a skill line. It exists only after the spellbook loaded once.
local function spellTab(skillLine)
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	for _, category in ipairs(book and book.categoryMixins or {}) do
		if category.skillLineIndex == skillLine then
			return book.CategoryTabSystem:GetTabButton(category:GetTabID())
		end
	end
end

src(function()
	local bank = Enum.SpellBookSpellBank.Player
	-- One row per spell name: the highest rank wins.
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
		-- No page jump: GoToSpell from addon code taints the spellbook and the action bars.
		add({ name = name, cat = s.isPassive and "Passive" or "Spell", sub = b.lineName, rank = RANK.spell,
			key = "spell:" .. name, icon = s.iconID, value = rankText, action = "Open spellbook",
			command = "TOGGLESPELLBOOK", secure = click("SpellbookMicroButton"),
			tab = function() return spellTab(line) end,
			dragHint = rankText and rankText .. " to your bars",
			drag = not s.isPassive and function() C_SpellBook.PickupSpellBookItem(slot, bank) end or nil })
	end
end)

-- 7. Macros ------------------------------------------------------------------------

src(function()
	local account, character = GetNumMacros()
	local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
	local function addMacro(index, tab, tabIndex)
		local name, icon = GetMacroInfo(index)
		if not name then return end
		add({ name = name, cat = "Macro", sub = tab == 1 and "Account" or "Character", rank = RANK.macro,
			key = "macro:" .. name, icon = icon, action = "Open macros",
			secure = { type = "macro", macrotext = "/macro" },
			run = function()
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

-- 8. Bag items ---------------------------------------------------------------------

-- The filter we set stays until cleared, so clear it when the bags close.
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

src(function()
	local seen = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local name = info and info.hyperlink and info.hyperlink:match("%[(.-)%]")
			if name and not seen[info.itemID] then
				seen[info.itemID] = true
				local n = C_Item.GetItemCount(info.itemID)
				add({ name = name, cat = "Item", rank = RANK.item, key = "item:" .. info.itemID,
					icon = info.iconFileID, value = n > 1 and "×" .. n or nil, action = "Show in bags",
					command = "OPENALLBAGS", secure = click("MainMenuBarBackpackButton"),
					run = function()
						C_Container.SetItemSearch(name)
						bagSearchSet = true
					end,
					drag = function() C_Container.PickupContainerItem(bag, slot) end })
			end
		end
	end
end)

-- 9. Currencies, reputations, Legacy Challenges ------------------------------------

src(function()
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local c = C_CurrencyInfo.GetCurrencyListInfo(i)
		if c and not c.isHeader and c.name then
			add({ name = c.name, cat = "Currency", rank = RANK.progress, key = "currency:" .. (c.currencyID or c.name),
				icon = c.iconFileID or CURRENCY_ICON, value = c.quantity and "|cffffffff" .. c.quantity .. "|r",
				action = "Open currency", command = "TOGGLECURRENCY", secure = click("CharacterMicroButton") })
		end
	end
	for i = 1, C_Reputation.GetNumFactions() do
		local f = C_Reputation.GetFactionDataByIndex(i)
		if f and f.name and (not f.isHeader or f.isHeaderWithRep) then
			local standing = f.reaction and _G["FACTION_STANDING_LABEL" .. f.reaction]
			add({ name = f.name, cat = "Reputation", rank = RANK.progress, key = "rep:" .. f.factionID,
				icon = REP_ICON, value = type(standing) == "string" and paint(FACTION_BAR_COLORS[f.reaction], standing) or nil,
				action = "Open reputation", command = "TOGGLECHARACTER2", secure = click("CharacterMicroButton") })
		end
	end
	for _, category in ipairs(GetCategoryList() or {}) do
		for i = 1, GetCategoryNumAchievements(category) do
			local id, name, _, completed, _, _, _, _, _, icon = GetAchievementInfo(category, i)
			if id then
				add({ name = name, cat = "Legacy Challenge", rank = RANK.progress, key = "ach:" .. id, icon = icon,
					value = completed and GREEN .. "Complete|r" or nil, action = "Open Legacy Challenges",
					command = "TOGGLELEGACYSYSTEM", secure = click("LegacyMicroButton") })
			end
		end
	end
end)

-- 10. Slash commands ---------------------------------------------------------------

src(function()
	-- Every command runs as a macro line, as if typed. Secure ones (/cast) are not in SlashCmdList.
	-- Typing "/" puts the box in command mode (UI.lua), where Space adds an argument.
	ns.eachSlash(function(command, by, folder, aliases)
		local also = #aliases > 0 and "also " .. table.concat(aliases, ", ") or nil
		local iconFile = folder and C_AddOns.GetAddOnMetadata(folder, "IconTexture")
		local iconAtlas = folder and not iconFile and C_AddOns.GetAddOnMetadata(folder, "IconAtlas")
		add({
			name = command, cat = "Command", sub = by and (also and by .. " · " .. also or by) or also,
			rank = RANK.slash, key = "slash:" .. command, slash = command, aliases = aliases, addon = by,
			icon = iconFile or (folder and 136243 or "Interface/Icons/UI_Chat"), atlas = iconAtlas or nil,
			action = "Run " .. command, secure = { type = "macro", macrotext = command },
		})
	end)
end)

-- 11. Friends and guild members ----------------------------------------------------

-- Localized class name to class file ("Shaman" -> "SHAMAN"), for class colours and icons.
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

---"34 Shaman · Orgrimmar", with the class in its colour.
local function who(level, className, file, area)
	local s = className and paint(file and RAID_CLASS_COLORS[file], className) or ""
	if level and level > 0 then s = level .. " " .. s end
	if area and area ~= "" then s = s .. " · " .. area end
	return s ~= "" and s or nil
end

local function whisper(name, key, cat, sub, file, send)
	add({ name = name, cat = cat, sub = sub, rank = RANK.people, key = key,
		icon = not file and 132200 or nil, atlas = file and "groupfinder-icon-class-" .. file:lower(),
		action = "Whisper", run = send })
end

src(function()
	for i = 1, C_FriendList.GetNumFriends() do
		local f = C_FriendList.GetFriendInfoByIndex(i)
		if f and f.connected and f.name then
			local name, file = f.name, classFile(f.className)
			whisper(name, "friend:" .. name, "Friend", who(f.level, f.className, file, f.area), file,
				function() ChatFrameUtil.SendTell(name) end)
		end
	end
	for i = 1, BNGetNumFriends() do
		local a = C_BattleNet.GetFriendAccountInfo(i)
		if a and a.accountName and not issecretvalue(a.accountName) and a.gameAccountInfo.isOnline then
			local account = a.accountName
			whisper(account, "bnet:" .. a.battleTag, "Friend", "Battle.net", nil,
				function() ChatFrameUtil.SendBNetTell(account) end)
		end
	end
	if IsInGuild() then
		C_GuildInfo.GuildRoster()
		for i = 1, GetNumGuildMembers() do
			local full, _, _, level, className, zone, _, _, online, _, file = GetGuildRosterInfo(i)
			if full and online then
				whisper(Ambiguate(full, "guild"), "guild:" .. full, "Guild", who(level, className, file, zone), file,
					function() ChatFrameUtil.SendTell(full) end)
			end
		end
	end
end)
