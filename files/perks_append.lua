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
			mana_max = math.floor(math.min(mana_max, 50000)) --max of 50k

			mana_charge = math.min(mana_charge * Randomf(1.2, 1.4)  ,  mana_charge + Random(80, 400)) + Random(60, 120)
			mana_charge = math.floor(math.min(mana_charge, 20000)) --max of 20k

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
	EXTRA_SLOTS = { --buffed to make held wand guaranteed plus 3 slots, a lesser buff also applies to all wands in 24px radius that arent held by player
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
					elseif EntityGetRootEntity(entity_id) == taker then increase = Random(1,3) --if in player's inventory, increase by 1-3
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
		ui_icon = "mods/nld_tweaks/files/perks/super_shield/ui.png",
		perk_icon = "mods/nld_tweaks/files/perks/super_shield/perk.png",
		stackable = false,
		usable_by_enemies = true,
		func = function( perk, taker, perk_name )
			local x,y = EntityGetTransform(taker)
			EntityAddChild(taker, EntityLoad("mods/nld_tweaks/files/perks/super_shield/shield.xml", x, y))
		end,
		func_remove = function(taker)
			for _, entity_id in ipairs(EntityGetAllChildren(taker) or {}) do
				if EntityGetName(entity_id) == "nld_super_shield" then
					EntityKill(entity_id)
					return
				end
			end
		end,
	},
	{-- 
		id = "NLD_",
	} and nil,
}

for _, perk in ipairs(additional_perks) do
	perk_list[#perk_list+1] = perk
end



local multiplayer_modifications = {

}


local multiplayer_perks = {
	{-- picks 2 random perks from other players and grants them
		id = "NLD_COPY_ALLY_PERKS",
		ui_name = "Copy Two Perks",
		ui_description = "Copy two random perks from other players",
	} and nil,
	{-- health lost is distributed to nearby allies as healing (stacks increase the range (and efficacy?))
		id = "NLD_RECYCLE_HEALTH",
		ui_name = "Recycle Health",
		ui_description = "Lost HP is recycled as healing for a nearby ally",
	} and nil,
	{-- a portion of damage taken by nearby allies is redirected to the perk holder (second stack increases to 50%)
		id = "NLD_TANKER",
		ui_name = "Team Tank",
		ui_description = "25% of damage taken by nearby allies is decreased by half and redirected to you",
	} and nil,
	{-- when the player dies, their zombie is much stronger BUT it is hostile to all creatures
		id = "NLD_BERSERKER",
		ui_name = "Restless Spirit",
		ui_description = "On death, your zombie will be much stronger and behave more aggressively to those around it",
	} and nil,
	{-- steals a random stackable perk from another player and spawns three of it
		id = "NLD_PILFER",
		ui_name = "Pilfer",
		ui_description = "Steal a stackable perk from a random player and spawn two more copies",
	} and nil,
	{-- inflicted satuses have a 1/[#nearby_players] chance to apply the status to all nearby players and otherwise nullify the effect
		id = "NLD_SHARE_STATUS",
		ui_name = "All or Nothing",
		ui_description = "Status Effects inflicted on you are spread between you and nearby allies evenly",
	} and nil,
	{-- connect to nearby players and combines the mana pool and regeneration rate of actively held wands plus buffs both by 20% (link is obstructed by terrain)
		id = "NLD_MANA_CHAIN", --the link chains, linking any connected player to any unconnected player if the distance between them is sufficient
		ui_name = "Mana Pool", --displays the pooled mana as a bar at the bottom centre of the screen
		ui_description = "Creates a magic chain between nearby allies pooling their mana and increasing efficiency",
	} and nil,
	{-- might scrap on the grounds friendly fire simply punishes people with bad aim (which just feels bad for everyone)
		id = "NLD_FRIENDLY_FIRE", --and limits wand building options in an environment where resources are already spread pretty thin
		ui_name = "Friendly Fire", --maybe give passive healing? idk still sounds potentially unfun and bad
		ui_description = "All players' spells can now hurt one another, but increase everyone's HP by 80%"
	} and nil,
	{-- steal 20% of all players' HP and grants it tripled to a random player (30% if there are two or less players)
		id = "NLD_HP_ROULETTE",
		ui_name = "Healthy Gambit",
		ui_description = "20% of Max Health is taken from all players and granted three times over to a random player",
	} and nil,
	{-- strengthens the psychic shield you grant to other players on death, allows you to grant it while still alive
		id = "NLD_BUFF_PSYCHIC_SHIELD",
		ui_name = "Strengthen Psychic Shield",
		ui_description = "Makes the Psychic Shield you grant to others tougher and no longer require you to die"
	} and nil,
	{-- 10% of gold from nearby expired nuggets is added to your wallet, but so is 10% of gold from gold nuggets that are picked up by other players anywhere
		id = "NLD_PASSIVE_INCOME",
		ui_name = "Passive Income",
		ui_description = "10% of gold from nearby expired Gold Nuggets or those picked up by allies is transferred to you",
	} and nil,
	{-- when spectating another player, allows you to hover your mouse over an enemy to freeze it in place
		id = "NLD_DIVINE_GLARE",
		ui_name = "Divine Glare",
		ui_description = "Allows you to inflict a fear status on a focused enemy when observing your peers",
	} and nil,
	{-- lose Psychic Shield on death but gain freecam
		id = "NLD_OMNISCIENT_VIEWER",
		ui_name = "Omniscient Spectator's Viewpoint",
		ui_description = "Loses Psychic Shield on death but you are able to project your mind to wherever it may wander",
	} and nil,
	{-- something something chain that increases range relative to max HP of the players? idk it needs a positive boon (may scrap)
		id = "NLD_CHAINED_TOGETHER",
	} and nil,
	{-- copy 5 perks? but every time you die you lose one
		id = "NLD_BORROW_PERKS",
	} and nil,
	{-- adds a chance to dodge (nullify) any attack with a (#nearby_players-1)/(#total_players-1) * .5 chance (for every nearby player, chance increases, up to 50%)
		id = "NLD_PLOT_CONTRIVANCE",
		ui_name = "Plot Contrivance",
		ui_description = "The more main characters there are around you, the less likely consequences are to impact you!"
	} and nil,
	{-- if you walk up to and stand next to an enemy for a short period of time, you are temporarily polymorphed into it
		id = "NLD_HOT_POLYTATO", --if you deceive a player into killing you, you get a boon and that get a malus (opposite of bonus)
	} and nil,
	{-- 
		id = "NLD_",
	} and nil,
}
--perk idea: make multiplayer perks have a custom outline? (like how One-Offs are green)
--item idea: soul link, throw it at another player and your healthbars are combined and linked BUT when one of you has tinker the effect is shared
--item idea: wormhole potion from terraria, item that lets you tp to another player of your choosing (party gets one per holy mountain, can also be found on pedestals)
--spell idea: cross the streams, makes it so if the projectile comes within close proximity of a different player's projectile, its damage is amplified
--spell idea: player homing (thank you d2d)
--spell idea: friendly fire spell that makes spells work on allies but doesnt change them working on yourself

--make vampirism allow you to take a portion of a player's HP if you interact with them
-- UNLESS they have slime/oil blood in which case you get sick, if gas blood you get gassy effect



if ModIsEnabled("quant.ew") then
	for _, perk in ipairs(multiplayer_perks) do
		perk_list[perk_list+1] = perk
	end
end