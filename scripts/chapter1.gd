extends RefCounted
## 第一章 · 重力篇（10 关）。关卡用文本格式写，格式说明见 levels/README.txt。
## 这里把文本直接嵌在脚本里（导出游戏时不会丢文件）；想试新关卡可以放进 levels/ 目录。
## 三轮 = 草(1-3) / 花(4-6) / 树(7-10)。每一轮结束后会揭晓：这几关的管道拼在一起，是一株什么。
## reveal 是这一关在最终"花园"画面里的位置（单位 = 格），关卡之间的相对位置决定了整体样貌。

const LevelText = preload("res://scripts/level_text.gd")

const L01 := """
title 连通器
round grass
flora grass
rows 6
hint 点【放水】。水会流到和水源一样高的地方——哪怕中间要先往下、再往上。
win 水只会流向不高于水源的地方，但中间可以先下后上——这就是连通器。
reveal 0 26
node S source 0 1
node A pipe 0 4
node B pipe 3 4
node G1 goal 3 2
node C pipe 6 4
node G2 goal 6 3
edge S A
edge A B
edge B G1
edge B C
edge C G2
solution
"""

const L02 := """
title 阀门
round grass
flora grass
rows 6
valves 2
hint 红色方块是关着的阀门，点击可以打开，但只有 2 次机会。两个终点都要点亮。
win 阀门决定水走哪条路，次数有限，每一次都要想清楚。
reveal 12 26
node S source 3 0
node F pipe 3 2
node L pipe 1 2
node G1 goal 1 4
node R pipe 5 2
node G2 goal 5 4
edge S F
edge F L valve
edge L G1
edge F R valve
edge R G2
solution F-L F-R
bad F-L
"""

const L03 := """
title 水箱
round grass
flora grass
rows 6
tanks 1
hint 水源太低，够不着高处的终点。你有一个装满水的水箱：放在哪个空位，水位就等于那里的高度。
win 水箱放得越高，水位越高。水从高处流下，再爬回同样的高度——这就是高低差的力量。
caption 三关的水，长成了一片草。没有哪一关单独画出了草——它是三关拼出来的。
reveal 24 26
node S source 0 4
node A pipe 1 4
node s1 slot 2 3
node P pipe 4 1
node s2 slot 6 0
node Q pipe 8 2
node s3 slot 9 3
node G goal 11 1
edge S A
edge A s1
edge s1 P
edge P s2
edge s2 Q
edge Q s3
edge s3 G
solution @s2
bad @s1
bad @s3
"""

const L04 := """
title 虹吸
round flower
flora flower
rows 6
tanks 1
siphons 1
hint 弧形管是虹吸管：装上后水能翻过比水位还高的山头，但出口必须比水位低。
win 水箱放得比出口高，水就被吸过去了；放得和出口一样高，吸不动。
reveal 0 20
node S source 0 3
node a pipe 1 3
node s1 slot 1 2
node s2 slot 1 1
node e pipe 3 3
node B pipe 6 2
node G goal 8 3
edge S a
edge a s1
edge s1 s2
edge a e
edge e B siphon 0
edge B G
solution @s2 ~e-B
bad @s1 ~e-B
bad @s2
"""

const L05 := """
title 混色
round flower
flora flower
rows 6
valves 2
hint 水源带颜色。同高或从高处流下来的水汇到一起会混色：红 + 蓝 = 紫。花朵开出的颜色，就是浇它的水的颜色。
win 没有哪个水源是紫色的，紫色是两种水在汇合处自己长出来的。
reveal 12 20
node SR source 0 2 R
node a pipe 2 2
node Gr goal 2 4 R
node m pipe 5 4
node Gp goal 5 5 RB
node b pipe 8 2
node Gb goal 8 4 B
node SB source 10 2 B
edge SR a
edge a Gr
edge a m valve
edge m Gp
edge b m valve
edge b Gb
edge SB b
solution a-m b-m
bad a-m
"""

