import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/core_providers.dart';
import 'package:hiddify/core/prefs/prefs.dart';
import 'package:hiddify/core/router/routes/routes.dart';
import 'package:hiddify/domain/failures.dart';
import 'package:hiddify/domain/profiles/profiles.dart';
import 'package:hiddify/features/common/confirmation_dialogs.dart';
import 'package:hiddify/features/profiles/notifier/notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';

class ProfileTile extends HookConsumerWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    this.isMain = false,
  });

  final Profile profile;

  /// home screen active profile card
  final bool isMain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final selectActiveMutation = useMutation(
      initialOnFailure: (err) {
        CustomToast.error(t.presentShortError(err)).show(context);
      },
      initialOnSuccess: () {
        if (context.mounted) context.pop();
      },
    );

    final subInfo = switch (profile) {
      RemoteProfile(:final subInfo) => subInfo,
      _ => null,
    };

    final effectiveMargin = isMain
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.only(left: 12, right: 12, bottom: 12);
    final double effectiveElevation = profile.active ? 12 : 4;
    final effectiveOutlineColor =
        profile.active ? theme.colorScheme.outlineVariant : Colors.transparent;

    return Card(
      margin: effectiveMargin,
      elevation: effectiveElevation,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: effectiveOutlineColor),
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.transparent,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile is RemoteProfile || !isMain) ...[
              SizedBox(
                width: 48,
                child: Semantics(
                  sortKey: const OrdinalSortKey(1),
                  child: ProfileActionButton(profile, !isMain),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: effectiveOutlineColor,
              ),
            ],
            Expanded(
              child: Semantics(
                button: true,
                sortKey: isMain ? const OrdinalSortKey(0) : null,
                focused: isMain,
                liveRegion: isMain,
                namesRoute: isMain,
                label: isMain ? t.profile.activeProfileBtnSemanticLabel : null,
                child: InkWell(
                  onTap: () {
                    if (isMain) {
                      const ProfilesRoute().go(context);
                    } else {
                      if (selectActiveMutation.state.isInProgress) return;
                      if (profile.active) return;
                      selectActiveMutation.setFuture(
                        ref
                            .read(profilesNotifierProvider.notifier)
                            .selectActiveProfile(profile.id),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMain)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Material(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                      semanticsLabel: t.profile
                                          .activeProfileNameSemanticLabel(
                                        name: profile.name,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                            semanticsLabel: profile.active
                                ? t.profile.activeProfileNameSemanticLabel(
                                    name: profile.name,
                                  )
                                : t.profile.nonActiveProfileBtnSemanticLabel(
                                    name: profile.name,
                                  ),
                          ),
                        if (subInfo != null) ...[
                          const Gap(4),
                          RemainingTrafficIndicator(subInfo.ratio),
                          const Gap(4),
                          ProfileSubscriptionInfo(subInfo),
                          const Gap(4),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileActionButton extends HookConsumerWidget {
  const ProfileActionButton(this.profile, this.showAllActions, {super.key});

  final Profile profile;
  final bool showAllActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    final updateProfileMutation = useMutation(
      initialOnFailure: (err) {
        CustomAlertDialog.fromErr(
          t.presentError(err, action: t.profile.update.failureMsg),
        ).show(context);
      },
      initialOnSuccess: () =>
          CustomToast.success(t.profile.update.successMsg).show(context),
    );

    if (profile case RemoteProfile() when !showAllActions) {
      return Semantics(
        button: true,
        enabled: !updateProfileMutation.state.isInProgress,
        child: Tooltip(
          message: t.profile.update.tooltip,
          child: InkWell(
            onTap: () {
              if (updateProfileMutation.state.isInProgress) {
                return;
              }
              updateProfileMutation.setFuture(
                ref
                    .read(profilesNotifierProvider.notifier)
                    .updateProfile(profile as RemoteProfile),
              );
            },
            child: const Icon(Icons.update),
          ),
        ),
      );
    }
    return ProfileActionsMenu(
      profile,
      (context, controller, child) {
        return Semantics(
          button: true,
          child: Tooltip(
            message: MaterialLocalizations.of(context).showMenuTooltip,
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: const Icon(Icons.more_vert),
            ),
          ),
        );
      },
    );
  }
}

class ProfileActionsMenu extends HookConsumerWidget {
  const ProfileActionsMenu(this.profile, this.builder, {super.key, this.child});

  final Profile profile;
  final MenuAnchorChildBuilder builder;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    final updateProfileMutation = useMutation(
      initialOnFailure: (err) {
        CustomAlertDialog.fromErr(
          t.presentError(err, action: t.profile.update.failureMsg),
        ).show(context);
      },
      initialOnSuccess: () =>
          CustomToast.success(t.profile.update.successMsg).show(context),
    );
    final deleteProfileMutation = useMutation(
      initialOnFailure: (err) {
        CustomAlertDialog.fromErr(t.presentError(err)).show(context);
      },
    );

    return MenuAnchor(
      builder: builder,
      menuChildren: [
        if (profile case RemoteProfile())
          MenuItemButton(
            leadingIcon: const Icon(Icons.update),
            child: Text(t.profile.update.buttonTxt),
            onPressed: () {
              if (updateProfileMutation.state.isInProgress) {
                return;
              }
              updateProfileMutation.setFuture(
                ref
                    .read(profilesNotifierProvider.notifier)
                    .updateProfile(profile as RemoteProfile),
              );
            },
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit),
          child: Text(t.profile.edit.buttonTxt),
          onPressed: () async {
            await ProfileDetailsRoute(profile.id).push(context);
          },
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete),
          child: Text(t.profile.delete.buttonTxt),
          onPressed: () async {
            if (deleteProfileMutation.state.isInProgress) {
              return;
            }
            final deleteConfirmed = await showConfirmationDialog(
              context,
              title: t.profile.delete.buttonTxt,
              message: t.profile.delete.confirmationMsg,
            );
            if (deleteConfirmed) {
              deleteProfileMutation.setFuture(
                ref
                    .read(profilesNotifierProvider.notifier)
                    .deleteProfile(profile),
              );
            }
          },
        ),
      ],
      child: child,
    );
  }
}

// TODO add support url
class ProfileSubscriptionInfo extends HookConsumerWidget {
  const ProfileSubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  (String, Color?) remainingText(TranslationsEn t, ThemeData theme) {
    if (subInfo.isExpired) {
      return (t.profile.subscription.expired, theme.colorScheme.error);
    } else if (subInfo.ratio >= 1) {
      return (t.profile.subscription.noTraffic, theme.colorScheme.error);
    } else if (subInfo.remaining.inDays > 365) {
      return (t.profile.subscription.remainingDuration(duration: "∞"), null);
    } else {
      return (
        t.profile.subscription
            .remainingDuration(duration: subInfo.remaining.inDays),
        null,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final remaining = remainingText(t, theme);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            subInfo.total > 10 * 1099511627776 //10TB
                ? "∞ GiB"
                : subInfo.consumption.sizeOf(subInfo.total),
            semanticsLabel:
                t.profile.subscription.remainingTrafficSemanticLabel(
              consumed: subInfo.consumption.sizeGB(),
              total: subInfo.total.sizeGB(),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Text(
          remaining.$1,
          style: theme.textTheme.bodySmall?.copyWith(color: remaining.$2),
        ),
      ],
    );
  }
}

// TODO change colors
class RemainingTrafficIndicator extends StatelessWidget {
  const RemainingTrafficIndicator(this.ratio, {super.key});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final startColor = ratio < 0.25
        ? const Color.fromRGBO(93, 205, 251, 1.0)
        : ratio < 0.65
            ? const Color.fromRGBO(205, 199, 64, 1.0)
            : const Color.fromRGBO(241, 82, 81, 1.0);
    final endColor = ratio < 0.25
        ? const Color.fromRGBO(49, 146, 248, 1.0)
        : ratio < 0.65
            ? const Color.fromRGBO(98, 115, 32, 1.0)
            : const Color.fromRGBO(139, 30, 36, 1.0);

    return LinearPercentIndicator(
      percent: ratio,
      animation: true,
      padding: EdgeInsets.zero,
      lineHeight: 6,
      barRadius: const Radius.circular(16),
      linearGradient: LinearGradient(
        colors: [startColor, endColor],
      ),
    );
  }
}
