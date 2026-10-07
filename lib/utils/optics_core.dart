// 光學計算核心庫：包含透鏡成像、光線折射、反射的數學模型
// 所有坐標系採用二維笛卡爾坐標 (x, y)，x 軸水平向右，y 軸垂直向上
// 物理距離單位為任意一致單位（通常對應畫布像素的邏輯單位）

import 'dart:math' as math;
import 'dart:ui';

// 光學物品類型枚舉
enum OpticalType {
  convexLens, // 凸透鏡
  concaveLens, // 凹透鏡
  planeMirror, // 平面鏡
  glassBlock, // 玻璃體
  wall, // 牆體（光屏/阻擋物）
  arrowObject, // 箭頭物體
  pointSource, // 點光源
  parallelSource, // 平行光源
}

// 二維向量 / 點
class Vec2 {
  final double x;
  final double y;
  const Vec2(this.x, this.y);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double dot(Vec2 o) => x * o.x + y * o.y;
  double get length => math.sqrt(x * x + y * y);
  Vec2 get normalized {
    final l = length;
    if (l < 1e-9) return const Vec2(0, 0);
    return Vec2(x / l, y / l);
  }

  Vec2 rotate(double angleRad) {
    final c = math.cos(angleRad);
    final s = math.sin(angleRad);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  Offset toOffset() => Offset(x, y);
}

// 一條射線：起點 + 方向向量
class Ray2 {
  final Vec2 origin;
  final Vec2 direction; // 單位向量
  Ray2(this.origin, Vec2 dir) : direction = dir.normalized;

  // 射線上 t 參數對應的點
  Vec2 pointAt(double t) => origin + direction * t;
}

// 直線 ax + by + c = 0
class Line2 {
  final double a;
  final double b;
  final double c;
  const Line2(this.a, this.b, this.c);

  // 由兩點構造直線
  factory Line2.fromPoints(Vec2 p1, Vec2 p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return Line2(dy, -dx, -(dy * p1.x - dx * p1.y));
  }

  // 求交點，若平行則返回 null
  Vec2? intersect(Line2 other) {
    final det = a * other.b - b * other.a;
    if (det.abs() < 1e-9) return null;
    final x = (b * other.c - c * other.b) / det;
    final y = (c * other.a - a * other.c) / det;
    return Vec2(x, y);
  }

  // 法向量
  Vec2 get normal => Vec2(a, b).normalized;
}

// 線段：由兩端點構成
class Segment2 {
  final Vec2 p1;
  final Vec2 p2;
  const Segment2(this.p1, this.p2);

  double get length => (p2 - p1).length;

  Line2 toLine() => Line2.fromPoints(p1, p2);

  // 求射線與線段的交點，返回 {point, t}
  // t 為射線參數（t >= 0 且交點在線段上才成立）
  ({Vec2 point, double t})? rayIntersect(Ray2 ray) {
    final x1 = ray.origin.x;
    final y1 = ray.origin.y;
    final x2 = ray.origin.x + ray.direction.x;
    final y2 = ray.origin.y + ray.direction.y;
    final x3 = p1.x;
    final y3 = p1.y;
    final x4 = p2.x;
    final y4 = p2.y;

    final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 1e-9) return null;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    final u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom;

    if (t >= 1e-6 && u >= 0 && u <= 1) {
      return (point: Vec2(x1 + t * (x2 - x1), y1 + t * (y2 - y1)), t: t);
    }
    return null;
  }
}

// 抽象光學物品
abstract class OpticalItem {
  final String id;
  OpticalType get type;
  // 返回物體的範圍線段（用於光線相交檢測）
  List<Segment2> get edges;
  // 拷貝並移動到新位置
  OpticalItem translate(Vec2 delta);
  // 命中測試：點是否接近物體（用於拖拽選中）
  bool hitTest(Vec2 p, {double tolerance = 12.0});

  OpticalItem(this.id);
}

