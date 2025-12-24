ModLuaFileAppend("data/scripts/perks/perk_list.lua", "mods/nld_tweaks/files/perks_append.lua")


local translations = ModTextFileGetContent("data/translations/common.csv") --get translations file
translations = translations .. "\n" .. ModTextFileGetContent("mods/nld_tweaks/standard.csv") --append with your own
translations = translations:gsub("\r", ""):gsub("\n\n+", "\n") --this is just a funky thing to fix fundamental bugginess with appending translations
ModTextFileSetContent("data/translations/common.csv", translations) --set translations file


if ModIsEnabled("quant.ew") then
	ModLuaFileAppend("mods/quant.ew/files/api/extra_modules.lua", "mods/nld_tweaks/files/ew.lua")
end

