# 连通（涌现 · TapTap Game Jam）

打开方式：Godot 4.3 或更高版本（项目已标 4.7） → 导入 `project.godot` → F5 运行。

## 操作
- 放水前：点水箱空位放/收水箱；点弧形管上的圆钮装/拆虹吸管。
- 点红色阀门打开通路（次数有限）；点【放水】开始；【重置】重来；通关后【下一关】/【揭晓】。
- 快捷键：ESC 暂停 · `[` `]` 切关 · `V` 看本轮揭晓 · `G` 看花园。

## 第一章 · 重力篇（10 关，三轮）
- 草（1–3）：连通器 / 阀门 / 水箱
- 花（4–6）：虹吸管 / 颜色混合 / 虹吸+混色
- 树（7–10）：钥匙 / 殊途同归（多解）/ 近路（诱惑错路）/ 一颗水箱
- 每一轮结束后"揭晓"：这几关的管道拼在一起，长成草 / 花 / 树；十关之后是一座花园。

## 核心规则（scripts/sim.gd，纯重力，没有任何抬升/损耗）
- 每个节点有高度；水位 = 水源/水箱所在高度，水能到达 高度 ≤ 水位 的所有连通节点
- 水箱放下就是新水源；关着的阀门两侧各自灌水到阀门处
- 虹吸管：能翻过比水位还高的山头（最多高 3 格），但出口必须严格低于水位
- 颜色：水源可带色（红/蓝/黄）；同高或从高处流下来的水汇合会混色，往上流不混色；终点可要求花色

## 文件结构
- scripts/sim.gd         模拟核心
- scripts/chapter1.gd    第一章 10 关（文本关卡格式，写法见 levels/README.txt）
- scripts/level_text.gd  文本关卡解析
- scripts/main.gd        绘制 / 输入 / 揭晓（全部代码构建）
- scripts/game_art.gd    开源美术素材的绘制（管壳贴图、图标、终点外框）
- scripts/game_ui.gd     主菜单 / 选关 / 暂停 / 说明 / 署名
- tests/solve.gd         解的枚举器：每关有几种解、有无死胡同、solution 是否可通关
  `godot --headless --path . --script res://tests/solve.gd`
- tests/smoke.gd         走完 10 关、三轮揭晓与花园：`... --script res://tests/smoke.gd`
- scripts/levels.gd + tests/run_tests.gd 是早期 5 关版本，保留作参考。

## 开源美术素材
- 水管：Kenney Puzzle Pack 2（CC0）。
- 阀门、水箱、水源、水滴：Game-icons.net（CC BY 3.0）。
- 来源与署名见 assets/THIRD_PARTY.md，也可从主菜单【素材署名】查看。

## 字体
使用系统字体显示中文（微软雅黑 / 苹方 / Noto Sans CJK 等）。导出到 Web 或手机时，
请把一个 .ttf 放进项目，并在 main.gd 里把 SystemFont 换成 FontFile。

## 多人协作
- 开始改之前先拉取，改完一小块就提交并推送，别攒很久。
- 分工：玩法规则与关卡主要改 `scripts/sim.gd`、`scripts/chapter1.gd`；UI/美术放 `assets/`、`scripts/game_art.gd`、`scripts/game_ui.gd`。要改 `scripts/main.gd` 请先在群里说一声，避免同时修改同一个文件。
- 提交信息写清楚改了什么，例如“第3关：调整水箱位置”。

## 第 11—13 关 · 自行运转的街区

第一章修复报告后继续进入第 11—13 关，统一选关页可直接进入：有限水量、水箱、换向阀、单向阀和浮子反馈。这里的水量模型与第一章的教学模型分离，详见 [实验室说明](docs/emergent-lab.md)。

全部十三关都有像素人物和底部剧情对话，空格推进、Esc 跳过。沿用七个区域背景，新增第一章关卡按故事地点复用对应区域；保持无网格。素材及提示词见 [美术说明](docs/story-art.md) 和 [场景说明](docs/region-scenes.md)。

第11—13关与前十关共用标题、底栏、暂停菜单和管道美术，使用直接点击操作：空位放/收水箱，阀门开关或换向，池间箭头安装/反向/拆除单向阀。点击容器旁「浮」安装或拆除默认浮子，右键可选择其他控制目标。取消实验室侧栏、单步和调试参数。

阶段结算改为修复报告：展示对应区域、规则小结和当前游玩记录，不再播放管道拼草/花/树动画。报告仅短暂淡入，可立即继续。


## 3D 角色、第一人称探索与组件比例

进入「水路地图」即可探索城市与七个街区。WASD 移动，按住右键转头，Shift 快走，F 交互，M 地图，V 切换第一/第三人称（探索之外仍使用原界面快捷键）。

- 新主角约 2.18 万三角面、66 个骨骼，含待机、走动和挥手。跑步目前复用加速走动。
- 中式房屋与店铺接入现有场景；程序化石板地面按世界坐标铺设。
- 1 世界单位按 1 米设计。主角高 1.65 米、眼高 1.52 米；房屋宽 7.2 / 高约 6.57 米，店铺宽 6.4 / 高约 6.92 米。建筑三轴等比缩放，导航阻挡按模型包围盒生成。
- 尺寸统一配置：`scripts/world_dimensions.gd`；完整设计：`docs/组件尺寸设计.md`。
- 模型与动画入口：`scenes/characters/adventure_character.tscn`；走动资源：`assets/characters/animations/walk.tres`。

验证命令（Godot 4.7.2）：

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://tests/character_smoke.gd
godot --headless --path . --script res://tests/first_person_smoke.gd
godot --headless --path . --script res://tests/scale_smoke.gd
godot --headless --path . --script res://tests/garden_smoke.gd
```

当前探索沿用二维导航和高度采样，不包含跳跃、建筑内部或完整三维刚体碰撞。
