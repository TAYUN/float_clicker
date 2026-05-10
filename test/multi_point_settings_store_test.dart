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

  test('loads default profile state when profiles are absent', () async {
    final state = await store.loadProfileState();

    expect(state.profiles, hasLength(1));
    expect(state.activeProfile.name, '默认配置');
    expect(
      state.activeProfile.configuration.settings,
      MultiPointSettings.defaults,
    );
    expect(state.loadedProfileIds, [state.activeProfileId]);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(MultiPointSettingsStore.profilesJsonKey),
      isNotNull,
    );
    expect(
      preferences.getString(MultiPointSettingsStore.activeProfileIdKey),
      state.activeProfileId,
    );
    expect(
      preferences.getString(MultiPointSettingsStore.loadedProfileIdsJsonKey),
      isNotNull,
    );
  });

  test('migrates legacy single configuration into default profile', () async {
    SharedPreferences.setMockInitialValues({
      MultiPointSettingsStore.intervalMsKey: 880,
      MultiPointSettingsStore.repeatCountKey: 6,
      MultiPointSettingsStore.infiniteLoopKey: true,
      MultiPointSettingsStore.tapDurationMsKey: 70,
      MultiPointSettingsStore.overlayInteractionModeKey: 'minimal',
      MultiPointSettingsStore.targetsJsonKey: jsonEncode([
        {
          'id': 'old',
          'order': 1,
          'label': '旧',
          'x': 123.0,
          'y': 456.0,
          'enabled': true,
        },
      ]),
    });

    final state = await store.loadProfileState();

    expect(state.profiles, hasLength(1));
    expect(state.activeProfile.name, '默认配置');
    expect(state.activeProfile.settings.intervalMs, 880);
    expect(state.activeProfile.settings.infiniteLoop, isTrue);
    expect(
      state.activeProfile.overlayUiSettings.interactionMode,
      OverlayInteractionMode.minimal,
    );
    expect(state.activeProfile.targets.values.single.id, 'old');
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

  test('persists multiple profiles and switches active profile', () async {
    final first = MultiPointProfile.defaultProfile().copyWith(
      id: 'first',
      name: '配置 A',
      settings: MultiPointSettings.defaults.copyWith(intervalMs: 600),
    );
    final second = MultiPointProfile.defaultProfile().copyWith(
      id: 'second',
      name: '配置 B',
      settings: MultiPointSettings.defaults.copyWith(intervalMs: 900),
    );

    await store.saveProfileState(
      MultiPointProfileState(
        profiles: [first, second],
        activeProfileId: second.id,
        loadedProfiles: const [
          LoadedMultiPointProfile(
            profileId: 'first',
            order: 1,
            isVisible: true,
          ),
          LoadedMultiPointProfile(
            profileId: 'second',
            order: 2,
            isVisible: true,
          ),
        ],
      ),
    );

    final state = await store.loadProfileState();
    final configuration = await store.loadConfiguration();

    expect(state.profiles.map((profile) => profile.name), ['配置 A', '配置 B']);
    expect(state.activeProfileId, 'second');
    expect(state.loadedProfileIds, ['first', 'second']);
    expect(configuration.settings.intervalMs, 900);
  });

  test('loaded profiles are normalized and kept after profile edits', () async {
    final first = MultiPointProfile.defaultProfile().copyWith(id: 'first');
    final second = MultiPointProfile.defaultProfile().copyWith(id: 'second');
    final third = MultiPointProfile.defaultProfile().copyWith(id: 'third');

    var state = await store.saveProfileState(
      MultiPointProfileState(
        profiles: [first, second, third],
        activeProfileId: second.id,
        loadedProfiles: const [
          LoadedMultiPointProfile(
            profileId: 'missing',
            order: 1,
            isVisible: true,
          ),
          LoadedMultiPointProfile(
            profileId: 'third',
            order: 2,
            isVisible: false,
          ),
          LoadedMultiPointProfile(
            profileId: 'second',
            order: 3,
            isVisible: true,
          ),
          LoadedMultiPointProfile(
            profileId: 'first',
            order: 4,
            isVisible: true,
          ),
        ],
      ),
    );

    expect(state.loadedProfileIds, ['second', 'first']);

    state = await store.deleteProfile('second');

    expect(state.profiles.map((profile) => profile.id), ['first', 'third']);
    expect(state.loadedProfileIds, ['first']);
  });

  test('loaded profile button positions persist with loaded state', () async {
    final first = MultiPointProfile.defaultProfile().copyWith(id: 'first');
    final second = MultiPointProfile.defaultProfile().copyWith(id: 'second');

    await store.saveProfileState(
      MultiPointProfileState(
        profiles: [first, second],
        activeProfileId: first.id,
        loadedProfiles: const [
          LoadedMultiPointProfile(
            profileId: 'first',
            order: 1,
            isVisible: true,
            buttonPositionX: 120,
            buttonPositionY: 240,
          ),
          LoadedMultiPointProfile(
            profileId: 'second',
            order: 2,
            isVisible: true,
            buttonPositionX: 320,
            buttonPositionY: 460,
          ),
        ],
      ),
    );

    final state = await store.loadProfileState();

    expect(state.loadedProfiles.first.buttonPositionX, 120);
    expect(state.loadedProfiles.first.buttonPositionY, 240);
    expect(state.loadedProfiles.last.buttonPositionX, 320);
    expect(state.loadedProfiles.last.buttonPositionY, 460);
  });

  test('hidden loaded profile keeps button position for reload', () async {
    final first = MultiPointProfile.defaultProfile().copyWith(id: 'first');
    final second = MultiPointProfile.defaultProfile().copyWith(id: 'second');

    final state = await store.saveProfileState(
      MultiPointProfileState(
        profiles: [first, second],
        activeProfileId: first.id,
        loadedProfiles: const [
          LoadedMultiPointProfile(
            profileId: 'first',
            order: 1,
            isVisible: true,
          ),
          LoadedMultiPointProfile(
            profileId: 'second',
            order: 2,
            isVisible: false,
            buttonPositionX: 333,
            buttonPositionY: 444,
          ),
        ],
      ),
    );

    expect(state.loadedProfileIds, ['first']);
    final hiddenProfile = state.loadedProfiles.firstWhere(
      (loadedProfile) => loadedProfile.profileId == 'second',
    );
    expect(hiddenProfile.isVisible, isFalse);
    expect(hiddenProfile.buttonPositionX, 333);
    expect(hiddenProfile.buttonPositionY, 444);
  });

  test('bad loaded profiles json falls back to active profile', () async {
    SharedPreferences.setMockInitialValues({
      MultiPointSettingsStore.loadedProfileIdsJsonKey: '{bad-json',
    });

    final state = await store.loadProfileState();

    expect(state.loadedProfileIds, [state.activeProfileId]);
  });

  test('profile management keeps one profile and syncs legacy keys', () async {
    var state = await store.createProfile(name: '操作');
    expect(state.profiles, hasLength(2));
    expect(state.activeProfile.name, '操作');

    state = await store.copyProfile(state.activeProfileId);
    expect(state.profiles, hasLength(3));
    expect(state.activeProfile.name, '操作 副本');

    state = await store.renameProfile(state.activeProfileId, '操作副本改名');
    expect(state.activeProfile.name, '操作副本改名');

    final copiedProfileId = state.activeProfileId;
    state = await store.deleteProfile(copiedProfileId);
    expect(state.profiles, hasLength(2));
    expect(state.activeProfileId, isNot(copiedProfileId));

    state = await store.deleteProfile(state.profiles.last.id);
    state = await store.deleteProfile(state.profiles.single.id);
    expect(state.profiles, hasLength(1));

    await store.saveConfiguration(
      state.activeProfile.configuration.copyWith(
        settings: MultiPointSettings.defaults.copyWith(intervalMs: 730),
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt(MultiPointSettingsStore.intervalMsKey), 730);
  });

  test('bad profiles json falls back to default profile', () async {
    SharedPreferences.setMockInitialValues({
      MultiPointSettingsStore.profilesJsonKey: '{bad-json',
    });

    final state = await store.loadProfileState();

    expect(state.profiles, hasLength(1));
    expect(state.activeProfile.name, '默认配置');
    expect(state.activeProfile.targets.values, [
      MultiPointTarget.defaultFirstTarget,
      MultiPointTarget.defaultSecondTarget,
    ]);
  });
}
