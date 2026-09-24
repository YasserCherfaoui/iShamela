import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

enum OtpMode { verify, reset }

/// SPEC-022 §3.5 — `/auth/otp?mode=verify|reset`
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.mode,
  });

  final String email;
  final OtpMode mode;

  static Future<void> open(
    BuildContext context, {
    required String email,
    required OtpMode mode,
  }) =>
      pushAuthPage(
        context,
        OtpScreen(email: email, mode: mode),
      );

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const _cooldown = Duration(seconds: 59);

  final _code = TextEditingController();
  late final AnimationController _shake;
  late final Animation<double> _shakeAnim;
  Timer? _timer;
  int _secondsLeft = _cooldown.inSeconds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _purpose =>
      widget.mode == OtpMode.verify ? 'verify' : 'reset';

  Future<void> _runMerge(AppLocalizations l10n) async {
    try {
      final db = await ref.read(stateDatabaseProvider.future);
      await ref.read(authProvider.notifier).mergeLocalAfterVerify(
            db,
            onProgress: (_) {
              final nav = appNavigatorKey.currentContext;
              if (nav != null) {
                showAuthSnack(nav, l10n.authSyncInProgress);
              }
            },
            onFailure: (_) {
              final nav = appNavigatorKey.currentContext;
              if (nav != null) {
                showAuthSnack(nav, l10n.authSyncFailed);
              }
            },
          );
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(
            email: widget.email,
            purpose: _purpose,
          );
      if (mounted) {
        showAuthSnack(context, l10n.authOtpResent);
        _startCooldown();
      }
    } catch (e) {
      if (mounted) showAuthSnack(context, localizeAuthError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(String code) async {
    if (code.length != 6 || _busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(authProvider.notifier).verifyOtp(
            email: widget.email,
            code: code,
            purpose: _purpose,
          );
      if (!mounted) return;
      if (widget.mode == OtpMode.verify) {
        // Background merge — never blocks reading (SPEC-022 §6).
        unawaited(_runMerge(l10n));
        if (!mounted) return;
        showAuthSnack(context, l10n.authWelcomeVerified);
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        if (!mounted) return;
        await ResetPasswordScreen.open(
          context,
          email: widget.email,
          resetToken: token ?? '',
        );
      }
    } catch (e) {
      final key = mapAuthErrorToMessageKey(e);
      setState(() {
        _error = localizeAuthError(l10n, e);
        _code.clear();
      });
      _shake.forward(from: 0);
      if (!mounted) return;
      if (key == 'authOtpExpired' || key == 'authOtpLocked') {
        showAuthSnack(context, localizeAuthError(l10n, e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final mm = (_secondsLeft ~/ 60).toString();
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    final resendTime = '$mm:$ss';
    final resendLead =
        l10n.authOtpResendIn(resendTime).replaceFirst(resendTime, '').trim();

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  AuthTopBar(
                    title: l10n.authOtpTitle,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: t.green100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mail_outline,
                        color: t.emphasis,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.authOtpPrompt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      height: 1.5,
                      color: t.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                );
              },
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _code,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  enableActiveFill: true,
                  autoDisposeControllers: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textStyle: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(14),
                    fieldHeight: 56,
                    fieldWidth: 46,
                    activeFillColor: t.card,
                    selectedFillColor: t.card,
                    inactiveFillColor: t.card,
                    activeColor: t.goldSoft,
                    selectedColor: t.goldSoft,
                    inactiveColor: t.hairline,
                    errorBorderColor: Theme.of(context).colorScheme.error,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onCompleted: _submit,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kFontUi,
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
                  const SizedBox(height: 18),
                  if (_secondsLeft > 0)
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 13,
                          color: t.muted,
                        ),
                        children: [
                          TextSpan(text: resendLead),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: resendTime,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    TextButton(
                      onPressed: _busy ? null : _resend,
                      child: Text(
                        l10n.authOtpResend,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w600,
                          color: t.green700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authOtpSpam,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 12,
                      height: 1.45,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  AuthPrimaryButton(
                    label: l10n.authOtpConfirm,
                    busy: _busy,
                    onPressed: () => _submit(_code.text),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.authChangeEmail,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
