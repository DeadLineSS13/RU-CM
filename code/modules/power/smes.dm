// the SMES
// stores power

#define SMESMAXCHARGELEVEL 250000
#define SMESMAXOUTPUT 250000

/obj/structure/machinery/power/smes
	name = "power storage unit"
	desc = "A high-capacity superconducting magnetic energy storage (SMES) unit."
	icon_state = "smes"
	density = 1
	anchored = 1
	use_power = 0
	directwired = 0
	var/output = 50000		//Amount of power it tries to output
	var/lastout = 0			//Amount of power it actually outputs to the powernet
	var/loaddemand = 0		//For use in restore()
	var/capacity = 5e6		//Maximum amount of power it can hold
	var/charge = 0		//Current amount of power it holds
	var/charging = 0		//1 if it's actually charging, 0 if not
	var/chargemode = 0		//1 if it's trying to charge, 0 if not.
	//var/chargecount = 0
	var/chargelevel = 0		//Amount of power it tries to charge from powernet
	var/online = 1			//1 if it's outputting power, 0 if not.
	var/name_tag = null
	var/obj/structure/machinery/power/terminal/terminal = null
	//Holders for powerout event.
	var/last_output = 0
	var/last_charge = 0
	var/last_online = 0
	var/open_hatch = 0
	var/building_terminal = 0 //Suggestions about how to avoid clickspam building several terminals accepted!
	var/input_level_max = 200000
	var/output_level_max = 200000
	var/should_be_mapped = 0 // If this is set to 0 it will send out warning on New()
	power_machine = TRUE

/obj/structure/machinery/power/smes/Initialize()
	. = ..()
	if(!powernet)
		connect_to_network()

	dir_loop:
		for(var/d in cardinal)
			var/turf/T = get_step(src, d)
			for(var/obj/structure/machinery/power/terminal/term in T)
				if(term && term.dir == turn(d, 180))
					terminal = term
					break dir_loop
	if(!terminal)
		stat |= BROKEN
		return
	terminal.master = src
	if(!terminal.powernet)
		terminal.connect_to_network()
	updateicon()
	start_processing()

	if(!should_be_mapped)
		warning("Non-buildable or Non-magical SMES at [src.x]X [src.y]Y [src.z]Z")

/obj/structure/machinery/power/smes/proc/updateicon()
	overlays.Cut()
	if(stat & BROKEN)	return

	overlays += image('icons/obj/structures/machinery/power.dmi', "smes_op[online]")

	if(charging == 2)
		overlays += image('icons/obj/structures/machinery/power.dmi', "smes_oc2")
	else if (charging == 1)
		overlays += image('icons/obj/structures/machinery/power.dmi', "smes_oc1")
	else
		if(chargemode)
			overlays += image('icons/obj/structures/machinery/power.dmi', "smes_oc0")

	var/clevel = chargedisplay()
	if(clevel>0)
		overlays += image('icons/obj/structures/machinery/power.dmi', "smes_og[clevel]")
	return


/obj/structure/machinery/power/smes/proc/chargedisplay()
	return round(5.5*charge/(capacity ? capacity : 5e6))

#define SMESRATE 0.05			// rate of internal charge to external power


/obj/structure/machinery/power/smes/process()
	if(stat & BROKEN)	return

	//store machine state to see if we need to update the icon overlays
	var/last_disp = chargedisplay()
	var/last_chrg = charging
	var/last_onln = online

	if(terminal)
		//If chargemod is set, try to charge
		//Use charging to let the player know whether we were able to obtain our target load.
		//TODO: Add a meter to tell players how much charge we are actually getting, and only set charging to 0 when we are unable to get any charge at all.
		if(chargemode)
			var/target_load = min((capacity-charge)/SMESRATE, chargelevel)		// charge at set rate, limited to spare capacity
			var/actual_load = add_load(target_load)		// add the load to the terminal side network
			charge += actual_load * SMESRATE	// increase the charge

			if (actual_load >= target_load) // Did we charge at full rate?
				charging = 2
			else if (actual_load) // If not, did we charge at least partially?
				charging = 1
			else // Or not at all?
				charging = 0

	if(online)		// if outputting
		lastout = min( charge/SMESRATE, output)		//limit output to that stored
		charge -= lastout*SMESRATE		// reduce the storage (may be recovered in /restore() if excessive)
		add_avail(lastout)				// add output to powernet (smes side)
		if(charge < 0.0001)
			online = 0					// stop output if charge falls to zero

	// only update icon if state changed
	if(last_disp != chargedisplay() || last_chrg != charging || last_onln != online)
		updateicon()

	return