const L06 := """
title 花园配色
round flower
flora flower
rows 6
siphons 2
hint 黄水藏在中间的水源里，两侧各有一座山。想让左边开橙花（红+黄）、右边开绿花（蓝+黄），黄水得翻过去。
win 三种颜色的水、两根虹吸管，开出了橙色和绿色——这两种颜色，没有一处水源是它们。
caption 三关的水，开成了一丛花。每朵花的颜色，都是水自己混出来的。
reveal 24 20
node SY source 5 2 Y
node tL pipe 4 2
node tR pipe 6 2
node SR source 0 1 R
node rA pipe 0 3
node eL pipe 2 3
node GL goal 2 5 RY
node SB source 10 1 B
node bB pipe 10 3
node eR pipe 8 3
node GR goal 8 5 BY
edge SY tL
edge SY tR
edge tL eL siphon 0
edge tR eR siphon 0
edge SR rA
edge rA eL
edge eL GL
edge SB bB
edge bB eR
edge eR GR
solution ~tL-eL ~tR-eR
bad ~tL-eL
"""

const L07 := """
title 钥匙
round tree
flora leaf
rows 6
valves 1
tanks 1
hint 只有 1 次开阀机会和 1 个水箱。高处终点需要足够的水位，右下终点可以从两条支路供水。
win 一个高处水箱，加一次开阀，就能给三个终点供水；右下终点有两条可用路线。
reveal 12 14
node S source 0 1
node F pipe 0 3
node a0 pipe 2 3
node a1 pipe 4 3
node a2 pipe 6 3
node GA goal 4 4
node s1 slot 7 2
node s2 slot 8 1
node s3 slot 9 0
node GT goal 11 0
node c pipe 8 4
node GB goal 8 5
node b0 pipe 2 5
node b1 pipe 5 5
edge S F
edge F a0
edge a0 a1
edge a1 GA
edge a1 a2
edge a2 s1
edge s1 s2
edge s2 s3
edge s3 GT
edge a2 c valve
edge c GB
edge F b0 valve
edge b0 b1
edge b1 GB
solution a2-c @s3
alt F-b0 @s3
bad a2-c @s2
bad a2-c @s1
bad a2-c
"""

const L08 := """
title 殊途同归
round tree
flora leaf
rows 6
valves 1
tanks 1
hint 低处的水源够不着高处的终点。你有一个水箱，也有一个阀门——办法不止一个。
win 放水箱，或者接通高处的水源：做法不同，水位一样高，结果一样。
reveal 0 8
node S1 source 0 4
node a pipe 2 4
node b pipe 4 4
node s slot 5 1
node c pipe 7 2
node G goal 9 3
node S2 source 10 0
edge S1 a
edge a b
edge b s
edge s c
edge c G
edge S2 c valve
solution @s
alt S2-c
"""

const L09 := """
title 近路
round tree
flora leaf
rows 6
siphons 1
hint 两根弧管，只能装一根。看着近的，未必吸得动。
win 离得近的出口和水位一样高，吸不动；绕高一点的出口低一格，反而通了。
reveal 24 8
node S source 0 2
node e pipe 2 2
node X pipe 4 2
node Y pipe 6 3
node G0 goal 4 4
node G1 goal 8 3
edge S e
edge e X siphon 1
edge e Y siphon 0
edge X G0
edge Y G0
edge Y G1
solution ~e-Y
bad ~e-X
"""

const L10 := """
title 一颗水箱
round tree
flora leaf
rows 6
tanks 1
hint 五个终点，水箱只有一个。别急着逐个去数——先想想水能从哪儿流到哪儿。
win 你只放了一个水箱，整棵树却全亮了。没有谁一个个点亮它们，是水自己涌上去的。
caption 四关的水，长成了一棵树。三轮连起来，是一座花园——你从头到尾，只放了几个水箱、开了几个阀门、装了几根虹吸管。
reveal 12 2
node S source 5 1
node F pipe 5 3
node l0 pipe 3 3
node l1 pipe 1 3
node GL goal 1 5
node u1 slot 0 2
node u2 slot 0 1
node u3 slot 0 0
node GU goal 2 0
node GC goal 5 0
node r0 pipe 7 3
node r1 pipe 9 3
node GR goal 9 5
node v1 slot 10 2
node v2 slot 10 1
node v3 slot 10 0
node GV goal 8 0
edge S F
edge F l0
edge l0 l1
edge l1 GL
edge l1 u1
edge u1 u2
edge u2 u3
edge u3 GU
edge GU GC
edge GC GV
edge F r0
edge r0 r1
edge r1 GR
edge r1 v1
edge v1 v2
edge v2 v3
edge v3 GV
solution @u3
alt @v3
bad @u2
bad @v2
bad @u1
"""

static func get_levels() -> Array:
	var out: Array = []
	for txt in [L01, L02, L03, L04, L05, L06, L07, L08, L09, L10]:
		out.append(LevelText.parse(txt))
	return out