// 薄透鏡：光軸水平，鏡心在 center，高度為 height（豎直），焦距 f
// 凸透鏡 f > 0；凹透鏡 f < 0
class ThinLensItem extends OpticalItem {
  final Vec2 center;
  final double height; // 透鏡總高度
  final double f; // 焦距（凸正凹負）
  final double angleRad; // 相對於豎直方向的旋轉（0 表示豎直放置，光軸水平）

  ThinLensItem({
    required String id,
    required this.center,
    required this.height,
    required this.f,
    this.angleRad = 0,
  }) : super(id);

  @override
  OpticalType get type =>
      f >= 0 ? OpticalType.convexLens : OpticalType.concaveLens;

  // 透鏡兩個端點
  Vec2 get top {
    final dir = Vec2(0, -1).rotate(angleRad);
    return center + dir * (height / 2);
  }

  Vec2 get bottom {
    final dir = Vec2(0, 1).rotate(angleRad);
    return center + dir * (height / 2);
  }

  // 光軸方向（與透鏡平面垂直）
  Vec2 get axisDir => Vec2(1, 0).rotate(angleRad);

  // 前焦點（物方）與後焦點（像方）
  Vec2 get frontFocus => center - axisDir * f.abs();
  Vec2 get backFocus => center + axisDir * f.abs();
  // 2F 點
  Vec2 get front2F => center - axisDir * (2 * f.abs());
  Vec2 get back2F => center + axisDir * (2 * f.abs());

  @override
  List<Segment2> get edges => [Segment2(top, bottom)];

  @override
  OpticalItem translate(Vec2 delta) => ThinLensItem(
        id: id,
        center: center + delta,
        height: height,
        f: f,
        angleRad: angleRad,
      );

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    final seg = edges.first;
    final line = seg.toLine();
    // 點到直線距離
    final num = (line.a * p.x + line.b * p.y + line.c).abs();
    final den = math.sqrt(line.a * line.a + line.b * line.b);
    final dist = den < 1e-9 ? (p - center).length : num / den;
    if (dist > tolerance) return false;
    // 投影到線段上判斷是否在範圍內
    final v = seg.p2 - seg.p1;
    final w = p - seg.p1;
    final t = v.dot(w) / v.dot(v);
    return t >= -0.05 && t <= 1.05;
  }
}

// 箭頭物體（豎直箭頭）：尖端在 tip，軸心線（底部）在 base
class ArrowItem extends OpticalItem {
  final Vec2 base;
  final Vec2 tip;
  ArrowItem({required String id, required this.base, required this.tip})
      : super(id);

  @override
  OpticalType get type => OpticalType.arrowObject;

  double get height => (tip - base).length;
  Vec2 get center => (base + tip) * 0.5;

  // 箭頭主體線段
  Segment2 get shaft => Segment2(base, tip);

  @override
  List<Segment2> get edges {
    // 箭頭頂部小三角兩邊（視覺用）
    final dir = (tip - base).normalized;
    final perp = Vec2(-dir.y, dir.x);
    final headBase = tip - dir * 10;
    return [
      shaft,
      Segment2(tip, headBase - perp * 6),
      Segment2(tip, headBase + perp * 6),
    ];
  }

  @override
  OpticalItem translate(Vec2 delta) => ArrowItem(
        id: id,
        base: base + delta,
        tip: tip + delta,
      );

  ArrowItem scaleHeight(double newHeight) {
    final dir = (tip - base).normalized;
    return ArrowItem(id: id, base: base, tip: base + dir * newHeight);
  }

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    return (p - center).length < tolerance + 10 ||
        (p - tip).length < tolerance ||
        (p - base).length < tolerance;
  }
}

// 點光源：從 position 向一個扇區發出 rayCount 條均勻分佈的射線
class PointSourceItem extends OpticalItem {
  final Vec2 position;
  final int rayCount; // 光線密度（條數）
  final double centralAngleRad; // 中心發射角（0 = 向右）
  final double spreadAngleRad; // 發散角（2π 為全向）

