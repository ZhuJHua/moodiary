import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/utils/function_extensions.dart';
import 'package:refreshed/refreshed.dart';

import '../../main.dart';
import 'side_bar_logic.dart';

class SideBarComponent extends StatelessWidget {
  const SideBarComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SideBarLogic());
    final state = Bind.find<SideBarLogic>().state;
    final textStyle = Theme.of(context).textTheme;

    Widget buildWeather() {
      return Column(
        children: [
          Icon(
            WeatherIcon.map[state.weatherResponse[0]]!,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(2.0, 2.0),
                blurRadius: 8.0,
                color: Colors.black38,
              ),
            ],
          ),
          Text(
            '${state.weatherResponse[2]} ${state.weatherResponse[1]}°C',
            style:
                textStyle.titleMedium!.copyWith(color: Colors.white, shadows: [
              const Shadow(
                offset: Offset(2.0, 2.0),
                blurRadius: 8.0,
                color: Colors.black38,
              ),
            ]),
          )
        ],
      );
    }

    Widget buildHitokoto() {
      return Center(
        child: Obx(() {
          return Text(
            state.hitokoto.value,
            style:
                textStyle.titleMedium!.copyWith(color: Colors.white, shadows: [
              const Shadow(
                offset: Offset(2.0, 2.0),
                blurRadius: 8.0,
                color: Colors.black38,
              ),
            ]),
            overflow: TextOverflow.fade,
          );
        }),
      );
    }

    Widget buildDate() {
      return Row(
        children: [
          Text(
            state.nowTime.day.toString(),
            style: textStyle.displayMedium!
                .copyWith(color: Colors.white, shadows: [
              const Shadow(
                offset: Offset(2.0, 2.0),
                blurRadius: 8.0,
                color: Colors.black38,
              ),
            ]),
          ),
          const SizedBox(
            width: 8.0,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.MMM().format(state.nowTime),
                style: textStyle.titleSmall!
                    .copyWith(color: Colors.white, shadows: [
                  const Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 8.0,
                    color: Colors.black38,
                  ),
                ]),
              ),
              Text(
                DateFormat.EEEE().format(state.nowTime),
                style: textStyle.titleMedium!
                    .copyWith(color: Colors.white, shadows: [
                  const Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 8.0,
                    color: Colors.black38,
                  ),
                ]),
              )
            ],
          ),
        ],
      );
    }

    return GetBuilder<SideBarLogic>(
      builder: (_) {
        return Drawer(
          child: Column(
            children: [
              Obx(() {
                return DrawerHeader(
                  decoration: BoxDecoration(
                      image: state.imageUrl.value.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                  state.imageUrl.value),
                              fit: BoxFit.cover,
                            )
                          : null),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildDate(),
                          if (state.getWeather &&
                              state.weatherResponse.value.isNotEmpty) ...[
                            buildWeather()
                          ]
                        ],
                      ),
                      Expanded(child: buildHitokoto()),
                    ],
                  ),
                );
              }),
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    Obx(() {
                      return AboutListTile(
                        icon: const Icon(Icons.info_outline),
                        applicationName: state.packageInfo.value != null
                            ? state.packageInfo.value!.appName
                            : '',
                        applicationVersion: state.packageInfo.value != null
                            ? 'v${state.packageInfo.value!.version}(${state.packageInfo.value!.buildNumber})'
                            : '',
                        applicationLegalese: '\u{a9} 2024 江有汜',
                        aboutBoxChildren: const [
                          Padding(
                            padding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                            child: Column(
                              children: [],
                            ),
                          )
                        ],
                        child: Text(l10n.sidebarAbout),
                      );
                    }),
                    ListTile(
                      leading: const Icon(Icons.security_outlined),
                      onTap: () {
                        logic.toPrivacy();
                      },
                      title: Text(
                        l10n.sidebarPrivacy,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      onTap: () {
                        logic.toReportPage();
                      },
                      title: Text(
                        l10n.sidebarBug,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.update),
                      onTap: () async {}.throttleWithTimeout(timeout: 3000),
                      title: Text(l10n.sidebarCheckUpdate),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
