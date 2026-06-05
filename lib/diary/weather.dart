import 'package:flutter/material.dart';

class WeatherOption {
  final int code;
  final String name;
  final IconData icon;
  const WeatherOption(this.code, this.name, this.icon);
}

const weatherOptions = <WeatherOption>[
  WeatherOption(1, '晴', Icons.wb_sunny),
  WeatherOption(2, '多云', Icons.filter_drama),
  WeatherOption(3, '阴', Icons.cloud),
  WeatherOption(4, '小雨', Icons.opacity),
  WeatherOption(5, '中雨', Icons.grain),
  WeatherOption(6, '大雨', Icons.beach_access),
  WeatherOption(7, '雷阵雨', Icons.flash_on),
  WeatherOption(8, '雪', Icons.ac_unit),
  WeatherOption(9, '雾', Icons.blur_on),
  WeatherOption(10, '大风', Icons.air),
];

WeatherOption weatherByCode(int? code) {
  return weatherOptions.firstWhere(
    (w) => w.code == code,
    orElse: () => const WeatherOption(99, '未知', Icons.help_outline),
  );
}
