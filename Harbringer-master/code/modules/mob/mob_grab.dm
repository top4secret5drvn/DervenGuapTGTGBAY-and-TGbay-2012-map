#define UPGRADE_COOLDOWN	40
#define UPGRADE_KILL_TIMER	100

/obj/item/weapon/grab
	name = "grab"
	flags = NOBLUDGEON
	var/obj/screen/grab/hud = null
	var/mob/affecting = null
	var/mob/assailant = null
	var/state = GRAB_PASSIVE

	var/allow_upgrade = 1
	var/last_upgrade = 0

	layer = 21
	abstract = 1
	item_state = "nothing"
	w_class = 5.0


/obj/item/weapon/grab/New(mob/user, mob/victim)
	..()
	loc = user
	assailant = user
	affecting = victim

	if(affecting.anchored)
		del(src)
		return

	hud = new /obj/screen/grab(src)
	hud.icon_state = "reinforce"
	hud.name = "reinforce grab"
	hud.master = src


//Used by throw_2 code to hand over the mob, instead of throw_2ing the grab. The grab is then deleted by the throw_2 code.
/obj/item/weapon/grab/proc/throw_2()
	if(affecting)
		if(affecting.buckled)
			return null
		if(state >= GRAB_AGGRESSIVE)
			return affecting
	return null


//This makes sure that the grab screen object is displayed in the correct hand.
/obj/item/weapon/grab/proc/synch()
	if(affecting)
		if(assailant.r_hand == src)
			if(istype(assailant,/mob/living/carbon/human))
				if(assailant.client.prefs.UI_type == "TG")
					hud.screen_loc = ui_tg_rhand
				else
					hud.screen_loc = ui_rhand
			else if(istype(assailant,/mob/living/carbon/alien))
				hud.screen_loc = ui_id
			else
				hud.screen_loc = ui_rhand
		else
			if(istype(assailant,/mob/living/carbon/human))
				if(assailant.client.prefs.UI_type == "TG")
					hud.screen_loc = ui_tg_lhand
				else
					hud.screen_loc = ui_lhand
			else if(istype(assailant,/mob/living/carbon/alien))
				hud.screen_loc = ui_belt
			else
				hud.screen_loc = ui_lhand


/obj/item/weapon/grab/process()
	confirm()

	if(assailant.client)
		assailant.client.screen -= hud
		assailant.client.screen += hud

	if(assailant.pulling == affecting)
		assailant.stop_pulling()

	if(state <= GRAB_AGGRESSIVE)
		allow_upgrade = 1
		if((assailant.l_hand && assailant.l_hand != src && istype(assailant.l_hand, /obj/item/weapon/grab)))
			var/obj/item/weapon/grab/G = assailant.l_hand
			if(G.affecting != affecting)
				allow_upgrade = 0
		if((assailant.r_hand && assailant.r_hand != src && istype(assailant.r_hand, /obj/item/weapon/grab)))
			var/obj/item/weapon/grab/G = assailant.r_hand
			if(G.affecting != affecting)
				allow_upgrade = 0
		if(state == GRAB_AGGRESSIVE)
			var/h = affecting.hand
			affecting.hand = 0
			affecting.drop_item()
			affecting.hand = 1
			affecting.drop_item()
			affecting.hand = h
			for(var/obj/item/weapon/grab/G in affecting.grabbed_by)
				if(G == src) continue
				if(G.state == GRAB_AGGRESSIVE)
					allow_upgrade = 0
		if(allow_upgrade)
			hud.icon_state = "reinforce"
		else
			hud.icon_state = "!reinforce"
	else
		if(!affecting.buckled)
			affecting.loc = assailant.loc

	if(state >= GRAB_NECK)
		affecting.Stun(5)	//It will hamper your voice, being choked and all.
		if(isliving(affecting))
			var/mob/living/L = affecting
			L.adjustOxyLoss(1)

	if(state >= GRAB_KILL)
		affecting.Weaken(5)	//Should keep you down unless you get help.
		affecting.losebreath = min(affecting.losebreath + 2, 3)


