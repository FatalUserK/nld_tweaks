dofile_once("mods/nld_tweaks/files/utilities.lua")


local modifications = {
	EXTRA_MANA = { --buff mana slightly, change 50% decrease in capacity to flat decrease 1-3 plus 10% of current capacity rounded down
		ui_description = "$nld_perkdesc_extra_mana",
		func = function(perk, taker, perk_name)
			local wand = GetHeldWand(taker)
			if wand == 0 then return end
			local x,y = EntityGetTransform(wand)

			local ability_comp = EntityGetFirstComponentIncludingDisabled(wand, "AbilityComponent")
			if not ability_comp then return end

			local mana_max = ComponentGetValue2(ability_comp, "mana_max")
			local mana_charge = ComponentGetValue2(ability_comp, "mana_charge_speed")
			local full_capacity = ComponentObjectGetValue2(ability_comp, "gun_config", "deck_capacity") --include ACs
			local capacity = EntityGetWandCapacity(wand) --do not include ACs
			local always_casts = math.max(0, full_capacity - capacity)

			local perk_x,perk_y =  EntityGetTransform(perk)
			SetRandomSeed(perk_x, perk_y)

			mana_max = math.min(mana_max * Randomf(1.3, 1.5)  ,  mana_max + Random(100, 500)) + Random(100, 200)
			mana_max = math.floor(math.min(mana_max, 50000))

			mana_charge = math.min(mana_charge * Randomf(1.2, 1.4)  ,  mana_charge + Random(80, 400)) + Random(60, 120)
			mana_charge = math.floor(math.min(mana_charge, 20000))

			capacity = math.max(capacity - Random(1, 3) - math.floor(capacity*.1), 1) --remove 1-3 AND one more for every 10 slots it has


			ComponentSetValue2(ability_comp, "mana_max", mana_max)
			ComponentSetValue2(ability_comp, "mana_charge_speed", mana_charge)
			ComponentObjectSetValue2(ability_comp, "gun_config", "deck_capacity", capacity + always_casts)


			--idk nonsense i stole from the original function
			local c = EntityGetAllChildren(wand)
			if (c ~= nil) and (#c > capacity + always_casts) then
				for i=always_casts+1,#c do
					local v = c[i]
					local comp2 = EntityGetFirstComponentIncludingDisabled(v, "ItemActionComponent")

					if (comp2 ~= nil) and (i > capacity + always_casts) then
						EntityRemoveFromParent(v)
						EntitySetTransform(v, x, y)

						local all = EntityGetAllComponents(v)

						for a,b in ipairs(all) do
							EntitySetComponentIsEnabled(v, b, true)
						end
					end
				end
			end
		end
	},
	EXTRA_SLOTS = { --buffed to make held wand guaranteed +3 slots, lesser buff also applies to all wands in 24px radius that arent held by player
		func = function(perk, taker, perk_name)
			local x, y = EntityGetTransform(perk)
			for i,entity_id in ipairs(EntityGetInRadiusWithTag(x, y, 24, "wand")) do
				local ability_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "AbilityComponent")
				if ability_comp then
					local full_capacity = tonumber(ComponentObjectGetValue2(ability_comp, "gun_config", "deck_capacity"))
					local capacity = EntityGetWandCapacity(entity_id)
					local always_casts = full_capacity - capacity

					local increase
					if entity_id == GetHeldWand(taker) then increase = 3 --if held wand, increase by 3
					elseif EntityGetRootEntity(entity_id) == taker then increase = Random(1, 3) --if in player's inventory, increase by 1-3
					else increase = Random(1, 2) end --if not in player inventory, increase by 1-2

					capacity = math.min(capacity + increase, math.max(25, capacity))
					ComponentObjectSetValue2(ability_comp, "gun_config", "deck_capacity", capacity + always_casts)
				end
			end
		end
	},
}

for _, perk in ipairs(perk_list) do
	local modification = modifications[perk.id]
	if modification then
		for key, value in pairs(modification) do
			perk[key] = value
		end
	end
end


local additional_perks = {
	{-- powerful shield that blocks projectiles from both sides, highly encourages a more melee-style wand build
		id = "NLD_SUPER_SHIELD",
		ui_name = "Super Shield",
		ui_description = "Gives you a small unbreakable shield... that blocks both ways!",
		ui_icon = "",
		perk_icon = "",
		stackable = false,
		func = function() end,
	} and nil,
	{--support role, healing? tank damage?

	} and nil,
}

for _, perk in ipairs(additional_perks) do
	perk_list[#perk_list+1] = perk
end


local multiplayer_perks = {
	{-- picks 3 random perks from other players and grants them
		id = "NLD_COPY_THREE_PERKS",
		ui_name = "Copy Three Perks",
		ui_description = "Copy three random perks from other players",

	} and nil
}

if ModIsEnabled("quant.ew") then
	for _, perk in ipairs(multiplayer_perks) do
		perk_list[perk_list+1] = perk
	end
end