import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'font_logic.dart';

class FontPage extends StatelessWidget {
  const FontPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<FontLogic>();
    final state = Bind.find<FontLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    return GetBuilder<FontLogic>(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('字体大小'),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  '拖动下方滑块预览字体',
                  style: textStyle.titleMedium,
                ),
              ),
              Text(
                '黄水塘里游着白鸭，\n'
                '高粱梗油青的刚高过头，\n'
                '这跳动的心怎样安插，\n'
                '田里一窄条路，八月里这忧愁？\n'
                '天是昨夜雨洗过的，山岗\n'
                '照着太阳又留一片影；\n'
                '羊跟着放羊的转进村庄，\n'
                '一大棵树荫下罩着井，又像是心！\n'
                '从没有人说过八月什么话，\n'
                '夏天过去了，也不到秋天。\n'
                '但我望着田垄，土墙上的瓜，\n'
                '仍不明白生活同梦怎样的连牵。',
                textAlign: TextAlign.center,
                textScaler: TextScaler.linear(state.fontScale),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Slider(
                        value: state.fontScale,
                        min: 0.8,
                        max: 1.2,
                        divisions: 4,
                        label: state.fontScale.toString(),
                        onChanged: (value) {
                          logic.changeFontScale(value);
                        }),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '小',
                            textScaler: TextScaler.linear(0.8),
                          ),
                          Text(
                            '标准',
                            textScaler: TextScaler.linear(1.0),
                          ),
                          Text(
                            '大',
                            textScaler: TextScaler.linear(1.2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 60,
                    )
                  ],
                ),
              )
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              logic.saveFontScale();
            },
            child: const Icon(Icons.check),
          ),
        );
      },
    );
  }
}
