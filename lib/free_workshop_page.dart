// 自由創意工坊：類 GeoGebra 的多物品光學場景構建器
// 物品：凸透鏡、凹透鏡、點光源、平行光源、平面鏡、牆體（光屏）、玻璃體
// 每個物品可自定義屬性，支持拖拽、刪除；畫布可切換空白/座標系
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/audio_util.dart';
import 'utils/optics_core.dart' as op;

enum WorkshopCanvasMode { blank, grid }

class FreeWorkshopPage extends StatefulWidget {
  const FreeWorkshopPage({super.key});

  @override
  State<FreeWorkshopPage> createState() => _FreeWorkshopPageState();
}

class _FreeWorkshopPageState extends State<FreeWorkshopPage> {
  // 場景物品
  final List<op.OpticalItem> _items = [];
  // 光源（單獨列出：點光源 + 平行光源；繪製光線時只發射這些）
  List<op.OpticalItem> get _sources => _items
      .where((i) =>
          i.type == op.OpticalType.pointSource ||
          i.type == op.OpticalType.parallelSource)
      .toList();

  WorkshopCanvasMode _canvasMode = WorkshopCanvasMode.grid;
  double _pixelPerUnit = 1.0;
  double _viewOffsetX = 0;
  double _viewOffsetY = 0;
  Size _canvasSize = Size.zero;
  bool _firstLayout = true;

  String? _selectedId; // 當前選中物品
  String? _draggingId; // 當前拖動物品
  Offset _dragStart = Offset.zero;
  bool _panningCanvas = false;
  Offset _panStart = Offset.zero;
  double _panStartOffsetX = 0;
  double _panStartOffsetY = 0;

  int _counter = 0;
  String _nextId(String prefix) => "$prefix${++_counter}";

  // 初始為空白畫布，完全由用戶自行添加物品
  @override
  void initState() {
    super.initState();
  }

  op.Vec2 screenToPhys(Offset p) {
    final cx = _canvasSize.width / 2 + _viewOffsetX;
    final cy = _canvasSize.height / 2 + _viewOffsetY;
    return op.Vec2((p.dx - cx) / _pixelPerUnit, -(p.dy - cy) / _pixelPerUnit);
  }

  Offset phys2Screen(op.Vec2 v) {
    final cx = _canvasSize.width / 2 + _viewOffsetX;
    final cy = _canvasSize.height / 2 + _viewOffsetY;
    return Offset(cx + v.x * _pixelPerUnit, cy - v.y * _pixelPerUnit);
  }

  void _autoFit() {
    const targetRange = 800.0; // 顯示 ±400
    final sx = _canvasSize.width / targetRange;
    final sy = _canvasSize.height / targetRange;
    _pixelPerUnit = math.min(sx, sy);
    if (_pixelPerUnit > 1.5) _pixelPerUnit = 1.5;
    if (_pixelPerUnit < 0.15) _pixelPerUnit = 0.15;
  }

  // GeoGebra 風格：每次新增物品時錯落放置，避免重疊
  op.Vec2 _spawnOffset() {
    final n = _items.length;
    final col = (n % 4) - 1.5; // -1.5, -0.5, 0.5, 1.5 四列
    final row = (n ~/ 4) - 1; // 每 4 個換行
    return op.Vec2(col * 150, row * 140);
  }

  // 添加物品並顯示屬性編輯對話框
  void _addItem(ToolType type) async {
    final props = await showDialog<_ItemCreateProps>(
      context: context,
      builder: (_) => _ItemCreateDialog(type: type),
    );
    if (props == null) return;
    final off = _spawnOffset();
    op.OpticalItem item;
    switch (type) {
      case ToolType.convexLens:
        item = op.ThinLensItem(
          id: _nextId("CL"),
          center: op.Vec2(-120 + off.x, 0 + off.y),
          height: props.height ?? 200,
          f: (props.focal ?? 150).toDouble(),
        );
        break;
      case ToolType.concaveLens:
        item = op.ThinLensItem(
          id: _nextId("VL"),
          center: op.Vec2(-120 + off.x, 0 + off.y),
          height: props.height ?? 200,
          f: -(props.focal ?? 150).toDouble(),
        );
        break;
      case ToolType.pointSource:
        item = op.PointSourceItem(
          id: _nextId("PS"),
          position: op.Vec2(-260 + off.x, 0 + off.y),
          rayCount: props.rayCount ?? 14,
          spreadAngleRad: props.spread ?? math.pi,
          centralAngleRad: props.centralDir ?? 0,
        );
        break;
      case ToolType.parallelSource:
        item = op.ParallelSourceItem(
          id: _nextId("PL"),
          startAnchor: op.Vec2(-320 + off.x, 0 + off.y),
          directionRad: props.direction ?? 0,
          beamWidth: props.beamWidth ?? 160,
          rayCount: props.rayCount ?? 11,
        );
        break;
      case ToolType.mirror:
        final m = props.mirrorLen ?? 160.0;
        final ang = (props.mirrorAngle ?? 0) * math.pi / 180;
        final dir = op.Vec2(math.sin(ang), math.cos(ang)); // 0°=豎直
        final c = op.Vec2(80 + off.x, 0 + off.y);
        item = op.PlaneMirrorItem(
          id: _nextId("M"),
          p1: c - dir * (m / 2),
          p2: c + dir * (m / 2),
        );
        break;
      case ToolType.wall:
        final w = props.wallW ?? 30.0;
        final h = props.wallH ?? 200.0;
        final c = op.Vec2(120 + off.x, 0 + off.y);
        item = op.WallItem(
          id: _nextId("W"),
          cornerA: op.Vec2(c.x - w / 2, c.y - h / 2),
          cornerB: op.Vec2(c.x + w / 2, c.y + h / 2),
        );
        break;
      case ToolType.glass:
        final gw = props.glassW ?? 120.0;
        final gh = props.glassH ?? 160.0;
        final c = op.Vec2(20 + off.x, 0 + off.y);
        item = op.GlassBlockItem(
          id: _nextId("G"),
          cornerA: op.Vec2(c.x - gw / 2, c.y - gh / 2),
          cornerB: op.Vec2(c.x + gw / 2, c.y + gh / 2),
          refractiveIndex: props.refractiveIndex ?? 1.5,
        );
        break;
    }
    setState(() {
      _items.add(item);
      _selectedId = item.id;
    });
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    setState(() {
      _items.removeWhere((i) => i.id == _selectedId);
      _selectedId = null;
    });
  }