  PointSourceItem({
    required String id,
    required this.position,
    this.rayCount = 18,
    this.centralAngleRad = 0,
    this.spreadAngleRad = math.pi,
  }) : super(id);

  @override
  OpticalType get type => OpticalType.pointSource;

  // 生成射線
  List<Ray2> emitRays() {
    final rays = <Ray2>[];
    if (rayCount <= 1) {
      rays.add(Ray2(position,
          Vec2(math.cos(centralAngleRad), math.sin(centralAngleRad))));
      return rays;
    }
    final half = spreadAngleRad / 2;
    for (int i = 0; i < rayCount; i++) {
      final t = rayCount == 1 ? 0.5 : i / (rayCount - 1);
      final a = centralAngleRad - half + spreadAngleRad * t;
      rays.add(Ray2(position, Vec2(math.cos(a), math.sin(a))));
    }
    return rays;
  }

  @override
  List<Segment2> get edges => [];

  @override
  OpticalItem translate(Vec2 delta) => PointSourceItem(
        id: id,
        position: position + delta,
        rayCount: rayCount,
        centralAngleRad: centralAngleRad,
        spreadAngleRad: spreadAngleRad,
      );

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) =>
      (p - position).length < tolerance;
}

// 平行光源：從 startAnchor 開始發出 rayCount 條均勻分佈於垂直方向的平行射線
class ParallelSourceItem extends OpticalItem {
  final Vec2 startAnchor; // 光源起始中心點
  final double directionRad; // 傳播方向（0 = 水平向右）
  final double beamWidth; // 光束寬度
  final int rayCount;

  ParallelSourceItem({
    required String id,
    required this.startAnchor,
    this.directionRad = 0,
    this.beamWidth = 160,
    this.rayCount = 11,
  }) : super(id);

  @override
  OpticalType get type => OpticalType.parallelSource;

  List<Ray2> emitRays() {
    final dir = Vec2(math.cos(directionRad), math.sin(directionRad));
    final perp = Vec2(-dir.y, dir.x); // 垂直方向
    final rays = <Ray2>[];
    if (rayCount <= 1) {
      rays.add(Ray2(startAnchor, dir));
      return rays;
    }
    for (int i = 0; i < rayCount; i++) {
      final t = rayCount == 1 ? 0.5 : i / (rayCount - 1);
      final offset = perp * (beamWidth * (t - 0.5));
      rays.add(Ray2(startAnchor + offset, dir));
    }
    return rays;
  }

  @override
  List<Segment2> get edges {
    final dir = Vec2(math.cos(directionRad), math.sin(directionRad));
    final perp = Vec2(-dir.y, dir.x);
    final p1 = startAnchor - perp * (beamWidth / 2);
    final p2 = startAnchor + perp * (beamWidth / 2);
    return [Segment2(p1, p2)];
  }

  @override
  OpticalItem translate(Vec2 delta) => ParallelSourceItem(
        id: id,
        startAnchor: startAnchor + delta,
        directionRad: directionRad,
        beamWidth: beamWidth,
        rayCount: rayCount,
      );

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    final seg = edges.first;
    final v = seg.p2 - seg.p1;
    final w = p - seg.p1;
    final t = v.dot(v) < 1e-9 ? 0.0 : (v.dot(w) / v.dot(v)).toDouble();
    if (t < -0.1 || t > 1.1) return false;
    final proj = seg.p1 + v * t;
    return (p - proj).length < tolerance + 4;
  }
}

// 平面鏡：反射面為 line segment
class PlaneMirrorItem extends OpticalItem {
  final Vec2 p1;
  final Vec2 p2;
  PlaneMirrorItem({required String id, required this.p1, required this.p2})
      : super(id);

  @override
  OpticalType get type => OpticalType.planeMirror;

