//kskbl
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/audio_util.dart';
import 'utils/api_key_guard.dart';
import 'package:flutter/services.dart';
import 'ray_field_entry.dart';

void main() {
  // 全局配置：状态栏透明 + 图标深色
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 状态栏背景透明
      statusBarIconBrightness: Brightness.dark, // 状态栏文字深色
    ),
  );
  runApp(const LensApp());
}

class LensApp extends StatelessWidget {
  const LensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optics Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      home: const MainMenuPage(),
    );
  }
}

// =============================================================================
// 通用视频背景组件
// =============================================================================
class AutoVideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;

  const AutoVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.88,
  });

  @override
  State<AutoVideoBackground> createState() => _AutoVideoBackgroundState();
}

class _AutoVideoBackgroundState extends State<AutoVideoBackground> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideo(MediaQuery.of(context).orientation);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_controller != null &&
        _lastOrientation != null &&
        currentOrientation != _lastOrientation) {
      _switchVideo(currentOrientation);
    }
  }

  void _initVideo(Orientation orientation) {
    _lastOrientation = orientation;
    final String path = orientation == Orientation.landscape
        ? 'assets/videos/bg_landscape.mp4'
        : 'assets/videos/bg_portrait.mp4';
    _controller = VideoPlayerController.asset(path)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
        _controller?.setLooping(true);
        _controller?.setVolume(0.0);
        _controller?.play();
      });
  }

  void _switchVideo(Orientation orientation) {
    _lastOrientation = orientation;
    _controller?.dispose();
    setState(() {
      _isInitialized = false;
      _controller = null;
    });
    final String path = orientation == Orientation.landscape
        ? 'assets/videos/bg_landscape.mp4'
        : 'assets/videos/bg_portrait.mp4';
    _controller = VideoPlayerController.asset(path)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
        _controller?.setLooping(true);
        _controller?.setVolume(0.0);
        _controller?.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand, // 强制铺满父布局，消除黑边根源
      children: [
        if (_isInitialized && _controller != null)
          ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover, // 等比铺满、裁剪多余画面，无黑边
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          )
        else
          Container(color: const Color(0xFFF8F9FA)),
        Container(color: Colors.white.withValues(alpha: widget.overlayOpacity)),
        widget.child,
      ],
    );
  }
}

// =============================================================================
// 主菜单页面
// =============================================================================
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;
    final double currentHeight = MediaQuery.of(context).size.height;
    final bool isShortScreen = currentHeight < 600;
    final double horizontalPadding = currentWidth > 600 ? 60.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AutoVideoBackground(
        overlayOpacity: 0.12,
        child: SizedBox.expand(
          child: SafeArea(
            child: Center(
              // ========== 修改1：新增滚动容器，横屏可上下滑动 ==========
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: currentHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    // ========== 修改2：替换Spacer为spaceBetween ==========
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 顶部标题区域
                        Column(
                          children: [
                            const SizedBox(height: 40),
                            Text(
                              "OPTICAL LENS IMAGING LAB",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: currentWidth > 600 ? 36 : 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: const Color(0xFF111111),
                                height: 1.2,
                              ),
                            ),
                            Text(
                              "Convex Lens Physics Teaching App",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: currentWidth > 600 ? 16 : 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                color: const Color(0xFF4A4A4A),
                              ),
                            ),
                            const SizedBox(height: 48),
                            Container(
                              width: 40,
                              height: 3,
                              color: const Color(0xFF4A4A4A),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),

                        // 中间菜单卡片
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMenuCard(
                              context,
                              'LAB INTRODUCTION',
                              '01 / CORE CONCEPTS & IMAGING LAWS',
                              () => const IntroductionMenuPage(),
                              isShortScreen,
                            ),
                            _buildMenuCard(
                              context,
                              'INTERACTIVE RAY FIELD',
                              '02 / DYNAMIC OPTICAL LABORATORY',
                              () => const RayFieldEntryPage(),
                              isShortScreen,
                            ),
                            _buildMenuCard(
                              context,
                              'KNOWLEDGE MATRIX',
                              '03 / OPTICAL MATRIX CHECKPOINT',
                              () => const QuizPage(),
                              isShortScreen,
                            ),
                          ],
                        ),

                        // 底部版本号
                        const Column(
                          children: [
                            Text(
                              'V.2.0 / OPTICAL RESEARCH LAB',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black38,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    Widget Function() targetPage,
    bool isShort,
  ) {
    return _HoverScaleButton(
      isShort: isShort,
      title: title,
      subtitle: subtitle,
      onTap: () async {
        await AudioUtil.playClick();
        Feedback.forTap(context);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                targetPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        );
      },
    );
  }
}

class _HoverScaleButton extends StatefulWidget {
  final bool isShort;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HoverScaleButton({
    required this.isShort,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: widget.isShort ? 8.0 : 14.0),
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.75),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF4A4A4A).withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.02),
                  blurRadius: _isHovered ? 16 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: widget.isShort ? 18.0 : 26.0,
                horizontal: 32.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color:
                        _isHovered ? const Color(0xFF4A4A4A) : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 知识点目录页
// =============================================================================
class IntroductionMenuPage extends StatelessWidget {
  const IntroductionMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modules = [
      {
        "id": "01",
        "title": "REFRACTION OF LIGHT",
        "subtitle": "How light bends when it goes through different materials",
        "page": const RefractionPage(),
      },
      {
        "id": "02",
        "title": "LENS FUNDAMENTALS",
        "subtitle": "Convex & concave lenses and basic terms",
        "page": const LensBasicsPage(),
      },
      {
        "id": "03",
        "title": "RAY DIAGRAM RULES",
        "subtitle": "Three special rays for drawing lens diagrams",
        "page": const RayDiagramRulesPage(),
      },
      {
        "id": "04",
        "title": "CONVEX IMAGING LAWS",
        "subtitle": "Image types at different object positions",
        "page": const ConvexImagingPage(),
      },
      {
        "id": "05",
        "title": "PRISM APPLICATIONS",
        "subtitle": "Prisms in nature, science and daily life",
        "page": const PrismApplicationsPage(),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      // ========== 修改：让body延伸到AppBar下方，消除顶部黑边 ==========
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, width: 1.2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF111111),
              size: 18,
            ),
            onPressed: () async {
              await AudioUtil.playClick();
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODULES',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Optics Syllabus Matrix',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...modules.map((module) {
                      return _ModuleCard(
                        id: module["id"],
                        title: module["title"],
                        subtitle: module["subtitle"],
                        onTap: () async {
                          await AudioUtil.playClick();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      module["page"],
                              transitionsBuilder: (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) =>
                                  FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final String id;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white : const Color(0xFFFAFAFA),
            border: Border.all(
              color: _isHovered
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.01),
                blurRadius: _isHovered ? 12 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                widget.id,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black38,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: _isHovered ? const Color(0xFF4A4A4A) : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 通用返回头部
PreferredSizeWidget _buildCommonAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12, width: 1.2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Color(0xFF111111),
          size: 18,
        ),
        onPressed: () async {
          await AudioUtil.playClick();
          Navigator.pop(context);
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    ),
  );
}

Widget _buildSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20.0, top: 8),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.black38,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 0.5, color: Colors.black12)),
      ],
    ),
  );
}

