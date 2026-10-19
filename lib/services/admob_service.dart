import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Kid-Safe AdMob Service adhering strictly to COPPA & Google Play Families Policy.
/// Configured for AdMob App ID: ca-app-pub-2532203580078870~1709736639
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  /// Your AdMob Application ID (Configured in AndroidManifest.xml and Info.plist)
  static const String appId = 'ca-app-pub-2532203580078870~1709736639';

  /// Your AdMob Ad Unit ID (Configured for Interstitial/Rewarded Video Ads)
  static const String liveAdUnitId = 'ca-app-pub-2532203580078870/7760139668';

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // In debug/development, always use Google's official test IDs to avoid policy violations.
  // In release builds, it automatically switches to your live Ad Unit ID: ca-app-pub-2532203580078870/7760139668
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return liveAdUnitId;
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    // Live Ad Unit configured: ca-app-pub-2532203580078870/7760139668
    return liveAdUnitId;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    // Live Ad Unit configured: ca-app-pub-2532203580078870/7760139668
    return liveAdUnitId;
  }

  /// Initialize Google Mobile Ads SDK with MANDATORY Child-Directed Treatment.
  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await MobileAds.instance.initialize();

    // CRITICAL FOR COPPA & GOOGLE PLAY FAMILIES:
    // 1. tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes
    // 2. tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes
    // 3. maxAdContentRating: MaxAdContentRating.g (General Audiences Only)
    final RequestConfiguration requestConfiguration = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      maxAdContentRating: MaxAdContentRating.g,
      testDeviceIds: <String>['TEST_DEVICE_ID'], // Add developer test device IDs
    );

    await MobileAds.instance.updateRequestConfiguration(requestConfiguration);
    debugPrint('[AdMob] Child-Directed Treatment (COPPA) configured for App ID: $appId');

    // Pre-load initial ads
    loadInterstitialAd();
    loadRewardedAd();
  }

  /// Create kid-compliant AdRequest without personalized identifiers
  AdRequest get _kidSafeAdRequest => const AdRequest(
    // In child-directed mode, Google automatically drops personal identifiers,
    // IDFA/AAID, and behavioral cookies.
    nonPersonalizedAds: true,
  );

  /// Load Interstitial Ad (shown only at natural game pauses/game over, NEVER during tapping)
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: _kidSafeAdRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('[AdMob] Interstitial loaded.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('[AdMob] Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Show Interstitial Ad (e.g. on Game Over)
  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (_interstitialAd == null) {
      debugPrint('[AdMob] Interstitial not ready yet.');
      onDismissed?.call();
      loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  /// Load Rewarded Video Ad (e.g., watch cartoon ad for extra hearts)
  void loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: _kidSafeAdRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('[AdMob] Rewarded Ad loaded.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('[AdMob] Rewarded Ad failed to load: $error');
        },
      ),
    );
  }

  /// Show Rewarded Video Ad with kid-friendly reward callback
  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdClosed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('[AdMob] Rewarded Ad not ready.');
      onAdClosed?.call();
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdClosed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('[AdMob] User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      },
    );
  }
}
