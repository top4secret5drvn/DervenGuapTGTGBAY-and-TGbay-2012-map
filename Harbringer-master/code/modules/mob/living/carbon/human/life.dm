//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

//NOTE: Breathing happens once per FOUR TICKS, unless the last breath fails. In which case it happens once per ONE TICK! So oxyloss healing is done once per 4 ticks while oxyloss damage is applied once per tick!
#define HUMAN_MAX_OXYLOSS 1 //Defines how much oxyloss humans can get per tick. A tile with no air at all (such as space) applies this value, otherwise it's a percentage of it.
#define HUMAN_CRIT_MAX_OXYLOSS ( (last_tick_duration) /5) //The amount of damage you'll get when in critical condition. We want this to be a 5 minute deal = 300s. There are 100HP to get through, so (1/3)*last_tick_duration per second. Breaths however only happen every 4 ticks.

#define HEAT_DAMAGE_LEVEL_1 3 //Amount of damage applied when your body temperature just passes the 360.15k safety point
#define HEAT_DAMAGE_LEVEL_2 6 //Amount of damage applied when your body temperature passes the 400K point
#define HEAT_DAMAGE_LEVEL_3 9 //Amount of damage applied when your body temperature passes the 1000K point

#define COLD_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when your body temperature just passes the 260.15k safety point
#define COLD_DAMAGE_LEVEL_2 3.5 //Amount of damage applied when your body temperature passes the 200K point
#define COLD_DAMAGE_LEVEL_3 5 //Amount of damage applied when your body temperature passes the 120K point

//Note that gas heat damage is only applied once every FOUR ticks.
#define HEAT_GAS_DAMAGE_LEVEL_1 3 //Amount of damage applied when the current breath's temperature just passes the 360.15k safety point
#define HEAT_GAS_DAMAGE_LEVEL_2 6 //Amount of damage applied when the current breath's temperature passes the 400K point
#define HEAT_GAS_DAMAGE_LEVEL_3 9 //Amount of damage applied when the current breath's temperature passes the 1000K point

#define COLD_GAS_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when the current breath's temperature just passes the 260.15k safety point
#define COLD_GAS_DAMAGE_LEVEL_2 3.5 //Amount of damage applied when the current breath's temperature passes the 200K point
#define COLD_GAS_DAMAGE_LEVEL_3 5 //Amount of damage applied when the current breath's temperature passes the 120K point

/mob/living/carbon/human
	var/oxygen_alert = 0
	var/toxins_alert = 0
	var/fire_alert = 0
	var/pressure_alert = 0
	var/prev_gender = null // Debug for plural genders
	var/temperature_alert = 0
	var/in_stasis = 0


/mob/living/carbon/human/Life()
	set invisibility = 0
	set background = 1

	if (monkeyizing)	return
	if(!loc)			return	// Fixing a null error that occurs when the mob isn't found in the world -- TLE

	..()

	/*
	//This code is here to try to determine what causes the gender switch to plural error. Once the error is tracked down and fixed, this code should be deleted
	//Also delete var/prev_gender once this is removed.
	if(prev_gender != gender)
		prev_gender = gender
		if(gender in list(PLURAL, NEUTER))
			message_admins("[src] ([ckey]) gender has been changed to plural or neuter. Please record what has happened recently to the person and then notify coders. (<A HREF='?_src_=holder;adminmoreinfo=\ref[src]'>?</A>)  (<A HREF='?_src_=vars;Vars=\ref[src]'>VV</A>) (<A HREF='?priv_msg=\ref[src]'>PM</A>) (<A HREF='?_src_=holder;adminplayerobservejump=\ref[src]'>JMP</A>)")
	*/
	//Apparently, the person who wrote this code designed it so that
	//blinded get reset each cycle and then get activated later in the
	//code. Very ugly. I dont care. Moving this stuff here so its easy
	//to find it.
	blinded = null
	fire_alert = 0 //Reset this here, because both breathe() and handle_environment() have a chance to set it.
	emote_cooldown = max(emote_cooldown - 1, 0)

	//TODO: seperate this out
	// update the current life tick, can be used to e.g. only do something every 4 ticks
	life_tick++
	var/datum/gas_mixture/environment = loc.return_air()

	in_stasis = istype(loc, /obj/structure/closet/body_bag/cryobag) && loc:opened == 0
	if(in_stasis) loc:used++

	//No need to update all of these procs if the guy is dead.
	if(stat != DEAD && !in_stasis)
		if(air_master.current_cycle%4==2 || failed_last_breath) 	//First, resolve location and get a breath
			breathe() 				//Only try to take a breath every 4 ticks, unless suffocating

		else //Still give containing object the chance to interact
			if(istype(loc, /obj/))
				var/obj/location_as_object = loc
				location_as_object.handle_internal_lifeform(src, 0)

		//Updates the number of stored chemicals for powers
		handle_changeling()

		//Mutations and radiation
		handle_mutations_and_radiation()

		//Chemicals in the body
		handle_chemicals_in_body()

		//Disabilities
		handle_disabilities()

		//Random events (vomiting etc)
		handle_random_events()

		handle_virus_updates()

		//stuff in the stomach
		handle_stomach()

		handle_shock()

		handle_pain()

		handle_medical_side_effects()

	handle_stasis_bag()

	//Check if we're on fire
	handle_fire()

	//Handle temperature/pressure differences between body and environment
	handle_environment(environment)

	//Status updates, death etc.
	handle_regular_status_updates()		//TODO: optimise ~Carn
	update_canmove()

	//Update our name based on whether our face is obscured/disfigured
	name = get_visible_name()

	handle_regular_hud_updates()

	pulse = handle_pulse()

	// Grabbing
	for(var/obj/item/weapon/grab/G in src)
		G.process()


/mob/living/carbon/human/calculate_affecting_pressure(var/pressure)
	..()
	var/pressure_difference = abs( pressure - ONE_ATMOSPHERE )

	var/pressure_adjustment_coefficient = 1	//Determins how much the clothing you are wearing protects you in percent.
	if(wear_suit && (wear_suit.flags & STOPSPRESSUREDMAGE))
		pressure_adjustment_coefficient -= PRESSURE_SUIT_REDUCTION_COEFFICIENT
	if(head && (head.flags & STOPSPRESSUREDMAGE))
		pressure_adjustment_coefficient -= PRESSURE_HEAD_REDUCTION_COEFFICIENT
	pressure_adjustment_coefficient = max(pressure_adjustment_coefficient,0) //So it isn't less than 0
	pressure_difference = pressure_difference * pressure_adjustment_coefficient
	if(pressure > ONE_ATMOSPHERE)
		return ONE_ATMOSPHERE + pressure_difference
	else
		return ONE_ATMOSPHERE - pressure_difference