  Segment2 get surface => Segment2(p1, p2);
  Vec2 get center => (p1 + p2) * 0.5;

  @override
  List<Segment2> get edges => [surface];

  // 反射定律
  Ray2 reflect(Ray2 incoming, Vec2 hitPoint) {
    final tangent = (p2 - p1).normalized;
    final normal = Vec2(-tangent.y, tangent.x);
    // 若入射方向與法線同向則翻轉法線
    final n = incoming.direction.dot(normal) > 0 ? normal * -1 : normal;
    final d = incoming.direction;
    final reflected = d - n * (2 * d.dot(n));
    return Ray2(hitPoint + reflected * 0.01, reflected);
  }

  @override
  OpticalItem translate(Vec2 delta) => PlaneMirrorItem(
        id: id,
        p1: p1 + delta,
        p2: p2 + delta,
      );

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    final v = p2 - p1;
    final w = p - p1;
    final t = v.dot(v) < 1e-9 ? 0.0 : (v.dot(w) / v.dot(v)).toDouble();
    if (t < -0.05 || t > 1.05) return false;
    final proj = p1 + v * t;
    return (p - proj).length < tolerance;
  }
}

// 牆體（矩形）：阻擋光線 + 可作光屏
class WallItem extends OpticalItem {
  final Vec2 cornerA; // 左下
  final Vec2 cornerB; // 右上
  WallItem({required String id, required this.cornerA, required this.cornerB})
      : super(id);

  @override
  OpticalType get type => OpticalType.wall;

  double get width => (cornerB.x - cornerA.x).abs();
  double get height => (cornerB.y - cornerA.y).abs();

  @override
  List<Segment2> get edges {
    final tl = Vec2(cornerA.x, cornerB.y);
    final br = Vec2(cornerB.x, cornerA.y);
    return [
      Segment2(cornerA, br), // 底
      Segment2(br, cornerB), // 右
      Segment2(cornerB, tl), // 頂
      Segment2(tl, cornerA), // 左
    ];
  }

  @override
  OpticalItem translate(Vec2 delta) => WallItem(
        id: id,
        cornerA: cornerA + delta,
        cornerB: cornerB + delta,
      );

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    final minX = math.min(cornerA.x, cornerB.x) - tolerance;
    final maxX = math.max(cornerA.x, cornerB.x) + tolerance;
    final minY = math.min(cornerA.y, cornerB.y) - tolerance;
    final maxY = math.max(cornerA.y, cornerB.y) + tolerance;
    return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
  }
}

// 玻璃體（矩形 + 自定義折射率 n）
class GlassBlockItem extends OpticalItem {
  final Vec2 cornerA; // 左下（物理坐標）
  final Vec2 cornerB; // 右上
  final double refractiveIndex; // 空氣 n=1，玻璃 n≈1.5

  GlassBlockItem({
    required String id,
    required this.cornerA,
    required this.cornerB,
    this.refractiveIndex = 1.5,
  }) : super(id);

  @override
  OpticalType get type => OpticalType.glassBlock;

  double get width => (cornerB.x - cornerA.x).abs();
  double get height => (cornerB.y - cornerA.y).abs();

  @override
  List<Segment2> get edges {
    final tl = Vec2(cornerA.x, cornerB.y);
    final br = Vec2(cornerB.x, cornerA.y);
    return [
      Segment2(cornerA, br),
      Segment2(br, cornerB),
      Segment2(cornerB, tl),
      Segment2(tl, cornerA),
    ];
  }

  @override
  OpticalItem translate(Vec2 delta) => GlassBlockItem(
        id: id,
        cornerA: cornerA + delta,
        cornerB: cornerB + delta,
        refractiveIndex: refractiveIndex,
      );

  // 點是否在玻璃體內部（包含邊界±eps）
  bool containsPoint(Vec2 p, {double eps = 0.5}) {
    final minX = math.min(cornerA.x, cornerB.x) - eps;
    final maxX = math.max(cornerA.x, cornerB.x) + eps;
    final minY = math.min(cornerA.y, cornerB.y) - eps;
    final maxY = math.max(cornerA.y, cornerB.y) + eps;
    return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
  }

