local load = dofile("tests/stubs.lua")
local ns = load({ "Lookup/Action.lua", "Lookup/Providers.lua", "Lookup/Discovery.lua" })

addons = {
	Auctionator = { Title = "Auctionator", IconTexture = "Interface/AddOns/Auctionator/Images/Logo" },
	AtlasLootClassic = { Title = "|TInterface/AddOns/AtlasLootClassic/atlas_tga:16|t AtlasLoot Forever |cFF22B14C[Core]|r",
		IconAtlas = "loot-atlas" },
	LayerSwap = { Title = "LayerSwap" },
	Lookup = { Title = "Lookup" },
}

-- Slash commands: the visible list, and the hidden table chat moves them into on first use.
local hiddenList = { WHO = true, ATLASLOOT = true }
SlashCmdList = setmetatable({ Auctionator = true, LOOKUP = true }, { __index = hiddenList })
SLASH_WHO1 = "/who"
SLASH_WHO2, SLASH_WHO3 = "/WHO", "/w2" -- the same spelling twice is not an alias
SLASH_Auctionator1, SLASH_Auctionator2 = "/auctionator", "/atr"
SLASH_ATLASLOOT1, SLASH_ATLASLOOT2 = "/atlasloot", "/al"
SLASH_LOOKUP1 = "/lookup"
taint = { SLASH_Auctionator1 = "Auctionator", SLASH_ATLASLOOT1 = "AtlasLootClassic", SLASH_LOOKUP1 = "Lookup" }

local byCommand = {}
for _, r in ipairs(ns.discover.slash()) do byCommand[r.command] = r end
local atr = byCommand["/auctionator"]
assert(atr.title == "Auctionator" and atr.folder == "Auctionator" and atr.aliases[1] == "/atr")
assert(atr.icon == "Interface/AddOns/Auctionator/Images/Logo" and atr.atlas == nil)
-- From the hidden table, with colour codes and inline icons cleaned from the title.
local al = byCommand["/atlasloot"]
assert(al and al.title == "AtlasLoot Forever [Core]", al and al.title)
assert(al.icon == nil and al.atlas == "loot-atlas")
-- Blizzard's have no addon; Lookup's own count as Blizzard's (no addon row for itself).
assert(byCommand["/who"].title == nil and byCommand["/lookup"].title == nil)
assert(#byCommand["/who"].aliases == 1 and byCommand["/who"].aliases[1] == "/w2")

-- Key bindings: only named ones, with the addon that named them.
local BINDINGS = { { "TOGGLEWORLDMAP", "BINDING_HEADER_INTERFACE", "M" }, { "ATLASLOOT_TOGGLE", nil, nil },
	{ "HEADER_BLANK", nil, nil } }
function GetNumBindings() return #BINDINGS end
function GetBinding(i) return unpack(BINDINGS[i]) end
BINDING_HEADER_INTERFACE = "Interface"
BINDING_NAME_TOGGLEWORLDMAP = "Open World Map"
BINDING_NAME_ATLASLOOT_TOGGLE = "Toggle AtlasLoot"
taint.BINDING_NAME_ATLASLOOT_TOGGLE = "AtlasLootClassic"
local b = ns.discover.bindings()
assert(#b == 2)
assert(b[1].header == "Interface" and b[1].bound and b[1].title == nil)
assert(b[2].command == "ATLASLOOT_TOGGLE" and not b[2].bound and b[2].title == "AtlasLoot Forever [Core]")

-- LibDataBroker launchers: owner by name when it is an addon, else by who set OnClick.
local onClick = function() end
local objects = {
	LayerSwap = { type = "launcher", OnClick = onClick, icon = "Interface/AddOns/LayerSwap/Media/logo" },
	AtlasLoot = { type = "launcher", OnClick = onClick, label = "AtlasLoot" },
	RXPGuides = { type = "data source", text = "Step 3" },
}
local ldb = { DataObjectIterator = function() return pairs(objects) end }
function LibStub(major) return major == "LibDataBroker-1.1" and ldb or nil end
taint.OnClick = "AtlasLootClassic"
local launchers = {}
for _, r in ipairs(ns.discover.launchers()) do launchers[r.name] = r end
assert(launchers.RXPGuides == nil)
assert(launchers.LayerSwap.title == "LayerSwap" and launchers.LayerSwap.icon == "Interface/AddOns/LayerSwap/Media/logo")
assert(launchers.AtlasLoot.folder == "AtlasLootClassic" and launchers.AtlasLoot.atlas == "loot-atlas")
assert(launchers.AtlasLoot.onClick == onClick)
assert(ns.discover.minimapButton("AtlasLoot") == nil)

print("ok")