/mob/living/carbon/human

	proc/handle_disabilities()
		if(zombie)
			return
		if (disabilities & EPILEPSY)
			if ((prob(1) && paralysis < 1))
				src << "\red You have a seizure!"
				for(var/mob/O in viewers(src, null))
					if(O == src)
						continue
					O.show_message(text("\red <B>[src] starts having a seizure!"), 1)
				Paralyse(10)
				make_jittery(1000)
		if (disabilities & COUGHING)
			if ((prob(5) && paralysis <= 1))
				drop_item()
				spawn( 0 )
					emote("cough")
					return
		if (disabilities & TOURETTES)
			if ((prob(10) && paralysis <= 1))
				Stun(10)
				spawn( 0 )
					switch(rand(1, 3))
						if(1)
							emote("twitch")
						if(2 to 3)
							say("[prob(50) ? ";" : ""][pick("SHIT", "PISS", "FUCK", "CUNT", "COCKSUCKER", "MOTHERFUCKER", "TITS")]")
					var/old_x = pixel_x
					var/old_y = pixel_y
					pixel_x += rand(-2,2)
					pixel_y += rand(-1,1)
					sleep(2)
					pixel_x = old_x
					pixel_y = old_y
					return
		if (disabilities & NERVOUS)
			if (prob(10))
				stuttering = max(10, stuttering)
		// No. -- cib
		/*if (getBrainLoss() >= 60 && stat != 2)
			if (prob(3))
				switch(pick(1,2,3))
					if(1)
						say(pick("IM A PONY NEEEEEEIIIIIIIIIGH", "without oxigen blob don't evoluate?", "CAPTAINS A COMDOM", "[pick("", "that faggot traitor")] [pick("joerge", "george", "gorge", "gdoruge")] [pick("mellens", "melons", "mwrlins")] is grifing me HAL;P!!!", "can u give me [pick("telikesis","halk","eppilapse")]?", "THe saiyans screwed", "Bi is THE BEST OF BOTH WORLDS>", "I WANNA PET TEH monkeyS", "stop grifing me!!!!", "SOTP IT#"))
					if(2)
						say(pick("FUS RO DAH","fucking 4rries!", "stat me", ">my face", "roll it easy!", "waaaaaagh!!!", "red wonz go fasta", "FOR TEH EMPRAH", "lol2cat", "dem dwarfs man, dem dwarfs", "SPESS MAHREENS", "hwee did eet fhor khayosss", "lifelike texture ;_;", "luv can bloooom", "PACKETS!!!"))
					if(3)
						emote("drool")
		*/

		if(stat != 2)
			var/rn = rand(0, 200)
			if(getBrainLoss() >= 5)
				if(0 <= rn && rn <= 3)
					custom_pain("Your head feels numb and painful.")
			if(getBrainLoss() >= 15)
				if(4 <= rn && rn <= 6) if(eye_blurry <= 0)
					src << "\red It becomes hard to see for some reason."
					eye_blurry = 10
			if(getBrainLoss() >= 35)
				if(7 <= rn && rn <= 9) if(hand && equipped())
					src << "\red Your hand won't respond properly, you drop what you're holding."
					drop_item()
			if(getBrainLoss() >= 50)
				if(10 <= rn && rn <= 12) if(!lying)
					src << "\red Your legs won't respond properly, you fall down."
					resting = 1

	proc/handle_stasis_bag()
		// Handle side effects from stasis bag
		if(in_stasis)
			// First off, there's no oxygen supply, so the mob will slowly take brain damage
			adjustBrainLoss(0.1)

			// Next, the method to induce stasis has some adverse side-effects, manifesting
			// as cloneloss
			adjustCloneLoss(0.1)

	proc/handle_mutations_and_radiation()

		if(zombie)
			druggy = 0
			weakened = 0
			paralysis = 0
			oxyloss = 0
			if(l_hand)
				drop_from_inventory(l_hand)
			if(r_hand)
				drop_from_inventory(r_hand)


		if(getFireLoss())
			if((COLD_RESISTANCE in mutations) || (prob(1)))
				heal_organ_damage(0,1)

		if ((HULK in mutations) && health <= 25)
			mutations.Remove(HULK)
			update_mutations()		//update our mutation overlays
			src << "\red You suddenly feel very weak."
			Weaken(3)
			emote("collapse")

		if (radiation && !zombie)
			if (radiation > 100)
				radiation = 100
				Weaken(10)
				src << "\red You feel weak."
				emote("collapse")

			if (radiation < 0)
				radiation = 0

			else
				if(species.flags & RAD_ABSORB)
					var/rads = radiation/25
					radiation -= rads
					nutrition += rads
					adjustBruteLoss(-(rads))
					adjustOxyLoss(-(rads))
					adjustToxLoss(-(rads))
					updatehealth()
					return

				var/damage = 0
				switch(radiation)
					if(1 to 49)
						radiation--
						if(prob(25))
							adjustToxLoss(1)
							damage = 1
							updatehealth()

					if(50 to 74)
						radiation -= 2
						damage = 1
						adjustToxLoss(1)
						if(prob(5))
							radiation -= 5
							Weaken(3)
							src << "\red You feel weak."
							emote("collapse")
						updatehealth()

					if(75 to 100)
						radiation -= 3
						adjustToxLoss(3)
						damage = 1
						if(prob(1))
							src << "\red You mutate!"
							randmutb(src)
							domutcheck(src,null)
							emote("gasp")
						updatehealth()

				if(damage && organs.len)
					var/datum/organ/external/O = pick(organs)
					if(istype(O)) O.add_autopsy_data("Radiation Poisoning", damage)

	proc/breathe()
		if(reagents.has_reagent("lexorin")) return
		if(istype(loc, /obj/machinery/atmospherics/unary/cryo_cell)) return
		if(species && (species.flags & NO_BREATHE || species.flags & IS_SYNTHETIC)) return

		var/datum/organ/internal/lungs/L = internal_organs["lungs"]
		L.process()

		var/datum/gas_mixture/environment = loc.return_air()
		var/datum/gas_mixture/breath
		// HACK NEED CHANGING LATER
		if(health < config.health_threshold_crit && !zombie)
			losebreath++
		if(losebreath>0) //Suffocating so do not take a breath
			losebreath--
			if (prob(10)) //Gasp per 10 ticks? Sounds about right.
				spawn emote("gasp")
			if(istype(loc, /obj/))
				var/obj/location_as_object = loc
				location_as_object.handle_internal_lifeform(src, 0)
		else
			//First, check for air from internal atmosphere (using an air tank and mask generally)
			breath = get_breath_from_internal(BREATH_VOLUME) // Super hacky -- TLE
			//breath = get_breath_from_internal(0.5) // Manually setting to old BREATH_VOLUME amount -- TLE

			//No breath from internal atmosphere so get breath from location
			if(!breath)
				if(isobj(loc))
					var/obj/location_as_object = loc
					breath = location_as_object.handle_internal_lifeform(src, BREATH_MOLES)
				else if(isturf(loc))
					var/breath_moles = 0
					/*if(environment.return_pressure() > ONE_ATMOSPHERE)
						// Loads of air around (pressure effect will be handled elsewhere), so lets just take a enough to fill our lungs at normal atmos pressure (using n = Pv/RT)
						breath_moles = (ONE_ATMOSPHERE*BREATH_VOLUME/R_IDEAL_GAS_EQUATION*environment.temperature)
					else*/
						// Not enough air around, take a percentage of what's there to model this properly
					breath_moles = environment.total_moles()*BREATH_PERCENTAGE

					breath = loc.remove_air(breath_moles)

					if(istype(wear_mask, /obj/item/clothing/mask/gas))
						var/obj/item/clothing/mask/gas/G = wear_mask
						var/datum/gas_mixture/filtered = new

						filtered.copy_from(breath)
						filtered.toxins *= G.gas_filter_strength
						for(var/datum/gas/gas in filtered.trace_gases)
							gas.moles *= G.gas_filter_strength
						filtered.update_values()
						loc.assume_air(filtered)

						breath.toxins *= 1 - G.gas_filter_strength
						for(var/datum/gas/gas in breath.trace_gases)
							gas.moles *= 1 - G.gas_filter_strength
						breath.update_values()

					if(!is_lung_ruptured())
						if(!breath || breath.total_moles < BREATH_MOLES / 5 || breath.total_moles > BREATH_MOLES * 5)
							if(prob(5))
								rupture_lung()

					// Handle filtering
					var/block = 0
					if(wear_mask)
						if(wear_mask.flags & BLOCK_GAS_SMOKE_EFFECT)
							block = 1
					if(glasses)
						if(glasses.flags & BLOCK_GAS_SMOKE_EFFECT)
							block = 1
					if(head)
						if(head.flags & BLOCK_GAS_SMOKE_EFFECT)
							block = 1

					if(!block)

						for(var/obj/effect/effect/smoke/chem/smoke in view(1, src))
							if(smoke.reagents.total_volume)
								smoke.reagents.reaction(src, INGEST)
								spawn(5)
									if(smoke)
										smoke.reagents.copy_to(src, 10) // I dunno, maybe the reagents enter the blood stream through the lungs?
								break // If they breathe in the nasty stuff once, no need to continue checking

			else //Still give containing object the chance to interact
				if(istype(loc, /obj/))
					var/obj/location_as_object = loc
					location_as_object.handle_internal_lifeform(src, 0)

		handle_breath(breath)

		if(breath)
			loc.assume_air(breath)

			//spread some viruses while we are at it
			if (virus2.len > 0)
				if (get_infection_chance(src) && prob(20))