  // 斯涅爾定律折射，返回新方向；全反射返回 null
  Vec2? refractDirection(Vec2 incomingDir, Vec2 normal, double n1, double n2) {
    // 確保法線方向指向入射光來源
    final n = incomingDir.dot(normal) > 0 ? normal * -1 : normal;
    final cosThetaI = -incomingDir.dot(n);
    final eta = n1 / n2;
    final sin2ThetaT = eta * eta * (1 - cosThetaI * cosThetaI);
    if (sin2ThetaT > 1) return null; // 全反射
    final cosThetaT = math.sqrt(1 - sin2ThetaT);
    return incomingDir * eta + n * (eta * cosThetaI - cosThetaT);
  }

  @override
  bool hitTest(Vec2 p, {double tolerance = 12.0}) {
    final minX = math.min(cornerA.x, cornerB.x) - tolerance;
    final maxX = math.max(cornerA.x, cornerB.x) + tolerance;
    final minY = math.min(cornerA.y, cornerB.y) - tolerance;
    final maxY = math.max(cornerA.y, cornerB.y) + tolerance;
    return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
  }
}

// 薄透鏡的成像計算結果（適用於豎直箭頭 + 透鏡豎直的情況）
class LensImageResult {
  final double u; // 物距（正數，物在透鏡前方時）
  final double v; // 像距（正實像/負虛像）
  final double magnification;
  final bool isReal;
  final bool isInverted;
  final String orientation;
  final String sizeClass;
  final String imageType;
  final Vec2 imageTip; // 像的尖端
  final Vec2 imageBase; // 像的底

  LensImageResult({
    required this.u,
    required this.v,
    required this.magnification,
    required this.isReal,
    required this.isInverted,
    required this.orientation,
    required this.sizeClass,
    required this.imageType,
    required this.imageTip,
    required this.imageBase,
  });
}

