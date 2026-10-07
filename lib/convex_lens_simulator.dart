// 凸透鏡模擬器：箭頭物體/點光源/平行光源
// 物體可在平面內自由移動，光源可調節光線密度與方向
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/audio_util.dart';
import 'utils/optics_core.dart' as op;

enum ObjectMode { arrow, pointSource, parallelSource }

class ConvexLensSimulatorPage extends StatefulWidget {
  const ConvexLensSimulatorPage({super.key});

  @override
  State<ConvexLensSimulatorPage> createState() =>
      _ConvexLensSimulatorPageState();
}

class _ConvexLensSimulatorPageState extends State<ConvexLensSimulatorPage> {
  // 物理參數
  double _f = 180.0; // 凸透鏡焦距(正值)
  double _lensHalfHeight = 130.0; // 透鏡半高
  ObjectMode _mode = ObjectMode.arrow;
  // 箭頭物體（物理坐標：透鏡中心為原點，x 向右，y 向上）
  double _objX = -240.0; // 箭頭底部 x
  double _objY = 0.0; // 箭頭底部 y（在軸上）
  double _objH = 70.0; // 箭頭高度
  // 點光源
  double _ptX = -240.0;
  double _ptY = 40.0;
  int _ptRayCount = 15;
  double _ptSpread = math.pi; // 發散角
  double _ptDir = 0.0; // 中心方向角
  // 平行光源
  double _plCenterX = -300.0;
  double _plCenterY = 0.0;
  int _plRayCount = 13;
  double _plBeamWidth = 160.0;
  double _plDirection = 0.0; // 0 = 水平向右

  // 畫布狀態
  double _pixelPerUnit = 1.0;
  double _viewOffsetX = 0.0;
  double _viewOffsetY = 0.0;
  Size _canvasSize = Size.zero;
  bool _firstLayout = true;

  // 拖拽狀態
  String _dragTarget = "NONE"; // LENS / OBJECT / NONE
  Offset _dragLast = Offset.zero;

  bool _fullscreen = false;

  late TextEditingController _fCtrl;
  late TextEditingController _objHCtrl;
  late TextEditingController _ptRCtrl;
  late TextEditingController _plRCtrl;

  @override
  void initState() {
    super.initState();
    _fCtrl = TextEditingController(text: "${_f.toInt()}");
    _objHCtrl = TextEditingController(text: "${_objH.toInt()}");
    _ptRCtrl = TextEditingController(text: "$_ptRayCount");
    _plRCtrl = TextEditingController(text: "$_plRayCount");
  }

  @override
  void dispose() {
    _fCtrl.dispose();
    _objHCtrl.dispose();
    _ptRCtrl.dispose();
    _plRCtrl.dispose();
    super.dispose();
  }

  // 坐標轉換：畫布 → 物理
  op.Vec2 screenToPhys(Offset p) {
    final cx = _canvasSize.width / 2 + _viewOffsetX;
    final cy = _canvasSize.height / 2 + _viewOffsetY;
    return op.Vec2((p.dx - cx) / _pixelPerUnit, -(p.dy - cy) / _pixelPerUnit);
  }

  // 物理 → 畫布
  Offset physToScreen(op.Vec2 v) {
    final cx = _canvasSize.width / 2 + _viewOffsetX;
    final cy = _canvasSize.height / 2 + _viewOffsetY;
    return Offset(cx + v.x * _pixelPerUnit, cy - v.y * _pixelPerUnit);
  }

  void _autoFit() {
    // 讓 -3f 到 +3f 的範圍能顯示
    final physW = _f * 7;
    final physH = _f * 3;
    final sx = _canvasSize.width / physW;
    final sy = _canvasSize.height / physH;
    _pixelPerUnit = math.min(sx, sy);
    if (_pixelPerUnit > 1.5) _pixelPerUnit = 1.5;
    if (_pixelPerUnit < 0.15) _pixelPerUnit = 0.15;
    _viewOffsetX = 0;
    _viewOffsetY = 0;
  }

