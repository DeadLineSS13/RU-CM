/mob/living/silicon/robot/dust()
	//Delete the MMI first so that it won't go popping out.
	QDEL_NULL(mmi)
	..()

/mob/living/silicon/robot/death(cause, gibbed)
	if(camera)
		camera.status = 0
	if(module)
		var/obj/item/device/gripper/G = locate(/obj/item/device/gripper) in module
		if(G) G.drop_item()
	remove_robot_verbs()
	..(gibbed,"is destroyed!")
	playsound(src.loc, 'sound/effects/metal_crash.ogg', 100)
	robogibs(src)
	qdel(src)