// 計算箭頭物體經過薄透鏡的成像（以透鏡中心為原點，光軸沿 +x）
// 輸入：lens，arrow（物體）
// 支持物體在透鏡任意一側：自動判斷入射方向軸 effAxis
// 假設透鏡 angleRad=0（豎直放置），此版本用於凸/凹透鏡模擬器的精準模式
LensImageResult? computeThinLensImage(ThinLensItem lens, ArrowItem arrow) {
  final axis = lens.axisDir;
  final perp = Vec2(-axis.y, axis.x); // 豎直方向

  final baseX = (arrow.base - lens.center).dot(axis);
  final baseY = (arrow.base - lens.center).dot(perp);
  final tipY = (arrow.tip - lens.center).dot(perp);

  // 自動判斷物體在哪一側：
  // baseX < 0 → 物在左側，入射光沿 +axis（常規情況）
  // baseX > 0 → 物在右側，入射光沿 -axis（相當於把坐標系左右翻轉再計算）
  // baseX ≈ 0 → 物在透鏡上，無法成像
  if (baseX.abs() < 1e-6) return null;
  final bool objOnLeft = baseX < 0;
  final double uX = baseX.abs(); // 物距（取絕對值，恆為正的實物距）
  final double f = lens.f; // 凸正凹負

  if ((uX - f).abs() < 1e-6) {
    // 物在焦點，無法成像
    final tip = lens.center + perp * 1e9;
    return LensImageResult(
      u: uX,
      v: double.infinity,
      magnification: double.infinity,
      isReal: false,
      isInverted: false,
      orientation: "NONE",
      sizeClass: "INFINITE (PARALLEL)",
      imageType: "NO IMAGE",
      imageTip: tip,
      imageBase: lens.center,
    );
  }

  // 薄透鏡公式：1/u + 1/v = 1/f → v = u*f/(u-f)
  // v 正負含義（在 effAxis 局部坐標系下）：
  //   v > 0 → 像在透鏡出射側（透鏡右側如果 objOnLeft，左側如果 objOnRight）
  //   v < 0 → 像在透鏡入射側（虛像）
  final vX = (uX * f) / (uX - f);
  final m = -vX / uX;

  // 把局部坐標系的 vX 轉換回到全局 axis 坐標系：
  // - objOnLeft 時 effAxis=axis，vX 的正負含義與 axis 方向一致
  // - objOnRight 時 effAxis=-axis，vX>0 表示在 effAxis+方向 = axis-方向 = 全局 x 為負
  final double globalImageX = objOnLeft ? vX : -vX;

  final imageBaseY = baseY * m;
  final imageTipY = tipY * m;

  final imageBase = lens.center + axis * globalImageX + perp * imageBaseY;
  final imageTip = lens.center + axis * globalImageX + perp * imageTipY;

  // 實像判斷：在 effAxis 局部坐標系下 v > 0（像在出射側，光線實際會聚）
  // 虛像：v < 0（像在入射側，反向延長線會聚）
  final isReal = vX > 0;
  final isInverted = m < 0;
  String orientation = isInverted ? "INVERTED" : "ERECT";
  String sizeClass;
  final absM = m.abs();
  if (absM > 1.01) {
    sizeClass = "MAGNIFIED";
  } else if (absM < 0.99) {
    sizeClass = "DIMINISHED";
  } else {
    sizeClass = "EQUAL-SIZED";
  }
  String imageType = isReal ? "REAL IMAGE" : "VIRTUAL IMAGE";

  return LensImageResult(
    u: uX,
    v: globalImageX, // 返回全局坐標系下的像距（正=右側，負=左側）
    magnification: m,
    isReal: isReal,
    isInverted: isInverted,
    orientation: orientation,
    sizeClass: sizeClass,
    imageType: imageType,
    imageTip: imageTip,
    imageBase: imageBase,
  );
}

// 透鏡對一條入射光線的作用（薄透鏡近似）
// 支持任意方向入射（光線從左→右或右→左均可）：矩陣光學統一在"+axis方向傳播"的局部坐標系
List<Ray2> applyThinLens(ThinLensItem lens, Ray2 incoming, Vec2 hitPoint) {
  final axis = lens.axisDir; // 光軸方向（x'）
  final perp = Vec2(-axis.y, axis.x); // y'（豎直）
  final rel = hitPoint - lens.center;
  final y = rel.dot(perp); // 入射高度
  final fVal = lens.f; // 凸正凹負

  final udx = incoming.direction.dot(axis);
  final udy = incoming.direction.dot(perp);
  if (udx.abs() < 1e-9) {
    // 垂直入射（沿 y 方向），視為撞擊透鏡邊緣，方向不變
    return [Ray2(hitPoint + incoming.direction * 0.1, incoming.direction)];
  }

  // 矩陣光學要求光線沿 +axis 方向傳播。如果實際光線沿 -axis 方向，
  // 先把方向翻轉到 +axis 空間計算斜率，得到出射斜率後再翻轉回來。
  final sign = udx > 0 ? 1.0 : -1.0; // 傳播方向沿 axis 的正負
  // 翻轉到 +axis 方向後的斜率（dy/dx'，x'遞增方向）
  final u = udy / (udx * sign); // 等價於 (sign*udy)/(sign*udx)，即 udy_eff/udx_eff
  final uPrime = u - y / fVal;

  // 出射方向在 +axis 空間：axis + perp * uPrime（單位化前）
  final newDirPositive = (axis + perp * uPrime).normalized;
  // 按原始傳播方向恢復（沿 -axis 入射時，出射也沿 -axis 方向前進）
  final newDir = sign > 0 ? newDirPositive : newDirPositive * -1;

  return [Ray2(hitPoint + newDir * 0.01, newDir)];
}

