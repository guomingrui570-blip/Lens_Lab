// 凹透鏡模擬器：與凸透鏡架構相同，但焦距恆為負值
// 成像規則：永遠是正立、縮小、虛像，像與物同側
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/audio_util.dart';
import 'utils/optics_core.dart' as op;

enum ConcaveObjectMode { arrow, pointSource, parallelSource }

class ConcaveLensSimulatorPage extends StatefulWidget {
  const ConcaveLensSimulatorPage({super.key});

  @override
  State<ConcaveLensSimulatorPage> createState() =>
      _ConcaveLensSimulatorPageState();
}

class _ConcaveLensSimulatorPageState extends State<ConcaveLensSimulatorPage> {
  // 凹透鏡參數（內部 f 存儲負值，但 UI 顯示其絕對值）
  double _fAbs = 180.0;
  double get _f => -_fAbs;
  double _lensHalfHeight = 130.0;
  ConcaveObjectMode _mode = ConcaveObjectMode.arrow;
  // 箭頭物體
  double _objX = -260.0;
  double _objY = 0.0;
  double _objH = 80.0;
  // 點光源
  double _ptX = -260.0;
  double _ptY = 40.0;
  int _ptRayCount = 15;
  double _ptSpread = math.pi;
  // 平行光源
  double _plCenterX = -320.0;
  double _plCenterY = 0.0;
  int _plRayCount = 13;
  double _plBeamWidth = 180.0;
  double _plDirection = 0.0;

  double _pixelPerUnit = 1.0;
  double _viewOffsetX = 0.0;
  double _viewOffsetY = 0.0;
  Size _canvasSize = Size.zero;
  bool _firstLayout = true;
  String _dragTarget = "NONE";
  bool _fullscreen = false;

  late TextEditingController _fCtrl;
  late TextEditingController _objHCtrl;
  late TextEditingController _ptRCtrl;
  late TextEditingController _plRCtrl;

