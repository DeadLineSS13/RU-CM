SUBSYSTEM_DEF(xenocon)
	name = "XENOCON"
	wait = 5 SECONDS
	priority = SS_PRIORITY_INACTIVITY
	flags = SS_NO_INIT
	var/rewarded = FALSE

/datum/controller/subsystem/xenocon/fire(resumed = FALSE)
	if(rewarded)
		return

	var/datum/hive_status/hive
	for(var/hivenumber in GLOB.hive_datum)
		hive = GLOB.hive_datum[hivenumber]
		if(hive.xenocon_points >= XENOCON_THRESHOLD)
			var/datum/emergency_call/em_call = new /datum/emergency_call/xenos/platoon()
			em_call.activate()
			rewarded = TRUE
