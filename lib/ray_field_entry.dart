// 互動光場實驗室 - 模塊選擇入口頁
// 三個子模塊：凸透鏡模擬器 / 凹透鏡模擬器 / 自由創意工坊
import 'package:flutter/material.dart';
import 'utils/audio_util.dart';
import 'convex_lens_simulator.dart';
import 'concave_lens_simulator.dart';
import 'free_workshop_page.dart';

class RayFieldEntryPage extends StatelessWidget {
  const RayFieldEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double currentWidth = MediaQuery.of(context).size.width;
    final double currentHeight = MediaQuery.of(context).size.height;
    final double horizontalPadding = currentWidth > 600 ? 60.0 : 24.0;
    final double titleSize = currentWidth > 600 ? 32 : 24;
    final double subtitleSize = currentWidth > 600 ? 13 : 11;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
              Icons.arrow_back_ios_new_rounded,
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
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          SizedBox(height: isLandscape ? 16 : 32),
                          Text(
                            "INTERACTIVE RAY FIELD",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: const Color(0xFF111111),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Three dynamic workbenches for geometric optics",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                              color: const Color(0xFF4A4A4A),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 40,
                            height: 3,
                            color: const Color(0xFF4A4A4A),
                          ),
                          SizedBox(height: isLandscape ? 20 : 32),
                        ],
                      ),
                      // ===== 三個模塊卡片 =====
                      if (isLandscape)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _buildModuleCard(
                              context: context,
                              icon: Icons.add_circle_outline,
                              id: "01",
                              title: "CONVEX LENS LAB",
                              subtitle:
                                  "Arrow / point / parallel sources · free 2D move · focal plane rules",
                              accentColor: const Color(0xFF2E7D32),
                              onTap: () async {
                                await AudioUtil.playClick();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, a, b) =>
                                        const ConvexLensSimulatorPage(),
                                    transitionsBuilder: (_, a, b, c) =>
                                        FadeTransition(
                                      opacity: a,
                                      child: c,
                                    ),
                                  ),
                                );
                              },
                            )),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildModuleCard(
                              context: context,
                              icon: Icons.remove_circle_outline,
                              id: "02",
                              title: "CONCAVE LENS LAB",
                              subtitle:
                                  "Diverging lens physics · virtual images · always diminished",
                              accentColor: const Color(0xFF1565C0),
                              onTap: () async {
                                await AudioUtil.playClick();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, a, b) =>
                                        const ConcaveLensSimulatorPage(),
                                    transitionsBuilder: (_, a, b, c) =>
                                        FadeTransition(
                                      opacity: a,
                                      child: c,
                                    ),
                                  ),
                                );
                              },
                            )),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildModuleCard(
                              context: context,
                              icon: Icons.auto_awesome,
                              id: "03",
                              title: "FREE WORKSHOP",
                              subtitle:
                                  "Lenses · mirrors · walls · glass blocks · blank or grid canvas",
                              accentColor: const Color(0xFF6A1B9A),
                              onTap: () async {
                                await AudioUtil.playClick();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, a, b) =>
                                        const FreeWorkshopPage(),
                                    transitionsBuilder: (_, a, b, c) =>
                                        FadeTransition(
                                      opacity: a,
                                      child: c,
                                    ),
                                  ),
                                );
                              },
                            )),
                          ],
                        )
                      else ...[
                        _buildModuleCard(
                          context: context,
                          icon: Icons.add_circle_outline,
                          id: "01",
                          title: "CONVEX LENS LAB",
                          subtitle:
                              "Arrow / point / parallel sources · free 2D move · focal plane rules",
                          accentColor: const Color(0xFF2E7D32),
                          onTap: () async {
                            await AudioUtil.playClick();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, a, b) =>
                                    const ConvexLensSimulatorPage(),
                                transitionsBuilder: (_, a, b, c) =>
                                    FadeTransition(opacity: a, child: c),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildModuleCard(
                          context: context,
                          icon: Icons.remove_circle_outline,
                          id: "02",
                          title: "CONCAVE LENS LAB",
                          subtitle:
                              "Diverging lens physics · virtual images · always diminished",
                          accentColor: const Color(0xFF1565C0),
                          onTap: () async {
                            await AudioUtil.playClick();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, a, b) =>
                                    const ConcaveLensSimulatorPage(),
                                transitionsBuilder: (_, a, b, c) =>
                                    FadeTransition(opacity: a, child: c),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildModuleCard(
                          context: context,
                          icon: Icons.auto_awesome,
                          id: "03",
                          title: "FREE WORKSHOP",
                          subtitle:
                              "Lenses · mirrors · walls · glass blocks · blank or grid canvas",
                          accentColor: const Color(0xFF6A1B9A),
                          onTap: () async {
                            await AudioUtil.playClick();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, a, b) =>
                                    const FreeWorkshopPage(),
                                transitionsBuilder: (_, a, b, c) =>
                                    FadeTransition(opacity: a, child: c),
                              ),
                            );
                          },
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'SELECT A WORKBENCH TO BEGIN',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required IconData icon,
    required String id,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return _ModuleCard(
      icon: icon,
      id: id,
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final IconData icon;
  final String id;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapUp: (_) => setState(() => _hover = false),
        onTapCancel: () => setState(() => _hover = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color:
                  _hover ? Colors.white : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hover
                    ? widget.accentColor.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.02),
                  blurRadius: _hover ? 16 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.id,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: widget.accentColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color:
                                  _hover ? widget.accentColor : Colors.black38,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
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