  @override
  void initState() {
    super.initState();
    _fCtrl = TextEditingController(text: "${_fAbs.toInt()}");
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

  op.Vec2 screenToPhys(Offset p) {
    final cx = _canvasSize.width / 2 + _viewOffsetX;
    final cy = _canvasSize.height / 2 + _viewOffsetY;
    return op.Vec2((p.dx - cx) / _pixelPerUnit, -(p.dy - cy) / _pixelPerUnit);
  }

  void _autoFit() {
    final physW = _fAbs * 7;
    final physH = _fAbs * 3;
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
        f: _f, // 負值代表凹透鏡
      );

  op.ArrowItem? get _arrowItem {
    if (_mode != ConcaveObjectMode.arrow) return null;
    return op.ArrowItem(
      id: "obj",
      base: op.Vec2(_objX, _objY),
      tip: op.Vec2(_objX, _objY + _objH),
    );
  }

  op.LensImageResult? get _arrowResult {
    final a = _arrowItem;
    if (a == null) return null;
    return op.computeThinLensImage(_lens, a);
  }

  List<op.TracedRay> get _tracedRays {
    final lens = _lens;
    final rays = <op.Ray2>[];
    if (_mode == ConcaveObjectMode.pointSource) {
      final ps = op.PointSourceItem(
        id: "ps",
        position: op.Vec2(_ptX, _ptY),
        rayCount: _ptRayCount,
        spreadAngleRad: _ptSpread,
      );
      rays.addAll(ps.emitRays());
    } else if (_mode == ConcaveObjectMode.parallelSource) {
      final ps = op.ParallelSourceItem(
        id: "pl",
        startAnchor: op.Vec2(_plCenterX, _plCenterY),
        directionRad: _plDirection,
        beamWidth: _plBeamWidth,
        rayCount: _plRayCount,
      );
      rays.addAll(ps.emitRays());
    } else {
      // 箭頭模式：凹透鏡 3 條代表光線
      final tip = op.Vec2(_objX, _objY + _objH);
      final objOnLeft = _objX < 0;
      final axisDir = objOnLeft ? const op.Vec2(1, 0) : const op.Vec2(-1, 0);
      // 出射側虛焦點（凹透鏡的出射側虛焦點在入射側的相反方向，但入射光"朝向"它）
      // 物在左 → 出射向右 → 虛焦點在左側 F(_f,0)  _f<0
      // 物在右 → 出射向左 → 虛焦點在右側 F'(_fAbs,0)
      final outFocus = op.Vec2(objOnLeft ? _f : _fAbs, 0);
      // 1) 平行光軸入射
      rays.add(op.Ray2(tip, axisDir));
      // 2) 過鏡心（方向指向鏡心，天然朝向透鏡）
      rays.add(op.Ray2(tip, (const op.Vec2(0, 0) - tip).normalized));
      // 3) 出射方向看起來像從 outFocus 發出：入射光"朝向 outFocus"，
      //    直線通過 tip 和 outFocus，方向選朝向透鏡（與 axisDir 同號）
      var dir3 = outFocus - tip;
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
        }
      } else {
        pts.add(r.origin + r.direction * 2000);
      }
      out.add(op.TracedRay(pts));
    }
    return out;
  }

  // 凹透鏡虛像延長線：出射光線的反向延長線相交於虛像點
  List<List<op.Vec2>> get _virtualExtensions {
    if (_mode != ConcaveObjectMode.arrow) return [];
    final lens = _lens;
    final tip = op.Vec2(_objX, _objY + _objH);
    final res = _arrowResult;
    if (res == null) return [];
    final imageTip = res.imageTip;
    final objOnLeft = _objX < 0;
    final axisDir = objOnLeft ? const op.Vec2(1, 0) : const op.Vec2(-1, 0);
    final outFocus = op.Vec2(objOnLeft ? _f : _fAbs, 0);
    var dir3 = outFocus - tip;
    if (dir3.dot(axisDir) < 0) dir3 = dir3 * -1;
    final threeRays = [
      op.Ray2(tip, axisDir),
      op.Ray2(tip, (const op.Vec2(0, 0) - tip).normalized),
      op.Ray2(tip, dir3.normalized),
    ];
    final segLens = lens.edges.first;
    final lines = <List<op.Vec2>>[];
    for (int i = 0; i < threeRays.length; i++) {
      final hit = segLens.rayIntersect(threeRays[i]);
      if (hit == null) continue;
      final outgoing = op.applyThinLens(lens, threeRays[i], hit.point);
      if (outgoing.isEmpty) continue;
      lines.add([hit.point, imageTip]);
    }
    return lines;
  }

  void _handlePanStart(DragStartDetails d) {
    final physP = screenToPhys(d.localPosition);
    if (_lens.hitTest(physP, tolerance: 16 / _pixelPerUnit)) {
      _dragTarget = "LENS";
    } else {
      if (_mode == ConcaveObjectMode.arrow) {
        final a = _arrowItem!;
        if (a.hitTest(physP, tolerance: 18 / _pixelPerUnit)) {
          _dragTarget = "OBJECT";
        }
      } else if (_mode == ConcaveObjectMode.pointSource) {
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
  }

  void _handlePanUpdate(DragUpdateDetails d) {
    final dxPhys = d.delta.dx / _pixelPerUnit;
    final dyPhys = -d.delta.dy / _pixelPerUnit;
    if (_dragTarget == "LENS") {
      setState(() {
        _viewOffsetX += d.delta.dx;
        _viewOffsetY += d.delta.dy;
      });
      return;
    }
    if (_dragTarget == "OBJECT") {
      setState(() {
        if (_mode == ConcaveObjectMode.arrow) {
          _objX += dxPhys;
          _objY += dyPhys;
        } else if (_mode == ConcaveObjectMode.pointSource) {
          _ptX += dxPhys;
          _ptY += dyPhys;
        } else {
          _plCenterX += dxPhys;
          _plCenterY += dyPhys;
        }
      });
    }
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
        title: const Text("CONCAVE LENS LAB",
            style: TextStyle(
                color: Color(0xFF1565C0),
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
        child: LayoutBuilder(builder: (context, constraints) {
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
        }),
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
              onPanEnd: (_) => _dragTarget = "NONE",
              child: CustomPaint(
                size: _canvasSize,
                painter: _ConcaveLensPainter(state: this),
              ),
            );
          }),
          Positioned(
            top: 36,
            right: 20,
            child: _exitFsBtn(),
          ),
          Positioned(
            top: 36,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("CONCAVE LENS LAB",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMetrics(op.LensImageResult? r) {
    final metrics = <_Metric2>[
      _Metric2("f (MAG)", "${_fAbs.toInt()}"),
      _Metric2("2f", "${(2 * _fAbs).toInt()}"),
    ];
    if (r != null && _mode == ConcaveObjectMode.arrow) {
      metrics.add(_Metric2("u (OBJ)", "${r.u.toStringAsFixed(0)}"));
      metrics.add(_Metric2(
          "v (IMG)", r.v.abs().toStringAsFixed(0))); // v 為負值（虛像），顯示其絕對值
      metrics.add(_Metric2("|M|", r.magnification.abs().toStringAsFixed(2)));
    } else {
      metrics.add(_Metric2("MODE", _modeName()));
      metrics.add(_Metric2("RAYS", "${_currentRayCount()}"));
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
        children: metrics.map((m) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]);
        }).toList(),
      ),
    );
  }

  String _modeName() {
    switch (_mode) {
      case ConcaveObjectMode.arrow:
        return "ARROW";
      case ConcaveObjectMode.pointSource:
        return "POINT SRC";
      case ConcaveObjectMode.parallelSource:
        return "PARALLEL";
    }
  }

  int _currentRayCount() {
    switch (_mode) {
      case ConcaveObjectMode.arrow:
        return 3;
      case ConcaveObjectMode.pointSource:
        return _ptRayCount;
      case ConcaveObjectMode.parallelSource:
        return _plRayCount;
    }
  }

  Widget _modeSelector(bool narrow) {
    final cards = [
      _ModeCard2(
        icon: Icons.north,
        label: "ARROW",
        desc: "Arrow Object",
        selected: _mode == ConcaveObjectMode.arrow,
        accent: const Color(0xFF212121),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ConcaveObjectMode.arrow);
        },
      ),
      _ModeCard2(
        icon: Icons.light_mode,
        label: "POINT",
        desc: "Point Source",
        selected: _mode == ConcaveObjectMode.pointSource,
        accent: const Color(0xFFFF6F00),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ConcaveObjectMode.pointSource);
        },
      ),
      _ModeCard2(
        icon: Icons.linear_scale,
        label: "PARALLEL",
        desc: "Parallel Beam",
        selected: _mode == ConcaveObjectMode.parallelSource,
        accent: const Color(0xFF1565C0),
        onTap: () async {
          await AudioUtil.playClick();
          setState(() => _mode = ConcaveObjectMode.parallelSource);
        },
      ),
    ];
    if (narrow) return Column(children: cards);
    return Row(children: [
      for (int i = 0; i < cards.length; i++) ...[
        Expanded(child: cards[i]),
        if (i != cards.length - 1) const SizedBox(width: 12),
      ]
    ]);
  }

  Widget _canvasCard() {
    return Stack(
      children: [
        GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: (_) => _dragTarget = "NONE",
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
                painter: _ConcaveLensPainter(state: this),
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
    final cards = <Widget>[];
    cards.add(_inputCard("FOCAL LENGTH (|f|)", _fCtrl, (v) {
      final val = double.tryParse(v) ?? 80;
      setState(() {
        _fAbs = val.clamp(20, 500);
        _fCtrl.text = "${_fAbs.toInt()}";
        _firstLayout = true;
      });
    }));
    if (_mode == ConcaveObjectMode.arrow) {
      cards.add(_inputCard("ARROW HEIGHT", _objHCtrl, (v) {
        final val = double.tryParse(v) ?? 40;
        setState(() {
          _objH = val.clamp(10, 200);
          _objHCtrl.text = "${_objH.toInt()}";
        });
      }));
    } else if (_mode == ConcaveObjectMode.pointSource) {
      cards.add(_inputCard("RAY DENSITY (count)", _ptRCtrl, (v) {
        final val = int.tryParse(v) ?? 15;
        setState(() {
          _ptRayCount = val.clamp(3, 60);
          _ptRCtrl.text = "$_ptRayCount";
        });
      }));
      cards.add(_sliderCard("BEAM SPREAD", _ptSpread, 0.1, math.pi * 2,
          (v) => setState(() => _ptSpread = v),
          format: (v) => "${(v * 180 / math.pi).toInt()}°"));
    } else {
      cards.add(_inputCard("RAY DENSITY (count)", _plRCtrl, (v) {
        final val = int.tryParse(v) ?? 13;
        setState(() {
          _plRayCount = val.clamp(3, 60);
          _plRCtrl.text = "$_plRayCount";
        });
      }));
      cards.add(_sliderCard("BEAM WIDTH", _plBeamWidth, 40, 400,
          (v) => setState(() => _plBeamWidth = v),
          format: (v) => "${v.toInt()}"));
      cards.add(_sliderCard("INCIDENT ANGLE", _plDirection, -math.pi / 2,
          math.pi / 2, (v) => setState(() => _plDirection = v),
          format: (v) => "${(v * 180 / math.pi).toStringAsFixed(1)}°"));
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
          const Text("IMAGE PROPERTIES (CONCAVE)",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          if (res != null && _mode == ConcaveObjectMode.arrow) ...[
            _propertyRow(
                "ORIENTATION", "ALWAYS ERECT", const Color(0xFF388E3C)),
            const SizedBox(height: 8),
            _propertyRow("SIZE", res.sizeClass, const Color(0xFF455A64)),
            const SizedBox(height: 8),
            _propertyRow("TYPE", res.imageType, const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
              ),
              child: const Text(
                "Concave lenses always produce ERECT, DIMINISHED, VIRTUAL images on the same side as the object.",
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1565C0),
                    height: 1.4,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                "Drag the source or arrow freely. Drag lens to pan view. Rays always diverge after a concave lens.",
                style:
                    TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
              ),
            ),
        ],
      ),
    );

    if (narrow) {
      return Column(
        children: [
          ...cards.map((c) =>
              Padding(padding: const EdgeInsets.only(bottom: 12), child: c)),
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
          children: [for (final c in cards) SizedBox(width: 240, child: c)],
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
                        contentPadding: EdgeInsets.symmetric(vertical: 10)),
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
            activeColor: const Color(0xFF1565C0),
            inactiveColor: Colors.black12,
            onChanged: (v) => setState(() => onChanged(v)),
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
              color: badgeColor, borderRadius: BorderRadius.circular(4)),
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

  Widget _exitFsBtn() {
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
            color: Colors.black87, borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.fullscreen_exit, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text("EXIT",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold))
        ]),
      ),
    );
  }
}

