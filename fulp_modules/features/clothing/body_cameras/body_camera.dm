
/obj/item/clothing/suit/armor/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/bodycamera_holder)

/**
 * The bodycamera
 *
 * This is the item that gets installed into items that have the bodycamera_holder element
 */
/obj/item/bodycam_upgrade
	name = "body camera upgrade"
	icon = 'fulp_modules/features/clothing/body_cameras/bodycamera.dmi'
	icon_state = "bodycamera"
	desc = "An armor vest upgrade, there's an instructions tag if you look a little closer..."
	///The camera itself.
	var/obj/machinery/camera/builtin_bodycamera

/obj/item/bodycam_upgrade/examine_more(mob/user)
	. += list(span_notice("Use [src] on any valid vest to quickly install."))
	. += list(span_notice("Use a [span_bold("screwdriver")] to remove it."))
	. += list(span_notice("While equipped, use your ID card on the vest to activate/deactivate the camera."))
	. += list(span_notice("Unequipping the vest will immediately deactivate the camera."))

/obj/item/bodycam_upgrade/Destroy()
	if(builtin_bodycamera)
		turn_off()
	return ..()

/obj/item/bodycam_upgrade/proc/is_on()
	if(isnull(builtin_bodycamera))
		return FALSE
	return TRUE

/obj/item/bodycam_upgrade/proc/turn_on(mob/user, obj/item/card/id/id_card)
	builtin_bodycamera = new(user)
	builtin_bodycamera.internal_light = FALSE
	builtin_bodycamera.network = list("ss13")
	builtin_bodycamera.c_tag = "-Body Camera: [(id_card.registered_name)] ([id_card.assignment])"
	user.balloon_alert(user, "bodycamera activated")
	playsound(loc, 'sound/machines/beep.ogg', get_clamped_volume(), TRUE, -1)

/obj/item/bodycam_upgrade/proc/turn_off(mob/user)
	playsound(loc, 'sound/machines/beep.ogg', get_clamped_volume(), TRUE, -1)
	user.balloon_alert(user, "bodycamera deactivated")
	QDEL_NULL(builtin_bodycamera)


/**
 * Bodycamera element
 *
 * Allows anything to have a body camera inserted into it
 */
/datum/element/bodycamera_holder
	element_flags = ELEMENT_BESPOKE|ELEMENT_DETACH
	id_arg_index = 2
	///The installed bodycamera
	var/obj/item/bodycam_upgrade/bodycamera_installed
	///The clothing part this needs to be on. This could possibly just be done by checking the clothing's slot
	var/clothingtype_required = ITEM_SLOT_OCLOTHING

/datum/element/bodycamera_holder/Attach(datum/target)
	. = ..()
	RegisterSignal(target, COMSIG_PARENT_ATTACKBY, .proc/on_attackby)
	RegisterSignal(target, COMSIG_PARENT_EXAMINE_MORE, .proc/on_examine_more)
	RegisterSignal(target, COMSIG_ATOM_TOOL_ACT(TOOL_SCREWDRIVER), .proc/on_screwdriver_act)

/datum/element/bodycamera_holder/Detach(datum/source, ...)
	UnregisterSignal(source, COMSIG_ATOM_TOOL_ACT(TOOL_SCREWDRIVER))
	UnregisterSignal(source, COMSIG_PARENT_ATTACKBY)
	UnregisterSignal(source, COMSIG_PARENT_EXAMINE)
	QDEL_NULL(bodycamera_installed)
	return ..()

/datum/element/bodycamera_holder/proc/on_examine_more(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if(!isnull(bodycamera_installed))
		examine_list += span_notice("It has [bodycamera_installed] installed.")
	else
		examine_list += span_notice("It has a spot to hook up a body camera onto.")

/datum/element/bodycamera_holder/proc/on_attackby(datum/source, obj/item/item, mob/living/user)
	SIGNAL_HANDLER

	if(istype(item, /obj/item/bodycam_upgrade))
		if(!isnull(bodycamera_installed))
			to_chat(user, span_warning("We have already installed [bodycamera_installed] installed!"))
			playsound(source, 'sound/machines/buzz-two.ogg', item.get_clamped_volume(), TRUE, -1)
		else
			item.forceMove(source)
			bodycamera_installed = item
			to_chat(user, span_warning("You install [item] into [source]."))
			playsound(source, 'sound/items/drill_use.ogg', item.get_clamped_volume(), TRUE, -1)
		return

	if(isnull(bodycamera_installed))
		return
	var/obj/item/card/id/card = item.GetID()
	if(!card)
		return
	var/obj/item/clothing/suit_slot = user.get_item_by_slot(clothingtype_required)
	if(!istype(suit_slot))
		to_chat(user, span_warning("You have to be wearing [source] to turn [bodycamera_installed] on!"))
		return

	//Do we have a camera on or off?
	if(bodycamera_installed.is_on())
		UnregisterSignal(source, COMSIG_ITEM_POST_UNEQUIP)
		bodycamera_installed.turn_off(user)
	else
		RegisterSignal(source, COMSIG_ITEM_POST_UNEQUIP, .proc/on_unequip)
		bodycamera_installed.turn_on(user, card)

/datum/element/bodycamera_holder/proc/on_screwdriver_act(atom/source, mob/user, obj/item/tool)
	SIGNAL_HANDLER

	if(isnull(bodycamera_installed))
		return
	if(bodycamera_installed.is_on())
		UnregisterSignal(source, COMSIG_ITEM_POST_UNEQUIP)
		bodycamera_installed.turn_off(user)
	to_chat(user, span_warning("You remove the [bodycamera_installed] from [source]."))
	playsound(source, 'sound/items/drill_use.ogg', tool.get_clamped_volume(), TRUE, -1)
	bodycamera_installed.forceMove(user.loc)
	INVOKE_ASYNC(user, /mob.proc/put_in_hands, bodycamera_installed)
	bodycamera_installed = null

/datum/element/bodycamera_holder/proc/on_unequip(obj/item/source, force, atom/newloc, no_move, invdrop, silent)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_ITEM_POST_UNEQUIP)
	bodycamera_installed.turn_off(source)
