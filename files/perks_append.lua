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
		ui_name = "Copy Three Perks",
		ui_description = "Copy three random perks from other players but lose one of your own",
	} and nil,
	{-- health lost is distributed to nearby allies as healing (stacks increase the range (and efficacy?))
		id = "NLD_RECYCLE_HEALTH",
		ui_name = "Recycle Health",
		ui_description = "A portion of lost health is recycled as healing for a nearby ally",
		stackable = true,
		stackable_is_rare = true,
		stackable_maximum = 3,
		max_in_perk_pool = 3,
		func = function(perk, taker, perk_name, number) --number is how many of this perk the target now owns

			if number == 1 then
				EntityAddComponent2(taker, "LuaComponent", {
					script_damage_received = "mods/nld_tweaks/files/perks/recycle_health.lua"
				})
				EntityAddComponent2(taker, "VariableStorageComponent", {
					name = "nld_health_recycle",
					value_float = .5,
					value_int = 200,
				})
			else
				local recycle_efficiency_comp
				for _, varcomp in ipairs(EntityGetComponent(taker, "VariableStorageComponent") or {}) do
					if ComponentGetValue2(varcomp, "name") == "nld_health_recycle" then
						recycle_efficiency_comp = varcomp break
					end
				end

				if recycle_efficiency_comp then
					ComponentSetValue2(recycle_efficiency_comp, ComponentGetValue2(recycle_efficiency_comp, "value_float") + .25)
					ComponentSetValue2(recycle_efficiency_comp, ComponentGetValue2(recycle_efficiency_comp, "value_int") + 150)
				end
			end
		end
	} and nil,
	{-- a portion of damage taken by nearby allies is redirected to the perk holder (second stack increases to 50%)
		id = "NLD_TANKER",
		ui_name = "Team Tank",
		ui_description = "25% of damage taken by nearby allies is decreased by half and redirected to you",
		stackable = true,
		stackable_is_rare = true,
		max_in_perk_pool = 2,
		func = function(perk, taker, perk_name, number)
			
		end
	} and nil,
	{-- when the player dies, their zombie is much stronger BUT it is hostile to all creatures
		id = "NLD_BERSERKER",
		ui_name = "Restless Spirit",
		ui_description = "On death, your zombie will be much stronger and behave more aggressively to those around it",
	} and nil,
	{-- steals a random stackable perk from another player and spawns three of it
		id = "NLD_PILFER",
		ui_name = "Pilfer",
		ui_description = "Steal a random stackable perk from a random player and spawn two more copies",
	} and nil,
	{-- inflicted satuses have a 1/[#nearby_players] chance to apply the status to all nearby players and otherwise nullify the effect
		id = "NLD_SHARE_STATUS",
		ui_name = "In It Together",
		ui_description = "Chance to be afflicted by a status effect is greatly reduced per nearby allies, but will afflict everyone if triggered",
		--subsequent stacks will decrease the chance for the effect to trigger further
	} and nil,
	{-- connect to nearby players and combines the mana pool and regeneration rate of actively held wands plus buffs both by 20% (link is obstructed by terrain)
		id = "NLD_MANA_CHAIN", --the link chains, linking any connected player to any unconnected player if the distance between them is sufficient
		ui_name = "Mana Pool", --displays the pooled mana as a bar at the bottom centre of the screen
		ui_description = "Connects a magic chain linking nearby allies pooling your mana and increasing efficiency",
	} and nil,
	{-- might scrap on the grounds friendly fire simply punishes people with bad aim (which just feels bad for everyone)
		id = "NLD_FRIENDLY_FIRE", --and limits wand building options in an environment where resources are already spread pretty thin
		ui_name = "Friendly Fire", --maybe give passive healing? idk still sounds potentially unfun and bad
		ui_description = "All players' spells can now hurt one another, but increase everyone's HP by 80%"
	} and nil,
	{-- steal 20% of all players' HP and grants it tripled to a random player (30% if there are two or less players)
		id = "NLD_HP_ROULETTE",
		ui_name = "$nld_perk_hp_roulette",
		ui_description = "All players wager a portion of their Max Health and the winner is granted the bet three-times over",
		ui_icon = "data/ui_gfx/perk_icons/extra_hp.png",
		perk_icon = "data/items_gfx/perks/extra_hp.png",
		one_off_effect = true,
		do_not_remove = true,
		stackable = true,
		--- TODO
		--- when perk is taken, HP is immediately yoinked with a noticeable visual effect, players can dodge by being poly'd or smth
		--- after wagers are collected, big spiritual gambling machines thunk in above the betters, jojo-stand style
		--- they have flashing lights and carnival noises as they roll, it rolls 3 match for the target winner
		--- 	if target winner is invalid when the animation ends (ie poly'd or smth), that player is removed as a better and their machine explodes
		--- 	if the bet failed, the machines flash red and try again
		--- 		if all machines are destroyed, print "A LOSER IS YOU" on every player's screen
		func = function(perk, taker, perk_name)
			if not EntityHasTag(taker, "player_unit") then return end --do this to only run func once
			print("----- EXECUTING HEALTHY GAMBIT FUNC -----")
			local players = EntityGetWithTag("ew_peer")
			local betters = {}

			local hp_steal_percent = #players > 2 and .2 or .3 --less than 3 players then increase wager to 30% to make it not worse extra-hp
			local hp_jackpot_multiplier = 3

			local maxhp_pool = 0
			local hp_pool = 0
			for _, player in ipairs(players) do
				local peer_id
				for _, varcomp in ipairs(EntityGetComponent(player, "VariableStorageComponent") or {}) do
					if ComponentGetValue2(varcomp, "name") == "ew_peer_id" then peer_id = ComponentGetValue2(varcomp, "value_string") end
				end
				local dmc = EntityGetFirstComponent(player, "DamageModelComponent")
				if dmc and peer_id then
					print("identified better: " .. player)
					betters[#betters+1] = peer_id --add to list of betters
					local maxhp = ComponentGetValue2(dmc, "max_hp") --get available max health
					local wagered_maxhp = maxhp * hp_steal_percent --get wager
					maxhp_pool = maxhp_pool + wagered_maxhp --add wager to pool
					print("deducting " .. wagered_maxhp .. " maxhp from the target")
					ComponentSetValue2(dmc, "max_hp", maxhp - wagered_maxhp)


					local hp = ComponentGetValue2(dmc, "hp")
					if maxhp < hp then --if maxhp decrease would consume HP, add it to the wager as change
						hp_pool = hp_pool + (hp - maxhp)
					end
				end
			end

			print("maxhp wager = " .. maxhp_pool)
			if #betters ~= 0 then --if no betters were found then fucking never mind i guess
				print("number of betters: 0" .. #betters)
				local x,y = EntityGetTransform(perk)
				SetRandomSeed(x,y)
				local winner = betters[Random(1, #betters)] --pick winner
				print("A WINNER IS PLAYER".. winner)

				maxhp_pool = maxhp_pool * hp_jackpot_multiplier --increase maxhp_pool by jackpot multiplier
				
				local dmc = EntityGetFirstComponent(winner, "DamageModelComponent")
				if not dmc then return end
				ComponentSetValue2(dmc, "max_hp", ComponentGetValue2(dmc, "max_hp") + maxhp_pool)
				ComponentSetValue2(dmc, "hp", ComponentGetValue2(dmc, "hp") + hp_pool)
			end
			print("----- CONDLUDING HEALTHY GAMBIT FUNC -----")
		end,
	},
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
		ui_name = "Hot Polytato",

	} and nil,
	{
		id = "NLD_GOLD_SPLIT",
		ui_name = "$nld_perk_gold_split",
		ui_description = "$nld_perkdesc_gold_split",
		ui_icon = "data/ui_gfx/perk_icons/extra_money.png",
		perk_icon = "data/items_gfx/perks/extra_money.png",
		one_off_effect = true,
		do_not_remove = true,
		stackable = true,
		stackable_is_rare = true,
		func = function(perk, taker, perk_name)
			local players = EntityGetWithTag("ew_peer")
			local combined_gold = 0
			local valid_players = {} --do this in case for some reason someone doesnt have a wallet to prevent me from needing to constantly check
			for _, player in ipairs(players) do
				local wallet = EntityGetFirstComponent(player, "WalletComponent")
				if wallet then
					valid_players[#valid_players+1] = player
					if ComponentGetValue2(wallet, "mHasReachedInf") then combined_gold = -1 break end --dont bother tallying up any more gold if its gonna be infinite anyway
					combined_gold = combined_gold + ComponentGetValue2(wallet, "money")
				end
			end

			if combined_gold == -1 then --if a player has infinite gold, give everyone else infinite gold
				for _, player in ipairs(valid_players) do
					ComponentSetValue2(EntityGetFirstComponent(player, "WalletComponent"), "mHasReachedInf", true)
					return
				end
			end --im considering making this actually remove inf gold from whomever has it and consider it as 2.1bil, but also removing inf gold might be buggy idk test later

			local gold_amount = math.ceil((combined_gold * 1.1) / #valid_players) --increase gold by 10%, divide between the number of targets, round up
			for _, player in ipairs(valid_players) do
				ComponentSetValue2(EntityGetFirstComponent(player, "WalletComponent"), "money", gold_amount)
			end
		end
	},
	{-- you become a bound spirit (similar to The Soul for The Forgotten in tboi)
		id = "NLD_BOUND_SPIRIT",
		ui_name = "Ritual of Binding",
		ui_description = "Become an unkillable spirit that switches between players to be bound to",
	} and nil, --add unique interaction wherein if you are already Linked to a player via the HP link item, you are stuck to them specifically but are strengthened
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

--mode idea: everyone starts in a different parallel world (implement a fork of Parallel Parity that enforces full mirroring) and have to power up to beat each other
-- every world has a Kolmi, beating it spawns a permanent portal to every other player's PW Intro Cave (colours indicate which is which)
-- pvp is enabled, respawning invokes a timer-based respawn system sending you back to your previous parallel world
-- either have limited respawns or timer increases per-respawn and if a player reaches you while you are dead and interacts with you then you lose

if ModIsEnabled("quant.ew") then
	for _, perk in pairs(multiplayer_perks) do
		perk_list[#perk_list+1] = perk
		print(("ADDED PERK [%s]"):format(perk.id or "NULL_ID"))
	end
end