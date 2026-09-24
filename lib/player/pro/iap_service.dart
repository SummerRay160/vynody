import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:oktoast/oktoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vynody/player/pro/app_channel.dart';
import 'package:vynody/player/pro/pro_license_service.dart';
import 'package:vynody/utils/localized_text.dart';

/// Product ID configured in App Store Connect.
const String kProLifetimeProductId = 'com.vynody.pro_lifetime';

/// State of In-App Purchase.
class IapState {
  const IapState({
    this.isAvailable = false,
    this.isLoadingProduct = false,
    this.isPurchasing = false,
    this.isRestoring = false,
    this.proProduct,
    this.errorMessage,
  });

  final bool isAvailable;
  final bool isLoadingProduct;
  final bool isPurchasing;
  final bool isRestoring;
  final ProductDetails? proProduct;
  final String? errorMessage;

  IapState copyWith({
    bool? isAvailable,
    bool? isLoadingProduct,
    bool? isPurchasing,
    bool? isRestoring,
    ProductDetails? proProduct,
    String? errorMessage,
    bool clearError = false,
  }) {
    return IapState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoadingProduct: isLoadingProduct ?? this.isLoadingProduct,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      proProduct: proProduct ?? this.proProduct,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Service managing In-App Purchases for Store releases.
class IapService extends ChangeNotifier {
  IapService(this._ref) {
    _init();
  }

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IapState _state = const IapState();
  IapState get state => _state;

  void _updateState(IapState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _init() async {
    // If GitHub release, Pro is always permanently unlocked, no need for IAP stream.
    if (AppChannel.isGitHubRelease) return;

    if (Platform.isWindows) {
      _updateState(_state.copyWith(isAvailable: true, isLoadingProduct: false));
      return;
    }

    // Listen to purchase events stream
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (dynamic error) {
        debugPrint('[IAP] Purchase stream error: $error');
        _updateState(_state.copyWith(
          isPurchasing: false,
          isRestoring: false,
          errorMessage: error.toString(),
        ));
      },
    );

    await loadProducts();
  }

  /// Query product details from App Store.
  Future<void> loadProducts() async {
    if (Platform.isWindows) return;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[IAP] Store is not available on this device');
        _updateState(_state.copyWith(isAvailable: false));
        return;
      }

      _updateState(_state.copyWith(isAvailable: true, isLoadingProduct: true));

      final ProductDetailsResponse response =
          await _iap.queryProductDetails({kProLifetimeProductId});

      if (response.error != null) {
        debugPrint('[IAP] Query products error: ${response.error?.message}');
        _updateState(_state.copyWith(
          isLoadingProduct: false,
          errorMessage: response.error?.message,
        ));
        return;
      }

      ProductDetails? matchedProduct;
      for (final product in response.productDetails) {
        if (product.id == kProLifetimeProductId) {
          matchedProduct = product;
          break;
        }
      }

      _updateState(_state.copyWith(
        isLoadingProduct: false,
        proProduct: matchedProduct,
        clearError: true,
      ));
    } catch (e) {
      debugPrint('[IAP] Failed to load products: $e');
      _updateState(_state.copyWith(
        isLoadingProduct: false,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Trigger buying the lifetime Pro product.
  Future<bool> buyPro() async {
    if (_state.isPurchasing) return false;

    if (Platform.isWindows) {
      try {
        const channel = MethodChannel('vynody/single_instance');
        final dynamic res = await channel.invokeMethod('purchaseStoreProduct', {
          'storeId': ProConfig.msStoreAddOnId,
        });
        if (res is Map && res['success'] == true) {
          await _ref.read(proLicenseServiceProvider).refreshLicense();
          showToast(currentAppL10n.iapPurchaseSuccess);
          return true;
        }
      } catch (e) {
        debugPrint('[IAP] Native MS Store purchase failed/skipped: $e');
      }

      // Fallback: Launch Microsoft Store PDP for the Add-on
      final storeUri = Uri.parse('ms-windows-store://pdp/?productid=${ProConfig.msStoreAddOnId}');
      try {
        if (await canLaunchUrl(storeUri)) {
          await launchUrl(storeUri);
        } else {
          final webUri = Uri.parse('https://apps.microsoft.com/detail/${ProConfig.msStoreAddOnId}');
          await launchUrl(webUri);
        }
        return true;
      } catch (e) {
        debugPrint('[IAP] buyPro Windows error: $e');
        showToast('唤起微软商店失败，请前往商店搜索购买');
        return false;
      }
    }

    // Ensure product details are loaded
    ProductDetails? product = _state.proProduct;
    if (product == null) {
      await loadProducts();
      product = _state.proProduct;
    }

    if (product == null) {
      showToast('无法连接应用商店获取商品信息，请检查网络后重试');
      return false;
    }

    _updateState(_state.copyWith(isPurchasing: true, clearError: true));

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        _updateState(_state.copyWith(isPurchasing: false));
      }
      return success;
    } catch (e) {
      debugPrint('[IAP] buyPro exception: $e');
      _updateState(_state.copyWith(
        isPurchasing: false,
        errorMessage: e.toString(),
      ));
      showToast('发起购买失败: $e');
      return false;
    }
  }

  DateTime? _lastSyncTime;

  /// Restore previously purchased items.
  Future<void> restorePurchases({bool silent = false}) async {
    if (_state.isRestoring || _state.isPurchasing) return;

    if (Platform.isWindows) {
      if (!silent) {
        _updateState(_state.copyWith(isRestoring: true, clearError: true));
      }
      try {
        await _ref.read(proLicenseServiceProvider).refreshLicense();
      } catch (_) {}
      if (!silent) {
        _updateState(_state.copyWith(isRestoring: false));
        showToast('已同步微软商店购买与授权状态');
      }
      return;
    }

    if (!silent) {
      _updateState(_state.copyWith(isRestoring: true, clearError: true));
    }

    try {
      await _iap.restorePurchases();
      // Note: restorePurchases triggers purchaseStream, where items are handled.
    } catch (e) {
      debugPrint('[IAP] restorePurchases exception: $e');
      if (!silent) {
        _updateState(_state.copyWith(
          isRestoring: false,
          errorMessage: e.toString(),
        ));
        showToast('恢复购买失败: $e');
      }
    } finally {
      if (!silent) {
        // Allow a brief delay for transactions to propagate before clearing restoring status
        Future.delayed(const Duration(seconds: 2), () {
          if (_state.isRestoring) {
            _updateState(_state.copyWith(isRestoring: false));
          }
        });
      }
    }
  }

  /// Silently check & sync purchases on app resume or after redeem sheet.
  Future<void> syncPurchasesSilently() async {
    if (AppChannel.isGitHubRelease) return;

    // Throttle to avoid duplicate requests within 6 seconds
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < const Duration(seconds: 6)) {
      return;
    }
    _lastSyncTime = now;

    try {
      debugPrint('[IAP] Silently syncing purchases on resume/redeem...');
      await restorePurchases(silent: true);
    } catch (e) {
      debugPrint('[IAP] Silent sync error: $e');
    }
  }

  /// Open the native store redemption interface or store redemption page.
  Future<void> redeemCode() async {
    if (AppChannel.isGitHubRelease) {
      showToast('当前版本无需兑换，所有 Pro 功能已完全开放');
      return;
    }

    if (Platform.isIOS) {
      try {
        final InAppPurchaseStoreKitPlatformAddition iosPlatform =
            _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatform.presentCodeRedemptionSheet();
        // Schedule silent syncs after presenting the sheet in case the user completes redemption
        Future.delayed(const Duration(seconds: 2), () => syncPurchasesSilently());
        Future.delayed(const Duration(seconds: 5), () => syncPurchasesSilently());
        return;
      } catch (e) {
        debugPrint('[IAP] presentCodeRedemptionSheet failed: $e');
      }
    }

    if (Platform.isMacOS) {
      // Direct deep link to Mac App Store redeem page
      final Uri macStoreUri = Uri.parse('macappstore://userAction=redeemCode');
      try {
        if (await canLaunchUrl(macStoreUri)) {
          await launchUrl(macStoreUri);
          return;
        }
      } catch (e) {
        debugPrint('[IAP] Launch macappstore redeem failed: $e');
      }

      final Uri webUri = Uri.parse('https://apps.apple.com/redeem');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      }
      return;
    }

    if (Platform.isWindows) {
      // Windows: Invoke native Microsoft Store redeem window
      final Uri storeUri = Uri.parse('ms-windows-store://redeem');
      try {
        if (await canLaunchUrl(storeUri)) {
          await launchUrl(storeUri);
          return;
        }
      } catch (e) {
        debugPrint('[IAP] Launch ms-windows-store redeem failed: $e');
      }

      final Uri fallbackUri = Uri.parse('https://redeem.microsoft.com');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      }
      return;
    }

