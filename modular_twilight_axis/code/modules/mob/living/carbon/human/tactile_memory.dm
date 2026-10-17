/mob/living/carbon/human/proc/hasTactileBlindness()
	return vision_obscured(src) || eyesclosed

/mob/living/carbon/human/verb/feel_ahead()
	set name = "Feel Ahead"
	set category = "IC"
	set desc = "Feel ahead with an empty hand or walking stick."

	if(!hasTactileBlindness())
		to_chat(src, span_notice("I can already see my surroundings."))
		return
	var/datum/component/tactile_memory/memory = \
		LoadComponent(/datum/component/tactile_memory)
	memory.probe()