//					log_debug("[src] : Exhaling some viruses")
					for(var/mob/living/carbon/M in view(1,src))
						src.spread_disease_to(M)


	proc/get_breath_from_internal(volume_needed)
		if(internal)
			if (!contents.Find(internal))
				internal = null
			if (!wear_mask || !(wear_mask.flags & MASKINTERNALS) )
				internal = null
			if(internal)
				return internal.remove_air_volume(volume_needed)
			else if(internals)
				internals.icon_state = "internal0"
		return null


	proc/handle_breath(datum/gas_mixture/breath)
		if(status_flags & GODMODE)
			return

		if(!breath || (breath.total_moles() == 0) || suiciding)
			if(reagents.has_reagent("inaprovaline"))
				return
			if(suiciding)
				adjustOxyLoss(2)//If you are suiciding, you should die a little bit faster
				failed_last_breath = 1
				oxygen_alert = max(oxygen_alert, 1)
				return 0
			if(health > config.health_threshold_crit && !zombie)
				adjustOxyLoss(HUMAN_MAX_OXYLOSS)
				failed_last_breath = 1
			else
				adjustOxyLoss(HUMAN_CRIT_MAX_OXYLOSS)
				failed_last_breath = 1

			oxygen_alert = max(oxygen_alert, 1)

			return 0

		var/safe_oxygen_min = 16 // Minimum safe partial pressure of O2, in kPa
		//var/safe_oxygen_max = 140 // Maximum safe partial pressure of O2, in kPa (Not used for now)
		var/safe_co2_max = 10 // Yes it's an arbitrary value who cares?
		var/safe_toxins_max = 0.005
		var/SA_para_min = 1
		var/SA_sleep_min = 5
		var/oxygen_used = 0
		var/nitrogen_used = 0
		var/breath_pressure = (breath.total_moles()*R_IDEAL_GAS_EQUATION*breath.temperature)/BREATH_VOLUME
		var/vox_oxygen_max = 1 // For vox.

		//Partial pressure of the O2 in our breath
		var/O2_pp = (breath.oxygen/breath.total_moles())*breath_pressure
		// Same, but for the toxins
		var/Toxins_pp = (breath.toxins/breath.total_moles())*breath_pressure
		// And CO2, lets say a PP of more than 10 will be bad (It's a little less really, but eh, being passed out all round aint no fun)
		var/CO2_pp = (breath.carbon_dioxide/breath.total_moles())*breath_pressure // Tweaking to fit the hacky bullshit I've done with atmo -- TLE
		//var/CO2_pp = (breath.carbon_dioxide/breath.total_moles())*0.5 // The default pressure value
		// Nitrogen, for Vox.
		var/Nitrogen_pp = (breath.nitrogen/breath.total_moles())*breath_pressure

		if(O2_pp < safe_oxygen_min && species.name != "Vox") 	// Too little oxygen
			if(prob(20))
				spawn(0) emote("gasp")
			if(O2_pp > 0)
				var/ratio = safe_oxygen_min/O2_pp
				adjustOxyLoss(min(5*ratio, HUMAN_MAX_OXYLOSS)) // Don't fuck them up too fast (space only does HUMAN_MAX_OXYLOSS after all!)
				failed_last_breath = 1
				oxygen_used = breath.oxygen*ratio/6
			else
				adjustOxyLoss(HUMAN_MAX_OXYLOSS)
				failed_last_breath = 1
			oxygen_alert = max(oxygen_alert, 1)
		/*else if (O2_pp > safe_oxygen_max) 		// Too much oxygen (commented this out for now, I'll deal with pressure damage elsewhere I suppose)
			spawn(0) emote("cough")
			var/ratio = O2_pp/safe_oxygen_max
			oxyloss += 5*ratio
			oxygen_used = breath.oxygen*ratio/6
			oxygen_alert = max(oxygen_alert, 1)*/
		else if(Nitrogen_pp < safe_oxygen_min && species.name == "Vox")  //Vox breathe nitrogen, not oxygen.

			if(prob(20))
				spawn(0) emote("gasp")
			if(Nitrogen_pp > 0)
				var/ratio = safe_oxygen_min/Nitrogen_pp
				adjustOxyLoss(min(5*ratio, HUMAN_MAX_OXYLOSS))
				failed_last_breath = 1
				nitrogen_used = breath.nitrogen*ratio/6
			else
				adjustOxyLoss(HUMAN_MAX_OXYLOSS)
				failed_last_breath = 1
			oxygen_alert = max(oxygen_alert, 1)

		else								// We're in safe limits
			failed_last_breath = 0
			adjustOxyLoss(-5)
			oxygen_used = breath.oxygen/6
			oxygen_alert = 0

		breath.oxygen -= oxygen_used
		breath.nitrogen -= nitrogen_used
		breath.carbon_dioxide += oxygen_used

		//CO2 does not affect failed_last_breath. So if there was enough oxygen in the air but too much co2, this will hurt you, but only once per 4 ticks, instead of once per tick.
		if(CO2_pp > safe_co2_max)
			if(!co2overloadtime) // If it's the first breath with too much CO2 in it, lets start a counter, then have them pass out after 12s or so.
				co2overloadtime = world.time
			else if(world.time - co2overloadtime > 120)
				Paralyse(3)
				adjustOxyLoss(3) // Lets hurt em a little, let them know we mean business
				if(world.time - co2overloadtime > 300) // They've been in here 30s now, lets start to kill them for their own good!
					adjustOxyLoss(8)
			if(prob(20)) // Lets give them some chance to know somethings not right though I guess.
				spawn(0) emote("cough")

		else
			co2overloadtime = 0

		if(Toxins_pp > safe_toxins_max) // Too much toxins
			var/ratio = (breath.toxins/safe_toxins_max) * 10
			//adjustToxLoss(clamp2(ratio, MIN_PLASMA_DAMAGE, MAX_PLASMA_DAMAGE))	//Limit amount of damage toxin exposure can do per second
			if(reagents)
				reagents.add_reagent("plasma", clamp2(ratio, MIN_PLASMA_DAMAGE, MAX_PLASMA_DAMAGE))
			toxins_alert = max(toxins_alert, 1)
		else if(O2_pp > vox_oxygen_max && species.name == "Vox") //Oxygen is toxic to vox.
			var/ratio = (breath.oxygen/vox_oxygen_max) * 1000
			adjustToxLoss(clamp2(ratio, MIN_PLASMA_DAMAGE, MAX_PLASMA_DAMAGE))
			toxins_alert = max(toxins_alert, 1)
		else
			toxins_alert = 0

		if(breath.trace_gases.len)	// If there's some other shit in the air lets deal with it here.
			for(var/datum/gas/sleeping_agent/SA in breath.trace_gases)
				var/SA_pp = (SA.moles/breath.total_moles())*breath_pressure
				if(SA_pp > SA_para_min) // Enough to make us paralysed for a bit
					Paralyse(3) // 3 gives them one second to wake up and run away a bit!
					if(SA_pp > SA_sleep_min) // Enough to make us sleep as well
						sleeping = min(sleeping+2, 10)
				else if(SA_pp > 0.15)	// There is sleeping gas in their lungs, but only a little, so give them a bit of a warning
					if(prob(20))
						spawn(0) emote(pick("giggle", "laugh"))
				SA.moles = 0

		if( (abs(310.15 - breath.temperature) > 50) && !(COLD_RESISTANCE in mutations)) // Hot air hurts :(
			if(status_flags & GODMODE)	return 1	//godmode
			if(breath.temperature < species.cold_level_1)
				if(prob(20))
					src << "\red You feel your face freezing and an icicle forming in your lungs!"
			else if(breath.temperature > species.heat_level_1)
				if(prob(20))
					src << "\red You feel your face burning and a searing heat in your lungs!"

			switch(breath.temperature)
				if(-INFINITY to species.cold_level_3)
					apply_damage(COLD_GAS_DAMAGE_LEVEL_3, BURN, "head", used_weapon = "Excessive Cold")
					fire_alert = max(fire_alert, 1)
				if(species.cold_level_3 to species.cold_level_2)
					apply_damage(COLD_GAS_DAMAGE_LEVEL_2, BURN, "head", used_weapon = "Excessive Cold")
					fire_alert = max(fire_alert, 1)
				if(species.cold_level_2 to species.cold_level_1)
					apply_damage(COLD_GAS_DAMAGE_LEVEL_1, BURN, "head", used_weapon = "Excessive Cold")
					fire_alert = max(fire_alert, 1)
				if(species.heat_level_1 to species.heat_level_2)
					apply_damage(HEAT_GAS_DAMAGE_LEVEL_1, BURN, "head", used_weapon = "Excessive Heat")
					fire_alert = max(fire_alert, 2)
				if(species.heat_level_2 to species.heat_level_3)
					apply_damage(HEAT_GAS_DAMAGE_LEVEL_2, BURN, "head", used_weapon = "Excessive Heat")
					fire_alert = max(fire_alert, 2)
				if(species.heat_level_3 to INFINITY)
					apply_damage(HEAT_GAS_DAMAGE_LEVEL_3, BURN, "head", used_weapon = "Excessive Heat")
					fire_alert = max(fire_alert, 2)

		//Temporary fixes to the alerts.

		return 1

	proc/handle_environment(datum/gas_mixture/environment)
		if(!environment)
			return

		var/loc_temp = T0C
		if(istype(loc, /obj/mecha))
			var/obj/mecha/M = loc
			loc_temp =  M.return_temperature()
