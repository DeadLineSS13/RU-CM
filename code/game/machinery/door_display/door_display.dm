///////////////////////////////////////////////////////////////////////////////////////////////
//  Parent of all door displays.
//  Description: This is a controls the timer for the brig doors, displays the timer on itself and
//               has a popup window when used, allowing to set the timer.
//  Code Notes: Combination of old brigdoor.dm code from rev4407 and the status_display.dm code
//  Date: 01/September/2010
//  Programmer: Veryinky
/////////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/machinery/door_display
	name = "Door Display"
	icon = 'icons/obj/structures/machinery/status_display.dmi'
	icon_state = "frame"
	desc = "A remote control for a door."
	anchored = 1.0    		// can't pick it up
	density = 0       		// can walk through it.
	var/open = 0			// If door should be open.
	var/id = null     		// id of door it controls.
	var/picture_state		// icon_state of alert picture, if not displaying text/numbers
	var/list/obj/structure/machinery/targets = list()

	maptext_height = 26
	maptext_width = 32

/obj/structure/machinery/door_display/Initialize()
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/structure/machinery/door_display/LateInitialize()
	. = ..()
	get_targets()

/obj/structure/machinery/door_display/proc/get_targets()
	for(var/obj/structure/machinery/door/D in machines)
		if (D.id == id)
			targets += D

	if(targets.len == 0)
		stat |= BROKEN
	update_icon()


// has the door power situation changed, if so update icon.
/obj/structure/machinery/door_display/power_change()
	..()
	update_icon()
	return


// open/closedoor checks if door_display has power, if so it checks if the
// linked door is open/closed (by density) then opens it/closes it.

// Opens and locks doors, power check
/obj/structure/machinery/door_display/proc/open_door()
	if(inoperable())	return 0

	for(var/obj/structure/machinery/door/D in targets)
		if(!D.density)	continue
		INVOKE_ASYNC(D, /obj/structure/machinery/door.proc/open)

	return 1


// Closes and unlocks doors, power check
/obj/structure/machinery/door_display/proc/close_door()
	if(inoperable())	return 0

	for(var/obj/structure/machinery/door/D in targets)
		if(D.density)	continue
		INVOKE_ASYNC(D, /obj/structure/machinery/door.proc/close)

	return 1

// Allows AIs to use door_display, see human attack_hand function below
/obj/structure/machinery/door_display/attack_remote(var/mob/user as mob)
	return attack_hand(user)


// Allows humans to use door_display
// Opens dialog window when someone clicks on door timer
// Allows altering timer and the timing boolean.
/obj/structure/machinery/door_display/attack_hand(var/mob/user as mob)
	if(..())
		return

	user.set_interaction(src)

	show_browser(user, display_contents(user), name, "computer", "size=400x500")
	return

/obj/structure/machinery/door_display/proc/display_contents(var/mob/user as mob)
	var/data = "<HTML><BODY><TT>"

	data += "<HR>Linked Door:</hr>"
	data += " <b> [id]</b><br/>"

	// Open/Close Door
	if (open)
		data += "<a href='?src=\ref[src];open=0'>Close Door</a><br/>"
	else
		data += "<a href='?src=\ref[src];open=1'>Open Door</a><br/>"

	data += "<br/>"

	data += "<br/><a href='?src=\ref[user];mach_close=computer'>Close Display</a>"
	data += "</TT></BODY></HTML>"

	return data

// Function for using door_data dialog input, checks if user has permission
// href_list to
//  "open" open/close door
// Also updates dialog window and display icon.
/obj/structure/machinery/door_display/Topic(href, href_list)
	if(..())
		return 0
	if(!allowed(usr))
		return 0

	usr.set_interaction(src)

	if(href_list["open"])
		open = text2num(href_list["open"])

		if (open)
			open_door()
		else
			close_door()

	src.add_fingerprint(usr)
	src.updateUsrDialog()
	src.update_icon()

	return 1


//icon update function
// if NOPOWER, display blank
// if BROKEN, display blue screen of death icon AI uses
/obj/structure/machinery/door_display/update_icon()
	if (stat & (NOPOWER))
		icon_state = "frame"
		return
	if (stat & (BROKEN))
		set_picture("ai_bsod")
		return

	var/display
	if (open)
		display = "OPEN"
	else
		display = "CLOSED"

	update_display(display)
	return


// Adds an icon in case the screen is broken/off, stolen from status_display.dm
/obj/structure/machinery/door_display/proc/set_picture(var/state)
	picture_state = state
	overlays.Cut()
	overlays += image('icons/obj/structures/machinery/status_display.dmi', icon_state = picture_state)


//Checks to see if there's 1 line or 2, adds text-icons-numbers/letters over display
// Stolen from status_display
/obj/structure/machinery/door_display/proc/update_display(var/text)
	var/new_text = {"<div style="font-size:'5pt'; color:'#09f'; font:'Arial Black'; text-align:center;" valign="top">[text]</div>"}
	if(maptext != new_text)
		maptext = new_text


