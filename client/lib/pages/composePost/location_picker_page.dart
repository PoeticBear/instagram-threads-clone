import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

/// 地图选址结果：弹层关闭时返回给 ComposePost。
class PickedLocation {
  final String name;
  final double latitude;
  final double longitude;

  const PickedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// 全屏地图选址页。
///
/// - pin 固定在屏幕中央，拖动地图 → 中心点变化 → 反查地名（防抖 400ms）
/// - 点 [Confirm] 把 (name, latitude, longitude) 透传给上游
/// - 不调用系统定位权限：首次进入默认北京，缩放 4
class LocationPickerPage extends StatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final String? initialName;

  const LocationPickerPage({
    super.key,
    this.initialCenter,
    this.initialZoom = 4,
    this.initialName,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // 默认中心点：北京
  static const LatLng _fallbackCenter = LatLng(39.9042, 116.4074);
  // 拿到用户位置后跳到的缩放级别（街道尺度）
  static const double _userLocatedZoom = 15;

  late LatLng _center;
  late double _zoom;
  final MapController _mapController = MapController();
  Timer? _debounce;
  int _requestSeq = 0;

  String _address = '';
  bool _loadingAddress = false;
  // 首次打开 picker 时是否仍在尝试获取用户当前位置
  bool _locatingUser = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? _fallbackCenter;
    _zoom = widget.initialZoom;
    _address = widget.initialName ?? '';
    if (widget.initialCenter != null) {
      // 草稿回填：立刻反查
      _reverseGeocode(_center);
    } else {
      // 首次打开：尝试定位到用户当前位置
      _locatingUser = true;
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapMoved(LatLng newCenter, double newZoom) {
    _center = newCenter;
    _zoom = newZoom;
    // 防抖：400ms 后再反查，避免拖动时疯狂请求
    _debounce?.cancel();
    setState(() => _loadingAddress = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _reverseGeocode(newCenter);
    });
  }

  /// 申请定位权限并获取一次当前位置。
  ///
  /// 失败（被拒 / 服务关 / 超时）一律静默回退，不弹任何错误：
  /// 用户仍能在默认中心点（北京）上选点。
  /// 拿到合法坐标后，平滑把地图中心点跳过去并立即反查地址。
  Future<void> _getCurrentLocation() async {
    try {
      // 1. 权限：未申请过则请求，已拒绝/永久拒绝则放弃（不骚扰用户）
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          developer.log('location permission not granted',
              name: 'LocationPicker');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // 2. 系统级定位服务必须打开
      if (!await Geolocator.isLocationServiceEnabled()) {
        developer.log('location service disabled', name: 'LocationPicker');
        return;
      }

      // 3. 取一次定位（中等精度 + 8s 超时，避免长时间等待）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;

      // 4. 拒绝 (0,0) 之类的「未初始化」假值
      if (position.latitude == 0 && position.longitude == 0) {
        developer.log('got 0,0 position, skip', name: 'LocationPicker');
        return;
      }

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = newCenter;
        _zoom = _userLocatedZoom;
      });
      // 平滑移动地图 + 立刻反查
      _mapController.move(newCenter, _userLocatedZoom);
      _reverseGeocode(newCenter);
    } catch (e) {
      // 任何异常（iOS 拒绝弹窗、定位失败、超时）都静默吃掉
      developer.log('getCurrentLocation failed: $e', name: 'LocationPicker');
    } finally {
      if (mounted) {
        setState(() => _locatingUser = false);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng ll) async {
    final seq = ++_requestSeq;
    try {
      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (!mounted || seq != _requestSeq) return;
      if (marks.isEmpty) {
        setState(() {
          _address = AppLocalizations.of(context)!.unknownLocation;
          _loadingAddress = false;
        });
        return;
      }
      final p = marks.first;
      // 拼接「街道, 城市, 国家」非空部分
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty) p.name!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.country ?? '').isNotEmpty) p.country!,
      ];
      final name = parts.join(', ');
      setState(() {
        _address =
            name.isEmpty ? AppLocalizations.of(context)!.unknownLocation : name;
        _loadingAddress = false;
      });
    } catch (e) {
      developer.log('reverseGeocode failed: $e', name: 'LocationPicker');
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _address = AppLocalizations.of(context)!.unknownLocation;
        _loadingAddress = false;
      });
    }
  }

  void _confirm() {
    // 若确认时仍在加载中，以最后一次成功结果为准（取非 loading 的 _address）
    if (_loadingAddress) {
      _debounce?.cancel();
    }
    Navigator.of(context).pop(PickedLocation(
      name: _address.isEmpty
          ? AppLocalizations.of(context)!.unknownLocation
          : _address,
      latitude: _center.latitude,
      longitude: _center.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: appColors.background,
        elevation: 0,
        leading: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Icons.arrow_back_ios_new,
              color: appColors.textPrimary, size: 20),
        ),
        title: Text(
          l10n.selectLocation,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 地图区域
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _zoom,
                      minZoom: 2,
                      maxZoom: 18,
                      onPositionChanged: (position, hasGesture) {
                        // 仅当用户主动拖动时反查，避免初始化时多余请求
                        if (hasGesture) {
                          _onMapMoved(position.center, position.zoom);
                        }
                      },
                    ),
                    children: [
                      // 高德（Amap）瓦片源：国内可达，免 API Key，中文标签
                      // - {s} 子域名轮询 1~4 做负载均衡
                      // - style=8 为标准矢量地图样式
                      // - 不需要 userAgentPackageName（高德 UA 校验较弱）
                      TileLayer(
                        urlTemplate:
                            'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                        subdomains: const ['1', '2', '3', '4'],
                        // 瓦片加载失败时显示的占位图（白底带斜线）
                        errorTileCallback: (tile, error, stackTrace) {
                          developer.log(
                            'tile load failed: $error',
                            name: 'LocationPicker',
                          );
                        },
                      ),
                      // 高德要求在地图角落显示署名
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© 高德地图'),
                        ],
                      ),
                    ],
                  ),
                ),
                // 顶部「正在定位」提示（首次打开 picker 时短暂出现）
                if (_locatingUser)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CupertinoActivityIndicator(radius: 8),
                            const SizedBox(width: 8),
                            Text(
                              l10n.locatingAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: appColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 固定在屏幕中央的 pin
                const Center(
                  child: Padding(
                    // 把 pin 视觉锚点往下移一点（图标底部尖端对齐中心点）
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ),
                // 底部地址卡片（浮在地图上方）
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: appColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.location,
                          size: 20,
                          color: appColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _loadingAddress
                              ? Text(
                                  l10n.locatingAddress,
                                  style: TextStyle(
                                    color: appColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                )
                              : Text(
                                  _address.isEmpty
                                      ? l10n.unknownLocation
                                      : _address,
                                  style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 确认按钮（底部 SafeArea）
          Container(
            color: appColors.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton.filled(
                  padding: EdgeInsets.zero,
                  onPressed: _confirm,
                  child: Text(
                    l10n.confirmLocation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