//		else if(istype(get_turf(src), /turf/space))		//space is not meant to change your body temperature.
		else if(istype(loc, /obj/machinery/atmospherics/unary/cryo_cell))
			loc_temp = loc:air_contents.temperature
		else
			loc_temp = environment.temperature

			//world << "Loc temp: [loc_temp] - Body temp: [bodytemperature] - Fireloss: [getFireLoss()] - Thermal protection: [get_thermal_protection()] - Fire protection: [thermal_protection + add_fire_protection(loc_temp)] - Heat capacity: [environment_heat_capacity] - Location: [loc] - src: [src]"

			//Body temperature is adjusted in two steps. Firstly your body tries to stabilize itself a bit.
		if(stat != 2)
			stabilize_temperature_from_calories()

	//		log_debug("Adjusting to atmosphere.")
			//After then, it reacts to the surrounding atmosphere based on your thermal protection
		if(!on_fire) //If you're on fire, you do not heat up or cool down based on surrounding gases
			if(loc_temp < BODYTEMP_COLD_DAMAGE_LIMIT)			//Place is colder than we are
				var/thermal_protection = get_cold_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
				if(thermal_protection < 1)
					var/amt = min((1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_COLD_DIVISOR), BODYTEMP_COOLING_MAX)
	//				log_debug("[loc_temp] is Cold. Cooling by [amt]")
					bodytemperature += amt
			else if (loc_temp > BODYTEMP_HEAT_DAMAGE_LIMIT)			//Place is hotter than we are
				var/thermal_protection = get_heat_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
				if(thermal_protection < 1)
					var/amt = min((1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_HEAT_DIVISOR), BODYTEMP_HEATING_MAX)
	//				log_debug("[loc_temp] is Heat. Heating up by [amt]")
					bodytemperature += amt

		// +/- 50 degrees from 310.15K is the 'safe' zone, where no damage is dealt.
		if(bodytemperature > BODYTEMP_HEAT_DAMAGE_LIMIT)
			//Body temperature is too hot.
			fire_alert = max(fire_alert, 1)
			if(status_flags & GODMODE)	return 1	//godmode
			switch(bodytemperature)
				if(360 to 400)
					apply_damage(HEAT_DAMAGE_LEVEL_1, BURN, used_weapon = "High Body Temperature")
					fire_alert = max(fire_alert, 2)
				if(400 to 1000)
					if(on_fire)
						apply_damage(HEAT_DAMAGE_LEVEL_3, BURN, used_weapon = "Skin Burns")
						fire_alert = max(fire_alert, 2)
					else
						apply_damage(HEAT_DAMAGE_LEVEL_2, BURN, used_weapon = "High Body Temperature")
						fire_alert = max(fire_alert, 2)
				if(1000 to INFINITY)
					apply_damage(HEAT_DAMAGE_LEVEL_3, BURN, used_weapon = "High Body Temperature")
					fire_alert = max(fire_alert, 2)

		else if(bodytemperature < BODYTEMP_COLD_DAMAGE_LIMIT)
			fire_alert = max(fire_alert, 1)
			if(status_flags & GODMODE)	return 1	//godmode
			if(!istype(loc, /obj/machinery/atmospherics/unary/cryo_cell))
				switch(bodytemperature)
					if(200 to 260)
						apply_damage(COLD_DAMAGE_LEVEL_1, BURN, used_weapon = "Low Body Temperature")
						fire_alert = max(fire_alert, 1)
					if(120 to 200)
						apply_damage(COLD_DAMAGE_LEVEL_2, BURN, used_weapon = "Low Body Temperature")
						fire_alert = max(fire_alert, 1)
					if(-INFINITY to 120)
						apply_damage(COLD_DAMAGE_LEVEL_3, BURN, used_weapon = "Low Body Temperature")
						fire_alert = max(fire_alert, 1)

		// Account for massive pressure differences.  Done by Polymorph
		// Made it possible to actually have something that can protect against high pressure... Done by Errorage. Polymorph now has an axe sticking from his head for his previous hardcoded nonsense!

		var/pressure = environment.return_pressure()
		var/adjusted_pressure = calculate_affecting_pressure(pressure) //Returns how much pressure actually affects the mob.
		if(status_flags & GODMODE)	return 1	//godmode

		if(adjusted_pressure >= species.hazard_high_pressure)
			adjustBruteLoss( min( ( (adjusted_pressure / species.hazard_high_pressure) -1 )*PRESSURE_DAMAGE_COEFFICIENT , MAX_HIGH_PRESSURE_DAMAGE) )
			pressure_alert = 2
		else if(adjusted_pressure >= species.warning_high_pressure)
			pressure_alert = 1
		else if(adjusted_pressure >= species.warning_low_pressure)
			pressure_alert = 0
		else if(adjusted_pressure >= species.hazard_low_pressure)
			pressure_alert = -1

			if(species && species.flags & IS_SYNTHETIC)
				bodytemperature += 0.5 * TEMPERATURE_DAMAGE_COEFFICIENT //Synthetics suffer overheating in a vaccuum. ~Z

		else

			if(species && species.flags & IS_SYNTHETIC)
				bodytemperature += 1 * TEMPERATURE_DAMAGE_COEFFICIENT

			if( !(COLD_RESISTANCE in mutations))
				adjustBruteLoss( LOW_PRESSURE_DAMAGE )
				pressure_alert = -2
			else
				pressure_alert = -1

		if(environment.toxins > MOLES_PLASMA_VISIBLE)
			pl_effects()
		return

///FIRE CODE
	handle_fire()
		if(..())
			return
		var/thermal_protection = get_heat_protection(30000) //If you don't have fire suit level protection, you get a temperature increase
		if((1 - thermal_protection) > 0.0001)
			bodytemperature += BODYTEMP_HEATING_MAX
		return
//END FIRE CODE

	/*
	proc/adjust_body_temperature(current, loc_temp, boost)
		var/temperature = current
		var/difference = abs(current-loc_temp)	//get difference
		var/increments// = difference/10			//find how many increments apart they are
		if(difference > 50)
			increments = difference/5
		else
			increments = difference/10
		var/change = increments*boost	// Get the amount to change by (x per increment)
		var/temp_change
		if(current < loc_temp)
			temperature = min(loc_temp, temperature+change)
		else if(current > loc_temp)
			temperature = max(loc_temp, temperature-change)
		temp_change = (temperature - current)
		return temp_change
	*/

	proc/stabilize_temperature_from_calories()
		var/body_temperature_difference = 310.15 - bodytemperature
		if (abs(body_temperature_difference) < 0.01)
			return //fuck this precision
		switch(bodytemperature)
			if(-INFINITY to 260.15) //260.15 is 310.15 - 50, the temperature where you start to feel effects.
				if(nutrition >= 2) //If we are very, very cold we'll use up quite a bit of nutriment to heat us up.
					nutrition -= 2
				var/recovery_amt = max((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), BODYTEMP_AUTORECOVERY_MINIMUM)
