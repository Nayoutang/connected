关卡文本格式（第一章的 10 关就是这样写的，见 scripts/chapter1.gd）
行以 # 开头是注释。坐标 = 列 行，行号越小越高（高度 = rows - 行）。

title 标题                 rows 6（画面行数）
valves 1  tanks 1  siphons 1     三种道具的数量（不写 = 0）
hint 提示   win 通关文字
round grass|flower|tree    这一关属于哪一轮（草/花/树）
flora grass|flower|leaf    终点长出什么
tank_color R               水箱里的水颜色（可不写）
caption 文字               写了就表示这是一轮的最后一关：通关后进入"揭晓"
reveal 列 行               这一关在最终花园画面里的位置（单位=格），决定整体拼出什么样子

node 编号 种类 列 行 [颜色]    种类：source / pipe / goal / slot(水箱空位)
                              颜色：R红 B蓝 Y黄，可叠写（RB=紫 RY=橙 BY=绿）；
                              水源写颜色 = 水的颜色，终点写颜色 = 要求的花色
edge a b                      普通管道
edge a b valve                阀门
edge a b siphon 行            虹吸管（弧形，最高点在第"行"行；出口必须比水位低，最多高出水位 3 格）

solution F-L @s2 ~e-B     预期解：阀门 a-b，水箱 @空位，虹吸 ~a-b
alt ...                   另一种预期解（多解关）
bad ...                   预期会失败的摆法

水的规则：只能流到不高于水位的地方（水位 = 水源/水箱所在高度）；
颜色：同高或从高处流下来的水汇合会混色，往上流不混色。

写完运行 tests/solve.gd 看每关有几种解、有没有死胡同、你写的 solution 能不能通关。
godot --headless --path . --script res://tests/solve.gd
