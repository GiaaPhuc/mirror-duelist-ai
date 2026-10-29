class_name StateEncoder
extends RefCounted
## Tạo state vector 22 chiều theo SPEC.md, mirror hoá theo góc nhìn của `me`
## (dùng me.facing làm hướng "phía trước", không dùng trái/phải tuyệt đối).
##
## Quy ước chi tiết:
## - s1 = (me.y - opp.y) / MAP_MAX_HEIGHT: dương nghĩa là đối thủ ở CAO hơn.
## - s8..12 / s13..17: one-hot [idle, attacking, blocking, stunned, airborne]
##   (attacking gồm light/heavy/kick/dash/dodge).
## - s20 = combo bản thân đang chain / 5; s21 = thời gian từ lần có đòn trúng
##   gần nhất (bất kỳ bên nào trúng) / 3 giây.


static func encode(me: FighterCharacter, opp: FighterCharacter) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(GameConstants.N_STATE)
	var f := float(me.facing)

	s[0] = clampf((opp.position.x - me.position.x) * f / GameConstants.MAP_WIDTH, -1.0, 1.0)
	s[1] = clampf((me.position.y - opp.position.y) / GameConstants.MAP_MAX_HEIGHT, -1.0, 1.0)
	s[2] = me.hp / GameConstants.MAX_HP
	s[3] = opp.hp / GameConstants.MAX_HP
	for i in 4:
		s[4 + i] = me.cooldown_ratio(i)
	s[8 + me.state_class()] = 1.0
	s[13 + opp.state_class()] = 1.0
	s[18] = clampf(me.velocity.x * f / GameConstants.MAX_RUN_SPEED, -1.0, 1.0)
	s[19] = clampf(opp.velocity.x * f / GameConstants.MAX_RUN_SPEED, -1.0, 1.0)
	s[20] = minf(float(me.combo) / 5.0, 1.0)
	s[21] = minf(float(me.ticks_since_hit) / (3.0 * float(GameConstants.TARGET_FPS)), 1.0)
	return s