class _Metric2 {
  final String label;
  final String value;
  _Metric2(this.label, this.value);
}

class _ModeCard2 extends StatefulWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _ModeCard2({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_ModeCard2> createState() => _ModeCard2State();
}

class _ModeCard2State extends State<_ModeCard2> {
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
                  offset: const Offset(0, 2))
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

// 凹透鏡繪製器：風格與凸透鏡類似，但使用藍色主題、凹透鏡形狀
class _ConcaveLensPainter extends CustomPainter {
  final _ConcaveLensSimulatorPageState state;
  _ConcaveLensPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + state._viewOffsetX;
    final cy = size.height / 2 + state._viewOffsetY;
    final ppu = state._pixelPerUnit;
    Offset p2s(op.Vec2 v) => Offset(cx + v.x * ppu, cy - v.y * ppu);

    final gridPaint = Paint()
      ..color = const Color(0xFFF3F3F3)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1.4;
    final majorPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    final step = _gridStep(ppu);
    final fAbs = state._fAbs;
    final minX = (-cx / ppu).floorToDouble() - 1;
    final maxX = ((size.width - cx) / ppu).ceilToDouble() + 1;
    final minY = -((size.height - cy) / ppu).ceilToDouble() - 1;
    final maxY = (cy / ppu).floorToDouble() + 1;

    for (double x = minX; x <= maxX; x += step) {
      final p = p2s(op.Vec2(x, 0));
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height),
          x.abs() % fAbs < 0.01 ? majorPaint : gridPaint);
    }
    for (double y = minY; y <= maxY; y += step) {
      final p = p2s(op.Vec2(0, y));
      canvas.drawLine(Offset(0, p.dy), Offset(size.width, p.dy),
          y.abs() % fAbs < 0.01 ? majorPaint : gridPaint);
    }

    // 焦平面
    final focalPlanePaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    _drawDashed(canvas, p2s(op.Vec2(fAbs, minY * 1.2)),
        p2s(op.Vec2(fAbs, maxY * 1.2)), focalPlanePaint);
    _drawDashed(canvas, p2s(op.Vec2(-fAbs, minY * 1.2)),
        p2s(op.Vec2(-fAbs, maxY * 1.2)), focalPlanePaint);

    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), axisPaint);

    // 焦點
    _drawMark(canvas, p2s(op.Vec2(fAbs, 0)), "F'", cy);
    _drawMark(canvas, p2s(op.Vec2(-fAbs, 0)), "F", cy);
    _drawMark(canvas, p2s(op.Vec2(2 * fAbs, 0)), "2F'", cy, big: false);
    _drawMark(canvas, p2s(op.Vec2(-2 * fAbs, 0)), "2F", cy, big: false);

    // 凹透鏡
    _drawConcave(canvas, p2s, state._lens);

    // 虛像延長虛線
    for (final seg in state._virtualExtensions) {
      if (seg.length < 2) continue;
      _drawDashed(
        canvas,
        p2s(seg[0]),
        p2s(seg[1]),
        Paint()
          ..color = const Color(0xFF1565C0).withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }

    // 光線
    for (final r in state._tracedRays) {
      final rayPaint = Paint()
        ..color = const Color(0xFF1976D2).withValues(alpha: 0.75)
        ..strokeWidth = 1.5;
      for (int i = 0; i < r.points.length - 1; i++) {
        canvas.drawLine(p2s(r.points[i]), p2s(r.points[i + 1]), rayPaint);
      }
      if (r.points.length >= 2) {
        _drawArrowHead(
          canvas,
          p2s(r.points[r.points.length - 2]),
          p2s(r.points[r.points.length - 1]),
          const Color(0xFF1976D2),
        );
      }
    }

    if (state._mode == ConcaveObjectMode.arrow) {
      final a = state._arrowItem!;
      _drawArrow(canvas, p2s(a.base), p2s(a.tip), const Color(0xFF212121), 3);
      _label(canvas, p2s(a.tip) + const Offset(-30, -24), "OBJECT",
          const Color(0xFF212121));
      final res = state._arrowResult;
      if (res != null && res.v.isFinite) {
        // 虛像一律用虛線
        _drawDashed(
          canvas,
          p2s(res.imageBase),
          p2s(res.imageTip),
          Paint()
            ..color = const Color(0xFF1565C0)
            ..strokeWidth = 3,
        );
        // 箭頭頂部
        _drawArrowHead(
          canvas,
          p2s(res.imageBase),
          p2s(res.imageTip),
          const Color(0xFF1565C0),
        );
        _label(canvas, p2s(res.imageTip) + const Offset(-56, -20),
            "VIRTUAL IMAGE", const Color(0xFF1565C0));
      }
    } else if (state._mode == ConcaveObjectMode.pointSource) {
      final p = p2s(op.Vec2(state._ptX, state._ptY));
      canvas.drawCircle(
          p,
          10,
          Paint()
            ..color = const Color(0xFFFF6F00).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = const Color(0xFFFF6F00)
            ..style = PaintingStyle.fill);
      _label(canvas, p + const Offset(-24, -22), "POINT SOURCE",
          const Color(0xFFFF6F00));
    } else {
      final src = op.ParallelSourceItem(
        id: "pl",
        startAnchor: op.Vec2(state._plCenterX, state._plCenterY),
        directionRad: state._plDirection,
        beamWidth: state._plBeamWidth,
      );
      final seg = src.edges.first;
      canvas.drawLine(
          p2s(seg.p1),
          p2s(seg.p2),
          Paint()
            ..color = const Color(0xFF1565C0)
            ..strokeWidth = 4);
      _label(canvas, p2s(src.startAnchor) + const Offset(-46, -20),
          "PARALLEL BEAM", const Color(0xFF1565C0));
    }
  }

  double _gridStep(double ppu) {
    const targetPixels = 60.0;
    final phys = targetPixels / ppu;
    final steps = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0];
    return steps.firstWhere((s) => s >= phys, orElse: () => steps.last);
  }

  void _drawDashed(Canvas c, Offset a, Offset b, Paint paint,
      {double dash = 6, double gap = 6}) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    final m = path.computeMetrics().first;
    var total = m.length;
    var start = 0.0;
    while (start < total) {
      final len = math.min(dash, total - start);
      final sub = m.extractPath(start, start + len);
      c.drawPath(sub, paint);
      start += dash + gap;
    }
  }

  void _drawMark(Canvas c, Offset p, String label, double cy,
      {bool big = true}) {
    c.drawCircle(
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
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(p.dx - tp.width / 2, cy + 8));
  }

  void _drawConcave(
      Canvas c, Offset Function(op.Vec2) toScr, op.ThinLensItem lens) {
    final top = toScr(lens.top);
    final bot = toScr(lens.bottom);
    final cx = toScr(lens.center).dx;
    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final h = (bot.dy - top.dy);
    final w = h * 0.10;
    // 凹透鏡：外側是兩端粗，中間細（用兩個向內的弧）
    final path = Path()
      ..moveTo(cx - w, top.dy)
      ..quadraticBezierTo(cx + w * 0.5, top.dy + h * 0.5, cx - w, bot.dy)
      ..lineTo(cx + w, bot.dy)
      ..quadraticBezierTo(cx - w * 0.5, top.dy + h * 0.5, cx + w, top.dy)
      ..close();
    c.drawPath(path, paint);
    c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1565C0).withValues(alpha: 0.08)
          ..style = PaintingStyle.fill);
    // 頂底箭頭：指向內側，表示凹
    c.drawLine(Offset(cx - 10, top.dy + 4), Offset(cx, top.dy + 14), paint);
    c.drawLine(Offset(cx + 10, top.dy + 4), Offset(cx, top.dy + 14), paint);
    c.drawLine(Offset(cx - 10, bot.dy - 4), Offset(cx, bot.dy - 14), paint);
    c.drawLine(Offset(cx + 10, bot.dy - 4), Offset(cx, bot.dy - 14), paint);
  }

  void _drawArrow(
      Canvas c, Offset base, Offset tip, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    c.drawLine(base, tip, paint);
    final dx = tip.dx - base.dx;
    final dy = tip.dy - base.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    final px = -uy;
    final py = ux;
    final head = math.min(14.0, len * 0.3);
    final h1 = Offset(tip.dx - ux * head + px * head * 0.45,
        tip.dy - uy * head + py * head * 0.45);
    final h2 = Offset(tip.dx - ux * head - px * head * 0.45,
        tip.dy - uy * head - py * head * 0.45);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(h1.dx, h1.dy)
      ..lineTo(h2.dx, h2.dy)
      ..close();
    c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _drawArrowHead(Canvas c, Offset a, Offset b, Color color) {
    _drawArrow(c, a, b, color, 1.2);
  }

  void _label(Canvas c, Offset pos, String text, Color color) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(covariant _ConcaveLensPainter old) => true;
}
