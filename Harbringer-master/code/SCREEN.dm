mob/proc
	mapgrab(list/l,scale=10) // list/l is something similar to view(), range(), oview(), or orange(); if there is no list, then it will be assumed
							 // 	that we are checking for the entire world on the user's z-level.
							 // scale is the scale of the map. This can be anything from 1 to anything;
							 // 	However, scale should be noted that it creates a 32x32 icon multiplied by width and height, and then each by scale.
							 //		So, a scale of 1 would create a 32x32 icon, 10 would be 320x320, etc.
		var/icon/newIcon = new ('icon_blank.dmi') // create the blank icon. this icon file is necessary for the program to work.
		if(l) // if there is a list
			var/minx=src.x // define the minimum x, y and maximum x, y
			var/miny=src.y
			var/maxx=src.x
			var/maxy=src.y
			for(var/turf/map in l)
				if(map.x <= minx)
					minx = map.x // if the turfs x is lower than the minx, make it the new minx (same concept applies for the rest of this section
				else
					if(map.x >= maxx)
						maxx = map.x
				if(map.y <= miny)
					miny = map.y
				else
					if(map.y >= maxy)
						maxy = map.y
			newIcon.Scale((maxx-minx+1)*scale,(maxy-miny+1)*scale) // scale it accordingly; basically, find the width/height and add 1
																					   // 	(in case the width would equal 0)
			for(var/turf/map in l) // check every turf in view(), range(), etc.
				var/icon/tempIcon = new (icon(map.icon,map.icon_state)) // create a temporary icon of the atom
				tempIcon.Scale(scale,scale) // Scale it accordingly // scale it
				newIcon.Blend(tempIcon,ICON_OVERLAY,(((map.x*scale)-(minx*scale)+1)),(((map.y*scale)-(miny*scale)+1))) // Blend our blank icon with the information from
				for(var/atom/atomMap in map)
					var/icon/tempIconAtom = new (icon(atomMap.icon,atomMap.icon_state,dir=atomMap.dir)) // create a temporary icon of the atom
					tempIconAtom.Scale(scale,scale) // Scale it accordingly
					newIcon.Blend(tempIconAtom,ICON_OVERLAY,(((map.x*scale)-(minx*scale)+1)),(((map.y*scale)-(miny*scale)+1)))
		else
			newIcon.Scale(world.maxx*scale,world.maxy*scale)
			for(var/turf/map in block(locate(1,1,src.z),locate(world.maxx,world.maxy,src.z)))
				var/icon/tempIcon = new (icon(map.icon,map.icon_state)) // create a temporary icon of the atom
				tempIcon.Scale(scale,scale) // Scale it accordingly
				newIcon.Blend(tempIcon,ICON_OVERLAY,((map.x*scale)-(1*scale)+1),((map.y*scale)-(1*scale)+1))
				for(var/atom/atomMap in map)
					var/icon/tempIconAtom = new (icon(atomMap.icon,atomMap.icon_state,dir=atomMap.dir)) // create a temporary icon of the atom
					tempIconAtom.Scale(scale,scale) // Scale it accordingly
					newIcon.Blend(tempIconAtom,ICON_OVERLAY,((map.x*scale)-(1*scale)+1),((map.y*scale)-(1*scale)+1))
		return newIcon


mob
	icon='mob.dmi'
	verb
		// You may actually want to use these in your game.
		Screenshot()
			var/icon/screenshot = new(src.mapgrab(range(src.client))) // This will grab all the information the player can see.
																	  // I used range() to get past opacity in some previous testing, though you can easily substitute with
																	  // view(), oview(), orange(), etc. As well, you can do something like view(6,src) if you desire! :)
			src << browse_rsc(screenshot,"Icon")
			src << browse("<img src=Icon>")
		Minimap()
			var/icon/minimap = new(src.mapgrab()) // When you don't put in any arguments, it takes the entire map on the players z-level
												  // Note: You can modify scale here by doing the following argument; src.mapgrab(scale=#)
			src << browse_rsc(minimap,"Icon")
			src << browse("<img src=Icon>")