  op.ThinLensItem get _lens => op.ThinLensItem(
        id: "lens",
        center: const op.Vec2(0, 0),
        height: _lensHalfHeight * 2,
        f: _f,
      );

  op.ArrowItem? get _arrowItem {
    if (_mode != ObjectMode.arrow) return null;
    return op.ArrowItem(
      id: "obj",
      base: op.Vec2(_objX, _objY),
      tip: op.Vec2(_objX, _objY + _objH),
    );
  }

  // 箭頭模式：計算成像
  op.LensImageResult? get _arrowResult {
    final a = _arrowItem;
    if (a == null) return null;
    return op.computeThinLensImage(_lens, a);
  }

  // 凸透鏡虛像延長線：用於顯示虛線（出射光線的反向延長線相交於虛像點）
  List<List<op.Vec2>> get _virtualExtensions {
    if (_mode != ObjectMode.arrow) return [];
    final lens = _lens;
    final tip = op.Vec2(_objX, _objY + _objH);
    final res = _arrowResult;
    if (res == null || res.isReal) return [];
    final imageTip = res.imageTip;
    final segLens = lens.edges.first;
    final lines = <List<op.Vec2>>[];
    // 三條特殊光線（與 _tracedRays 完全對應）：方向朝向透鏡
    final objOnLeft = _objX < 0;
    final frontF = op.Vec2(objOnLeft ? -_f : _f, 0); // 物側焦點（入射側）
    final axisDir = objOnLeft ? const op.Vec2(1, 0) : const op.Vec2(-1, 0);
    // 第三條：經過物側焦點的直線（從 tip 出發，要朝向透鏡）
    // 直線通過 tip 和 frontF，方向與 axisDir 同號（朝向透鏡）
    var dir3 = frontF - tip;
    if (dir3.dot(axisDir) < 0) dir3 = dir3 * -1;
    final threeRays = [
      op.Ray2(tip, axisDir),
      op.Ray2(tip, (const op.Vec2(0, 0) - tip).normalized),
      op.Ray2(tip, dir3.normalized),
    ];
    for (int i = 0; i < threeRays.length; i++) {
      final hit = segLens.rayIntersect(threeRays[i]);
      if (hit == null) continue;
      final outgoing = op.applyThinLens(lens, threeRays[i], hit.point);
      if (outgoing.isEmpty) continue;
      lines.add([hit.point, imageTip]);
    }
    return lines;
  }