  void _editSelected() async {
    final it = _items.firstWhere((i) => i.id == _selectedId,
        orElse: () => _items.first);
    final props = _ItemCreateProps.fromItem(it);
    final type = _typeOf(it.type);
    if (type == null) return;
    final res = await showDialog<_ItemCreateProps>(
      context: context,
      builder: (_) => _ItemCreateDialog(type: type, init: props),
    );
    if (res == null) return;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == _selectedId);
      if (idx < 0) return;
      final old = _items[idx];
      op.OpticalItem n;
      if (old is op.ThinLensItem) {
        n = op.ThinLensItem(
          id: old.id,
          center: old.center,
          height: res.height ?? old.height,
          f: old.f >= 0
              ? (res.focal?.toDouble() ?? old.f)
              : -(res.focal?.toDouble() ?? old.f.abs()),
          angleRad: old.angleRad,
        );
      } else if (old is op.PointSourceItem) {
        n = op.PointSourceItem(
          id: old.id,
          position: old.position,
          rayCount: res.rayCount ?? old.rayCount,
          spreadAngleRad: res.spread ?? old.spreadAngleRad,
          centralAngleRad: res.centralDir ?? old.centralAngleRad,
        );
      } else if (old is op.ParallelSourceItem) {
        n = op.ParallelSourceItem(
          id: old.id,
          startAnchor: old.startAnchor,
          directionRad: res.direction ?? old.directionRad,
          beamWidth: res.beamWidth ?? old.beamWidth,
          rayCount: res.rayCount ?? old.rayCount,
        );
      } else if (old is op.PlaneMirrorItem) {
        final m = res.mirrorLen ?? (old.p2 - old.p1).length;
        final c = (old.p1 + old.p2) * 0.5;
        final ang = (res.mirrorAngle ?? 0) * math.pi / 180;
        final dir = op.Vec2(math.sin(ang), math.cos(ang));
        n = op.PlaneMirrorItem(
          id: old.id,
          p1: c - dir * (m / 2),
          p2: c + dir * (m / 2),
        );
      } else if (old is op.WallItem) {
        final w = res.wallW ?? old.width;
        final h = res.wallH ?? old.height;
        final c = (old.cornerA + old.cornerB) * 0.5;
        n = op.WallItem(
          id: old.id,
          cornerA: op.Vec2(c.x - w / 2, c.y - h / 2),
          cornerB: op.Vec2(c.x + w / 2, c.y + h / 2),
        );
      } else if (old is op.GlassBlockItem) {
        final gw = res.glassW ?? old.width;
        final gh = res.glassH ?? old.height;
        final c = (old.cornerA + old.cornerB) * 0.5;
        n = op.GlassBlockItem(
          id: old.id,
          cornerA: op.Vec2(c.x - gw / 2, c.y - gh / 2),
          cornerB: op.Vec2(c.x + gw / 2, c.y + gh / 2),
          refractiveIndex: res.refractiveIndex ?? old.refractiveIndex,
        );
      } else {
        return;
      }
      _items[idx] = n;
    });
  }

  ToolType? _typeOf(op.OpticalType t) {
    switch (t) {
      case op.OpticalType.convexLens:
        return ToolType.convexLens;
      case op.OpticalType.concaveLens:
        return ToolType.concaveLens;
      case op.OpticalType.pointSource:
        return ToolType.pointSource;
      case op.OpticalType.parallelSource:
        return ToolType.parallelSource;
      case op.OpticalType.planeMirror:
        return ToolType.mirror;
      case op.OpticalType.wall:
        return ToolType.wall;
      case op.OpticalType.glassBlock:
        return ToolType.glass;
      default:
        return null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    final phys = screenToPhys(d.localFocalPoint);
    // GeoGebra 風格高容差命中：先看是否點擊到某個物品（由上到下優先級）
    for (int i = _items.length - 1; i >= 0; i--) {
      final it = _items[i];
      if (it is op.ArrowItem) continue; // workshop 不使用 arrow
      double tol;
      if (it is op.PointSourceItem) {
        tol = 26 / _pixelPerUnit;
      } else if (it is op.ParallelSourceItem) {
        tol = 30 / _pixelPerUnit;
      } else if (it is op.ThinLensItem) {
        tol = 26 / _pixelPerUnit;
      } else {
        tol = 22 / _pixelPerUnit;
      }
      if (it.hitTest(phys, tolerance: tol)) {
        setState(() {
          _draggingId = it.id;
          _selectedId = it.id;
          _dragStart = d.localFocalPoint;
        });
        return;
      }
    }
    // 空白處：平移畫布
    setState(() {
      _panningCanvas = true;
      _panStart = d.localFocalPoint;
      _panStartOffsetX = _viewOffsetX;
      _panStartOffsetY = _viewOffsetY;
      _selectedId = null;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // 1) 縮放（僅當多指 scale != 1 時生效）
    if ((d.scale - 1.0).abs() > 1e-4) {
      final old = _pixelPerUnit;
      final next = (old * d.scale).clamp(0.1, 3.0);
      setState(() {
        _pixelPerUnit = next;
      });
    }
    // 2) 平移 / 拖動物品（scale 手勢是 pan 超集，單指也會觸發）
    final delta = d.focalPointDelta;
    if (delta.dx.abs() > 1e-6 || delta.dy.abs() > 1e-6) {
      if (_draggingId != null) {
        final dx = delta.dx / _pixelPerUnit;
        final dy = -delta.dy / _pixelPerUnit;
        final physDelta = op.Vec2(dx, dy);
        setState(() {
          final idx = _items.indexWhere((i) => i.id == _draggingId);
          if (idx < 0) return;
          _items[idx] = _items[idx].translate(physDelta);
        });
      } else if (_panningCanvas) {
        setState(() {
          _viewOffsetX += delta.dx;
          _viewOffsetY += delta.dy;
        });
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() {
      _draggingId = null;
      _panningCanvas = false;
    });
  }

  // 構建光線追蹤結果
  List<op.TracedRay> computeAllRays() {
    final out = <op.TracedRay>[];
    for (final s in _sources) {
      List<op.Ray2> rays;
      if (s is op.PointSourceItem) {
        rays = s.emitRays();
      } else if (s is op.ParallelSourceItem) {
        rays = s.emitRays();
      } else {
        continue;
      }
      for (final r in rays) {
        out.addAll(op.traceRayScene(r, _items, maxBounces: 8));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 720;
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
        title: const Text("FREE WORKSHOP",
            style: TextStyle(
                color: Color(0xFF6A1B9A),
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
              onPressed: () async {
                await AudioUtil.playClick();
                setState(() {
                  _firstLayout = true;
                  _viewOffsetX = 0;
                  _viewOffsetY = 0;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          if (narrow) {
            return Column(
              children: [
                _toolBar(true),
                Expanded(child: _canvasArea()),
                _bottomInfo(true),
              ],
            );
          } else {
            return Row(
              children: [
                _toolBar(false),
                Expanded(child: _canvasArea()),
                _rightPanel(),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _toolBar(bool horizontal) {
    final buttons = [
      _ToolBtn(
        icon: Icons.add_circle_outline,
        label: "Convex\nLens",
        accent: const Color(0xFF2E7D32),
        onTap: () => _addItem(ToolType.convexLens),
      ),
      _ToolBtn(
        icon: Icons.remove_circle_outline,
        label: "Concave\nLens",
        accent: const Color(0xFF1565C0),
        onTap: () => _addItem(ToolType.concaveLens),
      ),
      _ToolBtn(
        icon: Icons.light_mode,
        label: "Point\nSrc",
        accent: const Color(0xFFFF6F00),
        onTap: () => _addItem(ToolType.pointSource),
      ),
      _ToolBtn(
        icon: Icons.linear_scale,
        label: "Parallel",
        accent: const Color(0xFF00838F),
        onTap: () => _addItem(ToolType.parallelSource),
      ),
      _ToolBtn(
        icon: Icons.filter_list_alt,
        label: "Mirror",
        accent: const Color(0xFF546E7A),
        onTap: () => _addItem(ToolType.mirror),
      ),
      _ToolBtn(
        icon: Icons.check_box_outline_blank,
        label: "Wall",
        accent: const Color(0xFF6D4C41),
        onTap: () => _addItem(ToolType.wall),
      ),
      _ToolBtn(
        icon: Icons.square_foot,
        label: "Glass",
        accent: const Color(0xFF00ACC1),
        onTap: () => _addItem(ToolType.glass),
      ),
      const SizedBox.shrink(),
      _ToolBtn(
        icon: Icons.delete_outline,
        label: "Delete",
        accent: const Color(0xFFC62828),
        onTap: _deleteSelected,
        disabled: _selectedId == null,
      ),
      _ToolBtn(
        icon: Icons.tune,
        label: "Edit",
        accent: const Color(0xFF4527A0),
        onTap: _editSelected,
        disabled: _selectedId == null,
      ),
    ];
    final containerBg = BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(12),
    );
    if (horizontal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        decoration: containerBg,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: buttons,
        ),
      );
    }
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: containerBg,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "TOOLBOX",
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 2),
            ...buttons,
          ],
        ),
      ),
    );
  }

  Widget _canvasArea() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (context, c) {
          // ✅ 关键修复：这里的 c 才是画布真实占用的尺寸；之前错误地用了外层 body LayoutBuilder 的整屏 constraints。
          final realSize = Size(c.maxWidth, c.maxHeight);
          if (_firstLayout ||
              (_canvasSize.width - realSize.width).abs() > 0.5 ||
              (_canvasSize.height - realSize.height).abs() > 0.5) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _canvasSize = realSize;
                if (_firstLayout) _autoFit();
                _firstLayout = false;
              });
            });
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: CustomPaint(
                    // 用 Positioned.fill + SizedBox.expand 撑满真实画布区域，让 Painter 的 size 与命中基准 size 完全一致。
                    size: realSize,
                    painter: _WorkshopPainter(state: this),
                  ),
                ),
              ),
              // 畫布模式切換
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          offset: Offset(1, 1)),
                    ],
                  ),
                  child: SegmentedButton<WorkshopCanvasMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: WorkshopCanvasMode.blank,
                        label: Text("BLANK"),
                      ),
                      ButtonSegment(
                        value: WorkshopCanvasMode.grid,
                        label: Text("GRID"),
                      ),
                    ],
                    selected: {_canvasMode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _canvasMode = s.first;
                      });
                    },
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "ITEMS: ${_items.length}  |  RAYS: ${_sources.length}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _rightPanel() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("WORKSHOP CONTROLS",
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.black38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          _quickInfoCard(),
          const SizedBox(height: 12),
          const Text("ZOOM",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          Slider(
            value: _pixelPerUnit,
            min: 0.15,
            max: 2.5,
            activeColor: const Color(0xFF6A1B9A),
            onChanged: (v) => setState(() => _pixelPerUnit = v),
          ),
          const SizedBox(height: 8),
          Text(
            "Scale: 1 unit = ${(1 / _pixelPerUnit).toStringAsFixed(1)} px",
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.2)),
            ),
            child: const Text(
              "• Tap a tool to add\n• Drag items to move\n• Blank drag = pan view\n• Pinch = zoom\n• Tap Edit to modify properties",
              style: TextStyle(
                  height: 1.6,
                  fontSize: 11,
                  color: Color(0xFF4A148C),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomInfo(bool narrow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _quickInfoCard(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("ZOOM ",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              Expanded(
                child: Slider(
                  value: _pixelPerUnit,
                  min: 0.15,
                  max: 2.5,
                  activeColor: const Color(0xFF6A1B9A),
                  onChanged: (v) => setState(() => _pixelPerUnit = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickInfoCard() {
    final sel = _selectedId != null
        ? _items.where((i) => i.id == _selectedId).firstOrNull
        : null;
    if (sel == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          "No item selected. Tap an item or add one from the toolbox.",
          style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
        ),
      );
    }
    String typeName;
    Color color;
    String details;
    if (sel is op.ThinLensItem) {
      if (sel.f > 0) {
        typeName = "CONVEX LENS";
        color = const Color(0xFF2E7D32);
      } else {
        typeName = "CONCAVE LENS";
        color = const Color(0xFF1565C0);
      }
      details = "|f| = ${sel.f.abs().toStringAsFixed(0)}";
    } else if (sel is op.PointSourceItem) {
      typeName = "POINT SOURCE";
      color = const Color(0xFFFF6F00);
      details = "Rays: ${sel.rayCount}";
    } else if (sel is op.ParallelSourceItem) {
      typeName = "PARALLEL SOURCE";
      color = const Color(0xFF00838F);
      details = "Rays: ${sel.rayCount}";
    } else if (sel is op.PlaneMirrorItem) {
      typeName = "PLANE MIRROR";
      color = const Color(0xFF546E7A);
      details = "Length: ${(sel.p2 - sel.p1).length.toStringAsFixed(0)}";
    } else if (sel is op.WallItem) {
      typeName = "WALL (SCREEN)";
      color = const Color(0xFF6D4C41);
      details =
          "${sel.width.toStringAsFixed(0)} × ${sel.height.toStringAsFixed(0)}";
    } else if (sel is op.GlassBlockItem) {
      typeName = "GLASS BLOCK";
      color = const Color(0xFF00ACC1);
      details = "n = ${sel.refractiveIndex.toStringAsFixed(2)}";
    } else {
      typeName = "ITEM";
      color = Colors.black54;
      details = "";
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.info_outline, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeName,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(details,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum ToolType {
  convexLens,
  concaveLens,
  pointSource,
  parallelSource,
  mirror,
  wall,
  glass,
}

// 創建物品時的屬性
class _ItemCreateProps {
  double? focal; // 透鏡焦距
  double? height; // 透鏡高度
  int? rayCount; // 光源光線數
  double? spread; // 點光源發散角
  double? centralDir; // 點光源中心發射方向（0=右）
  double? direction; // 平行光源方向
  double? beamWidth; // 平行光束寬
  double? mirrorLen; // 平面鏡長度
  double? mirrorAngle; // 平面鏡旋轉角（0=豎直，度）
  double? wallW; // 牆寬
  double? wallH; // 牆高
  double? glassW; // 玻璃寬
  double? glassH; // 玻璃高
  double? refractiveIndex; // 玻璃折射率

  _ItemCreateProps({
    this.focal,
    this.height,
    this.rayCount,
    this.spread,
    this.centralDir,
    this.direction,
    this.beamWidth,
    this.mirrorLen,
    this.mirrorAngle,
    this.wallW,
    this.wallH,
    this.glassW,
    this.glassH,
    this.refractiveIndex,
  });

  factory _ItemCreateProps.fromItem(op.OpticalItem it) {
    final p = _ItemCreateProps();
    if (it is op.ThinLensItem) {
      p.focal = it.f.abs();
      p.height = it.height;
    } else if (it is op.PointSourceItem) {
      p.rayCount = it.rayCount;
      p.spread = it.spreadAngleRad;
      p.centralDir = it.centralAngleRad;
    } else if (it is op.ParallelSourceItem) {
      p.rayCount = it.rayCount;
      p.beamWidth = it.beamWidth;
      p.direction = it.directionRad;
    } else if (it is op.PlaneMirrorItem) {
      final v = it.p2 - it.p1;
      p.mirrorLen = v.length;
      // 以 (0,1) 為基準（豎直向上）計算夾角 → 轉角度
      final up = math.Point(0, 1);
      final ang = math.atan2(v.y * up.x - v.x * up.y, v.x * up.x + v.y * up.y);
      p.mirrorAngle = ang * 180 / math.pi;
    } else if (it is op.WallItem) {
      p.wallW = it.width;
      p.wallH = it.height;
    } else if (it is op.GlassBlockItem) {
      p.glassW = it.width;
      p.glassH = it.height;
      p.refractiveIndex = it.refractiveIndex;
    }
    return p;
  }
}

// 創建/編輯物品對話框
class _ItemCreateDialog extends StatefulWidget {
  final ToolType type;
  final _ItemCreateProps? init;
  const _ItemCreateDialog({required this.type, this.init});

  @override
  State<_ItemCreateDialog> createState() => _ItemCreateDialogState();
}

class _ItemCreateDialogState extends State<_ItemCreateDialog> {
  late TextEditingController _c1;
  late TextEditingController _c2;
  late TextEditingController _c3;
  late TextEditingController _c4;

  @override
  void initState() {
    super.initState();
    final p = widget.init ?? _ItemCreateProps();
    switch (widget.type) {
      case ToolType.convexLens:
      case ToolType.concaveLens:
        _c1 = TextEditingController(text: "${(p.focal ?? 150).toInt()}");
        _c2 = TextEditingController(text: "${(p.height ?? 200).toInt()}");
        _c3 = TextEditingController();
        _c4 = TextEditingController();
        break;
      case ToolType.pointSource:
        _c1 = TextEditingController(text: "${p.rayCount ?? 14}");
        _c2 = TextEditingController(
            text: "${((p.spread ?? math.pi) * 180 / math.pi).toInt()}");
        _c3 = TextEditingController(
            text:
                "${((p.centralDir ?? 0) * 180 / math.pi).toStringAsFixed(1)}");
        _c4 = TextEditingController();
        break;
      case ToolType.parallelSource:
        _c1 = TextEditingController(text: "${p.rayCount ?? 11}");
        _c2 = TextEditingController(text: "${(p.beamWidth ?? 160).toInt()}");
        _c3 = TextEditingController(
            text: "${((p.direction ?? 0) * 180 / math.pi).toStringAsFixed(1)}");
        _c4 = TextEditingController();
        break;
      case ToolType.mirror:
        _c1 = TextEditingController(text: "${(p.mirrorLen ?? 160).toInt()}");
        _c2 = TextEditingController(
            text: "${(p.mirrorAngle ?? 0).toStringAsFixed(1)}");
        _c3 = TextEditingController();
        _c4 = TextEditingController();
        break;
      case ToolType.wall:
        _c1 = TextEditingController(text: "${(p.wallW ?? 30).toInt()}");
        _c2 = TextEditingController(text: "${(p.wallH ?? 200).toInt()}");
        _c3 = TextEditingController();
        _c4 = TextEditingController();
        break;
      case ToolType.glass:
        _c1 = TextEditingController(text: "${(p.glassW ?? 120).toInt()}");
        _c2 = TextEditingController(text: "${(p.glassH ?? 160).toInt()}");
        _c3 = TextEditingController(
            text: (p.refractiveIndex ?? 1.5).toStringAsFixed(2));
        _c4 = TextEditingController();
        break;
    }
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    super.dispose();
  }

  String? title() {
    switch (widget.type) {
      case ToolType.convexLens:
        return "ADD CONVEX LENS";
      case ToolType.concaveLens:
        return "ADD CONCAVE LENS";
      case ToolType.pointSource:
        return "ADD POINT SOURCE";
      case ToolType.parallelSource:
        return "ADD PARALLEL SOURCE";
      case ToolType.mirror:
        return "ADD PLANE MIRROR";
      case ToolType.wall:
        return "ADD WALL (SCREEN)";
      case ToolType.glass:
        return "ADD GLASS BLOCK";
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> fields = [];
    switch (widget.type) {
      case ToolType.convexLens:
      case ToolType.concaveLens:
        fields.add(_field("Focal Length (|f|)", _c1, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Lens Height", _c2, suffix: " units"));
        break;
      case ToolType.pointSource:
        fields.add(_field("Ray Count", _c1, suffix: " rays"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Spread Angle", _c2, suffix: "°"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Central Direction (0=right)", _c3, suffix: "°"));
        break;
      case ToolType.parallelSource:
        fields.add(_field("Ray Count", _c1, suffix: " rays"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Beam Width", _c2, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Incident Direction (0=right)", _c3, suffix: "°"));
        break;
      case ToolType.mirror:
        fields.add(_field("Mirror Length", _c1, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Rotation Angle (0=vertical)", _c2, suffix: "°"));
        break;
      case ToolType.wall:
        fields.add(_field("Width", _c1, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Height", _c2, suffix: " units"));
        break;
      case ToolType.glass:
        fields.add(_field("Width", _c1, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Height", _c2, suffix: " units"));
        fields.add(const SizedBox(height: 10));
        fields.add(_field("Refractive Index (n)", _c3));
        break;
    }
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title()!,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
      content: SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: fields),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF222222),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            final p = _ItemCreateProps();
            try {
              switch (widget.type) {
                case ToolType.convexLens:
                case ToolType.concaveLens:
                  p.focal = double.parse(_c1.text);
                  p.height = double.parse(_c2.text);
                  break;
                case ToolType.pointSource:
                  p.rayCount = int.parse(_c1.text);
                  p.spread = double.parse(_c2.text) * math.pi / 180;
                  p.centralDir = double.parse(_c3.text) * math.pi / 180;
                  break;
                case ToolType.parallelSource:
                  p.rayCount = int.parse(_c1.text);
                  p.beamWidth = double.parse(_c2.text);
                  p.direction = double.parse(_c3.text) * math.pi / 180;
                  break;
                case ToolType.mirror:
                  p.mirrorLen = double.parse(_c1.text);
                  p.mirrorAngle = double.parse(_c2.text);
                  break;
                case ToolType.wall:
                  p.wallW = double.parse(_c1.text);
                  p.wallH = double.parse(_c2.text);
                  break;
                case ToolType.glass:
                  p.glassW = double.parse(_c1.text);
                  p.glassH = double.parse(_c2.text);
                  p.refractiveIndex = double.parse(_c3.text);
                  break;
              }
              Navigator.pop(context, p);
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Invalid input. Please enter valid numbers.")));
            }
          },
          child: const Text("CONFIRM",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]'))
                ],
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            if (suffix != null)
              Text(suffix,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ]);
  }
}

class _ToolBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool disabled;
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.disabled = false,
  });
  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapUp: (_) => setState(() => _hover = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          constraints: const BoxConstraints(minWidth: 80),
          decoration: BoxDecoration(
            color: _hover && !disabled
                ? widget.accent.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hover && !disabled
                    ? widget.accent.withValues(alpha: 0.5)
                    : Colors.black12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  color: disabled ? Colors.black26 : widget.accent, size: 22),
              const SizedBox(height: 4),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          disabled ? Colors.black26 : const Color(0xFF111111),
                      letterSpacing: 0.4,
                      height: 1.1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 工坊繪製器 =====
class _WorkshopPainter extends CustomPainter {
  final _FreeWorkshopPageState state;
  _WorkshopPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + state._viewOffsetX;
    final cy = size.height / 2 + state._viewOffsetY;
    final ppu = state._pixelPerUnit;
    Offset p2s(op.Vec2 v) => Offset(cx + v.x * ppu, cy - v.y * ppu);

    if (state._canvasMode == WorkshopCanvasMode.grid) {
      _drawGrid(canvas, size, cx, cy, ppu);
    }

    // 先畫玻璃體（填充）與牆體、平面鏡等背景
    for (final it in state._items) {
      if (it is op.GlassBlockItem) {
        _drawGlass(canvas, p2s, it);
      } else if (it is op.WallItem) {
        _drawWall(canvas, p2s, it);
      }
    }

    // 畫光線
    final rays = state.computeAllRays();
    final rayPaint = Paint()
      ..color = const Color(0xFFFF5252).withValues(alpha: 0.7)
      ..strokeWidth = 1.3;
    for (final r in rays) {
      for (int i = 0; i < r.points.length - 1; i++) {
        final a = p2s(r.points[i]);
        final b = p2s(r.points[i + 1]);
        canvas.drawLine(a, b, rayPaint);
      }
      if (r.points.length >= 2) {
        _drawArrowHead(canvas, p2s(r.points[r.points.length - 2]),
            p2s(r.points[r.points.length - 1]), const Color(0xFFFF5252));
      }
    }

    // 畫透鏡、鏡子、光源
    for (final it in state._items) {
      if (it is op.ThinLensItem) {
        if (it.f > 0) {
          _drawConvex(canvas, p2s, it, state._selectedId == it.id);
        } else {
          _drawConcave(canvas, p2s, it, state._selectedId == it.id);
        }
      } else if (it is op.PlaneMirrorItem) {
        _drawMirror(canvas, p2s, it, state._selectedId == it.id);
      } else if (it is op.PointSourceItem) {
        _drawPointSrc(canvas, p2s, it, state._selectedId == it.id);
      } else if (it is op.ParallelSourceItem) {
        _drawParallelSrc(canvas, p2s, it, state._selectedId == it.id);
      }
    }

    // 選中高亮框（GeoGebra 風格：對每種物品計算 2D 包圍盒，避免一維線段過於扁平）
    if (state._selectedId != null) {
      final sel =
          state._items.where((i) => i.id == state._selectedId).firstOrNull;
      if (sel != null) {
        double minX = double.infinity,
            minY = double.infinity,
            maxX = -double.infinity,
            maxY = -double.infinity;
        if (sel is op.PointSourceItem) {
          final sp = p2s(sel.position);
          minX = sp.dx - 16;
          maxX = sp.dx + 16;
          minY = sp.dy - 16;
          maxY = sp.dy + 16;
        } else if (sel is op.ParallelSourceItem) {
          final seg = sel.edges.first;
          final a = p2s(seg.p1);
          final b = p2s(seg.p2);
          final pad = 14.0;
          minX = math.min(a.dx, b.dx) - pad;
          maxX = math.max(a.dx, b.dx) + pad;
          minY = math.min(a.dy, b.dy) - pad;
          maxY = math.max(a.dy, b.dy) + pad;
        } else if (sel is op.ThinLensItem) {
          final t = p2s(sel.top);
          final b = p2s(sel.bottom);
          final pad = 16.0;
          minX = math.min(t.dx, b.dx) - pad;
          maxX = math.max(t.dx, b.dx) + pad;
          minY = math.min(t.dy, b.dy);
          maxY = math.max(t.dy, b.dy);
        } else if (sel is op.PlaneMirrorItem) {
          final a = p2s(sel.p1);
          final b = p2s(sel.p2);
          final pad = 10.0;
          minX = math.min(a.dx, b.dx) - pad;
          maxX = math.max(a.dx, b.dx) + pad;
          minY = math.min(a.dy, b.dy) - pad;
          maxY = math.max(a.dy, b.dy) + pad;
        } else {
          final edges = sel.edges;
          for (final e in edges) {
            for (final p in [e.p1, e.p2]) {
              final sp = p2s(p);
              if (sp.dx < minX) minX = sp.dx;
              if (sp.dx > maxX) maxX = sp.dx;
              if (sp.dy < minY) minY = sp.dy;
              if (sp.dy > maxY) maxY = sp.dy;
            }
          }
        }
        if (minX.isFinite && minY.isFinite) {
          final rect = Rect.fromLTRB(minX - 6, minY - 6, maxX + 6, maxY + 6);
          canvas.drawRect(
            rect,
            Paint()
              ..color = const Color(0xFF6A1B9A).withValues(alpha: 0.18)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = const Color(0xFF6A1B9A)
              ..strokeWidth = 1.8
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  void _drawGrid(Canvas c, Size size, double cx, double cy, double ppu) {
    final step0 = _gridStep(ppu);
    // 可見物理範圍（ppu 縮放 + viewOffset 平移後，當前畫面可見的物理 x/y）
    final visMinX = (-cx) / ppu;
    final visMaxX = (size.width - cx) / ppu;
    final visMinY = -(size.height - cy) / ppu;
    final visMaxY = cy / ppu;
    // === 1. 淡灰色方格背景（隨平移/縮放一起移動） ===
    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    final startX = (visMinX / step0).floorToDouble() * step0;
    final startY = (visMinY / step0).floorToDouble() * step0;
    for (double x = startX; x <= visMaxX + step0 * 0.5; x += step0) {
      // 軸線本身下面單獨加粗，這裡跳過避免重疊顏色不均
      if (x.abs() < step0 * 0.01) continue;
      final sx = cx + x * ppu;
      c.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }
    for (double y = startY; y <= visMaxY + step0 * 0.5; y += step0) {
      if (y.abs() < step0 * 0.01) continue;
      final sy = cy - y * ppu;
      c.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }
    // === 2. X / Y 兩條加粗主軸：兩端分別延伸到畫面邊界（隨平移/縮放動） ===
    final axisPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square;
    // X 軸：若 y=0 在畫面內 → 從畫面左邊界畫到右邊界；否則只在可見範圍頂/底邊畫
    if (cy >= 0 && cy <= size.height) {
      c.drawLine(Offset(0, cy), Offset(size.width, cy), axisPaint);
    } else if (cy < 0) {
      // 原點在畫面上方 → 僅在頂邊畫出 x 軸
      c.drawLine(const Offset(0, 0), Offset(size.width, 0), axisPaint);
    } else {
      c.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    }
    // Y 軸
    if (cx >= 0 && cx <= size.width) {
      c.drawLine(Offset(cx, 0), Offset(cx, size.height), axisPaint);
    } else if (cx < 0) {
      c.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
    } else {
      c.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), axisPaint);
    }
    // === 3. 軸箭頭：箭頭畫在「當前可見的軸端」（若原點在畫面內 → 兩端都畫） ===
    const axColor = Color(0xFF111111);
    void drawArrowX(double xEnd, bool tipRight) {
      if (xEnd < 0 || xEnd > size.width) return;
      final base = tipRight ? xEnd - 18 : xEnd + 18;
      _arrow(c, Offset(xEnd, cy), Offset(base, cy), axColor, w: 2.8);
    }

    void drawArrowY(double yEnd, bool tipUp) {
      if (yEnd < 0 || yEnd > size.height) return;
      final base = tipUp ? yEnd + 18 : yEnd - 18;
      _arrow(c, Offset(cx, yEnd), Offset(cx, base), axColor, w: 2.8);
    }

    if (cy >= 0 && cy <= size.height) {
      // X 軸：右側箭頭（x+ 方向）
      drawArrowX(size.width - 8, true);
      drawArrowX(8, false);
    }
    if (cx >= 0 && cx <= size.width) {
      // Y 軸：上側箭頭（y+ 方向）
      drawArrowY(8, true);
      drawArrowY(size.height - 8, false);
    }
    // === 4. 坐標標籤 x / y / O ===
    const ts = TextStyle(
        color: axColor,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.4);
    final tpX = TextPainter(
        text: const TextSpan(text: "x", style: ts),
        textDirection: TextDirection.ltr)
      ..layout();
    final tpY = TextPainter(
        text: const TextSpan(text: "y", style: ts),
        textDirection: TextDirection.ltr)
      ..layout();
    final tpO = TextPainter(
        text: const TextSpan(
            text: "O",
            style: TextStyle(
                color: Color(0xFF424242),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout();
    if (cy >= 0 && cy <= size.height) {
      tpX.paint(c, Offset(size.width - 22, cy + 8));
    } else if (cy < 0) {
      tpX.paint(c, Offset(size.width - 22, 8));
    } else {
      tpX.paint(c, Offset(size.width - 22, size.height - 18));
    }
    if (cx >= 0 && cx <= size.width) {
      tpY.paint(c, Offset(cx + 8, 2));
    } else if (cx < 0) {
      tpY.paint(c, const Offset(8, 2));
    } else {
      tpY.paint(c, Offset(size.width - 18, 2));
    }
    if (cx >= -6 && cx <= size.width + 6 && cy >= -6 && cy <= size.height + 6) {
      tpO.paint(c, Offset(cx - 18, cy + 6));
    }
  }

  double _gridStep(double ppu) {
    const target = 55.0;
    final phys = target / ppu;
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

  void _drawConvex(Canvas c, Offset Function(op.Vec2) p2s, op.ThinLensItem lens,
      bool selected) {
    final top = p2s(lens.top);
    final bot = p2s(lens.bottom);
    final cx = p2s(lens.center).dx;
    final h = (bot.dy - top.dy);
    final w = h * 0.08;
    final accent = selected ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32);
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(cx - w, top.dy)
      ..quadraticBezierTo(cx, top.dy + h * 0.05, cx + w, top.dy)
      ..lineTo(cx + w, bot.dy)
      ..quadraticBezierTo(cx, bot.dy - h * 0.05, cx - w, bot.dy)
      ..close();
    c.drawPath(path, paint);
    c.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill);
    c.drawLine(Offset(cx - 8, top.dy), Offset(cx, top.dy + 10), paint);
    c.drawLine(Offset(cx + 8, top.dy), Offset(cx, top.dy + 10), paint);
    c.drawLine(Offset(cx - 8, bot.dy), Offset(cx, bot.dy - 10), paint);
    c.drawLine(Offset(cx + 8, bot.dy), Offset(cx, bot.dy - 10), paint);
  }

  void _drawConcave(Canvas c, Offset Function(op.Vec2) p2s,
      op.ThinLensItem lens, bool selected) {
    final top = p2s(lens.top);
    final bot = p2s(lens.bottom);
    final cx = p2s(lens.center).dx;
    final h = (bot.dy - top.dy);
    final w = h * 0.10;
    final accent = selected ? const Color(0xFF1565C0) : const Color(0xFF1565C0);
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
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
          ..color = accent.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill);
    c.drawLine(Offset(cx - 10, top.dy + 4), Offset(cx, top.dy + 14), paint);
    c.drawLine(Offset(cx + 10, top.dy + 4), Offset(cx, top.dy + 14), paint);
    c.drawLine(Offset(cx - 10, bot.dy - 4), Offset(cx, bot.dy - 14), paint);
    c.drawLine(Offset(cx + 10, bot.dy - 4), Offset(cx, bot.dy - 14), paint);
  }

  void _drawMirror(Canvas c, Offset Function(op.Vec2) p2s, op.PlaneMirrorItem m,
      bool selected) {
    final accent = selected ? const Color(0xFF37474F) : const Color(0xFF546E7A);
    final p1 = p2s(m.p1);
    final p2 = p2s(m.p2);
    c.drawLine(
        p1,
        p2,
        Paint()
          ..color = accent
          ..strokeWidth = 4);
    // 背面斜線
    final dir = (p2 - p1);
    final len = math.sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
    if (len < 1) return;
    final ux = dir.dx / len;
    final uy = dir.dy / len;
    final nx = -uy;
    final ny = ux;
    final hatchingPaint = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (int i = 0; i < len; i += 10) {
      final bx = p1.dx + ux * i;
      final by = p1.dy + uy * i;
      c.drawLine(
          Offset(bx, by), Offset(bx + nx * 8, by + ny * 8), hatchingPaint);
    }
  }

  void _drawWall(Canvas c, Offset Function(op.Vec2) p2s, op.WallItem w) {
    final a = p2s(w.cornerA);
    final b = p2s(w.cornerB);
    final rect = Rect.fromLTRB(math.min(a.dx, b.dx), math.min(a.dy, b.dy),
        math.max(a.dx, b.dx), math.max(a.dy, b.dy));
    final paint = Paint()
      ..color = const Color(0xFF6D4C41).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    c.drawRect(rect, paint);
    // 畫布紋理（斜線）
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    for (double x = rect.left; x < rect.right + rect.height; x += 12) {
      c.drawLine(
          Offset(x, rect.top), Offset(x - rect.height, rect.bottom), linePaint);
    }
    c.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF4E342E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _drawGlass(Canvas c, Offset Function(op.Vec2) p2s, op.GlassBlockItem g) {
    final a = p2s(g.cornerA);
    final b = p2s(g.cornerB);
    final rect = Rect.fromLTRB(math.min(a.dx, b.dx), math.min(a.dy, b.dy),
        math.max(a.dx, b.dx), math.max(a.dy, b.dy));
    c.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF00ACC1).withValues(alpha: 0.18)
          ..style = PaintingStyle.fill);
    c.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF00838F)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    // 標示 n 值
    final tp = TextPainter(
        text: TextSpan(
            text: "n=${g.refractiveIndex.toStringAsFixed(2)}",
            style: const TextStyle(
                color: Color(0xFF006064),
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(rect.left + 6, rect.top + 6));
  }

  void _drawPointSrc(Canvas c, Offset Function(op.Vec2) p2s,
      op.PointSourceItem s, bool selected) {
    final p = p2s(s.position);
    c.drawCircle(
        p,
        12,
        Paint()
          ..color =
              (selected ? const Color(0xFFE65100) : const Color(0xFFFF6F00))
                  .withValues(alpha: 0.25)
          ..style = PaintingStyle.fill);
    c.drawCircle(
        p,
        7,
        Paint()
          ..color = selected ? const Color(0xFFE65100) : const Color(0xFFFF6F00)
          ..style = PaintingStyle.fill);
    // 光芒
    final ray = Paint()
      ..color = (selected ? const Color(0xFFE65100) : const Color(0xFFFF6F00))
          .withValues(alpha: 0.7)
      ..strokeWidth = 1.3;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final x1 = p.dx + math.cos(a) * 10;
      final y1 = p.dy + math.sin(a) * 10;
      final x2 = p.dx + math.cos(a) * 16;
      final y2 = p.dy + math.sin(a) * 16;
      c.drawLine(Offset(x1, y1), Offset(x2, y2), ray);
    }
  }

  void _drawParallelSrc(Canvas c, Offset Function(op.Vec2) p2s,
      op.ParallelSourceItem s, bool selected) {
    final seg = s.edges.first;
    final a = p2s(seg.p1);
    final b = p2s(seg.p2);
    final accent = selected ? const Color(0xFF006064) : const Color(0xFF00838F);
    c.drawLine(
        a,
        b,
        Paint()
          ..color = accent
          ..strokeWidth = 5);
    // 小箭頭方向
    final dir = math.Point(math.cos(s.directionRad), math.sin(s.directionRad));
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final arrP1 = mid;
    final arrP2 = Offset(mid.dx + dir.x * 18, mid.dy + dir.y * -18);
    _arrow(c, arrP2, arrP1, accent);
  }

  void _arrow(Canvas c, Offset tip, Offset base, Color color,
      {double w = 3.0}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
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
    final head = math.min(12.0, len * 0.4);
    final h1 = Offset(tip.dx - ux * head + px * head * 0.5,
        tip.dy - uy * head + py * head * 0.5);
    final h2 = Offset(tip.dx - ux * head - px * head * 0.5,
        tip.dy - uy * head - py * head * 0.5);
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(h1.dx, h1.dy)
      ..lineTo(h2.dx, h2.dy)
      ..close();
    c.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _drawArrowHead(Canvas c, Offset a, Offset b, Color color) {
    _arrow(c, b, a, color, w: 1.2);
  }

  @override
  bool shouldRepaint(covariant _WorkshopPainter old) => true;
}
