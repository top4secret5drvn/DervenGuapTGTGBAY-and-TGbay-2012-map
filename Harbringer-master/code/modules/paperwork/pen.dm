/* Pens!
 * Contains:
 *		Pens
 *		Sleepy Pens
 *		Parapens
 */


/*
 * Pens
 */
/obj/item/weapon/pen
	desc = "It's a normal black ink pen."
	name = "pen"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "pen"
	item_state = "pen"
	flags = FPRINT | TABLEPASS
	slot_flags = SLOT_BELT | SLOT_EARS
	throw_2force = 0
	w_class = 1.0
	throw_2_speed = 7
	throw_2_range = 15
	m_amt = 10
	var/colour = "black"	//what colour the ink is!
	pressure_resistance = 2


/obj/item/weapon/pen/blue
	desc = "It's a normal blue ink pen."
	icon_state = "pen_blue"
	colour = "blue"

/obj/item/weapon/pen/red
	desc = "It's a normal red ink pen."
	icon_state = "pen_red"
	colour = "red"

/obj/item/weapon/pen/invisible
	desc = "It's an invisble pen marker."
	icon_state = "pen"
	colour = "white"


/obj/item/weapon/pen/attack(mob/M as mob, mob/user as mob)
	if(!ismob(M))
		return
	if(user.zone_sel.selecting != "eyes" && user.zone_sel.selecting != "head")
		if((CLUMSY in user.mutations) && prob(50))
			M = user
	return eyestab(M,user)
	user << "<span class='warning'>You stab [M] with the pen.</span>"
//	M << "\red You feel a tiny prick!" //That's a whole lot of meta!
	M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been stabbed with [name]  by [user.name] ([user.ckey])</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Used the [name] to stab [M.name] ([M.ckey])</font>")
	msg_admin_attack("[user.name] ([user.ckey]) Used the [name] to stab [M.name] ([M.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
	return


/*
 * Sleepy Pens
 */
/obj/item/weapon/pen/sleepypen
	desc = "It's a black ink pen with a sharp point and a carefully engraved \"Waffle Co.\""
	flags = FPRINT | TABLEPASS | OPENCONTAINER
	origin_tech = "materials=2;syndicate=5"


/obj/item/weapon/pen/sleepypen/New()
	var/datum/reagents/R = new/datum/reagents(30) //Used to be 300
	reagents = R
	R.my_atom = src
	R.add_reagent("chloralhydrate", 22)	//Used to be 100 sleep toxin//30 Chloral seems to be fatal, reducing it to 22./N
	..()
	return


/obj/item/weapon/pen/sleepypen/attack(mob/M as mob, mob/user as mob)
	if(!(istype(M,/mob)))
		return
	..()
	if(reagents.total_volume)
		if(M.reagents) reagents.trans_to(M, 50) //used to be 150
	return


/*
 * Parapens
 */
 /obj/item/weapon/pen/paralysis
 	desc = "It's a black ink pen with a sharp point and a carefully engraved \"Waffle Co.\""
	flags = FPRINT | TABLEPASS | OPENCONTAINER
	origin_tech = "materials=2;syndicate=5"


/obj/item/weapon/pen/paralysis/attack(mob/M as mob, mob/user as mob)
	if(!(istype(M,/mob)))
		return
	..()
	if(reagents.total_volume)
		if(M.reagents) reagents.trans_to(M, 50)
	return


/obj/item/weapon/pen/paralysis/New()
	var/datum/reagents/R = new/datum/reagents(50)
	reagents = R
	R.my_atom = src
	R.add_reagent("zombiepowder", 10)
	R.add_reagent("impedrezene", 25)
	R.add_reagent("cryptobiolin", 15)
	..()
	return