    if (Platform.isAndroid) {
      final Uri playStoreUri = Uri.parse('https://play.google.com/redeem');
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
      return;
    }
  }

  /// Handle incoming purchase details from the stream.
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('[IAP] Purchase update: ${purchaseDetails.productID} -> ${purchaseDetails.status}');

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _updateState(_state.copyWith(isPurchasing: true));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchaseDetails.productID == kProLifetimeProductId) {
            // Unlock Pro license
            await _ref.read(proLicenseServiceProvider).setPurchased(true);
            showToast(purchaseDetails.status == PurchaseStatus.restored
                ? currentAppL10n.iapRestoreSuccess
                : currentAppL10n.iapPurchaseSuccess);
          }

          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }

          _updateState(_state.copyWith(
            isPurchasing: false,
            isRestoring: false,
            clearError: true,
          ));
          break;

        case PurchaseStatus.error:
          debugPrint('[IAP] Purchase error: ${purchaseDetails.error?.message}');
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          _updateState(_state.copyWith(
            isPurchasing: false,
            isRestoring: false,
            errorMessage: purchaseDetails.error?.message,
          ));
          if (purchaseDetails.error?.message != null) {
            showToast(currentAppL10n.iapPurchaseCancelledOrFailed(purchaseDetails.error!.message));
          }
          break;

        case PurchaseStatus.canceled:
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          _updateState(_state.copyWith(
            isPurchasing: false,
            isRestoring: false,
          ));
          break;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for [IapService].
final iapServiceProvider = ChangeNotifierProvider<IapService>((ref) {
  return IapService(ref);
});

/// Riverpod provider for [IapState].
final iapStateProvider = Provider<IapState>((ref) {
  final service = ref.watch(iapServiceProvider);
  return service.state;
});