  // 光源模式：生成所有射線並追蹤（只穿過透鏡）
  List<op.TracedRay> get _tracedRays {
    final lens = _lens;
    final rays = <op.Ray2>[];
    if (_mode == ObjectMode.pointSource) {
      final ps = op.PointSourceItem(
        id: "ps",
        position: op.Vec2(_ptX, _ptY),
        rayCount: _ptRayCount,
        centralAngleRad: _ptDir,
        spreadAngleRad: _ptSpread,
      );
      rays.addAll(ps.emitRays());
    } else if (_mode == ObjectMode.parallelSource) {
      final ps = op.ParallelSourceItem(
        id: "pl",
        startAnchor: op.Vec2(_plCenterX, _plCenterY),
        directionRad: _plDirection,
        beamWidth: _plBeamWidth,
        rayCount: _plRayCount,
      );
      rays.addAll(ps.emitRays());
    } else {
      // 箭頭模式：3 條代表光線（凸透鏡三規則）
      final tip = op.Vec2(_objX, _objY + _objH);
      final objOnLeft = _objX < 0;
      final axisDir = objOnLeft ? const op.Vec2(1, 0) : const op.Vec2(-1, 0);
      // 物側焦點：物在左是 F(-f,0)，物在右是 F'(f,0)
      final frontF = op.Vec2(objOnLeft ? -_f : _f, 0);
      // 1) 平行光軸入射
      rays.add(op.Ray2(tip, axisDir));
      // 2) 通過鏡心的光線（方向指向鏡心，天然朝向透鏡，因為 tip 與 (0,0) 在透鏡兩側/物側）
      rays.add(op.Ray2(tip, (const op.Vec2(0, 0) - tip).normalized));
      // 3) 經過物側焦點：直線通過 tip 與 frontF，方向選朝向透鏡的那一個
      // 即使物在焦內（u<f，tip 在 frontF 與透鏡之間），翻轉方向也能等效為"從焦點發出經過 tip"的光線
      var dir3 = frontF - tip;
      if (dir3.dot(axisDir) < 0) dir3 = dir3 * -1;
      rays.add(op.Ray2(tip, dir3.normalized));
    }

    final out = <op.TracedRay>[];
    for (final r in rays) {
      final pts = <op.Vec2>[r.origin];
      final seg = lens.edges.first;
      final hit = seg.rayIntersect(r);
      if (hit != null) {
        pts.add(hit.point);
        final outgoing = op.applyThinLens(lens, r, hit.point);
        if (outgoing.isNotEmpty) {
          pts.add(outgoing.first.origin + outgoing.first.direction * 2000);
        } else {
          pts.add(r.origin + r.direction * 2000);
        }
      } else {
        pts.add(r.origin + r.direction * 2000);
      }
      out.add(op.TracedRay(pts));
    }
    return out;
  }

  void _handlePanStart(DragStartDetails d) {
    final physP = screenToPhys(d.localPosition);
    if (_lens.hitTest(physP, tolerance: 16 / _pixelPerUnit)) {
      _dragTarget = "LENS";
    } else {
      if (_mode == ObjectMode.arrow) {
        final a = _arrowItem!;
        if (a.hitTest(physP, tolerance: 18 / _pixelPerUnit)) {
          _dragTarget = "OBJECT";
        }
      } else if (_mode == ObjectMode.pointSource) {
        final ps = op.PointSourceItem(id: "ps", position: op.Vec2(_ptX, _ptY));
        if (ps.hitTest(physP, tolerance: 20 / _pixelPerUnit)) {
          _dragTarget = "OBJECT";
        }
      } else {
        final ps = op.ParallelSourceItem(
          id: "pl",
          startAnchor: op.Vec2(_plCenterX, _plCenterY),
          beamWidth: _plBeamWidth,
        );
        if (ps.hitTest(physP, tolerance: 20 / _pixelPerUnit)) {
          _dragTarget = "OBJECT";
        }
      }
    }
    _dragLast = d.localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails d) {
    final dxPhys = d.delta.dx / _pixelPerUnit;
    final dyPhys = -d.delta.dy / _pixelPerUnit;

    if (_dragTarget == "LENS") {
      // 平移整個視圖（透鏡保持在中心，用視圖偏移實現觀察位置變化）
      setState(() {
        _viewOffsetX += d.delta.dx;
        _viewOffsetY += d.delta.dy;
      });
      return;
    }
    if (_dragTarget == "OBJECT") {
      setState(() {
        if (_mode == ObjectMode.arrow) {
          _objX += dxPhys;
          _objY += dyPhys;
        } else if (_mode == ObjectMode.pointSource) {
          _ptX += dxPhys;
          _ptY += dyPhys;
        } else {
          _plCenterX += dxPhys;
          _plCenterY += dyPhys;
        }
      });
    }
    _dragLast = d.localPosition;
  }

