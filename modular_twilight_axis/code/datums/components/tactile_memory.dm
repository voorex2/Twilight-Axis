/datum/component/tactile_memory
	var/next_probe = 0
	var/list/impressions = list()
	var/list/expiry_times = list()
	var/client/viewer
	var/memory_z

/datum/component/tactile_memory/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(clearMemory))
	RegisterSignal(parent, COMSIG_MOB_STATCHANGE, PROC_REF(clearMemory))
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(onMove))

/datum/component/tactile_memory/Destroy()
	clearMemory()
	return ..()

/datum/component/tactile_memory/proc/clearMemory()
	SIGNAL_HANDLER
	if(viewer)
		viewer.images -= impressions
	impressions.Cut()
	expiry_times.Cut()
	viewer = null
	STOP_PROCESSING(SSprocessing, src)

/datum/component/tactile_memory/proc/onMove()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/user = parent
	if(!isturf(user.loc) || user.z != memory_z)
		clearMemory()

/datum/component/tactile_memory/process()
	var/mob/living/carbon/human/user = parent
	if(!user.client || user.client != viewer || user.stat != CONSCIOUS \
		|| !user.hasTactileBlindness() || user.client.eye != user)
		clearMemory()
		return
	for(var/index = impressions.len, index >= 1, index--)
		if(world.time < expiry_times[index])
			continue
		viewer.images -= impressions[index]
		impressions.Cut(index, index + 1)
		expiry_times.Cut(index, index + 1)
	if(!impressions.len)
		clearMemory()

/datum/component/tactile_memory/proc/probe()
	var/mob/living/carbon/human/user = parent
	if(world.time < next_probe || !user.client || !isturf(user.loc))
		return
	if(user.stat != CONSCIOUS || user.incapacitated() \
		|| !user.hasTactileBlindness() || user.client.eye != user)
		return
	if(!user.has_active_hand())
		to_chat(user, span_warning("I need a hand to feel ahead."))
		return
	var/obj/item/tool = user.get_active_held_item()
	if(tool && !tool.walking_stick)
		to_chat(user, span_warning("I need an empty hand or a walking stick."))
		return
	next_probe = world.time + 1 SECONDS
	var/turf/origin = user.loc
	var/probe_dir = user.dir
	var/hand_index = user.active_hand_index
	if(!do_after(user, 0.5 SECONDS, target = user))
		return
	if(user.loc != origin || user.dir != probe_dir \
		|| user.active_hand_index != hand_index \
		|| user.get_active_held_item() != tool || !user.has_active_hand() \
		|| user.incapacitated() || user.stat != CONSCIOUS \
		|| !user.hasTactileBlindness() || !user.client \
		|| user.client.eye != user)
		return
	if(viewer && viewer != user.client)
		clearMemory()
	viewer = user.client
	memory_z = user.z
	var/turf/previous = origin
	var/reach = tool ? 2 : 1
	for(var/distance = 1, distance <= reach, distance++)
		var/turf/target = get_step(previous, probe_dir)
		if(!target)
			break
		if(!target.Adjacent(previous))
			break
		if(feelTurf(target))
			break
		previous = target
	if(impressions.len)
		START_PROCESSING(SSprocessing, src)
	to_chat(user, span_notice("I feel out the shapes ahead of me."))

/datum/component/tactile_memory/proc/feelTurf(turf/target)
	for(var/index = impressions.len, index >= 1, index--)
		var/image/old_image = impressions[index]
		if(old_image.loc != target)
			continue
		viewer.images -= old_image
		impressions.Cut(index, index + 1)
		expiry_times.Cut(index, index + 1)
	remember(target, target)
	if(target.density)
		return TRUE
	var/scanned = 0
	var/blocked = FALSE
	for(var/atom/movable/object in target)
		if(++scanned > 24)
			return TRUE
		if(object.density)
			blocked = TRUE
		if(object.invisibility || object.alpha < 255)
			continue
		if(isobj(object) && !istype(object, /obj/effect))
			remember(object, target)
	return blocked

/datum/component/tactile_memory/proc/remember(atom/object, turf/location)
	if(!object.icon || !object.icon_state)
		return
	var/image/impression = image(object.icon, location, object.icon_state)
	impression.dir = object.dir
	impression.pixel_x = object.pixel_x
	impression.pixel_y = object.pixel_y
	impression.plane = HUD_PLANE
	impression.layer = LOW_OBJ_LAYER
	impression.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	impression.appearance_flags = RESET_COLOR | RESET_ALPHA
	impression.filters = list(
		filter(type = "color", color = list(
			0, 0, 0, 0,
			0, 0, 0, 0,
			0, 0, 0, 0,
			0, 0, 0, 1,
			0.06, 0.06, 0.06, 0)),
		filter(type = "outline", size = 1, color = "#b8c1c7"))
	while(impressions.len >= 64)
		viewer.images -= impressions[1]
		impressions.Cut(1, 2)
		expiry_times.Cut(1, 2)
	impressions += impression
	expiry_times += world.time + 8 SECONDS
	viewer.images += impression
	animate(impression, alpha = 0, time = 8 SECONDS)
