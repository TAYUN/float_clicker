import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'package:float_clicker/features/multi_point/multi_point_settings.dart';
import 'package:float_clicker/features/multi_point/multi_point_settings_store.dart';

void main() {
  const store = MultiPointSettingsStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads default multi point configuration', () async {
    final configuration = await store.loadConfiguration();

    expect(configuration.settings, MultiPointSettings.defaults);
    expect(
      configuration.overlayUiSettings,
      MultiPointOverlayUiSettings.defaults,
    );
    expect(configuration.targets.values, [
      MultiPointTarget.defaultFirstTarget,
      MultiPointTarget.defaultSecondTarget,
    ]);
    expect(configuration.targets.hasEnabledTarget, isTrue);
  });

  test('adds targets until max limit and rejects overflow', () {
    var targets = MultiPointTargets.defaults();

    while (targets.canAdd) {
      targets = targets.addTarget();
    }

    expect(targets.length, MultiPointTargets.maxTargets);
    expect(targets.values.last.id, 'p12');
    expect(targets.values.last.order, 12);
    expect(targets.canAdd, isFalse);
    expect(() => targets.addTarget(), throwsStateError);
  });

  test('remove keeps at least one target object', () {
    var targets = MultiPointTargets.defaults();
    targets = targets.removeTarget('p1');

    expect(targets.values.single.id, 'p2');
    expect(targets.values.single.order, 1);
    expect(targets.canRemove, isFalse);
    expect(() => targets.removeTarget('p2'), throwsStateError);
  });

  test('reorder normalizes execution order while keeping stable ids', () {
    final targets = MultiPointTargets.defaults()
        .addTarget(id: 'custom')
        .reorderTarget(oldIndex: 2, newIndex: 0);

    expect(targets.values.map((target) => target.id), ['custom', 'p1', 'p2']);
    expect(targets.values.map((target) => target.order), [1, 2, 3]);
  });

  test(
    'allows disabling all targets but returns execution validation error',
    () {
      var targets = MultiPointTargets.defaults();
      targets = targets.setTargetEnabled('p1', false);
      targets = targets.setTargetEnabled('p2', false);

      expect(targets.hasEnabledTarget, isFalse);
      expect(targets.enabledTargets, isEmpty);
      expect(
        targets.executionValidationErrorCode,
        MultiPointTargets.noEnabledTargetsErrorCode,
      );
    },
  );

  test('loads bad targets json with default targets fallback', () async {
    SharedPreferences.setMockInitialValues({
      MultiPointSettingsStore.targetsJsonKey: '{bad-json',
    });

    final targets = await store.loadTargets();

    expect(targets.values, [
      MultiPointTarget.defaultFirstTarget,
      MultiPointTarget.defaultSecondTarget,
    ]);
  });

  test('loads empty targets json with default targets fallback', () async {
    SharedPreferences.setMockInitialValues({
      MultiPointSettingsStore.targetsJsonKey: '[]',
    });

    final targets = await store.loadTargets();

    expect(targets.values.length, 2);
    expect(targets.values.every((target) => target.enabled), isTrue);
  });

  test('persists settings overlay ui settings and targets json', () async {
    final targets = MultiPointTargets.defaults()
        .addTarget(id: 'custom')
        .setTargetEnabled('p2', false);
    final configuration = MultiPointConfiguration(
      settings: MultiPointSettings.defaults.copyWith(
        intervalMs: 750,
        repeatCount: 3,
        infiniteLoop: true,
        tapDurationMs: 90,
      ),
      overlayUiSettings: MultiPointOverlayUiSettings.defaults.copyWith(
        interactionMode: OverlayInteractionMode.minimal,
        toolbarPositionX: 30,
        toolbarPositionY: 40,
        isToolbarCollapsed: true,
      ),
      targets: targets,
    );

    await store.saveConfiguration(configuration);
    final loaded = await store.loadConfiguration();

    expect(loaded.settings, configuration.settings);
    expect(loaded.overlayUiSettings, configuration.overlayUiSettings);
    expect(loaded.targets, configuration.targets);

    final preferences = await SharedPreferences.getInstance();
    final savedTargetsJson = preferences.getString(
      MultiPointSettingsStore.targetsJsonKey,
    );
    final savedTargets = jsonDecode(savedTargetsJson!) as List<Object?>;

    expect(savedTargets.length, 3);
    expect((savedTargets[1] as Map<String, Object?>)['enabled'], isFalse);
  });
}