// called after all power processes are finished
// restores charge level to smes if there was excess this ptick
/obj/structure/machinery/power/smes/proc/restore()
	if(stat & BROKEN)
		return

	if(!online)
		loaddemand = 0
		return

	var/excess = powernet.netexcess		// this was how much wasn't used on the network last ptick, minus any removed by other SMESes

	excess = min(lastout, excess)				// clamp it to how much was actually output by this SMES last ptick

	excess = min((capacity-charge)/SMESRATE, excess)	// for safety, also limit recharge by space capacity of SMES (shouldn't happen)

	// now recharge this amount

	var/clev = chargedisplay()

	charge += excess * SMESRATE
	powernet.netexcess -= excess		// remove the excess from the powernet, so later SMESes don't try to use it

	loaddemand = lastout-excess

	if(clev != chargedisplay() )
		updateicon()
	return

//Will return 1 on failure
/obj/structure/machinery/power/smes/proc/make_terminal(const/mob/user)
	if (user.loc == loc)
		to_chat(user, SPAN_WARNING("You must not be on the same tile as the [src]."))
		return 1

	//Direction the terminal will face to
	var/tempDir = get_dir(user, src)
	switch(tempDir)
		if (NORTHEAST, SOUTHEAST)
			tempDir = EAST
		if (NORTHWEST, SOUTHWEST)
			tempDir = WEST
	var/turf/tempLoc = get_step(src, reverse_direction(tempDir))
	if (istype(tempLoc, /turf/open/space))
		to_chat(user, SPAN_WARNING("You can't build a terminal on space."))
		return 1
	else if (istype(tempLoc))
		if(tempLoc.intact_tile)
			to_chat(user, SPAN_WARNING("You must remove the floor plating first."))
			return 1
	to_chat(user, SPAN_NOTICE("You start adding cable to the [src]."))
	if(do_after(user, 50 * user.get_skill_duration_multiplier(SKILL_ENGINEER), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
		terminal = new /obj/structure/machinery/power/terminal(tempLoc)
		terminal.setDir(tempDir)
		terminal.master = src
		return 0
	return 1


/obj/structure/machinery/power/smes/add_load(var/amount)
	if(terminal && terminal.powernet)
		return terminal.powernet.draw_power(amount)
	return 0

/obj/structure/machinery/power/smes/power_change()
	return

/obj/structure/machinery/power/smes/attack_remote(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/structure/machinery/power/smes/attack_hand(mob/user)
	add_fingerprint(user)
	ui_interact(user)


/obj/structure/machinery/power/smes/attackby(var/obj/item/W as obj, var/mob/user as mob)
	if(HAS_TRAIT(W, TRAIT_TOOL_SCREWDRIVER))
		if(!open_hatch)
			open_hatch = 1
			to_chat(user, SPAN_NOTICE("You open the maintenance hatch of [src]."))
			return 0
		else
			open_hatch = 0
			to_chat(user, SPAN_NOTICE("You close the maintenance hatch of [src]."))
			return 0

	if (!open_hatch)
		to_chat(user, SPAN_WARNING("You need to open access hatch on [src] first!"))
		return 0

	if(istype(W, /obj/item/stack/cable_coil) && !terminal && !building_terminal)
		building_terminal = 1
		var/obj/item/stack/cable_coil/CC = W
		if (CC.get_amount() <= 10)
			to_chat(user, SPAN_WARNING("You need more cables."))
			building_terminal = 0
			return 0
		if (make_terminal(user))
			building_terminal = 0
			return 0
		building_terminal = 0
		CC.use(10)
		user.visible_message(\
				SPAN_NOTICE("[user.name] has added cables to the [src]."),\
				SPAN_NOTICE("You added cables to the [src]."))
		terminal.connect_to_network()
		stat = 0
		return 0

	else if(HAS_TRAIT(W, TRAIT_TOOL_WIRECUTTERS) && terminal && !building_terminal)
		building_terminal = 1
		var/turf/tempTDir = terminal.loc
		if (istype(tempTDir))
			if(tempTDir.intact_tile)
				to_chat(user, SPAN_WARNING("You must remove the floor plating first."))
			else
				to_chat(user, SPAN_NOTICE("You begin to cut the cables..."))
				playsound(get_turf(src), 'sound/items/Deconstruct.ogg', 25, 1)
				if(do_after(user, 50 * user.get_skill_duration_multiplier(SKILL_ENGINEER), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					if (prob(50) && electrocute_mob(usr, terminal.powernet, terminal))
						var/datum/effect_system/spark_spread/s = new /datum/effect_system/spark_spread
						s.set_up(5, 1, src)
						s.start()
						building_terminal = 0
						return 0
					new /obj/item/stack/cable_coil(loc,10)
					user.visible_message(\
						SPAN_NOTICE("[user.name] cut the cables and dismantled the power terminal."),\
						SPAN_NOTICE("You cut the cables and dismantle the power terminal."))
					qdel(terminal)
					terminal = null
		building_terminal = 0
		return 0
	return 1

/obj/structure/machinery/power/smes/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)

	if(stat & BROKEN)
		return

	// this is the data which will be sent to the ui
	var/data[0]
	data["nameTag"] = name_tag
	data["storedCapacity"] = round(100.0*charge/capacity, 0.1)
	data["charging"] = charging
	data["chargeMode"] = chargemode
	data["chargeLevel"] = chargelevel
	data["chargeMax"] = input_level_max
	data["outputOnline"] = online
	data["outputLevel"] = output
	data["outputMax"] = output_level_max
	data["outputLoad"] = round(loaddemand)

	// update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// the ui does not exist, so we'll create a new() one
        // for a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, "smes.tmpl", "SMES Power Storage Unit", 540, 380)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()
		// auto update every Master Controller tick
		ui.set_auto_update(1)


/obj/structure/machinery/power/smes/Topic(href, href_list)
	..()

	if (usr.stat || usr.is_mob_restrained() )
		return
	if (!(istype(usr, /mob/living/carbon/human) || SSticker) && SSticker.mode.name != "monkey")
		if(!isRemoteControlling(usr))
			to_chat(usr, SPAN_DANGER("You don't have the dexterity to do this!"))
			return

	if (!istype(src.loc, /turf) && !istype(usr, /mob/living/silicon/))
		return 0 // Do not update ui

	if( href_list["cmode"] )
		chargemode = !chargemode
		if(!chargemode)
			charging = 0
		updateicon()

	else if( href_list["online"] )
		online = !online
		updateicon()
	else if( href_list["input"] )
		switch( href_list["input"] )
			if("min")
				chargelevel = 0
			if("max")
				chargelevel = input_level_max
			if("set")
				chargelevel = input(usr, "Enter new input level (0-[input_level_max])", "SMES Input Power Control", chargelevel) as num
		chargelevel = max(0, min(input_level_max, chargelevel))	// clamp to range

	else if( href_list["output"] )
		switch( href_list["output"] )
			if("min")
				output = 0
			if("max")
				output = output_level_max
			if("set")
				output = input(usr, "Enter new output level (0-[output_level_max])", "SMES Output Power Control", output) as num
		output = max(0, min(output_level_max, output))	// clamp to range

	investigate_log("input/output; [chargelevel>output?"<font color='green'>":"<font color='red'>"][chargelevel]/[output]</font>|Output-mode: [online?"<font color='green'>on</font>":"<font color='red'>off</font>"]|Input-mode: [chargemode?"<font color='green'>auto</font>":"<font color='red'>off</font>"] by [usr.key]","singulo")

	return 1


/obj/structure/machinery/power/smes/proc/ion_act()
	if(is_ground_level(z))
		if(prob(1)) //explosion
			for(var/mob/M in viewers(src))
				M.show_message(SPAN_DANGER("The [src.name] is making strange noises!"), 3, SPAN_DANGER("You hear sizzling electronics."), 2)
			sleep(10*pick(4,5,6,7,10,14))
			var/datum/effect_system/smoke_spread/smoke = new /datum/effect_system/smoke_spread()
			smoke.set_up(1, 0, src.loc)
			smoke.attach(src)
			smoke.start()
			explosion(src.loc, -1, 0, 1, 3, 1, 0)
			qdel(src)
			return
		if(prob(15)) //Power drain
			var/datum/effect_system/spark_spread/s = new /datum/effect_system/spark_spread
			s.set_up(3, 1, src)
			s.start()
			if(prob(50))
				emp_act(1)
			else
				emp_act(2)
		if(prob(5)) //smoke only
			var/datum/effect_system/smoke_spread/smoke = new /datum/effect_system/smoke_spread()
			smoke.set_up(1, 0, src.loc)
			smoke.attach(src)
			smoke.start()


/obj/structure/machinery/power/smes/emp_act(severity)
	online = 0
	charging = 0
	output = 0
	charge -= 1e6/severity
	if (charge < 0)
		charge = 0
	spawn(100)
		output = initial(output)
		charging = initial(charging)
		online = initial(online)
	..()



/obj/structure/machinery/power/smes/magical
	name = "magical power storage unit"
	desc = "A high-capacity superconducting magnetic energy storage (SMES) unit. Magically produces power."
	capacity = 9000000
	output = 250000
	should_be_mapped = 1

/obj/structure/machinery/power/smes/magical/process()
	charge = 5000000
	..()

/proc/rate_control(var/S, var/V, var/C, var/Min=1, var/Max=5, var/Limit=null)
	var/href = "<A href='?src=\ref[S];rate control=1;[V]"
	var/rate = "[href]=-[Max]'>-</A>[href]=-[Min]'>-</A> [(C?C : 0)] [href]=[Min]'>+</A>[href]=[Max]'>+</A>"
	if(Limit) return "[href]=-[Limit]'>-</A>"+rate+"[href]=[Limit]'>+</A>"
	return rate


#undef SMESRATE