Widget _buildTerm(String name, String desc) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

Widget _buildRule(String cond, String res) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            cond,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Color(0xFF111111),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            res,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildImageCard(String assetPath) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        width: double.infinity,
      ),
    ),
  );
}

// 2.1 光的折射页面
class RefractionPage extends StatelessWidget {
  const RefractionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // 消除顶部黑边
      appBar: _buildCommonAppBar(context),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHAPTER 01',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Refraction of Light',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'When light goes from one transparent material to another at an angle, it bends. This bending is called refraction. It happens because light travels at different speeds in different materials.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildImageCard('assets/images/refraction_diagram.png'),
                    _buildSectionHeader('TWO RULES OF REFRACTION'),
                    _buildTerm(
                      'Rule 1: Same Plane',
                      'The incoming ray, the bent ray, and the normal line all lie on the same flat surface.',
                    ),
                    _buildTerm(
                      "Rule 2: Snell's Law",
                      'How much light bends depends on the two materials. We write it as: n = sin(i) / sin(r)',
                    ),
                    _buildSectionHeader('HOW LIGHT BENDS'),
                    _buildTerm(
                      'Into a denser material (air → glass/water)',
                      'Light slows down and bends TOWARDS the normal line. The angle r is smaller than angle i.',
                    ),
                    _buildTerm(
                      'Into a less dense material (water → air)',
                      'Light speeds up and bends AWAY FROM the normal line. The angle r is bigger than angle i.',
                    ),
                    _buildTerm(
                      'Straight on (90° hit)',
                      'If light hits the surface straight head-on, it does not bend at all. It goes straight through.',
                    ),
                    _buildSectionHeader('THINGS YOU SEE EVERY DAY'),
                    _buildTerm(
                      'Bent straw in water',
                      'A straw in a glass looks broken at the water surface because of refraction.',
                    ),
                    _buildTerm(
                      'Shallow-looking pool',
                      'A swimming pool looks shallower than it really is. The light bends when it comes out of water.',
                    ),
                    _buildTerm(
                      'Glass block shift',
                      'Light goes in and out of a flat glass block. It comes out parallel to the ray that went in, but shifted sideways.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2.2 透镜基础
class LensBasicsPage extends StatelessWidget {
  const LensBasicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // 消除顶部黑边
      appBar: _buildCommonAppBar(context),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHAPTER 02',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lens Fundamentals',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'A lens is a clear curved piece of glass or plastic. It bends light to form images. There are two main types of lenses.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildImageCard('assets/images/hand_lens.png'),
                    _buildSectionHeader('TWO TYPES OF LENSES'),
                    _buildTerm(
                      'Convex Lens (Converging)',
                      'Thicker in the middle, thinner at the edges. It brings light rays together to a single point.',
                    ),
                    _buildTerm(
                      'Concave Lens (Diverging)',
                      'Thinner in the middle, thicker at the edges. It spreads light rays outward, away from each other.',
                    ),
                    const SizedBox(height: 8),
                    _buildImageCard('assets/images/lens_formula.png'),
                    _buildSectionHeader('KEY PARTS'),
                    _buildTerm(
                      'Principal Axis',
                      'The straight line that runs through the center of the lens, right down the middle.',
                    ),
                    _buildTerm(
                      'Optical Center (O)',
                      'The center point of the lens. Any ray passing through this point goes straight without bending.',
                    ),
                    _buildTerm(
                      'Principal Focus (F)',
                      'The point where parallel light rays meet after passing through the lens.',
                    ),
                    _buildTerm(
                      'Focal Length (f)',
                      'The distance from the center of the lens to the focal point. It tells us how strong the lens is.',
                    ),
                    _buildSectionHeader('USEFUL FORMULAS'),
                    _buildTerm(
                      'Lens Formula',
                      'Links object distance (u), image distance (v) and focal length (f): 1/f = 1/v + 1/u',
                    ),
                    _buildTerm(
                      'Magnification (m)',
                      'How many times bigger the image is than the object: m = image height / object height = v / u',
                    ),
                    _buildTerm(
                      'Power of Lens (P)',
                      'How strongly the lens bends light, measured in dioptres (D): P = 1 / f (in meters)',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2.3 光线作图规则
class RayDiagramRulesPage extends StatelessWidget {
  const RayDiagramRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // 消除顶部黑边
      appBar: _buildCommonAppBar(context),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHAPTER 03',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ray Diagram Construction',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'We use ray diagrams to find where the image will form. There are three special rays that are easy to draw. You only need two of them to find the image.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildImageCard('assets/images/ray_rules.png'),
                    _buildSectionHeader('THREE SPECIAL RAYS'),
                    _buildTerm(
                      'Ray 1 — Parallel to the axis',
                      'A ray coming in parallel to the principal axis bends and passes through the focal point on the other side.',
                    ),
                    _buildTerm(
                      'Ray 2 — Through optical center',
                      'A ray passing straight through the center of the lens does not bend. It continues in a straight line.',
                    ),
                    _buildTerm(
                      'Ray 3 — Through the focal point',
                      'A ray that comes from the object and passes through the focal point comes out parallel to the axis.',
                    ),
                    _buildSectionHeader('IMAGE TYPES'),
                    _buildTerm(
                      'Real Image',
                      'Light rays actually meet at the image point. You can project this image onto a screen.',
                    ),
                    _buildTerm(
                      'Virtual Image',
                      'Light rays do not really meet. They only look like they come from the image. You cannot project it onto a screen.',
                    ),
                    _buildTerm(
                      'How to find the image',
                      'The top of the image is where any two refracted rays cross. The image stands perpendicular to the principal axis.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2.4 凸透镜成像
class ConvexImagingPage extends StatelessWidget {
  const ConvexImagingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // 消除顶部黑边
      appBar: _buildCommonAppBar(context),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHAPTER 04',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Convex Lens Imaging Rules',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'The type and size of the image depend on where the object is placed. There are 6 main cases for a convex lens.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildImageCard('assets/images/image_distance.png'),
                    _buildSectionHeader('ALL 6 IMAGING CASES'),
                    const SizedBox(height: 8),
                    const Text(
                      'Case 1: Object very far away (at infinity)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_infinity.png'),
                    _buildRule('Image position', 'At the focal point F'),
                    _buildRule('Image type', 'Real, inverted, very tiny'),
                    const SizedBox(height: 16),
                    const Text(
                      'Case 2: Object beyond 2F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_beyond_2f.png'),
                    _buildRule(
                      'Image position',
                      'Between F and 2F on the other side',
                    ),
                    _buildRule(
                      'Image type',
                      'Real, inverted, smaller than object',
                    ),
                    _buildRule('Everyday use', 'Cameras, human eyes'),
                    const SizedBox(height: 16),
                    const Text(
                      'Case 3: Object exactly at 2F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_at_2f.png'),
                    _buildRule('Image position', 'At 2F on the other side'),
                    _buildRule(
                      'Image type',
                      'Real, inverted, same size as object',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Case 4: Object between F and 2F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_between_f_2f.png'),
                    _buildRule('Image position', 'Beyond 2F on the other side'),
                    _buildRule(
                      'Image type',
                      'Real, inverted, bigger than object',
                    ),
                    _buildRule('Everyday use', 'Projectors, microscopes'),
                    const SizedBox(height: 16),
                    const Text(
                      'Case 5: Object exactly at focus F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_at_f.png'),
                    _buildRule('Image position', 'No image forms'),
                    _buildRule(
                      'Image type',
                      'Rays come out parallel to each other',
                    ),
                    _buildRule('Everyday use', 'Torches, searchlights'),
                    const SizedBox(height: 16),
                    const Text(
                      'Case 6: Object between lens and F',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageCard('assets/images/lens_inside_f.png'),
                    _buildRule(
                      'Image position',
                      'On the same side as the object',
                    ),
                    _buildRule(
                      'Image type',
                      'Virtual, upright, bigger than object',
                    ),
                    _buildRule('Everyday use', 'Magnifying glasses'),
                    _buildSectionHeader('EASY RULES TO REMEMBER'),
                    _buildTerm(
                      'Focus divides real and virtual',
                      'Object outside F → real image. Object inside F → virtual image.',
                    ),
                    _buildTerm(
                      '2F divides big and small',
                      'Object outside 2F → small image. Between F and 2F → big image.',
                    ),
                    _buildTerm(
                      'Real image motion rule',
                      'When object moves closer to the lens, the image moves away and gets bigger.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2.5 棱镜应用
class PrismApplicationsPage extends StatelessWidget {
  const PrismApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // 消除顶部黑边
      appBar: _buildCommonAppBar(context),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHAPTER 05',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Real-World Prism Uses',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'A prism is a triangle-shaped block of clear glass or plastic. It bends light and splits white light into rainbow colors. Prisms are used everywhere in nature and technology.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    _buildSectionHeader('IN NATURE'),
                    const SizedBox(height: 8),
                    _buildImageCard('assets/images/rainbow_drop.png'),
                    _buildTerm(
                      'Rainbows',
                      'Tiny water drops in the air act like small prisms. Sunlight bends, reflects, and splits into colors inside each drop, forming a rainbow.',
                    ),
                    _buildSectionHeader('SCIENCE TOOLS'),
                    const SizedBox(height: 8),
                    _buildImageCard('assets/images/spectrometer.png'),
                    _buildTerm(
                      'Spectrometer',
                      'Scientists use prisms to split light into colors. This helps them find out what materials are made of, even stars far away.',
                    ),
                    _buildTerm(
                      'Periscope',
                      'Two prisms reflect light to let you see over walls or around corners. Submarines and tanks use this to see outside.',
                    ),
                    _buildTerm(
                      'Binoculars & Telescopes',
                      'Prisms flip the image the right way up and make the instrument shorter by folding the light path.',
                    ),
                    _buildSectionHeader('MEDICAL USES'),
                    const SizedBox(height: 8),
                    _buildImageCard('assets/images/ophthalmoscope.png'),
                    _buildTerm(
                      'Eye examination tools',
                      'Doctors use prisms in tools to look inside your eye and check for eye health problems.',
                    ),
                    _buildTerm(
                      'Prism glasses',
                      'Special glasses with prism lenses help people whose eyes do not line up correctly. They move the image so both eyes see together.',
                    ),
                    _buildSectionHeader('DAILY TECHNOLOGY'),
                    _buildTerm(
                      'Camera viewfinders',
                      'Prisms inside cameras reflect light so you see a clear, upright image through the viewfinder.',
                    ),
                    _buildTerm(
                      'Fiber optics',
                      'Small prisms help guide light signals into fiber optic cables for fast internet and phone calls.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 光线交互实验室
// =============================================================================
class RayDiagramPage extends StatefulWidget {
  const RayDiagramPage({super.key});

  @override
  State<RayDiagramPage> createState() => _RayDiagramPageState();
}

class _RayDiagramPageState extends State<RayDiagramPage> {
  // ========== 物理参数 ==========
  double _u = 158.0;
  double _f = 250.0;
  final double _objectHeight = 50.0;
  final double _lensHalfHeight = 140.0;

  // ========== 画布与缩放状态 ==========
  double _pixelPerUnit = 1.0;
  double _viewOffsetX = 0.0;
  Size _canvasSize = Size.zero;
  Size _baseCanvasSize = Size.zero;
  bool _isFirstLayout = true;
  String _dragMode = "NONE";

  // ========== 全屏状态 ==========
  bool _isCanvasFullscreen = false;

  late TextEditingController _uController;
  late TextEditingController _fController;

  @override
  void initState() {
    super.initState();
    _uController = TextEditingController(text: "${_u.toInt()}");
    _fController = TextEditingController(text: "${_f.toInt()}");
  }

  @override
  void dispose() {
    _uController.dispose();
    _fController.dispose();
    super.dispose();
  }

  // ========== 成像属性判断 ==========
  Map<String, String> _deriveProperties() {
    if (_u > 2 * _f) {
      return {
        "orientation": "INVERTED",
        "size": "DIMINISHED",
        "type": "REAL IMAGE",
      };
    } else if (_u == 2 * _f) {
      return {
        "orientation": "INVERTED",
        "size": "EQUAL-SIZED",
        "type": "REAL IMAGE",
      };
    } else if (_u > _f && _u < 2 * _f) {
      return {
        "orientation": "INVERTED",
        "size": "MAGNIFIED",
        "type": "REAL IMAGE",
      };
    } else if (_u == _f) {
      return {
        "orientation": "NONE",
        "size": "INFINITE (PARALLEL)",
        "type": "NO IMAGE",
      };
    } else {
      return {
        "orientation": "ERECT",
        "size": "MAGNIFIED",
        "type": "VIRTUAL IMAGE",
      };
    }
  }

  // ========== 仅布局尺寸变化时执行一次自动缩放适配 ==========
  void _autoFitScale(double canvasWidth) {
    double leftNeed = _u + 60;
    double rightNeed = 2 * _f + 60;
    double totalPhysicalWidth = leftNeed + rightNeed;
    _pixelPerUnit = canvasWidth / totalPhysicalWidth;

    if (_pixelPerUnit > 1.2) _pixelPerUnit = 1.2;
    if (_pixelPerUnit < 0.2) _pixelPerUnit = 0.2;

    _viewOffsetX = (rightNeed - leftNeed) * _pixelPerUnit / 2;
    _clampViewOffset();
  }

  // ========== 钳位视图偏移量，防止Slider越界 ==========
  void _clampViewOffset() {
    double maxOffset = 2 * _f * _pixelPerUnit;
    if (_viewOffsetX > maxOffset) {
      _viewOffsetX = maxOffset;
    } else if (_viewOffsetX < -maxOffset) {
      _viewOffsetX = -maxOffset;
    }
  }

  // ========== 提交时校验数值（取整、最小值10、英文提示） ==========
  void _validateAndApply(
    TextEditingController controller,
    ValueChanged<double> onApply,
  ) {
    final inputText = controller.text.trim();
    final parsed = double.tryParse(inputText);

    if (parsed == null) {
      controller.text = "${onApply == _applyU ? _u.toInt() : _f.toInt()}";
      return;
    }

    int intValue = parsed.round();
    if (intValue < 10) {
      controller.text = "10";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "For optimal viewing experience, the value is too small and has been automatically set to 10",
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      onApply(10.0);
    } else {
      controller.text = "$intValue";
      onApply(intValue.toDouble());
    }
  }

  void _applyU(double val) {
    setState(() {
      _u = val;
      // 修改参数不重新计算缩放，保持画面比例稳定
    });
  }

  void _applyF(double val) {
    setState(() {
      _f = val;
      // 修改焦距不重新计算缩放，焦点位置不会乱动
      _clampViewOffset(); // 仅修正滑块边界，不改变整体比例
    });
  }

  // ========== 坐标转换 ==========
  double _screenToPhysics(double screenX) {
    double centerX = _baseCanvasSize.width / 2 + _viewOffsetX;
    return (screenX - centerX) / _pixelPerUnit;
  }

  // ========== 拖拽交互 ==========
  void _handlePanStart(DragStartDetails details) {
    double clickPhysicsX = _screenToPhysics(details.localPosition.dx);
    double objPhysicsX = -_u;

    if (clickPhysicsX.abs() < 25 / _pixelPerUnit) {
      _dragMode = "LENS";
    } else if ((clickPhysicsX - objPhysicsX).abs() < 25 / _pixelPerUnit) {
      _dragMode = "OBJECT";
    } else {
      _dragMode = "NONE";
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    double physicsX = _screenToPhysics(details.localPosition.dx);

    setState(() {
      if (_dragMode == "OBJECT") {
        double newU = -physicsX;
        if (newU > 10) {
          _u = newU;
          _uController.text = "${_u.toInt()}";
          // 拖拽不触发自动缩放，画面比例保持不变
        }
      }
    });
  }

  // ========== 全屏画布页面 ==========
  Widget _buildFullscreenCanvas() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (_isFirstLayout || _canvasSize.width != constraints.maxWidth) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                _baseCanvasSize = _canvasSize;
                _autoFitScale(constraints.maxWidth);
                _isFirstLayout = false;
              }
              return GestureDetector(
                onPanStart: _handlePanStart,
                onPanUpdate: _handlePanUpdate,
                child: CustomPaint(
                  size: _canvasSize,
                  painter: ScaledLensPainter(
                    u: _u,
                    f: _f,
                    objectHeight: _objectHeight,
                    lensHalfHeight: _lensHalfHeight,
                    pixelPerUnit: _pixelPerUnit,
                    viewOffsetX: _viewOffsetX,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                await AudioUtil.playClick();
                setState(() {
                  _isCanvasFullscreen = false;
                  _isFirstLayout = true;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_exit, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "EXIT FULLSCREEN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: _buildHorizontalSlider(),
          ),
        ],
      ),
    );
  }

  // ========== 底部横向平移滑块 ==========
  Widget _buildHorizontalSlider() {
    double maxOffset = 2 * _f * _pixelPerUnit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Slider(
        value: _viewOffsetX,
        min: -maxOffset,
        max: maxOffset,
        activeColor: const Color(0xFF4A4A4A),
        inactiveColor: Colors.black12,
        onChanged: (val) {
          setState(() {
            _viewOffsetX = val;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCanvasFullscreen) {
      return _buildFullscreenCanvas();
    }

    double v = (_u - _f != 0) ? (_u * _f) / (_u - _f) : double.infinity;
    final props = _deriveProperties();

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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () async {
              await AudioUtil.playClick();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
        title: const Text(
          "RAY FIELD LAB",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        shape: Border(
          bottom:
              BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1),
        ),
      ),
      // ========== 修改1：恢复视频背景组件 ==========
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ========== 仅尺寸变化时执行一次适配 ==========
              if (_isFirstLayout || _canvasSize.width != constraints.maxWidth) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                double screenH = constraints.maxHeight;
                // ========== 修改2：画布占比从0.40改为0.35，避免顶部显示不全 ==========
                _baseCanvasSize = Size(
                  constraints.maxWidth - 48,
                  screenH * 0.35,
                );
                _autoFitScale(_baseCanvasSize.width);
                _isFirstLayout = false;
              }

              bool isNarrowScreen = constraints.maxWidth < 600;

              return SingleChildScrollView(
                // ========== 修改3：减小顶部padding ==========
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ========== 顶部参数栏 ==========
                    _buildTopMetricBar(v),
                    const SizedBox(height: 16),

                    // ========== 光路画布 ==========
                    _buildRayCanvas(),
                    const SizedBox(height: 8),

                    // ========== 平移滑块 ==========
                    _buildHorizontalSlider(),
                    const SizedBox(height: 12),

                    // ========== 底部参数面板（自适应横竖排列） ==========
                    _buildParameterPanel(isNarrowScreen, props),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ========== 顶部参数指标栏 ==========
  Widget _buildTopMetricBar(double v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTopMetric("u (OBJECT DISTANCE)", "${_u.toInt()}"),
          _buildTopMetric("f (FOCAL LENGTH)", "${_f.toInt()}"),
          _buildTopMetric("2f (DOUBLE FOCAL)", "${(2 * _f).toInt()}"),
          _buildTopMetric(
              "v (IMAGE DISTANCE)", v.isInfinite ? "∞" : v.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _buildTopMetric(String label, String val) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          val,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }

  // ========== 光路画布区域 ==========
  Widget _buildRayCanvas() {
    return Stack(
      children: [
        GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          child: Container(
            height: _baseCanvasSize.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: ScaledLensPainter(
                  u: _u,
                  f: _f,
                  objectHeight: _objectHeight,
                  lensHalfHeight: _lensHalfHeight,
                  pixelPerUnit: _pixelPerUnit,
                  viewOffsetX: _viewOffsetX,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () async {
              await AudioUtil.playClick();
              setState(() {
                _isCanvasFullscreen = true;
                _isFirstLayout = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.fullscreen,
                size: 20,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== 参数面板（自适应横竖排列） ==========
  Widget _buildParameterPanel(bool isNarrow, Map<String, String> props) {
    Widget paramCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SYSTEM PARAMETERS (DRAG LENS OR OBJECT ON CANVAS)",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          isNarrow
              ? Column(
                  children: [
                    _buildInputField(
                      "Object Distance (u)",
                      _uController,
                      () => _validateAndApply(_uController, _applyU),
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      "Focal Length (f)",
                      _fController,
                      () => _validateAndApply(_fController, _applyF),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        "Object Distance (u)",
                        _uController,
                        () => _validateAndApply(_uController, _applyU),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        "Focal Length (f)",
                        _fController,
                        () => _validateAndApply(_fController, _applyF),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );

    Widget propertyCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPropertyRow(
            "ORIENTATION",
            props["orientation"]!,
            const Color(0xFF616161),
          ),
          const SizedBox(height: 8),
          _buildPropertyRow(
            "FIELD SIZE",
            props["size"]!,
            const Color(0xFF424242),
          ),
          const SizedBox(height: 8),
          _buildPropertyRow(
            "IMAGE TYPE",
            props["type"]!,
            _u < _f ? const Color(0xFFFF2D55) : const Color(0xFF4CAF50),
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          paramCard,
          const SizedBox(height: 16),
          propertyCard,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 11, child: paramCard),
          const SizedBox(width: 20),
          Expanded(flex: 9, child: propertyCard),
        ],
      );
    }
  }

  // ========== 输入框 + 提交按钮 ==========
  Widget _buildInputField(
    String label,
    TextEditingController ctrl,
    VoidCallback onSubmit,
  ) {
    double btnHeight = MediaQuery.of(context).size.shortestSide * 0.09;
    if (btnHeight > 44) btnHeight = 44;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: btnHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222222),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: onSubmit,
                child: const Text(
                  "SUBMIT",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyRow(String label, String value, Color badgeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black45,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 光路绘制器
// =============================================================================
class ScaledLensPainter extends CustomPainter {
  final double u;
  final double f;
  final double objectHeight;
  final double lensHalfHeight;
  final double pixelPerUnit;
  final double viewOffsetX;

  ScaledLensPainter({
    required this.u,
    required this.f,
    required this.objectHeight,
    required this.lensHalfHeight,
    required this.pixelPerUnit,
    required this.viewOffsetX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final double centerX = size.width / 2 + viewOffsetX;

    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.5;
    final lensPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    final rayPaint = Paint()
      ..color = const Color(0xFFFF2D55)
      ..strokeWidth = 2.0;
    final objectPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 3.5;
    final imagePaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 3.0;

    // 主光轴
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);

    // 透镜
    final lensH = lensHalfHeight * pixelPerUnit;
    canvas.drawLine(
      Offset(centerX, midY - lensH),
      Offset(centerX, midY + lensH),
      lensPaint,
    );
    canvas.drawLine(
      Offset(centerX, midY - lensH),
      Offset(centerX - 8, midY - lensH + 10),
      lensPaint,
    );
    canvas.drawLine(
      Offset(centerX, midY - lensH),
      Offset(centerX + 8, midY - lensH + 10),
      lensPaint,
    );
    canvas.drawLine(
      Offset(centerX, midY + lensH),
      Offset(centerX - 8, midY + lensH - 10),
      lensPaint,
    );
    canvas.drawLine(
      Offset(centerX, midY + lensH),
      Offset(centerX + 8, midY + lensH - 10),
      lensPaint,
    );

    // 焦点标记
    _drawNode(canvas, Offset(centerX - f * pixelPerUnit, midY), "F", midY);
    _drawNode(canvas, Offset(centerX - 2 * f * pixelPerUnit, midY), "2F", midY);
    _drawNode(canvas, Offset(centerX + f * pixelPerUnit, midY), "F'", midY);
    _drawNode(
        canvas, Offset(centerX + 2 * f * pixelPerUnit, midY), "2F'", midY);

    // 物体
    final double objX = centerX - u * pixelPerUnit;
    final double objH = objectHeight * pixelPerUnit;
    final double objTopY = midY - objH;
    canvas.drawLine(Offset(objX, midY), Offset(objX, objTopY), objectPaint);
    canvas.drawLine(
      Offset(objX, objTopY),
      Offset(objX - 6, objTopY + 10),
      objectPaint,
    );
    canvas.drawLine(
      Offset(objX, objTopY),
      Offset(objX + 6, objTopY + 10),
      objectPaint,
    );
    _drawPainterText(
      canvas,
      Offset(objX - 25, objTopY - 22),
      "Object (u)",
      Colors.black87,
    );

    // 成像计算
    double v = (u - f != 0) ? (u * f) / (u - f) : double.infinity;
    double magnification = (u - f != 0) ? f / (f - u) : double.infinity;
    double imgH = objectHeight * magnification * pixelPerUnit;
    double imgX = centerX + v * pixelPerUnit;
    double imgTopY = midY - imgH;

    if (u > f) {
      // 实像光路
      canvas.drawLine(
          Offset(objX, objTopY), Offset(centerX, objTopY), rayPaint);
      canvas.drawLine(
          Offset(centerX, objTopY), Offset(imgX, imgTopY), rayPaint);
      canvas.drawLine(Offset(objX, objTopY), Offset(imgX, imgTopY), rayPaint);

      if (imgX < size.width) {
        double slope1 = (imgTopY - objTopY) / (imgX - centerX);
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(size.width, imgTopY + slope1 * (size.width - imgX)),
          rayPaint,
        );
        double slope2 = (imgTopY - midY) / (imgX - centerX);
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(size.width, imgTopY + slope2 * (size.width - imgX)),
          rayPaint,
        );
      }

      if (imgX < size.width && imgX > 0) {
        canvas.drawLine(Offset(imgX, midY), Offset(imgX, imgTopY), imagePaint);
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(imgX - 6, imgTopY - 10),
          imagePaint,
        );
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(imgX + 6, imgTopY - 10),
          imagePaint,
        );
        _drawPainterText(
          canvas,
          Offset(imgX - 25, imgTopY + 8),
          "Image (v)",
          const Color(0xFF4CAF50),
        );
      }
    } else if (u < f) {
      // 虚像光路
      canvas.drawLine(
          Offset(objX, objTopY), Offset(centerX, objTopY), rayPaint);
      double slopeF = (midY - objTopY) / (f * pixelPerUnit);
      canvas.drawLine(
        Offset(centerX, objTopY),
        Offset(size.width, objTopY + slopeF * (size.width - centerX)),
        rayPaint,
      );
      double slopeC = (midY - objTopY) / (u * pixelPerUnit);
      canvas.drawLine(
        Offset(objX, objTopY),
        Offset(size.width, midY + slopeC * (size.width - centerX)),
        rayPaint,
      );

      final dashedPaint = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1.2;
      _drawDashed(
        canvas,
        Offset(centerX, objTopY),
        Offset(imgX, imgTopY),
        dashedPaint,
      );
      _drawDashed(
        canvas,
        Offset(centerX, midY),
        Offset(imgX, imgTopY),
        dashedPaint,
      );

      if (imgX > 0 && imgX < size.width) {
        canvas.drawLine(Offset(imgX, midY), Offset(imgX, imgTopY), imagePaint);
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(imgX - 6, imgTopY + 10),
          imagePaint,
        );
        canvas.drawLine(
          Offset(imgX, imgTopY),
          Offset(imgX + 6, imgTopY + 10),
          imagePaint,
        );
        _drawPainterText(
          canvas,
          Offset(imgX - 30, imgTopY - 22),
          "Virtual Image",
          const Color(0xFF4CAF50),
        );
      }
    }
  }

  void _drawPainterText(
      Canvas canvas, Offset offset, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawNode(Canvas canvas, Offset offset, String label, double midY) {
    canvas.drawCircle(offset, 3.0, Paint()..color = Colors.black45);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(offset.dx - 6, midY + 10));
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    double distance = (end - start).distance;
    final int count = (distance / 8).floor();
    for (int i = 0; i < count; i++) {
      if (i % 2 == 0) {
        canvas.drawLine(
          Offset.lerp(start, end, i / count)!,
          Offset.lerp(start, end, (i + 1) / count)!,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScaledLensPainter oldDelegate) =>
      oldDelegate.u != u ||
      oldDelegate.f != f ||
      oldDelegate.pixelPerUnit != pixelPerUnit ||
      oldDelegate.viewOffsetX != viewOffsetX;
}

// =============================================================================
// 答题面板 + Gemini AI 聊天页面
// =============================================================================
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  int _streak = 0;
  int? _selectedIdx;
  bool _isSettled = false;

  late AnimationController _streakController;
  late Animation<double> _streakScale;

  bool _isAiThinking = false;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [
    {
      "role": "gemini",
      "text":
          "Hi! I'm your Optics AI Tutor. Ask me anything about refraction, lenses, ray diagrams or prisms!",
    },
  ];

  final List<Map<String, dynamic>> _staticQuestions = [
    {
      "q":
          "When the object is beyond 2f, what kind of image does a convex lens form?",
      "opt": [
        "Inverted, smaller, real image",
        "Inverted, bigger, real image",
        "Upright, bigger, virtual image",
      ],
      "correct": 0,
      "praise": "Well done! This is exactly how cameras and our eyes work.",
      "analysis":
          "When u > 2f, the image forms between f and 2f on the other side. It is real, inverted and smaller than the object.",
    },
    {
      "q": "A magnifying glass works because the object is placed:",
      "opt": ["Beyond 2f", "Between f and 2f", "Inside the focal point f"],
      "correct": 2,
      "praise":
          "Perfect! Inside the focus gives an upright magnified virtual image.",
      "analysis":
          "When the object is between the lens and the focal point (u < f), the rays spread out. Our eye traces them back to see a larger, upright virtual image.",
    },
    {
      "q":
          "A classroom projector shows a big clear picture on the wall. The slide must be placed at:",
      "opt": ["u < f", "f < u < 2f", "u > 2f"],
      "correct": 1,
      "praise": "Great! Projectors use the magnified real image case.",
      "analysis":
          "When the object is between f and 2f, the image forms far beyond 2f. It is real, inverted and much bigger than the object.",
    },
    {
      "q":
          "In the human eye, the lens forms an image on the retina. That image is:",
      "opt": [
        "Upright, magnified, virtual",
        "Inverted, magnified, real",
        "Inverted, smaller, real",
      ],
      "correct": 2,
      "praise": "Correct! Our brain flips the image back for us automatically.",
      "analysis":
          "Objects far away are beyond 2f for the eye lens. The image on the retina is small, inverted and real. Our brain interprets it the right way up.",
    },
    {
      "q":
          "If an object placed 15 cm from a convex lens forms a same-sized real image, the focal length is:",
      "opt": ["7.5 cm", "15 cm", "30 cm"],
      "correct": 0,
      "praise": "Excellent! Same size image happens exactly at 2f.",
      "analysis":
          "A same-sized real image forms when u = 2f. If u = 15 cm, then 2f = 15 cm, so f = 7.5 cm.",
    },
    {
      "q":
          "When you use a magnifying glass and move the lens slightly away from the object (still inside f), the image will:",
      "opt": ["Get smaller", "Get bigger", "Stay the same size"],
      "correct": 1,
      "praise": "Very sharp! Closer to focus means bigger virtual image.",
      "analysis":
          "For virtual images (u < f), as the object moves toward the focal point, the image distance and image size both increase.",
    },
    {
      "q": "The objective lens of a microscope works the same way as a:",
      "opt": ["Camera lens", "Projector lens", "Reading magnifier"],
      "correct": 1,
      "praise":
          "Right! It makes a bigger real image for the eyepiece to look at.",
      "analysis":
          "The objective lens takes the tiny specimen and forms a magnified real image (f < u < 2f). Then the eyepiece acts as a magnifying glass to look at that image.",
    },
    {
      "q":
          "Parallel sunlight passes through a convex lens and forms a sharp tiny spot 10 cm away. If we put an object 25 cm away, the image will be:",
      "opt": [
        "Inverted, bigger, real",
        "Inverted, smaller, real",
        "Upright, bigger, virtual",
      ],
      "correct": 1,
      "praise":
          "Perfect reasoning! 25 cm is beyond 2f, so camera mode applies.",
      "analysis":
          "Parallel rays focus at f, so f = 10 cm and 2f = 20 cm. u = 25 cm is beyond 2f, so the image is real, inverted and smaller.",
    },
    {
      "q":
          "When you cannot see nearby objects clearly (long-sightedness), doctors prescribe convex glasses. They help by:",
      "opt": [
        "Bending light inward before it enters the eye",
        "Spreading light outward before it enters the eye",
        "Making the eye itself bigger",
      ],
      "correct": 0,
      "praise": "Great answer! Convex lenses add extra focusing power.",
      "analysis":
          "In long-sightedness, the eye does not bend light enough. The convex lens pre-converges the light, so the image forms right on the retina.",
    },
    {
      "q":
          "As an object moves slowly from far away toward the 2F point of a convex lens, the image:",
      "opt": [
        "Moves closer and gets smaller",
        "Moves away and gets bigger",
        "Stays in the same place",
      ],
      "correct": 1,
      "praise": "Excellent! Object approaches → image recedes and grows.",
      "analysis":
          "For real images, as the object moves closer to the lens, the image moves farther away on the other side and becomes larger in size.",
    },
  ];

  Map<String, dynamic> _currentQuestion = {};

  @override
  void initState() {
    super.initState();
    // 动画初始化
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _streakScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 2.2), weight: 40.0),
      TweenSequenceItem(tween: Tween(begin: 2.2, end: 1.0), weight: 60.0),
    ]).animate(
      CurvedAnimation(
        parent: _streakController,
        curve: Curves.easeInOutBack,
      ),
    );
    _loadQuestion();
  }

  @override
  void dispose() {
    _streakController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _loadQuestion() {
    if (_idx < _staticQuestions.length) {
      _currentQuestion = _staticQuestions[_idx];
    } else {
      _currentQuestion = _generateRandomQuestion();
    }
  }

  Map<String, dynamic> _generateRandomQuestion() {
    final rand = math.Random();
    int f = 10 + rand.nextInt(6);
    int type = rand.nextInt(3);
    int u;
    String device = "";
    String qText = "";
    List<String> options = [];
    int correctIdx = 0;
    String praiseStr = "";
    String analysisStr = "";

    List<String> devices0 = [
      "Digital camera",
      "Phone camera",
      "Security camera",
    ];
    List<String> devices1 = [
      "Classroom projector",
      "Movie projector",
      "Microscope objective",
    ];
    List<String> devices2 = [
      "Magnifying glass",
      "Reading glasses",
      "Jewelers loupe",
    ];

    if (type == 0) {
      u = 2 * f + 5 + rand.nextInt(20);
      device = devices0[rand.nextInt(devices0.length)];
      qText =
          "A $device uses a convex lens with focal length f = ${f}cm. If the object is u = ${u}cm away, the image on the sensor is:";
      options = [
        "Inverted, smaller, real image",
        "Inverted, bigger, real image",
        "Upright, magnified, virtual image",
      ];
      correctIdx = 0;
      praiseStr = "Correct! This is the camera case: u > 2f.";
      analysisStr =
          "f = ${f}cm so 2f = ${2 * f}cm. u = ${u}cm is greater than 2f, so the image is real, inverted and smaller.";
    } else if (type == 1) {
      u = f + 2 + rand.nextInt(f - 3);
      device = devices1[rand.nextInt(devices1.length)];
      qText =
          "A $device uses a lens with f = ${f}cm. If the slide is placed u = ${u}cm from the lens, the image on the screen is:";
      options = [
        "Upright virtual image",
        "Inverted, magnified real image",
        "Inverted, smaller real image",
      ];
      correctIdx = 1;
      praiseStr = "Right! Projectors use the f < u < 2f case.";
      analysisStr =
          "f = ${f}cm so 2f = ${2 * f}cm. u = ${u}cm is between f and 2f, so the image is real, inverted and magnified.";
    } else {
      u = 3 + rand.nextInt(f - 4);
      device = devices2[rand.nextInt(devices2.length)];
      qText =
          "A $device has focal length f = ${f}cm. If you hold it u = ${u}cm from a small object, you see:";
      options = [
        "Inverted, magnified real image",
        "Upright, smaller virtual image",
        "Upright, magnified virtual image",
      ];
      correctIdx = 2;
      praiseStr = "Perfect! Inside the focus gives a magnified virtual image.";
      analysisStr =
          "f = ${f}cm. u = ${u}cm is less than f (inside the focus). The image is virtual, upright and bigger than the object.";
    }

    return {
      "q": qText,
      "opt": options,
      "correct": correctIdx,
      "praise": praiseStr,
      "analysis": analysisStr,
    };
  }

  void _submitAnswer(int choice) async {
    if (_isSettled) return;
    Feedback.forTap(context);
    await AudioUtil.playClick();
    setState(() {
      _selectedIdx = choice;
      _isSettled = true;
      if (choice == _currentQuestion["correct"]) {
        _streak++;
        _streakController.forward(from: 0.0);
        AudioUtil.playCorrect();
      } else {
        _streak = 0;
        AudioUtil.playIncorrect();
      }
    });
  }

  void _nextQuestion() async {
    await AudioUtil.playClick();
    setState(() {
      _idx++;
      _selectedIdx = null;
      _isSettled = false;
      _loadQuestion();
    });
  }

  Future<void> _sendToGemini(String userText) async {
    if (userText.trim().isEmpty) return;
    if (!ApiKeyGuard.hasValidKey) {
      setState(() {
        _chatMessages.add({"role": "user", "text": userText.trim()});
        _chatMessages.add({
          "role": "gemini",
          "text":
              "API Key is not configured. Please build with --dart-define=GEMINI_API_KEY=your_key.",
        });
      });
      return;
    }
    setState(() {
      _chatMessages.add({"role": "user", "text": userText.trim()});
      _isAiThinking = true;
    });

    try {
      final requestBody = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": userText.trim()},
            ],
          },
        ],
        "systemInstruction": {
          "parts": [
            {
              "text":
                  "You are a professional middle school physics optics tutor. Answer questions about light refraction, lenses, ray diagrams or prisms in simple, easy English. Keep answers clear and under 200 words. For questions unrelated to optics, reply very briefly.",
            },
          ],
        },
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 800},
      };

      final response = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/${ApiKeyGuard.geminiModel}:generateContent?key=${ApiKeyGuard.geminiKey}",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data["candidates"][0]["content"]["parts"][0]["text"];
        if (mounted) {
          setState(() {
            _chatMessages.add({"role": "gemini", "text": reply});
            _isAiThinking = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _chatMessages.add({
              "role": "gemini",
              "text":
                  "Sorry, API request failed. Please check your network or API key.",
            });
            _isAiThinking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            "role": "gemini",
            "text": "Network error. Please check your internet connection.",
          });
          _isAiThinking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    final bool isWide = screenW > 950;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // ========== 修改：让body延伸到AppBar下方，消除顶部黑边 ==========
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, width: 1.2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF111111),
              size: 18,
            ),
            onPressed: () async {
              await AudioUtil.playClick();
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
      body: AutoVideoBackground(
        overlayOpacity: 0.88,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 11, child: _buildQuizPanel()),
        const SizedBox(width: 24),
        Expanded(flex: 9, child: _buildGeminiChatPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(flex: 6, child: _buildQuizPanel()),
        const SizedBox(height: 16),
        Expanded(flex: 4, child: _buildGeminiChatPanel()),
      ],
    );
  }

  Widget _buildQuizPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _idx < _staticQuestions.length
                      ? "CORE QUIZ 0${_idx + 1} / 10"
                      : "INFINITE MODE (LEVEL ${_idx + 1})",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  children: [
                    if (_streak > 0)
                      const Icon(
                        Icons.local_fire_department,
                        size: 18,
                        color: Color(0xFFFF2D55),
                      ),
                    const SizedBox(width: 4),
                    const Text(
                      "STREAK: ",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black38,
                      ),
                    ),
                    ScaleTransition(
                      scale: _streakScale,
                      child: Text(
                        "$_streak",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _streak > 0
                              ? const Color(0xFFFF2D55)
                              : Colors.black26,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _currentQuestion["q"] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...(_currentQuestion["opt"] as List<String>)
                      .asMap()
                      .entries
                      .map((e) {
                    final int optionIdx = e.key;
                    Color borderClr = Colors.black.withValues(alpha: 0.08);
                    Color bgClr = Colors.white;
                    IconData? suffixIcon;

                    if (_isSettled) {
                      if (optionIdx == _currentQuestion["correct"]) {
                        bgClr = const Color(0xFFE8F5E9);
                        borderClr = const Color(0xFFA5D6A7);
                        suffixIcon = Icons.check_circle_outline;
                      } else if (_selectedIdx == optionIdx) {
                        bgClr = const Color(0xFFFFEBEE);
                        borderClr = const Color(
                          0xFFEF5350,
                        ).withValues(alpha: 0.4);
                        suffixIcon = Icons.highlight_off;
                      }
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                          side: BorderSide(
                            color: borderClr,
                            width: _isSettled ? 1.8 : 1.0,
                          ),
                          backgroundColor: bgClr,
                        ),
                        onPressed: () => _submitAnswer(optionIdx),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  color: Color(0xFF212121),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (suffixIcon != null)
                              Icon(
                                suffixIcon,
                                size: 18,
                                color: optionIdx == _currentQuestion["correct"]
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFEF5350),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_isSettled) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedIdx == _currentQuestion["correct"]
                                ? "CORRECT!"
                                : "EXPLANATION",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: _selectedIdx == _currentQuestion["correct"]
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFFE53935),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedIdx == _currentQuestion["correct"]
                                ? _currentQuestion["praise"]
                                : _currentQuestion["analysis"],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF222222),
                        padding: const EdgeInsets.all(18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _nextQuestion,
                      child: const Text(
                        "NEXT QUESTION",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.2,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isAiThinking
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF616161),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isAiThinking ? "AI IS TYPING..." : "OPTICS AI TUTOR",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length + (_isAiThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isAiThinking && index == _chatMessages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Thinking...",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                final msg = _chatMessages[index];
                final bool isAi = msg["role"] == "gemini";
                return Align(
                  alignment:
                      isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isAi
                          ? const Color(0xFFF5F5F5)
                          : const Color(0xFFEAEAEA),
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.2,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: _chatController,
                      enabled: !_isAiThinking,
                      decoration: const InputDecoration(
                        hintText: "Ask about optics...",
                        hintStyle: TextStyle(
                          color: Colors.black26,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (val) async {
                        if (_isAiThinking || val.trim().isEmpty) return;
                        await AudioUtil.playMessage();
                        _sendToGemini(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.send_outlined,
                    color: Color(0xFF424242),
                  ),
                  onPressed: _isAiThinking
                      ? null
                      : () async {
                          final val = _chatController.text.trim();
                          if (val.isEmpty) return;
                          await AudioUtil.playMessage();
                          _sendToGemini(val);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
