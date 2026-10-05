# 城市主界面

流程：标题页「开始游戏」→ 修复事务所 → 水路地图 → 关卡简报 → 剧情 / 关卡。暂停返回主界面进入事务所。主界面使用独立不透明背景，不显示关卡管线。

背景：`assets/story/city-home.png`，通过内置 imagegen 生成。布局代码：`scripts/city_home.gd`。画面参考塞尔达的自然探索氛围，导航延续明日方舟式信息分区，保留百阶城原创世界观，未使用两款游戏的角色、标志或原图。

最终生成提示词：

Use case: stylized-concept. Create a polished original 16:9 landscape background for the main hub of a Chinese waterworks puzzle adventure 'Baijie City'. No text, no logos, no UI. A breathtaking terraced mountain town after drought, ancient Chinese blue tiled rooftops, aqueducts and copper water pipes, a quiet repair workshop balcony in foreground left with a waterwheel and small planted pots, a sunlit arched bridge and clear turquoise stream leading into distant mountains. Lush grass, wind and adventurous open-air atmosphere inspired by Zelda's tranquil environmental storytelling, painterly stylized game environment with crisp finely textured edges compatible with pixel-art town assets. Golden morning light, warm stone, muted teal shadows, atmospheric depth. Composition: impressive city and mountain focal point on LEFT and CENTER; RIGHT third is calm darker shaded stone terrace and foliage suitable for overlaying readable menu cards. Bottom edge dark foreground. No characters, no weapons, no existing game symbols. Wide cinematic framing, beautiful professional game background.

验证：`tests/home_smoke.gd` 检查开始游戏进入主界面、选择关卡、暂停返回、960×540 窗口截图；`tests/lab_ui_smoke.gd` 检查既有关卡流程。