//Actual string input to icon display for loop, with 5 pixel x offsets for each letter.
//Stolen from status_display
/obj/structure/machinery/door_display/proc/texticon(var/tn, var/px = 0, var/py = 0)
	var/image/I = image('icons/obj/structures/machinery/status_display.dmi', "blank")
	var/len = length(tn)

	for(var/d = 1 to len)
		var/char = copytext(tn, len-d+1, len-d+2)
		if(char == " ")
			continue
		var/image/ID = image('icons/obj/structures/machinery/status_display.dmi', icon_state = char)
		ID.pixel_x = -(d - 1) * 5 + px
		ID.pixel_y = py
		I.overlays += ID
	return I

//************ RESEARCH DOORS ****************\\
// Research cells have flashers and shutters/pod doors.
/obj/structure/machinery/door_display/research_cell
	var/open_shutter = 0
	var/has_wall_divider = FALSE
	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "research"
	maptext = ""
	req_access = list(ACCESS_MARINE_RESEARCH)

/obj/structure/machinery/door_display/research_cell/get_targets()
	..()
	for(var/obj/structure/machinery/flasher/F in machines)
		if(F.id == id)
			targets += F
	if(has_wall_divider)
		for(var/turf/closed/wall/almayer/research/containment/wall/divide/W in orange(src, 8))
			targets += W

/obj/structure/machinery/door_display/research_cell/Destroy()
	//Opening doors and shutters
	ion_act()
	return ..()

/obj/structure/machinery/door_display/research_cell/proc/ion_act()
	//Open the doors up to let the xenos out
	//Otherwise there isn't a way to get them out
	//And they deserve a rampage after being locked up for so long
	open_shutter(TRUE)
	open_door(TRUE)

/obj/structure/machinery/door_display/update_icon()
	return

/obj/structure/machinery/door_display/research_cell/display_contents(var/mob/user as mob)
	var/data = "<HTML><BODY><TT>"

	data += "<HR>Linked Door:</hr>"
	data += " <b> [id]</b><br/>"
	data += "<br/>"

	// Open/Close Shutter
	if(open_shutter)
		data += "<a href='?src=\ref[src];shutter=0; open=0'>Close Shutter</a><br/>"
	else
		data += "<a href='?src=\ref[src];shutter=1'>Open Shutter</a><br/>"

	// Open/Close Door
	if(open_shutter)
		if (open)
			data += "<a href='?src=\ref[src];open=0'>Close Door</a><br/>"
		else
			data += "<a href='?src=\ref[src];open=1'>Open Door</a><br/>"

	data += "<br/>"

	// Mounted flash controls
	for(var/obj/structure/machinery/flasher/F in targets)
		if(F.last_flash && (F.last_flash + 150) > world.time)
			data += "<br/><A href='?src=\ref[src];fc=1'>Flash Charging</A>"
		else
			data += "<br/><A href='?src=\ref[src];fc=1'>Activate Flash</A>"

	data += "<br/>"

	//Room Divider
	if(has_wall_divider)
		data += "<br/><A href='?src=\ref[src];divider=1'>Containment Divider</A><br/>"

	data += "<br/><a href='?src=\ref[user];mach_close=computer'>Close Display</a>"
	data += "</TT></BODY></HTML>"

	return data

// "fc" activates flasher
// "shutter" opens/closes the shutter.

/obj/structure/machinery/door_display/research_cell/Topic(href, href_list)
	if(!..())
		return 0

	if(href_list["fc"])
		for(var/obj/structure/machinery/flasher/F in targets)
			F.flash()

	if(href_list["divider"])
		for(var/turf/closed/wall/almayer/research/containment/wall/divide/W in targets)
			if(W.density)
				W.open()
			else
				W.close()
			playsound(loc, 'sound/machines/elevator_openclose.ogg', 25, 1)

	if(href_list["shutter"])
		open_shutter = text2num(href_list["shutter"])
		open = text2num(href_list["open"])

		if(open_shutter)
			open_shutter()
		else
			close_door()
			close_shutter()

	add_fingerprint(usr)
	updateUsrDialog()

	return 1


// Opens and locks doors, power check
/obj/structure/machinery/door_display/research_cell/open_door(var/force = FALSE)
	if(inoperable() && !force)	return 0

	for(var/obj/structure/machinery/door/airlock/D in targets)
		if(!D.density) continue
		spawn(0)
			D.unlock(force)
			D.open(force)

	return 1

// Closes and unlocks doors, power check
/obj/structure/machinery/door_display/research_cell/close_door()
	if(inoperable())	return 0

	for(var/obj/structure/machinery/door/airlock/D in targets)
		if(D.density)	continue
		spawn(0)
			D.close()
			D.lock()

	return 1

// Opens and locks doors, power check
/obj/structure/machinery/door_display/research_cell/proc/open_shutter(var/force = FALSE)
	if(inoperable() && !force)	return 0

	for(var/obj/structure/machinery/door/poddoor/D in targets)
		if(D.stat & BROKEN) continue
		if(!D.density) continue
		INVOKE_ASYNC(D, /obj/structure/machinery/door.proc/open)

	return 1

// Closes and unlocks doors, power check
/obj/structure/machinery/door_display/research_cell/proc/close_shutter()
	if(inoperable())	return 0

	for(var/obj/structure/machinery/door/poddoor/D in targets)
		if(D.stat & BROKEN) continue
		if(D.density)	continue
		INVOKE_ASYNC(D, /obj/structure/machinery/door.proc/close)

	return 1
