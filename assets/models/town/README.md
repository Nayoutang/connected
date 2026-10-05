# 百阶城 3D 模型

本目录包含 12 个真实网格的 Godot PackedScene，可直接拖入 3D 场景编辑、旋转和缩放。造型根据 assets/generated-town 中对应透明 PNG 制作，不是平面图片贴片。采用统一青瓦、暖墙、木梁与黄铜材质；参考图片的手绘纹理未逐像素复刻。

模型：house、shop、shed、clocktower、reservoir、greenhouse、gate、stairs、bridge、bench、planter、lamp。

游戏中的 garden_world.gd 已实例化这些模型，保留原有地图碰撞与导航；阶梯升高 1.5 单位，桥面与原通行高度一致。遮挡角色的模型继续使用透明淡出。相同材质的部件合并为网格，单个模型只有 2 至 8 个渲染部件。

建模源文件：scripts/town_models.gd。重新导出：Godot --headless --path . --script tests/bake_town_models.gd。导出的 tscn 不依赖运行时建模脚本。

验证：tests/garden_smoke.gd，覆盖七个地区、桥梁寻路、楼梯通行、附近交互、物资箱、修复关卡与地图往返。