// 光線追蹤：從射線出發，與場景中所有光學物品交互，返回一系列折線段
// segments: 繪製用的連續折線（實線）
// virtualSegments: 虛線（虛像等）
// maxBounces: 最大反射/折射次數
class TracedRay {
  final List<Vec2> points; // 折線點
  final bool isVirtual;
  TracedRay(this.points, {this.isVirtual = false});
}

// 簡單的光線場景追蹤：針對「自由創意工坊」
// items：所有光學物品；空氣折射率 n=1
List<TracedRay> traceRayScene(Ray2 initial, List<OpticalItem> items,
    {int maxBounces = 6}) {
  final traces = <TracedRay>[];
  final visited = <(OpticalItem, int)>{}; // 避免重複撞擊同一物品
  Vec2 currentOrigin = initial.origin;
  Vec2 currentDir = initial.direction;
  final path = <Vec2>[currentOrigin];
  int bounce = 0;
  bool insideGlass = false;

  while (bounce <= maxBounces) {
    // 找最近的交點
    OpticalItem? hitItem;
    ({Vec2 point, double t})? hit;
    Segment2? hitEdge;
    double minT = 1e18;

    for (final item in items) {
      if (item is PointSourceItem ||
          item is ParallelSourceItem ||
          item is ArrowItem) continue;
      // 對於 GlassBlockItem，即使起點在玻璃內也不跳過（需要找到射出邊）
      // 其他物品仍按原邏輯跳過起點所在物品
      if (item.hitTest(currentOrigin, tolerance: 0.01) &&
          item is! GlassBlockItem) continue;
      for (final edge in item.edges) {
        final r = edge.rayIntersect(Ray2(currentOrigin, currentDir));
        if (r != null && r.t > 0.001 && r.t < minT) {
          minT = r.t;
          hit = r;
          hitItem = item;
          hitEdge = edge;
        }
      }
    }

    // 若沒有撞擊：畫一條延伸射線後結束
    if (hit == null || hitItem == null) {
      path.add(currentOrigin + currentDir * 3000);
      break;
    }

    path.add(hit.point);

    if (hitItem is PlaneMirrorItem) {
      // 反射
      final reflected =
          hitItem.reflect(Ray2(currentOrigin, currentDir), hit.point);
      currentOrigin = reflected.origin;
      currentDir = reflected.direction;
      bounce++;
    } else if (hitItem is ThinLensItem) {
      final outs =
          applyThinLens(hitItem, Ray2(currentOrigin, currentDir), hit.point);
      if (outs.isEmpty) break;
      currentOrigin = outs.first.origin;
      currentDir = outs.first.direction;
      bounce++;
    } else if (hitItem is GlassBlockItem) {
      // 折射：進入或離開
      final tangent = (hitEdge!.p2 - hitEdge.p1).normalized;
      var normal = Vec2(-tangent.y, tangent.x);
      // 確保法線指向入射光來源
      if (currentDir.dot(normal) > 0) normal = normal * -1;
      final n1 = insideGlass ? hitItem.refractiveIndex : 1.0;
      final n2 = insideGlass ? 1.0 : hitItem.refractiveIndex;
      final newDirV = hitItem.refractDirection(currentDir, normal, n1, n2);
      if (newDirV == null) {
        // 全反射
        final n = normal;
        final d = currentDir;
        final reflected = d - n * (2 * d.dot(n));
        currentOrigin = hit.point + reflected * 0.01;
        currentDir = reflected;
      } else {
        insideGlass = !insideGlass;
        currentOrigin = hit.point + newDirV * 0.01;
        currentDir = newDirV;
      }
      bounce++;
    } else if (hitItem is WallItem) {
      // 牆體：停止（作光屏）
      break;
    } else {
      // 其他：不交互，穿過
      currentOrigin = hit.point + currentDir * 0.01;
      bounce++;
    }
  }

  traces.add(TracedRay(path));
  return traces;
}
