/obj/item/projectile/forcebolt
	name = "force bolt"
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "ice_1"
	damage = 20
	flag = "energy"
	embed = 1

/obj/item/projectile/forcebolt/strong
	name = "force bolt"

/obj/item/projectile/forcebolt/on_hit(var/atom/target, var/blocked = 0)

	var/obj/T = target
	var/throw_2dir = get_dir(firer,target)
	T.throw_2_at(get_edge_target_turf(target, throw_2dir),10,10)
	return 1

/*
/obj/item/projectile/forcebolt/strong/on_hit(var/atom/target, var/blocked = 0)

	// NONE OF THIS WORKS. DO NOT USE.
	var/throw_2dir = null

	for(var/mob/M in hearers(2, src))
		if(M.loc != src.loc)
			throw_2dir = get_dir(src,target)
			M.throw_2_at(get_edge_target_turf(M, throw_2dir),15,1)
	return ..()
*/