/obj/item/weapon/grab/proc/s_click(obj/screen/S)
	if(!affecting)
		return
	if(state == GRAB_UPGRADING)
		return
	if(assailant.next_move > world.time)
		return
	if(world.time < (last_upgrade + UPGRADE_COOLDOWN))
		return
	if(!assailant.canmove || assailant.lying)
		del(src)
		return

	last_upgrade = world.time

	if(state < GRAB_AGGRESSIVE)
		if(!allow_upgrade)
			return
		assailant.visible_message("<span class='warning'>[assailant] has grabbed [affecting] aggressively (now hands)!</span>")
		state = GRAB_AGGRESSIVE
		icon_state = "grabbed1"
	else
		if(state < GRAB_NECK)
			if(isslime(affecting))
				assailant << "<span class='notice'>You squeeze [affecting], but nothing interesting happens.</span>"
				return

			assailant.visible_message("<span class='warning'>[assailant] has reinforced \his grip on [affecting] (now neck)!</span>")
			state = GRAB_NECK
			icon_state = "grabbed+1"
			if(!affecting.buckled)
				affecting.loc = assailant.loc
			affecting.attack_log += "\[[time_stamp()]\] <font color='orange'>Has had their neck grabbed by [assailant.name] ([assailant.ckey])</font>"
			assailant.attack_log += "\[[time_stamp()]\] <font color='red'>Grabbed the neck of [affecting.name] ([affecting.ckey])</font>"
			log_attack("<font color='red'>[assailant.name] ([assailant.ckey]) grabbed the neck of [affecting.name] ([affecting.ckey])</font>")
			hud.icon_state = "disarm/kill"
			hud.name = "disarm/kill"
		else
			if(state < GRAB_UPGRADING)
				assailant.visible_message("<span class='danger'>[assailant] starts to tighten \his grip on [affecting]'s neck!</span>")
				hud.icon_state = "disarm/kill1"
				state = GRAB_UPGRADING
				if(do_after(assailant, UPGRADE_KILL_TIMER))
					if(state == GRAB_KILL)
						return
					if(!affecting)
						del(src)
						return
					if(!assailant.canmove || assailant.lying)
						del(src)
						return
					state = GRAB_KILL
					assailant.visible_message("<span class='danger'>[assailant] has tightened \his grip on [affecting]'s neck!</span>")
					affecting.attack_log += "\[[time_stamp()]\] <font color='orange'>Has been strangled (kill intent) by [assailant.name] ([assailant.ckey])</font>"
					assailant.attack_log += "\[[time_stamp()]\] <font color='red'>Strangled (kill intent) [affecting.name] ([affecting.ckey])</font>"
					log_attack("<font color='red'>[assailant.name] ([assailant.ckey]) Strangled (kill intent) [affecting.name] ([affecting.ckey])</font>")

					assailant.next_move = world.time + 10
					affecting.losebreath += 1
				else
					assailant.visible_message("<span class='warning'>[assailant] was unable to tighten \his grip on [affecting]'s neck!</span>")
					hud.icon_state = "disarm/kill"
					state = GRAB_NECK


//This is used to make sure the victim hasn't managed to yackety sax away before using the grab.
/obj/item/weapon/grab/proc/confirm()
	if(!assailant || !affecting)
		del(src)
		return 0

	if(affecting)
		if(!isturf(assailant.loc) || ( !isturf(affecting.loc) || assailant.loc != affecting.loc && get_dist(assailant, affecting) > 1) )
			del(src)
			return 0

	return 1


/obj/item/weapon/grab/attack(mob/M, mob/user)
	if(!affecting)
		return

	if(M == affecting)
		s_click(hud)
		return

	if(M == assailant && state >= GRAB_AGGRESSIVE)
		if( (ishuman(user) && (FAT in user.mutations) && ismonkey(affecting) ) || ( isalien(user) && iscarbon(affecting) ) )
			var/mob/living/carbon/attacker = user
			user.visible_message("<span class='danger'>[user] is attempting to devour [affecting]!</span>")
			if(istype(user, /mob/living/carbon/alien/humanoid/hunter))
				if(!do_mob(user, affecting)||!do_after(user, 30)) return
			else
				if(!do_mob(user, affecting)||!do_after(user, 100)) return
			user.visible_message("<span class='danger'>[user] devours [affecting]!</span>")
			affecting.loc = user
			attacker.stomach_contents.Add(affecting)
			del(src)


/obj/item/weapon/grab/dropped()
	del(src)

/obj/item/weapon/grab/Del()
	del(hud)
	..()
