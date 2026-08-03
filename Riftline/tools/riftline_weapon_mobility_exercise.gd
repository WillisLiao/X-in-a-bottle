extends SceneTree

func _initialize() -> void:
	assert(Duelist.Weapon.KNIFE == 1)
	var m4_hip := Duelist.standing_speed_profile(Duelist.Weapon.PULSE, false)
	var m4_ads := Duelist.standing_speed_profile(Duelist.Weapon.PULSE, true)
	var knife := Duelist.standing_speed_profile(Duelist.Weapon.KNIFE, false)
	assert(is_equal_approx(float(m4_hip.forward), 7.2))
	assert(is_equal_approx(float(m4_hip.lateral), 5.472))
	assert(is_equal_approx(float(m4_ads.forward), 5.904))
	assert(is_equal_approx(float(m4_ads.lateral), 4.48704))
	assert(is_equal_approx(float(knife.forward), 8.28))
	assert(is_equal_approx(float(knife.lateral), 7.7004))
	assert(is_equal_approx(float(Duelist.mobility_facts(99 as Duelist.Weapon).get("hip_strafe", 0.0)), 0.76))
	print("Riftline weapon mobility exercise: PASS")
	quit()
