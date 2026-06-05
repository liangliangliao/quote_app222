import 'will_models.dart';
import 'will_seed.dart';
import 'will_unit_index_seed.dart';
import 'will_route_link_seed.dart';

class WillRouteResolver {
  static List<WillProblemPath> recommendedProblemsForUnit(WillUnitIndex unit) {
    final titles = kUnitProblemOverrides[unit.id] ?? _problemDefaultsForUnit(unit);
    return kWillProblemPaths.where((e) => titles.contains(e.title)).toList();
  }

  static List<WillTaskPlan> recommendedTasksForUnit(WillUnitIndex unit) {
    final titles = kUnitTaskOverrides[unit.id] ?? _taskDefaultsForUnit(unit);
    return kWillTaskPlans.where((e) => titles.contains(e.title)).toList();
  }

  static List<WillWorldZone> recommendedZonesForUnit(WillUnitIndex unit) {
    final titles = kUnitZoneOverrides[unit.id] ?? _zoneDefaultsForUnit(unit);
    return kWillWorldZones.where((e) => titles.contains(e.title)).toList();
  }

  static List<WillTaskPlan> recommendedTasksForProblem(WillProblemPath problem) {
    return kWillTaskPlans.where((task) => task.linkedCardIds.any(problem.linkedCardIds.contains)).toList();
  }

  static List<WillWorldZone> recommendedZonesForProblem(WillProblemPath problem) {
    return kWillWorldZones.where((zone) => zone.linkedCardIds.any(problem.linkedCardIds.contains)).toList();
  }

  static List<WillProblemPath> recommendedProblemsForTask(WillTaskPlan task) {
    return kWillProblemPaths.where((problem) => problem.linkedCardIds.any(task.linkedCardIds.contains)).toList();
  }

  static List<WillWorldZone> recommendedZonesForTask(WillTaskPlan task) {
    return kWillWorldZones.where((zone) => zone.linkedCardIds.any(task.linkedCardIds.contains)).toList();
  }

  static List<WillProblemPath> recommendedProblemsForZone(WillWorldZone zone) {
    return kWillProblemPaths.where((problem) => problem.linkedCardIds.any(zone.linkedCardIds.contains)).toList();
  }

  static List<WillTaskPlan> recommendedTasksForZone(WillWorldZone zone) {
    return kWillTaskPlans.where((task) => task.linkedCardIds.any(zone.linkedCardIds.contains)).toList();
  }

  static WillTaskPlan? taskByTitle(String title) {
    for (final task in kWillTaskPlans) {
      if (task.title == title) return task;
    }
    return null;
  }

  static WillUnitIndex? unitById(String id) {
    for (final unit in kWillUnitIndexes) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  static List<String> _problemDefaultsForUnit(WillUnitIndex unit) {
    final n = _idNumber(unit.id);
    switch (unit.moduleCode) {
      case 'D':
        if (n <= 19) return const ['明知该做却做不到'];
        if (n <= 40) return const ['明知该做却做不到', '总在权衡，一直定不下来'];
        if (n <= 77) return const ['明知该做却做不到'];
        return const ['明知该做却做不到', '总在权衡，一直定不下来'];
      case 'I':
        if (n <= 10) return const ['明知该做却做不到', '总被眼前舒服拉走'];
        return const ['明知该做却做不到', '总在权衡，一直定不下来'];
      case 'A':
      case 'T':
        return const ['总在权衡，一直定不下来'];
      case 'E':
        return const ['明知该做却做不到', '总在权衡，一直定不下来'];
      case 'X':
        return const ['冲动一来就控制不住', '总被眼前舒服拉走'];
      case 'O':
        return const ['明知该做却做不到'];
      case 'P':
        return const ['总被眼前舒服拉走', '冲动一来就控制不住'];
      case 'R':
      case 'F':
      case 'W':
      default:
        return const ['明知该做却做不到'];
    }
  }

  static List<String> _taskDefaultsForUnit(WillUnitIndex unit) {
    final n = _idNumber(unit.id);
    switch (unit.moduleCode) {
      case 'D':
        if (n <= 19) return const ['10 秒起步'];
        if (n <= 40) return const ['10 秒起步', '30 秒注意锁定'];
        if (n <= 77) return const ['30 秒注意锁定', '晚间意志复盘'];
        return const ['晚间意志复盘'];
      case 'I':
        if (n <= 10) return const ['10 秒起步'];
        if (n <= 15) return const ['10 秒起步', '晚间意志复盘'];
        return const ['30 秒注意锁定', '晚间意志复盘'];
      case 'A':
      case 'T':
        return const ['晚间意志复盘'];
      case 'E':
        return const ['30 秒注意锁定', '晚间意志复盘'];
      case 'X':
        return const ['90 秒延迟诱惑', '晚间意志复盘'];
      case 'O':
        return const ['10 秒起步', '晚间意志复盘'];
      case 'P':
        return const ['90 秒延迟诱惑', '晚间意志复盘'];
      case 'R':
        return const ['30 秒注意锁定', '晚间意志复盘'];
      case 'F':
        return const ['晚间意志复盘'];
      case 'W':
      default:
        return const ['10 秒起步', '晚间意志复盘'];
    }
  }

  static List<String> _zoneDefaultsForUnit(WillUnitIndex unit) {
    final n = _idNumber(unit.id);
    switch (unit.moduleCode) {
      case 'D':
        if (n <= 19) return const ['感动港'];
        if (n <= 40) return const ['起意场'];
        if (n <= 77) return const ['感动港', '努力坡'];
        return const ['感动港', '起意场'];
      case 'I':
        if (n <= 10) return const ['起意场'];
        if (n <= 15) return const ['起意场', '努力坡'];
        return const ['努力坡'];
      case 'A':
        return const ['审议庭'];
      case 'T':
        return const ['裁决塔', '努力坡'];
      case 'E':
        return const ['努力坡'];
      case 'X':
        return const ['诱惑市集'];
      case 'O':
        return const ['阻塞谷'];
      case 'P':
        return const ['诱惑市集'];
      case 'R':
        return const ['观念神殿', '努力坡'];
      case 'F':
        return const ['自由岔路'];
      case 'W':
      default:
        return const ['锻造工坊'];
    }
  }

  static int _idNumber(String id) {
    final match = RegExp(r'-(\d+)$').firstMatch(id);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