//				log_debug("Cold. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
				bodytemperature += recovery_amt
			if(260.15 to 360.15)
				var/recovery_amt = body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR
//				log_debug("Norm. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
				bodytemperature += recovery_amt
			if(360.15 to INFINITY) //360.15 is 310.15 + 50, the temperature where you start to feel effects.
				//We totally need a sweat system cause it totally makes sense...~
				var/recovery_amt = min((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), -BODYTEMP_AUTORECOVERY_MINIMUM)	//We're dealing with negative numbers
//				log_debug("Hot. Difference = [body_temperature_difference]. Recovering [recovery_amt]")
				bodytemperature += recovery_amt

	//This proc returns a number made up of the flags for body parts which you are protected on. (such as HEAD, UPPER_TORSO, LOWER_TORSO, etc. See setup.dm for the full list)
	proc/get_heat_protection_flags(temperature) //Temperature is the temperature you're being exposed to.
		var/thermal_protection_flags = 0
		//Handle normal clothing
		if(head)
			if(head.max_heat_protection_temperature && head.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= head.heat_protection
		if(wear_suit)
			if(wear_suit.max_heat_protection_temperature && wear_suit.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= wear_suit.heat_protection
		if(w_uniform)
			if(w_uniform.max_heat_protection_temperature && w_uniform.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= w_uniform.heat_protection
		if(shoes)
			if(shoes.max_heat_protection_temperature && shoes.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= shoes.heat_protection
		if(gloves)
			if(gloves.max_heat_protection_temperature && gloves.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= gloves.heat_protection
		if(wear_mask)
			if(wear_mask.max_heat_protection_temperature && wear_mask.max_heat_protection_temperature >= temperature)
				thermal_protection_flags |= wear_mask.heat_protection

		return thermal_protection_flags

	proc/get_heat_protection(temperature) //Temperature is the temperature you're being exposed to.
		var/thermal_protection_flags = get_heat_protection_flags(temperature)

		var/thermal_protection = 0.0
		if(thermal_protection_flags)
			if(thermal_protection_flags & HEAD)
				thermal_protection += THERMAL_PROTECTION_HEAD
			if(thermal_protection_flags & UPPER_TORSO)
				thermal_protection += THERMAL_PROTECTION_UPPER_TORSO
			if(thermal_protection_flags & LOWER_TORSO)
				thermal_protection += THERMAL_PROTECTION_LOWER_TORSO
			if(thermal_protection_flags & LEG_LEFT)
				thermal_protection += THERMAL_PROTECTION_LEG_LEFT
			if(thermal_protection_flags & LEG_RIGHT)
				thermal_protection += THERMAL_PROTECTION_LEG_RIGHT
			if(thermal_protection_flags & FOOT_LEFT)
				thermal_protection += THERMAL_PROTECTION_FOOT_LEFT
			if(thermal_protection_flags & FOOT_RIGHT)
				thermal_protection += THERMAL_PROTECTION_FOOT_RIGHT
			if(thermal_protection_flags & ARM_LEFT)
				thermal_protection += THERMAL_PROTECTION_ARM_LEFT
			if(thermal_protection_flags & ARM_RIGHT)
				thermal_protection += THERMAL_PROTECTION_ARM_RIGHT
			if(thermal_protection_flags & HAND_LEFT)
				thermal_protection += THERMAL_PROTECTION_HAND_LEFT
			if(thermal_protection_flags & HAND_RIGHT)
				thermal_protection += THERMAL_PROTECTION_HAND_RIGHT


		return min(1,thermal_protection)

	//See proc/get_heat_protection_flags(temperature) for the description of this proc.
	proc/get_cold_protection_flags(temperature)
		var/thermal_protection_flags = 0
		//Handle normal clothing

		if(head)
			if(head.min_cold_protection_temperature && head.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= head.cold_protection
		if(wear_suit)
			if(wear_suit.min_cold_protection_temperature && wear_suit.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= wear_suit.cold_protection
		if(w_uniform)
			if(w_uniform.min_cold_protection_temperature && w_uniform.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= w_uniform.cold_protection
		if(shoes)
			if(shoes.min_cold_protection_temperature && shoes.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= shoes.cold_protection
		if(gloves)
			if(gloves.min_cold_protection_temperature && gloves.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= gloves.cold_protection
		if(wear_mask)
			if(wear_mask.min_cold_protection_temperature && wear_mask.min_cold_protection_temperature <= temperature)
				thermal_protection_flags |= wear_mask.cold_protection

		return thermal_protection_flags

	proc/get_cold_protection(temperature)

		if(COLD_RESISTANCE in mutations)
			return 1 //Fully protected from the cold.

		temperature = max(temperature, 2.7) //There is an occasional bug where the temperature is miscalculated in ares with a small amount of gas on them, so this is necessary to ensure that that bug does not affect this calculation. Space's temperature is 2.7K and most suits that are intended to protect against any cold, protect down to 2.0K.
		var/thermal_protection_flags = get_cold_protection_flags(temperature)

		var/thermal_protection = 0.0
		if(thermal_protection_flags)
			if(thermal_protection_flags & HEAD)
				thermal_protection += THERMAL_PROTECTION_HEAD
			if(thermal_protection_flags & UPPER_TORSO)
				thermal_protection += THERMAL_PROTECTION_UPPER_TORSO
			if(thermal_protection_flags & LOWER_TORSO)
				thermal_protection += THERMAL_PROTECTION_LOWER_TORSO
			if(thermal_protection_flags & LEG_LEFT)
				thermal_protection += THERMAL_PROTECTION_LEG_LEFT
			if(thermal_protection_flags & LEG_RIGHT)
				thermal_protection += THERMAL_PROTECTION_LEG_RIGHT
			if(thermal_protection_flags & FOOT_LEFT)
				thermal_protection += THERMAL_PROTECTION_FOOT_LEFT
			if(thermal_protection_flags & FOOT_RIGHT)
				thermal_protection += THERMAL_PROTECTION_FOOT_RIGHT
			if(thermal_protection_flags & ARM_LEFT)
				thermal_protection += THERMAL_PROTECTION_ARM_LEFT
			if(thermal_protection_flags & ARM_RIGHT)
				thermal_protection += THERMAL_PROTECTION_ARM_RIGHT
			if(thermal_protection_flags & HAND_LEFT)
				thermal_protection += THERMAL_PROTECTION_HAND_LEFT
			if(thermal_protection_flags & HAND_RIGHT)
				thermal_protection += THERMAL_PROTECTION_HAND_RIGHT

		return min(1,thermal_protection)

	/*
	proc/add_fire_protection(var/temp)
		var/fire_prot = 0
		if(head)
			if(head.protective_temperature > temp)
				fire_prot += (head.protective_temperature/10)
		if(wear_mask)
			if(wear_mask.protective_temperature > temp)
				fire_prot += (wear_mask.protective_temperature/10)
		if(glasses)
			if(glasses.protective_temperature > temp)
				fire_prot += (glasses.protective_temperature/10)
		if(ears)
			if(ears.protective_temperature > temp)
				fire_prot += (ears.protective_temperature/10)
		if(wear_suit)
			if(wear_suit.protective_temperature > temp)
				fire_prot += (wear_suit.protective_temperature/10)
		if(w_uniform)
			if(w_uniform.protective_temperature > temp)
				fire_prot += (w_uniform.protective_temperature/10)
		if(gloves)
			if(gloves.protective_temperature > temp)
				fire_prot += (gloves.protective_temperature/10)
		if(shoes)
			if(shoes.protective_temperature > temp)
				fire_prot += (shoes.protective_temperature/10)

		return fire_prot

	proc/handle_temperature_damage(body_part, exposed_temperature, exposed_intensity)
		if(nodamage)
			return
		//world <<"body_part = [body_part], exposed_temperature = [exposed_temperature], exposed_intensity = [exposed_intensity]"
		var/discomfort = min(abs(exposed_temperature - bodytemperature)*(exposed_intensity)/2000000, 1.0)

		if(exposed_temperature > bodytemperature)
			discomfort *= 4

		if(mutantrace == "plant")
			discomfort *= TEMPERATURE_DAMAGE_COEFFICIENT * 2 //I don't like magic numbers. I'll make mutantraces a datum with vars sometime later. -- Urist
		else
			discomfort *= TEMPERATURE_DAMAGE_COEFFICIENT //Dangercon 2011 - now with less magic numbers!
		//world <<"[discomfort]"

		switch(body_part)
			if(HEAD)
				apply_damage(2.5*discomfort, BURN, "head")
			if(UPPER_TORSO)
				apply_damage(2.5*discomfort, BURN, "chest")
			if(LEGS)
				apply_damage(0.6*discomfort, BURN, "l_leg")
				apply_damage(0.6*discomfort, BURN, "r_leg")
			if(ARMS)
				apply_damage(0.4*discomfort, BURN, "l_arm")
				apply_damage(0.4*discomfort, BURN, "r_arm")
	*/

	proc/handle_chemicals_in_body()

		if(reagents && !(species.flags & IS_SYNTHETIC)) //Synths don't process reagents.
			var/alien = 0 //Not the best way to handle it, but neater than checking this for every single reagent proc.
			if(species && species.name == "Diona")
				alien = 1
			else if(species && species.name == "Vox")
				alien = 2
			reagents.metabolize(src,alien)

		var/total_plasmaloss = 0
		for(var/obj/item/I in src)
			if(I.contaminated)
				total_plasmaloss += vsc.plc.CONTAMINATION_LOSS
		if(status_flags & GODMODE)	return 0	//godmode
		adjustToxLoss(total_plasmaloss)


		// nutrition decrease
		if (nutrition > 0 && stat != 2)
			nutrition = max (0, nutrition - HUNGER_FACTOR)

		if(species.flags & REQUIRE_LIGHT)
			if(nutrition < 200)
				take_overall_damage(2,0)
				traumatic_shock++

		if (drowsyness)
			drowsyness--
			eye_blurry = max(2, eye_blurry)
			if (prob(5))
				sleeping += 1
				Paralyse(5)

		confused = max(0, confused - 1)
		// decrement dizziness counter, clamped to 0
		if(resting)
			dizziness = max(0, dizziness - 15)
			jitteriness = max(0, jitteriness - 15)
		else
			dizziness = max(0, dizziness - 3)
			jitteriness = max(0, jitteriness - 3)

		if(!(species.flags & IS_SYNTHETIC)) handle_trace_chems()

		var/datum/organ/internal/liver/liver = internal_organs["liver"]
		liver.process()

		var/datum/organ/internal/eyes/eyes = internal_organs["eyes"]
		eyes.process()

		updatehealth()

		return //TODO: DEFERRED

	proc/handle_regular_status_updates()
		if(stat == DEAD)	//DEAD. BROWN BREAD. SWIMMING WITH THE SPESS CARP
			blinded = 1
			silent = 0
		else				//ALIVE. LIGHTS ARE ON
			updatehealth()	//TODO
			if(!in_stasis)
				handle_organs()
				handle_blood()

			if(health <= config.health_threshold_dead || brain_op_stage == 4.0)
				if(!zombie)
					death()
					blinded = 1
					silent = 0
					return 1

			// the analgesic effect wears off slowly
			analgesic = max(0, analgesic - 1)

			//UNCONSCIOUS. NO-ONE IS HOME
			if( (getOxyLoss() > 50) || ((config.health_threshold_crit > health) && (!zombie)) )
				Paralyse(3)

				/* Done by handle_breath()
				if( health <= 20 && prob(1) )
					spawn(0)
						emote("gasp")
				if(!reagents.has_reagent("inaprovaline"))
					adjustOxyLoss(1)*/

			if(hallucination)
				if(hallucination >= 20)
					if(prob(3))
						fake_attack(src)
					if(!handling_hal)
						spawn handle_hallucinations() //The not boring kind!

				if(hallucination<=2)
					hallucination = 0
					halloss = 0
				else
					hallucination -= 2

			else
				for(var/atom/a in hallucinations)
					del a

				if(halloss > 100)
					src << "<span class='notice'>You're in too much pain to keep going...</span>"
					for(var/mob/O in oviewers(src, null))
						O.show_message("<B>[src]</B> slumps to the ground, too weak to continue fighting.", 1)
					Paralyse(10)
					setHalLoss(99)

			if(paralysis)
				AdjustParalysis(-1)
				blinded = 1
				stat = UNCONSCIOUS
				if(halloss > 0)
					adjustHalLoss(-3)
			else if(sleeping)
				handle_dreams()
				adjustHalLoss(-3)
				if (mind)
					if((mind.active && client != null) || immune_to_ssd) //This also checks whether a client is connected, if not, sleep is not reduced.
						sleeping = max(sleeping-1, 0)
				blinded = 1
				stat = UNCONSCIOUS
				if( prob(2) && health && !hal_crit )
					spawn(0)
						emote("snore")
			else if(resting)
				if(halloss > 0)
					adjustHalLoss(-3)
			//CONSCIOUS
			else
				stat = CONSCIOUS
				if(halloss > 0)
					adjustHalLoss(-1)

			//Eyes
			if(sdisabilities & BLIND)	//disabled-blind, doesn't get better on its own
				blinded = 1
			else if(eye_blind)			//blindness, heals slowly over time
				eye_blind = max(eye_blind-1,0)
				blinded = 1
			else if(istype(glasses, /obj/item/clothing/glasses/sunglasses/blindfold))	//resting your eyes with a blindfold heals blurry eyes faster
				eye_blurry = max(eye_blurry-3, 0)
				blinded = 1
			else if(eye_blurry)	//blurry eyes heal slowly
				eye_blurry = max(eye_blurry-1, 0)

			//Ears
			if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
				ear_deaf = max(ear_deaf, 1)
			else if(ear_deaf)			//deafness, heals slowly over time
				ear_deaf = max(ear_deaf-1, 0)
			else if(istype(l_ear, /obj/item/clothing/ears/earmuffs) || istype(r_ear, /obj/item/clothing/ears/earmuffs))	//resting your ears with earmuffs heals ear damage faster
				ear_damage = max(ear_damage-0.15, 0)
				ear_deaf = max(ear_deaf, 1)
			else if(ear_damage < 25)	//ear damage heals slowly under this threshold. otherwise you'll need earmuffs
				ear_damage = max(ear_damage-0.05, 0)

			//Other
			if(stunned)
				AdjustStunned(-1)

			if(weakened)
				weakened = max(weakened-1,0)	//before you get mad Rockdtben: I done this so update_canmove isn't called multiple times

			if(stuttering)
				stuttering = max(stuttering-1, 0)
			if (src.slurring)
				slurring = max(slurring-1, 0)
			if(silent)
				silent = max(silent-1, 0)

			if(druggy)
				druggy = max(druggy-1, 0)

			// Increase germ_level regularly
			if(prob(40))
				germ_level += 1
			// If you're dirty, your gloves will become dirty, too.
			if(gloves && germ_level > gloves.germ_level && prob(10))
				gloves.germ_level += 1
		return 1

	proc/handle_regular_hud_updates()
		if(!client)	return 0

		for(var/image/hud in client.images)
			if(copytext(hud.icon_state,1,4) == "hud") //ugly, but icon comparison is worse, I believe
				client.images.Remove(hud)

		client.screen.Remove(global_hud.blurry, global_hud.druggy, global_hud.vimpaired, global_hud.darkMask, global_hud.g_dither, global_hud.r_dither, global_hud.gray_dither, global_hud.lp_dither)

		update_action_buttons()

		if(damageoverlay.overlays)
			damageoverlay.overlays = list()

		if (rest) rest.icon_state = text("rest[resting]")

		if(stat == UNCONSCIOUS)
			//Critical damage passage overlay
			if(health <= 0)
				var/image/I
				switch(health)
					if(-20 to -10)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage1")
					if(-30 to -20)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage2")
					if(-40 to -30)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage3")
					if(-50 to -40)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage4")
					if(-60 to -50)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage5")
					if(-70 to -60)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage6")
					if(-80 to -70)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage7")
					if(-90 to -80)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage8")
					if(-95 to -90)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage9")
					if(-INFINITY to -95)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "passage10")
				damageoverlay.overlays += I
		else
			//Oxygen damage overlay
			if(oxyloss)
				var/image/I
				switch(oxyloss)
					if(10 to 20)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay1")
					if(20 to 25)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay2")
					if(25 to 30)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay3")
					if(30 to 35)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay4")
					if(35 to 40)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay5")
					if(40 to 45)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay6")
					if(45 to INFINITY)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "oxydamageoverlay7")
				damageoverlay.overlays += I

			//Fire and Brute damage overlay (BSSR)
			var/hurtdamage = src.getBruteLoss() + src.getFireLoss() + damageoverlaytemp
			damageoverlaytemp = 0 // We do this so we can detect if someone hits us or not.
			if(hurtdamage)
				var/image/I
				switch(hurtdamage)
					if(10 to 25)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay1")
					if(25 to 40)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay2")
					if(40 to 55)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay3")
					if(55 to 70)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay4")
					if(70 to 85)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay5")
					if(85 to INFINITY)
						I = image("icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "brutedamageoverlay6")
				damageoverlay.overlays += I

		if( stat == DEAD )
			sight |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
			see_in_dark = 8
			if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO
			if(healths)		healths.icon_state = "health7"	//DEAD healthmeter
/*			if(client)
				if(client.view != world.view)
					if(locate(/obj/item/weapon/gun/energy/sniperrifle, contents))
						var/obj/item/weapon/gun/energy/sniperrifle/s = locate() in src
						if(s.zoom)
							s.zoom()*/

		else
			sight &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
			see_in_dark = species.darksight
			see_invisible = see_in_dark>2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING
			if(dna)
				switch(dna.mutantrace)
					if("slime")
						see_in_dark = 3
						see_invisible = SEE_INVISIBLE_LEVEL_ONE
					if("shadow")
						see_in_dark = 8
						see_invisible = SEE_INVISIBLE_LEVEL_ONE

			if(XRAY in mutations)
				sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
				see_in_dark = 8
				if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO

			if(zombie)
//				if(healths)		healths.icon_state = "health7"	//DEAD healthmeter
				sight |= SEE_MOBS
				see_in_dark = 4

			if(seer==1)
				var/obj/effect/rune/R = locate() in loc
				if(R && R.word1 == cultwords["see"] && R.word2 == cultwords["hell"] && R.word3 == cultwords["join"])
					see_invisible = SEE_INVISIBLE_OBSERVER
				else
					see_invisible = SEE_INVISIBLE_LIVING
					seer = 0

			if(istype(wear_mask, /obj/item/clothing/mask/gas/voice/space_ninja))
				var/obj/item/clothing/mask/gas/voice/space_ninja/O = wear_mask
				switch(O.mode)
					if(0)
						var/target_list[] = list()
						for(var/mob/living/target in oview(src))
							if( target.mind&&(target.mind.special_role||issilicon(target)) )//They need to have a mind.
								target_list += target
						if(target_list.len)//Everything else is handled by the ninja mask proc.
							O.assess_targets(target_list, src)
						if(!druggy)		see_invisible = SEE_INVISIBLE_LIVING
					if(1)
						see_in_dark = 5
						if(!druggy)		see_invisible = SEE_INVISIBLE_LIVING
					if(2)
						sight |= SEE_MOBS
						if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO
					if(3)
						sight |= SEE_TURFS
						if(!druggy)		see_invisible = SEE_INVISIBLE_LIVING

			if(glasses)
				var/obj/item/clothing/glasses/G = glasses
				if(istype(G))
					see_in_dark += G.darkness_view
					if(G.vision_flags)
						sight |= G.vision_flags
						if(!druggy)
							see_invisible = SEE_INVISIBLE_MINIMUM

	/* HUD shit goes here, as long as it doesn't modify sight flags */
	// The purpose of this is to stop xray and w/e from preventing you from using huds -- Love, Doohl

				if(istype(glasses, /obj/item/clothing/glasses/sunglasses/sechud))
					var/obj/item/clothing/glasses/sunglasses/sechud/O = glasses
					if(O.hud)		O.hud.process_hud(src)
					if(!druggy)		see_invisible = SEE_INVISIBLE_LIVING
				else if(istype(glasses, /obj/item/clothing/glasses/hud))
					var/obj/item/clothing/glasses/hud/O = glasses
					O.process_hud(src)
					if(!druggy)
						see_invisible = SEE_INVISIBLE_LIVING

			else if(!seer)
				see_invisible = SEE_INVISIBLE_LIVING

			if(healths)
				if (analgesic)
					healths.icon_state = "health_health_numb"
				else
					switch(hal_screwyhud)
						if(1)	healths.icon_state = "health6"
						if(2)	healths.icon_state = "health7"
						else
							//switch(health - halloss)
							switch(100 - ((species && species.flags & NO_PAIN) ? 0 : traumatic_shock))
								if(100 to INFINITY)		healths.icon_state = "health0"
								if(80 to 100)			healths.icon_state = "health1"
								if(60 to 80)			healths.icon_state = "health2"
								if(40 to 60)			healths.icon_state = "health3"
								if(20 to 40)			healths.icon_state = "health4"
								if(0 to 20)				healths.icon_state = "health5"
								else					healths.icon_state = "health6"
				if(zombie)
					healths.icon_state = "health7"

			if(nutrition_icon)
				switch(nutrition)
					if(450 to INFINITY)				nutrition_icon.icon_state = "nutrition0"
					if(350 to 450)					nutrition_icon.icon_state = "nutrition1"
					if(250 to 350)					nutrition_icon.icon_state = "nutrition2"
					if(150 to 250)					nutrition_icon.icon_state = "nutrition3"
					else							nutrition_icon.icon_state = "nutrition4"

			if(pressure)
				pressure.icon_state = "pressure[pressure_alert]"

			if(pullin)
				if(pulling)								pullin.icon_state = "pull1"
				else									pullin.icon_state = "pull0"
//			if(rest)	//Not used with new UI
//				if(resting || lying || sleeping)		rest.icon_state = "rest1"
//				else									rest.icon_state = "rest0"
			if(toxin)
				if(hal_screwyhud == 4 || toxins_alert)	toxin.icon_state = "tox1"
				else									toxin.icon_state = "tox0"
			if(oxygen)
				if(hal_screwyhud == 3 || oxygen_alert)	oxygen.icon_state = "oxy1"
				else									oxygen.icon_state = "oxy0"
			if(fire)
				if(fire_alert)							fire.icon_state = "fire[fire_alert]" //fire_alert is either 0 if no alert, 1 for cold and 2 for heat.
				else									fire.icon_state = "fire0"

			if(bodytemp)
				switch(bodytemperature) //310.055 optimal body temp
					if(370 to INFINITY)		bodytemp.icon_state = "temp4"
					if(350 to 370)			bodytemp.icon_state = "temp3"
					if(335 to 350)			bodytemp.icon_state = "temp2"
					if(320 to 335)			bodytemp.icon_state = "temp1"
					if(300 to 320)			bodytemp.icon_state = "temp0"
					if(295 to 300)			bodytemp.icon_state = "temp-1"
					if(280 to 295)			bodytemp.icon_state = "temp-2"
					if(260 to 280)			bodytemp.icon_state = "temp-3"
					else					bodytemp.icon_state = "temp-4"

			if(blind)
				if(blinded)		blind.layer = 18
				else			blind.layer = 0

			if(disabilities & NEARSIGHTED)	//this looks meh but saves a lot of memory by not requiring to add var/prescription
				if(glasses)					//to every /obj/item
					var/obj/item/clothing/glasses/G = glasses
					if(!G.prescription)
						client.screen += global_hud.vimpaired
				else
					client.screen += global_hud.vimpaired

			if(eye_blurry)			client.screen += global_hud.blurry
			if(druggy)				client.screen += global_hud.druggy

			var/masked = 0

			if( istype(head, /obj/item/clothing/head/welding) || istype(head, /obj/item/clothing/head/helmet/space/unathi))
				var/obj/item/clothing/head/welding/O = head
				if(!O.up && tinted_weldhelh)
					client.screen += global_hud.darkMask
					masked = 1

			if(!masked && istype(glasses, /obj/item/clothing/glasses/welding) )
				var/obj/item/clothing/glasses/welding/O = glasses
				if(!O.up && tinted_weldhelh)
					client.screen += global_hud.darkMask

			if((istype(wear_mask, /obj/item/clothing/mask/gas) && !istype(wear_mask, /obj/item/clothing/mask/gas/swat) && !istype(wear_mask, /obj/item/clothing/mask/gas/syndicate)) || istype(glasses, /obj/item/clothing/glasses/night))
				client.screen += global_hud.g_dither

			if ((istype(glasses, /obj/item/clothing/glasses/thermal) && !istype(glasses, /obj/item/clothing/glasses/thermal/syndi)) || istype(glasses, /obj/item/clothing/glasses/hud/security) || istype(wear_mask, /obj/item/clothing/mask/gas/swat) || istype(wear_mask, /obj/item/clothing/mask/gas/syndicate))
				client.screen += global_hud.r_dither

			if (istype(glasses, /obj/item/clothing/glasses/sunglasses) || istype(head, /obj/item/clothing/head/helmet/riot))
				client.screen += global_hud.gray_dither

			if (istype(glasses, /obj/item/clothing/glasses/meson) || istype(glasses, /obj/item/clothing/glasses/thermal/syndi))
				client.screen += global_hud.lp_dither


			if(machine)
				if(!machine.check_eye(src))		reset_view(null)
			else
				var/isRemoteObserve = 0
				if((mRemote in mutations) && remoteview_target)
					if(remoteview_target.stat==CONSCIOUS)
						isRemoteObserve = 1
				if(!isRemoteObserve && client && !client.adminobs)
					remoteview_target = null
					reset_view(null)
		return 1

	proc/handle_random_events()
		// Puke if toxloss is too high
		if(!stat)
			if (getToxLoss() >= 45 && nutrition > 20)
				vomit()

		//0.1% chance of playing a scary sound to someone who's in complete darkness
//		if(isturf(loc) && rand(1,1000) == 1)
//			var/turf/currentTurf = loc
//			if(!currentTurf.lighting_lumcount)
//				playsound_local(src,pick(scarySounds),50, 1, -1)

	proc/handle_virus_updates()
		if(status_flags & GODMODE)	return 0	//godmode
		if(bodytemperature > 406)
			for(var/datum/disease/D in viruses)
				D.cure()
			for (var/ID in virus2)
				var/datum/disease2/disease/V = virus2[ID]
				V.cure(src)

		for(var/obj/effect/decal/cleanable/blood/B in view(1,src))
			if(B.virus2.len)
				for (var/ID in B.virus2)
					var/datum/disease2/disease/V = B.virus2[ID]
					infect_virus2(src,V)

		for(var/obj/effect/decal/cleanable/mucus/M in view(1,src))
			if(M.virus2.len)
				for (var/ID in M.virus2)
					var/datum/disease2/disease/V = M.virus2[ID]
					infect_virus2(src,V)

		for (var/ID in virus2)
			var/datum/disease2/disease/V = virus2[ID]
			if(isnull(V)) // Trying to figure out a runtime error that keeps repeating
				CRASH("virus2 nulled before calling activate()")
			else
				V.activate(src)
			// activate may have deleted the virus
			if(!V) continue

			// check if we're immune
			if(V.antigen & src.antibodies)
				V.dead = 1

		return

	proc/handle_stomach()
		spawn(0)
			for(var/mob/living/M in stomach_contents)
				if(M.loc != src)
					stomach_contents.Remove(M)
					continue
				if(istype(M, /mob/living/carbon) && stat != 2)
					if(M.stat == 2)
						M.death(1)
						stomach_contents.Remove(M)
						del(M)
						continue
					if(air_master.current_cycle%3==1)
						if(!(M.status_flags & GODMODE))
							M.adjustBruteLoss(5)
						nutrition += 10

	proc/handle_changeling()
		if(mind && mind.changeling)
			mind.changeling.regenerate()

	handle_shock()
		..()
		if(status_flags & GODMODE)	return 0	//godmode
		if(analgesic || (species && species.flags & NO_PAIN)) return // analgesic avoids all traumatic shock temporarily
		if(zombie) return

		if(health < config.health_threshold_softcrit)// health 0 makes you immediately collapse
			shock_stage = max(shock_stage, 61)

		if(traumatic_shock >= 80)
			shock_stage += 1
		else if(health < config.health_threshold_softcrit)
			shock_stage = max(shock_stage, 61)
		else
			shock_stage = min(shock_stage, 160)
			shock_stage = max(shock_stage-1, 0)
			return

		if(shock_stage == 10)
			src << "<font color='red'><b>"+pick("It hurts so much!", "You really need some painkillers..", "Dear god, the pain!")

		if(shock_stage >= 30)
			if(shock_stage == 30) emote("is having trouble keeping their eyes open.",1)//,"is having trouble keeping their eyes open.")
			eye_blurry = max(2, eye_blurry)
			stuttering = max(stuttering, 5)

		if(shock_stage == 40)
			src << "<font color='red'><b>"+pick("The pain is excrutiating!", "Please, just end the pain!", "Your whole body is going numb!")

		if (shock_stage >= 60)
			if(shock_stage == 60) emote("'s body becomes limp.",1)//,"'s body becomes limp.")
			if (prob(2))
				src << "<font color='red'><b>"+pick("The pain is excrutiating!", "Please, just end the pain!", "Your whole body is going numb!")
				Weaken(20)

		if(shock_stage >= 80)
			if (prob(5))
				src << "<font color='red'><b>"+pick("The pain is excrutiating!", "Please, just end the pain!", "Your whole body is going numb!")
				Weaken(20)

		if(shock_stage >= 120)
			if (prob(2))
				src << "<font color='red'><b>"+pick("You black out!", "You feel like you could die any moment now.", "You're about to lose consciousness.")
				Paralyse(5)

		if(shock_stage == 150)
			emote("can no longer stand, collapsing!",1)//,"can no longer stand, collapsing!")
			Weaken(20)

		if(shock_stage >= 150)
			Weaken(20)

	proc/handle_pulse()

		if(life_tick % 5) return pulse	//update pulse every 5 life ticks (~1 tick/sec, depending on server load)

		if(species && species.flags & NO_BLOOD) return PULSE_NONE //No blood, no pulse.

		if(stat == DEAD)
			return PULSE_NONE	//that's it, you're dead, nothing can influence your pulse

		if(zombie)
			return PULSE_NONE

		var/temp = PULSE_NORM

		if(round(vessel.get_reagent_amount("blood")) <= BLOOD_VOLUME_BAD)	//how much blood do we have
			temp = PULSE_THREADY	//not enough :(

		if(status_flags & FAKEDEATH)
			temp = PULSE_NONE		//pretend that we're dead. unlike actual death, can be inflienced by meds

		for(var/datum/reagent/R in reagents.reagent_list)
			if(R.id in bradycardics)
				if(temp <= PULSE_THREADY && temp >= PULSE_NORM)
					temp--
					break		//one reagent is enough
								//comment out the breaks to make med effects stack
		for(var/datum/reagent/R in reagents.reagent_list)				//handles different chems' influence on pulse
			if(R.id in tachycardics)
				if(temp <= PULSE_FAST && temp >= PULSE_NONE)
					temp++
					break
		for(var/datum/reagent/R in reagents.reagent_list) //To avoid using fakedeath
			if(R.id in heartstopper)
				temp = PULSE_NONE
				break
		for(var/datum/reagent/R in reagents.reagent_list) //Conditional heart-stoppage
			if(R.id in cheartstopper)
				if(R.volume >= R.overdose)
					temp = PULSE_NONE
					break

		return temp


#undef HUMAN_MAX_OXYLOSS
#undef HUMAN_CRIT_MAX_OXYLOSS
