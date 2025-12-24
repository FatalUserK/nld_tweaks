
local ew_api = dofile_once("mods/quant.ew/files/api/ew_api.lua")

local rpc = ew_api.new_rpc_namespace("nld_tweaks") --create namespace

rpc.players_multiply_health = function(hp, maxhp, target)
	print("MULTIPLYING HP")
	hp = hp or 1
	maxhp = maxhp or 1

	for _, player in ipairs(EntityGetWithTag("player_unit")) do
		if target then
			for _, varcomp in ipairs(EntityGetComponent(player, "VariableStorageComponent") or {}) do
				if ComponentGetValue2(varcomp, "name") == "ew_peer_id" and ComponentGetValue2(varcomp, "value_string") ~= target then
					return
				end
			end
		end

		local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
		if dmc then
			ComponentSetValue2(dmc, "hp", ComponentGetValue2(dmc, "hp") * hp)
			ComponentSetValue2(dmc, "max_hp", ComponentGetValue2(dmc, "max_hp") * maxhp)
		else print("ERR - DamageModelComponent IS NIL FOR \"player_multiply_hp\" TARGET, EID IS " .. player) return end
	end
end

rpc.players_modify_health = function(hp, maxhp, target)
	print("MODIFYING HP")
	hp = hp or 1
	maxhp = maxhp or 1

	for _, player in ipairs(EntityGetWithTag("player_unit")) do
		if target then
			for _, varcomp in ipairs(EntityGetComponent(player, "VariableStorageComponent") or {}) do
				if ComponentGetValue2(varcomp, "name") == "ew_peer_id" and ComponentGetValue2(varcomp, "value_string") ~= target then
					return
				end
			end
		end

		local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
		if dmc then
			ComponentSetValue2(dmc, "hp", ComponentGetValue2(dmc, "hp") + hp)
			ComponentSetValue2(dmc, "max_hp", ComponentGetValue2(dmc, "max_hp") + maxhp)
		else print("ERR - DamageModelComponent IS NIL FOR \"player_multiply_hp\" TARGET, EID IS " .. player) return end
	end
end

util.add_cross_call("nld_player_multiply_health", function(hp, maxhp)
	rpc.players_multiply_health(hp, maxhp)
end)

util.add_cross_call("nld_player_modify_health", function(hp, maxhp)
	rpc.players_modify_health(hp, maxhp)
end)