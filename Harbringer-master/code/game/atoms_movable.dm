/atom/movable
	layer = 3
	var/last_move = null
	var/anchored = 0
	// var/elevation = 2    - not used anywhere
	var/move_speed = 10
	var/l_move_time = 1
	var/m_flag = 1
	var/throw_2ing = 0
	var/throw_2_speed = 2
	var/throw_2_range = 7
	var/moved_recently = 0
	var/mob/pulledby = null

/atom/movable/Move()
	var/atom/A = src.loc
	. = ..()
	src.move_speed = world.timeofday - src.l_move_time
	src.l_move_time = world.timeofday
	src.m_flag = 1
	if ((A != src.loc && A && A.z == src.z))
		src.last_move = get_dir(A, src.loc)
	return

/atom/movable/Bump(var/atom/A as mob|obj|turf|area, yes)
	if(src.throw_2ing)
		src.throw_2_impact(A)
		src.throw_2ing = 0

	spawn( 0 )
		if ((A && yes))
			A.last_bumped = world.time
			A.Bumped(src)
		return
	..()
	return

/atom/movable/proc/forceMove(atom/destination)
	if(destination)
		if(loc)
			loc.Exited(src)
		loc = destination
		loc.Entered(src)
		return 1
	return 0

/atom/movable/proc/hit_check(var/speed)
	if(src.throw_2ing)
		for(var/atom/A in get_turf(src))
			if(A == src) continue
			if(istype(A,/mob/living))
				if(A:lying) continue
				src.throw_2_impact(A,speed)
				if(src.throw_2ing == 1)
					src.throw_2ing = 0
			if(isobj(A))
				if(A.density && !A.throw_2pass)	// **TODO: Better behaviour for windows which are dense, but shouldn't always stop movement
					src.throw_2_impact(A,speed)
					src.throw_2ing = 0

/atom/movable/proc/throw_2_at(atom/target, range, speed)
	if(!target || !src)	return 0
	//use a modified version of Bresenham's algorithm to get from the atom's current position to that of the target

	src.throw_2ing = 1

	if(usr)
		if(HULK in usr.mutations)
			src.throw_2ing = 2 // really strong throw_2!

	var/dist_x = abs(target.x - src.x)
	var/dist_y = abs(target.y - src.y)

	var/dx
	if (target.x > src.x)
		dx = EAST
	else
		dx = WEST

	var/dy
	if (target.y > src.y)
		dy = NORTH
	else
		dy = SOUTH
	var/dist_travelled = 0
	var/dist_since_sleep = 0
	var/area/a = get_area(src.loc)
	if(dist_x > dist_y)
		var/error = dist_x/2 - dist_y



		while(src && target &&((((src.x < target.x && dx == EAST) || (src.x > target.x && dx == WEST)) && dist_travelled < range) || (a && a.has_gravity == 0)  || istype(src.loc, /turf/space)) && src.throw_2ing && istype(src.loc, /turf))
			// only stop when we've gone the whole distance (or max throw_2 range) and are on a non-space tile, or hit something, or hit the end of the map, or someone picks it up
			if(error < 0)
				var/atom/step = get_step(src, dy)
				if(!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
					break
				src.Move(step)
				hit_check(speed)
				error += dist_x
				dist_travelled++
				dist_since_sleep++
				if(dist_since_sleep >= speed)
					dist_since_sleep = 0
					sleep(1)
			else
				var/atom/step = get_step(src, dx)
				if(!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
					break
				src.Move(step)
				hit_check(speed)
				error -= dist_y
				dist_travelled++
				dist_since_sleep++
				if(dist_since_sleep >= speed)
					dist_since_sleep = 0
					sleep(1)
			a = get_area(src.loc)
	else
		var/error = dist_y/2 - dist_x
		while(src && target &&((((src.y < target.y && dy == NORTH) || (src.y > target.y && dy == SOUTH)) && dist_travelled < range) || (a.has_gravity == 0)  || istype(src.loc, /turf/space)) && src.throw_2ing && istype(src.loc, /turf))
			// only stop when we've gone the whole distance (or max throw_2 range) and are on a non-space tile, or hit something, or hit the end of the map, or someone picks it up
			if(error < 0)
				var/atom/step = get_step(src, dx)
				if(!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
					break
				src.Move(step)
				hit_check(speed)
				error += dist_y
				dist_travelled++
				dist_since_sleep++
				if(dist_since_sleep >= speed)
					dist_since_sleep = 0
					sleep(1)
			else
				var/atom/step = get_step(src, dy)
				if(!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
					break
				src.Move(step)
				hit_check(speed)
				error -= dist_x
				dist_travelled++
				dist_since_sleep++
				if(dist_since_sleep >= speed)
					dist_since_sleep = 0
					sleep(1)

			a = get_area(src.loc)

	//done throw_2ing, either because it hit something or it finished moving
	src.throw_2ing = 0
	if(isobj(src)) src.throw_2_impact(get_turf(src),speed)


//Overlays
/atom/movable/overlay
	var/atom/master = null
	anchored = 1

/atom/movable/overlay/New()
	for(var/x in src.verbs)
		src.verbs -= x
	return

/atom/movable/overlay/attackby(a, b)
	if (src.master)
		return src.master.attackby(a, b)
	return

/atom/movable/overlay/attack_paw(a, b, c)
	if (src.master)
		return src.master.attack_paw(a, b, c)
	return

/atom/movable/overlay/attack_hand(a, b, c)
	if (src.master)
		return src.master.attack_hand(a, b, c)
	return