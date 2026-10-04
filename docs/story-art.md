# 退潮之后：剧情与美术接入

已加入百阶城背景、维修员阿澄与守塔人岑伯的透明像素立绘。四个教学关与三个涌现关均包含开场和完成对话。点击空白处、空格或回车：先补全当前句，再推进；Esc 或跳过按钮结束。实验室提供重温剧情。剧情期间暂停模拟，关闭后保留玩家原先的暂停状态。

演出：逐字显示、人物淡入滑入、城市漂浮微光、成功扩散水波。共享 story_backdrop / story_dialogue，剧情文案集中 story_data，实验室侧栏样式缓存，不再逐帧创建 StyleBox。没有更改水量守恒与装置规则。

资源：assets/story/baijie.png、acheng.png、cen.png。采用内置 image_gen 生成，非开源第三方素材；既有 Kenney / Game-icons 署名继续保留。美术是剧情氛围层，背景的装饰水路不参与模拟。

## 最终生成提示词

Use case: illustration-story. Game background asset, landscape 16:9. Crisp low-resolution pixel art, visible square pixel clusters, limited blue-gray, teal and brass palette. Baijie city, a hopeful abandoned terraced hillside town after drought, layered stone stairs, modest houses, rooftop rainwater tanks, gravity pipes, small greenhouse and sparse seedlings. Dawn warm light at horizon, atmospheric distant mountain silhouettes. Wide establishing shot, no people, no lettering, no UI. Detailed architecture mainly around edges, calmer dark middle for overlaying a water puzzle. Authentic pixel game artwork, no smooth painting or photorealism.

Use case: illustration-story. A game dialogue character portrait asset on genuinely transparent background. Young adult Chinese female waterworks repairer A-Cheng, short dark teal hair, brass goggles on head, indigo work jacket rolled sleeves, warm ochre scarf, tool belt, one hand holding a small wrench, hopeful thoughtful expression. Three quarter view facing slightly right, waist-up complete silhouette with head and elbows uncut. Crisp deliberate retro pixel art with large visible square pixel clusters as if drawn on a 128 by 160 pixel canvas then nearest-neighbor enlarged; limited 24-color blue gray teal ochre palette, hard pixel edges, no smooth gradients no antialiasing no text no ground shadow. For a warm post-drought hillside city puzzle game.

Use case: illustration-story. Transparent game dialogue portrait of Uncle Cen, elderly Chinese waterworks keeper, short silver hair and moustache, kind weathered face, round brass glasses, navy work coat with teal collar, holds rolled old pipe blueprint. Waist-up complete silhouette, facing slightly left, all head elbows inside frame. Crisp retro pixel art, large visible square pixel clusters as if 128x160 nearest neighbor enlarged, limited bluegray teal brass ochre palette, hard pixel edges, no antialiasing no smooth gradients. Warm hopeful post-drought hillside city. No text, no background, no ground shadow. Match a young repairer with brass goggles indigo jacket and ochre scarf.


## 主分支合并更新

已兼容第一章十关（虹吸、混色、草花树揭晓）及三关涌现实验室。原四关剧情已扩展为十关，不再按四关索引读取。七张区域图继续使用：第一章依次为归城、旧街、高台、钟楼、温室、苗圃、旧街、双户街区、高台、苗圃；实验室为温室、双户街区、苗圃。新关卡暂按地点复用现有区域美术。