  void _handlePanEnd(_) {
    _dragTarget = "NONE";
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) return _buildFullscreen();
    final res = _arrowResult;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, width: 1.2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87, size: 18),
            onPressed: () async {
              await AudioUtil.playClick();
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
        title: const Text("CONVEX LENS LAB",
            style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12, width: 1.2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(Icons.center_focus_strong,
                  color: Colors.black87, size: 18),
              tooltip: "Refit View",
              onPressed: () async {
                await AudioUtil.playClick();
                setState(() {
                  _firstLayout = true;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            if (_firstLayout) {
              _canvasSize = Size(w - 48, h * 0.38);
              _autoFit();
              _firstLayout = false;
            }
            final narrow = w < 620;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topMetrics(res),
                  const SizedBox(height: 12),
                  _modeSelector(narrow),
                  const SizedBox(height: 12),
                  _canvasCard(),
                  const SizedBox(height: 12),
                  _paramsPanel(narrow, res),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(builder: (context, c) {
            if (_firstLayout ||
                _canvasSize.width != c.maxWidth ||
                _canvasSize.height != c.maxHeight) {
              _canvasSize = Size(c.maxWidth, c.maxHeight);
              _autoFit();
              _firstLayout = false;
            }
            return GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: CustomPaint(
                size: _canvasSize,
                painter: _LensSimPainter(
                  state: this,
                ),
              ),
            );
          }),
          Positioned(
            top: 36,
            right: 20,
            child: _exitFullscreenBtn(),
          ),
          Positioned(
            top: 36,
            left: 20,
            child: _titleBadge(),
          ),
        ],
      ),
    );
  }

  Widget _topMetrics(op.LensImageResult? r) {
    final metrics = <_Metric>[
      _Metric("f (FOCAL)", "${_f.toInt()}"),
      _Metric("2f", "${(2 * _f).toInt()}"),
    ];
    if (r != null && _mode == ObjectMode.arrow) {
      metrics.add(_Metric("u (OBJ)", "${r.u.toStringAsFixed(0)}"));
      metrics.add(
          _Metric("v (IMG)", r.v.isInfinite ? "∞" : r.v.toStringAsFixed(0)));
      metrics.add(_Metric(
          "MAG",
          r.magnification.isInfinite
              ? "∞"
              : r.magnification.abs().toStringAsFixed(2)));
    } else {
      metrics.add(_Metric("MODE", _modeName()));
      metrics.add(_Metric("RAYS", "${_currentRayCount()}"));
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1.2),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 10,
        runSpacing: 10,
        children: metrics.map((m) => _metricItem(m)).toList(),
      ),
    );
  }

  Widget _metricItem(_Metric m) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black38,
                  letterSpacing: 0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(m.value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111))),
        ],
      );

  String _modeName() {
    switch (_mode) {
      case ObjectMode.arrow:
        return "ARROW";
      case ObjectMode.pointSource:
        return "POINT SRC";
      case ObjectMode.parallelSource:
        return "PARALLEL";
    }
  }

  int _currentRayCount() {
    switch (_mode) {
      case ObjectMode.arrow:
        return 3;
      case ObjectMode.pointSource:
        return _ptRayCount;
      case ObjectMode.parallelSource:
        return _plRayCount;
    }
  }

  Widget _modeSelector(bool narrow) {
    final cards = [
      _ModeCard(
        icon: Icons.north,
        label: "ARROW",
        desc: "Arrow Object",
        selected: _mode == ObjectMode.arrow,
        accent: const Color(0xFF212121),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ObjectMode.arrow);
        },
      ),
      _ModeCard(
        icon: Icons.light_mode,
        label: "POINT",
        desc: "Point Source",
        selected: _mode == ObjectMode.pointSource,
        accent: const Color(0xFFFF6F00),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ObjectMode.pointSource);
        },
      ),
      _ModeCard(
        icon: Icons.linear_scale,
        label: "PARALLEL",
        desc: "Parallel Beam",
        selected: _mode == ObjectMode.parallelSource,
        accent: const Color(0xFF1565C0),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ObjectMode.parallelSource);
        },
      ),
    ];
    if (narrow) {
      return Column(children: cards);
    }
    return Row(children: [
      for (int i = 0; i < cards.length; i++) ...[
        Expanded(child: cards[i]),
        if (i != cards.length - 1) const SizedBox(width: 12),
      ],
    ]);
  }

  Widget _canvasCard() {
    return Stack(
      children: [
        GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            height: _canvasSize.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: _LensSimPainter(state: this),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () async {
              await AudioUtil.playClick();
              setState(() {
                _fullscreen = true;
                _firstLayout = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(2, 2))
                ],
              ),
              child: const Icon(Icons.fullscreen,
                  size: 20, color: Color(0xFF4A4A4A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paramsPanel(bool narrow, op.LensImageResult? res) {
    final List<Widget> paramCards = [];
    // 通用：焦距
    paramCards.add(_inputCard("FOCAL LENGTH (f)", _fCtrl, (v) {
      final val = double.tryParse(v) ?? 80;
      setState(() {
        _f = val.clamp(20, 500);
        _fCtrl.text = "${_f.toInt()}";
        _firstLayout = true;
      });
    }));

    if (_mode == ObjectMode.arrow) {
      paramCards.add(_inputCard("ARROW HEIGHT", _objHCtrl, (v) {
        final val = double.tryParse(v) ?? 40;
        setState(() {
          _objH = val.clamp(10, 200);
          _objHCtrl.text = "${_objH.toInt()}";
        });
      }));
    } else if (_mode == ObjectMode.pointSource) {
      paramCards.add(_inputCard("RAY DENSITY (count)", _ptRCtrl, (v) {
        final val = int.tryParse(v) ?? 15;
        setState(() {
          _ptRayCount = val.clamp(3, 60);
          _ptRCtrl.text = "$_ptRayCount";
        });
      }));
      paramCards.add(_sliderCard(
        "BEAM SPREAD",
        _ptSpread,
        0.1,
        math.pi * 2,
        (v) => setState(() => _ptSpread = v),
        format: (v) => "${(v * 180 / math.pi).toInt()}°",
      ));
    } else {
      paramCards.add(_inputCard("RAY DENSITY (count)", _plRCtrl, (v) {
        final val = int.tryParse(v) ?? 13;
        setState(() {
          _plRayCount = val.clamp(3, 60);
          _plRCtrl.text = "$_plRayCount";
        });
      }));
      paramCards.add(_sliderCard(
        "BEAM WIDTH",
        _plBeamWidth,
        40,
        400,
        (v) => setState(() => _plBeamWidth = v),
        format: (v) => "${v.toInt()}",
      ));
      paramCards.add(_sliderCard(
        "INCIDENT ANGLE",
        _plDirection,
        -math.pi / 2,
        math.pi / 2,
        (v) => setState(() => _plDirection = v),
        format: (v) => "${(v * 180 / math.pi).toStringAsFixed(1)}°",
      ));
    }

    final imageCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("IMAGE PROPERTIES",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          if (res != null && _mode == ObjectMode.arrow) ...[
            _propertyRow(
                "ORIENTATION",
                res.orientation,
                res.isInverted
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF388E3C)),
            const SizedBox(height: 8),
            _propertyRow("SIZE", res.sizeClass, const Color(0xFF455A64)),
            const SizedBox(height: 8),
            _propertyRow("TYPE", res.imageType,
                res.isReal ? const Color(0xFF2E7D32) : const Color(0xFF1565C0)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _mode == ObjectMode.arrow
                    ? "Drag arrow object across 2D plane; drag lens to pan view."
                    : "Drag the light source freely. Observe ray refraction and focal behavior.",
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.4),
              ),
            ),
        ],
      ),
    );

    if (narrow) {
      return Column(
        children: [
          ...paramCards.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: c,
              )),
          imageCard,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in paramCards) SizedBox(width: 240, child: c),
          ],
        ),
        const SizedBox(height: 12),
        imageCard,
      ],
    );
  }

  Widget _inputCard(
      String label, TextEditingController ctrl, ValueChanged<String> onSubmit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: onSubmit,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222222),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => onSubmit(ctrl.text),
                  child: const Text("SET",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderCard(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {required String Function(double) format}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 0.3)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(format(value),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: const Color(0xFF2E7D32),
            inactiveColor: Colors.black12,
            onChanged: (v) {
              setState(() => onChanged(v));
            },
          ),
        ],
      ),
    );
  }

  Widget _propertyRow(String label, String value, Color badgeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black45)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
        ),
      ],
    );
  }

  Widget _exitFullscreenBtn() {
    return GestureDetector(
      onTap: () async {
        await AudioUtil.playClick();
        setState(() {
          _fullscreen = false;
          _firstLayout = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.fullscreen_exit, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text("EXIT",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _titleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text("CONVEX LENS LAB",
          style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }
}

// ===== 模式切換卡片 =====
class _ModeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _ModeCard(
      {required this.icon,
      required this.label,
      required this.desc,
      required this.selected,
      required this.accent,
      required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapUp: (_) => setState(() => _hover = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: widget.selected
                    ? widget.accent.withValues(alpha: 0.6)
                    : Colors.black12,
                width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.06 : 0.01),
                blurRadius: _hover ? 10 : 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  color: widget.selected ? widget.accent : Colors.black38,
                  size: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.selected
                              ? widget.accent
                              : const Color(0xFF111111),
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(widget.desc,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 繪製器 =====
class _LensSimPainter extends CustomPainter {
  final _ConvexLensSimulatorPageState state;
  _LensSimPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    if (state._canvasSize == Size.zero) {
      state._canvasSize = size;
    }
    final cx = size.width / 2 + state._viewOffsetX;
    final cy = size.height / 2 + state._viewOffsetY;
    final ppu = state._pixelPerUnit;

    Offset phys2screen(op.Vec2 v) => Offset(cx + v.x * ppu, cy - v.y * ppu);

    // 背景格線（微弱）
    final gridPaint = Paint()
      ..color = const Color(0xFFF3F3F3)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1.4;
    final majorPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    final gridSpacing = _gridStep(ppu);
    final minX = (-cx / ppu).floorToDouble() - 1;
    final maxX = ((size.width - cx) / ppu).ceilToDouble() + 1;
    final minY = -((size.height - cy) / ppu).ceilToDouble() - 1;
    final maxY = (cy / ppu).floorToDouble() + 1;

    for (double x = minX; x <= maxX; x += gridSpacing) {
      final p = phys2screen(op.Vec2(x, 0));
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height),
          x.abs() % (state._f) < 0.01 ? majorPaint : gridPaint);
    }
    for (double y = minY; y <= maxY; y += gridSpacing) {
      final p = phys2screen(op.Vec2(0, y));
      canvas.drawLine(Offset(0, p.dy), Offset(size.width, p.dy),
          y.abs() % (state._f) < 0.01 ? majorPaint : gridPaint);
    }

    // 焦平面（虛線）
    final focalPlanePaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    _drawDashedLine(canvas, phys2screen(op.Vec2(state._f, minY * 1.2)),
        phys2screen(op.Vec2(state._f, maxY * 1.2)), focalPlanePaint);
    _drawDashedLine(canvas, phys2screen(op.Vec2(-state._f, minY * 1.2)),
        phys2screen(op.Vec2(-state._f, maxY * 1.2)), focalPlanePaint);

    // 主光軸
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), axisPaint);
    final axisText = TextPainter(
      text: const TextSpan(
          text: "PRINCIPAL AXIS",
          style: TextStyle(
              color: Colors.black38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    axisText.paint(canvas, Offset(size.width - axisText.width - 12, cy + 6));

    // 焦點標記
    _drawFocalMark(canvas, phys2screen(op.Vec2(state._f, 0)), "F'", cy);
    _drawFocalMark(canvas, phys2screen(op.Vec2(-state._f, 0)), "F", cy);
    _drawFocalMark(canvas, phys2screen(op.Vec2(2 * state._f, 0)), "2F'", cy,
        big: false);
    _drawFocalMark(canvas, phys2screen(op.Vec2(-2 * state._f, 0)), "2F", cy,
        big: false);

    // 透鏡
    _drawLens(canvas, phys2screen, state._lens);

    // 虛像延長虛線（凸透鏡 u<f 時的虛像）
    for (final seg in state._virtualExtensions) {
      if (seg.length < 2) continue;
      _drawDashedLine(
        canvas,
        phys2screen(seg[0]),
        phys2screen(seg[1]),
        Paint()
          ..color = const Color(0xFF1565C0).withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }

    // 光線
    for (final r in state._tracedRays) {
      final rayPaint = Paint()
        ..color = const Color(0xFFF44336).withValues(alpha: 0.75)
        ..strokeWidth = 1.5;
      for (int i = 0; i < r.points.length - 1; i++) {
        final a = phys2screen(r.points[i]);
        final b = phys2screen(r.points[i + 1]);
        canvas.drawLine(a, b, rayPaint);
      }
      if (r.points.length >= 2) {
        final endA = phys2screen(r.points[r.points.length - 2]);
        final endB = phys2screen(r.points[r.points.length - 1]);
        _drawArrowHead(canvas, endA, endB, const Color(0xFFF44336));
      }
    }

    // 箭頭模式：繪製物體和像
    if (state._mode == ObjectMode.arrow) {
      final a = state._arrowItem!;
      final res = state._arrowResult;
      _drawArrow(
        canvas,
        phys2screen(a.base),
        phys2screen(a.tip),
        const Color(0xFF212121),
        width: 3.0,
      );
      _labelText(canvas, phys2screen(a.tip) + const Offset(-30, -24), "OBJECT",
          const Color(0xFF212121));
      if (res != null) {
        final show = res.v.isFinite;
        // 修正：用物理坐標直接與 minX / maxX 比較（原邏輯坐標系混淆導致虛像不顯示）
        final insideX =
            res.imageTip.x >= minX - 50 && res.imageTip.x <= maxX + 50;
        final insideY =
            res.imageTip.y >= minY - 50 && res.imageTip.y <= maxY + 50;
        if (show && insideX && insideY) {
          final color =
              res.isReal ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
          if (!res.isReal) {
            // 虛像用虛線箭頭
            _drawDashedLine(
                canvas,
                phys2screen(res.imageBase),
                phys2screen(res.imageTip),
                Paint()
                  ..color = color
                  ..strokeWidth = 3);
            // 虛像也畫箭頭尖端
            _drawArrowHead(
              canvas,
              phys2screen(res.imageBase),
              phys2screen(res.imageTip),
              color,
            );
          } else {
            _drawArrow(canvas, phys2screen(res.imageBase),
                phys2screen(res.imageTip), color,
                width: 3.0, flip: res.isInverted);
          }
          _labelText(
              canvas,
              phys2screen(res.imageTip) +
                  Offset(res.isReal ? 8 : -40, res.isInverted ? 12 : -20),
              res.isReal ? "REAL IMAGE" : "VIRTUAL IMAGE",
              color);
        }
      }
    } else if (state._mode == ObjectMode.pointSource) {
      final p = phys2screen(op.Vec2(state._ptX, state._ptY));
      final paint = Paint()
        ..color = const Color(0xFFFF6F00)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 6, paint);
      canvas.drawCircle(
          p,
          10,
          Paint()
            ..color = const Color(0xFFFF6F00).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill);
      _labelText(canvas, p + const Offset(-24, -22), "POINT SOURCE",
          const Color(0xFFFF6F00));
    } else {
      // 平行光源：標記起點區域
      final src = op.ParallelSourceItem(
          id: "pl",
          startAnchor: op.Vec2(state._plCenterX, state._plCenterY),
          directionRad: state._plDirection,
          beamWidth: state._plBeamWidth);
      final seg = src.edges.first;
      final paint = Paint()
        ..color = const Color(0xFF1565C0)
        ..strokeWidth = 4;
      canvas.drawLine(phys2screen(seg.p1), phys2screen(seg.p2), paint);
      _labelText(canvas, phys2screen(src.startAnchor) + const Offset(-46, -20),
          "PARALLEL BEAM", const Color(0xFF1565C0));
    }
  }

  double _gridStep(double ppu) {
    const targetPixels = 60.0;
    final phys = targetPixels / ppu;
    // 選擇 10/20/50/100/200/500 階
    final steps = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0];
    return steps.firstWhere((s) => s >= phys, orElse: () => steps.last);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 6, double gap = 6}) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    final metrics = path.computeMetrics().first;
    var total = metrics.length;
    var start = 0.0;
    while (start < total) {
      final len = math.min(dash, total - start);
      final sub = metrics.extractPath(start, start + len);
      canvas.drawPath(sub, paint);
      start += dash + gap;
    }
  }

  void _drawFocalMark(Canvas canvas, Offset p, String label, double cy,
      {bool big = true}) {
    canvas.drawCircle(
        p,
        big ? 3.5 : 2.5,
        Paint()
          ..color = Colors.black45
          ..style = PaintingStyle.fill);
    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              color: Colors.black38,
              fontSize: big ? 12 : 10,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(p.dx - tp.width / 2, cy + 8));
  }

  void _drawLens(
      Canvas canvas, Offset Function(op.Vec2) toScr, op.ThinLensItem lens) {
    final top = toScr(lens.top);
    final bot = toScr(lens.bottom);
    final cx = toScr(lens.center).dx;
    final paint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    // 主體（橢圓弧兩側 + 直線中間）
    final h = (bot.dy - top.dy);
    final w = h * 0.08;
    final path = Path()
      ..moveTo(cx - w, top.dy)
      ..quadraticBezierTo(cx, top.dy + h * 0.05, cx + w, top.dy)
      ..lineTo(cx + w, bot.dy)
      ..quadraticBezierTo(cx, bot.dy - h * 0.05, cx - w, bot.dy)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2E7D32).withValues(alpha: 0.10)
          ..style = PaintingStyle.fill);
    // 頂底箭頭表示凸透鏡
    canvas.drawLine(Offset(cx - 8, top.dy), Offset(cx, top.dy + 10), paint);
    canvas.drawLine(Offset(cx + 8, top.dy), Offset(cx, top.dy + 10), paint);
    canvas.drawLine(Offset(cx - 8, bot.dy), Offset(cx, bot.dy - 10), paint);
    canvas.drawLine(Offset(cx + 8, bot.dy), Offset(cx, bot.dy - 10), paint);
  }

  void _drawArrow(Canvas canvas, Offset base, Offset tip, Color color,
      {double width = 3.0, bool flip = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, paint);
    // 箭頭頭部（朝向 tip）
    final dx = tip.dx - base.dx;
    final dy = tip.dy - base.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    final px = -uy;
    final py = ux;
    final headLen = math.min(14.0, len * 0.3);
    final h1 = Offset(tip.dx - ux * headLen + px * headLen * 0.45,
        tip.dy - uy * headLen + py * headLen * 0.45);
    final h2 = Offset(tip.dx - ux * headLen - px * headLen * 0.45,
        tip.dy - uy * headLen - py * headLen * 0.45);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(h1.dx, h1.dy)
      ..lineTo(h2.dx, h2.dy)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _drawArrowHead(Canvas canvas, Offset a, Offset b, Color color) {
    _drawArrow(canvas, a, b, color, width: 1.2);
  }

  void _labelText(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _LensSimPainter old) => true;
}

class _Metric {
  final String label;
  final String value;
  _Metric(this.label, this.value);
}
