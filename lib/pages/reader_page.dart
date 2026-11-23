import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../sources/comic_source.dart';

enum ReadMode { horizontal, verticalPage, webtoon }

enum ReadDirection { ltr, rtl }

enum DualPageMode { single, tabletAuto, dual }

enum ImageFitMode { contain, fitWidth, fitHeight }

enum ReaderBgTheme { paper, beige, white, night, black }

class ReaderPage extends StatefulWidget {
  final ComicSource source;
  final List<ComicChapter> chapters;
  final int initialIndex;

  const ReaderPage({
    super.key,
    required this.source,
    required this.chapters,
    required this.initialIndex,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late int _currentIndex = widget.initialIndex;
  List<String> _images = [];
  bool _loading = true;
  bool _showOverlay = true;
  String? _error;

  int _currentPage = 0; // 永遠以「單頁索引 (0-based)」記錄，避免切換橫豎屏跑位
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  // 閱讀設定狀態
  ReadMode _readMode = ReadMode.horizontal;
  ReadDirection _readDirection = ReadDirection.rtl;
  DualPageMode _dualPageMode = DualPageMode.tabletAuto;
  ImageFitMode _fitMode = ImageFitMode.contain;
  ReaderBgTheme _bgTheme = ReaderBgTheme.paper;

  ComicChapter get _currentChapter => widget.chapters[_currentIndex];

  bool _useDualPage(BuildContext context) {
    if (_readMode == ReadMode.webtoon) return false;
    if (_dualPageMode == DualPageMode.dual) return true;
    if (_dualPageMode == DualPageMode.single) return false;
    return MediaQuery.of(context).size.width >= 600;
  }

  /// 改善後的頁數文字（平板雙頁顯示 1-2 / 13，單頁顯示 1 / 13）
  String _formatPageLabel(BuildContext context) {
    if (_images.isEmpty) return '載入中...';
    final total = _images.length;
    final isDual = _useDualPage(context);
    if (!isDual) {
      return '${(_currentPage + 1).clamp(1, total)} / $total';
    }
    final first = (_currentPage ~/ 2) * 2 + 1;
    final second = first + 1;
    if (second <= total) {
      return '$first-$second / $total';
    }
    return '$first / $total';
  }

  double get _readingProgress {
    if (_images.length <= 1) return 1.0;
    return (_currentPage / (_images.length - 1)).clamp(0.0, 1.0);
  }

  Color get _backgroundColor {
    switch (_bgTheme) {
      case ReaderBgTheme.paper:
        return const Color(0xFFF7F6F2);
      case ReaderBgTheme.beige:
        return const Color(0xFFF2EBD9);
      case ReaderBgTheme.white:
        return Colors.white;
      case ReaderBgTheme.night:
        return const Color(0xFF1C1C1E);
      case ReaderBgTheme.black:
        return Colors.black;
    }
  }

  bool get _isDarkBg =>
      _bgTheme == ReaderBgTheme.night || _bgTheme == ReaderBgTheme.black;

  BoxFit get _boxFit {
    switch (_fitMode) {
      case ImageFitMode.contain:
        return BoxFit.contain;
      case ImageFitMode.fitWidth:
        return BoxFit.fitWidth;
      case ImageFitMode.fitHeight:
        return BoxFit.fitHeight;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _error = null;
      _images = [];
      _currentPage = 0;
    });
    try {
      final urls = await widget.source.getChapterImages(_currentChapter.url);
      if (mounted) {
        setState(() {
          _images = urls;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '圖片載入失敗：$e';
          _loading = false;
        });
      }
    }
  }

  void _jumpToPage(int pageIndex, {bool animate = false}) {
    if (_images.isEmpty) return;
    final target = pageIndex.clamp(0, _images.length - 1);
    setState(() => _currentPage = target);

    if (_readMode == ReadMode.webtoon) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final ratio = _images.length > 1 ? target / (_images.length - 1) : 0.0;
        if (animate) {
          _scrollController.animateTo(
            maxScroll * ratio,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(maxScroll * ratio);
        }
      }
    } else {
      if (_pageController.hasClients) {
        final isDual = _useDualPage(context);
        final spreadIdx = isDual ? target ~/ 2 : target;
        if (animate) {
          _pageController.animateToPage(
            spreadIdx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.jumpToPage(spreadIdx);
        }
      }
    }
  }

  /// 點擊畫面左/中/右區域：左右平滑翻頁，中間開關工具列
  void _handleTap(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    if (_readMode == ReadMode.webtoon || (dx > width * 0.28 && dx < width * 0.72)) {
      setState(() => _showOverlay = !_showOverlay);
      return;
    }

    final isDual = _useDualPage(context);
    final step = isDual ? 2 : 1;
    final tappedRight = dx >= width * 0.72;
    final goNext = _readDirection == ReadDirection.rtl ? !tappedRight : tappedRight;

    if (goNext) {
      if (_currentPage + step < _images.length) {
        _jumpToPage(_currentPage + step, animate: true);
      }
    } else {
      if (_currentPage - step >= 0) {
        _jumpToPage(_currentPage - step, animate: true);
      } else if (_currentPage > 0) {
        _jumpToPage(0, animate: true);
      }
    }
  }

  void _openTocSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F6F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPages = _images.isEmpty ? 1 : _images.length;
            final displayPage = (_currentPage + 1).clamp(1, totalPages);

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            '目錄',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F1F1F),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} / ${widget.chapters.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black45,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _circleCloseButton(() => Navigator.pop(ctx)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '本話 ${_formatPageLabel(context)}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.black87,
                                inactiveTrackColor: Colors.black12,
                                thumbColor: Colors.white,
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: displayPage.toDouble(),
                                min: 1,
                                max: totalPages.toDouble(),
                                onChanged: _images.isEmpty
                                    ? null
                                    : (val) {
                                        final idx = val.round() - 1;
                                        setModalState(() => _currentPage = idx);
                                        _jumpToPage(idx);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.black12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: widget.chapters.length,
                        itemBuilder: (_, i) {
                          final ch = widget.chapters[i];
                          final isCurrent = i == _currentIndex;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            leading: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.black87 : Colors.black38,
                                fontFamily: 'monospace',
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            title: Text(
                              ch.title,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF1F1F1F),
                              ),
                            ),
                            subtitle: Text(
                              isCurrent ? '在讀 · 預設' : '預設',
                              style: const TextStyle(fontSize: 12, color: Colors.black45),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 20)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              if (i != _currentIndex) {
                                setState(() => _currentIndex = i);
                                _loadChapter();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F6F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void update(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _jumpToPage(_currentPage);
              });
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          '閱讀設定',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const Spacer(),
                        _circleCloseButton(() => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('閱讀方式'),
                    _segmentedControl<ReadMode>(
                      selected: _readMode,
                      options: const {
                        ReadMode.horizontal: '橫向翻頁',
                        ReadMode.verticalPage: '上下翻頁',
                        ReadMode.webtoon: '條漫',
                      },
                      onSelected: (v) => update(() => _readMode = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('閱讀方向'),
                    _segmentedControl<ReadDirection>(
                      selected: _readDirection,
                      options: const {
                        ReadDirection.ltr: '從左往右',
                        ReadDirection.rtl: '從右往左',
                      },
                      onSelected: (v) => update(() => _readDirection = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('雙頁顯示（平板書本效果）'),
                    _segmentedControl<DualPageMode>(
                      selected: _dualPageMode,
                      options: const {
                        DualPageMode.single: '單頁',
                        DualPageMode.tabletAuto: '平板自動',
                        DualPageMode.dual: '雙頁',
                      },
                      onSelected: (v) => update(() => _dualPageMode = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('畫面適配'),
                    _segmentedControl<ImageFitMode>(
                      selected: _fitMode,
                      options: const {
                        ImageFitMode.contain: '完整顯示',
                        ImageFitMode.fitWidth: '適應寬度',
                        ImageFitMode.fitHeight: '適應高度',
                      },
                      onSelected: (v) => update(() => _fitMode = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('閱讀底色'),
                    _segmentedControl<ReaderBgTheme>(
                      selected: _bgTheme,
                      options: const {
                        ReaderBgTheme.paper: '紙白',
                        ReaderBgTheme.beige: '米黃',
                        ReaderBgTheme.white: '純白',
                        ReaderBgTheme.night: '夜間',
                        ReaderBgTheme.black: '純黑',
                      },
                      onSelected: (v) => update(() => _bgTheme = v),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _circleCloseButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _segmentedControl<T>({
    required T selected,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEBE9E4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF1F1F1F) : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageItem(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: widget.source.getImageHeaders(_currentChapter.url),
      fit: _boxFit,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => SizedBox(
        height: 360,
        child: Center(
          child: CircularProgressIndicator(
            color: _isDarkBg ? Colors.white54 : Colors.black45,
          ),
        ),
      ),
      errorWidget: (_, url, error) => Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: _isDarkBg ? Colors.white54 : Colors.black38,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '錯誤：$error\n網址：$url',
              style: TextStyle(
                fontSize: 11,
                color: _isDarkBg ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 平板實體書中縫立體陰影
  Widget _buildBookCenterGutter() {
    final shadowBase = _isDarkBg ? Colors.black : Colors.black;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                shadowBase.withOpacity(_isDarkBg ? 0.35 : 0.08),
                shadowBase.withOpacity(_isDarkBg ? 0.55 : 0.14),
                shadowBase.withOpacity(_isDarkBg ? 0.35 : 0.08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// 極簡頂部指示線與 •••（對應截圖頂部視覺）
  Widget _buildMinimalTopIndicator() {
    final fg = _isDarkBg ? Colors.white38 : Colors.black38;
    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: _readingProgress,
                    minHeight: 1.5,
                    backgroundColor: fg.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(fg.withOpacity(0.55)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '•••',
                  style: TextStyle(fontSize: 10, letterSpacing: 2, color: fg),
                ),
              ),
              Text(
                _formatPageLabel(context),
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReaderContent() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: _isDarkBg ? Colors.white : Colors.black87,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: _isDarkBg ? Colors.white : Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_readMode == ReadMode.webtoon) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _images.length,
          itemBuilder: (_, i) => _buildImageItem(_images[i]),
        ),
      );
    }

    final isDual = _useDualPage(context);
    final pageCount = isDual ? (_images.length / 2).ceil() : _images.length;

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection:
              _readMode == ReadMode.horizontal ? Axis.horizontal : Axis.vertical,
          reverse: _readMode == ReadMode.horizontal &&
              _readDirection == ReadDirection.rtl,
          itemCount: pageCount,
          onPageChanged: (idx) =>
              setState(() => _currentPage = isDual ? idx * 2 : idx),
          itemBuilder: (_, i) {
            Widget pageChild;
            if (!isDual) {
              pageChild = InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5,
                child: Center(child: _buildImageItem(_images[i])),
              );
            } else {
              final firstIdx = i * 2;
              final secondIdx = firstIdx + 1;
              final hasSecond = secondIdx < _images.length;

              final firstImg = Expanded(
                child: Align(
                  alignment: _readDirection == ReadDirection.rtl
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: _buildImageItem(_images[firstIdx]),
                ),
              );
              final secondImg = hasSecond
                  ? Expanded(
                      child: Align(
                        alignment: _readDirection == ReadDirection.rtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _buildImageItem(_images[secondIdx]),
                      ),
                    )
                  : const Expanded(child: SizedBox.shrink());

              final pair = _readDirection == ReadDirection.rtl
                  ? [secondImg, firstImg]
                  : [firstImg, secondImg];

              pageChild = InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: pair,
                ),
              );
            }

            // 翻頁微縮放與淡入動畫
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double value = 1.0;
                if (_pageController.position.haveDimensions) {
                  final page = _pageController.page ?? i.toDouble();
                  value = (1 - ((page - i).abs() * 0.06)).clamp(0.92, 1.0);
                }
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value.clamp(0.75, 1.0),
                    child: child,
                  ),
                );
              },
              child: pageChild,
            );
          },
        ),
        if (isDual) _buildBookCenterGutter(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topBg = _isDarkBg
        ? const Color.fromRGBO(28, 28, 30, 0.92)
        : const Color.fromRGBO(247, 246, 242, 0.94);
    final topFg = _isDarkBg ? Colors.white : const Color(0xFF1F1F1F);

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTap,
            child: _buildReaderContent(),
          ),
          // 隱藏工具列時顯示極簡頂部進度線與 •••
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showOverlay ? 0.0 : 1.0,
            child: _buildMinimalTopIndicator(),
          ),
          // 頂部滑動動畫工具列
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              offset: _showOverlay ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showOverlay ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showOverlay,
                  child: Container(
                    color: topBg,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left, color: topFg, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentChapter.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: topFg,
                                    ),
                                  ),
                                  Text(
                                    '${widget.source.name} / COMIC',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: topFg.withOpacity(0.55),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '目錄',
                              icon: Icon(Icons.format_list_bulleted_rounded, color: topFg),
                              onPressed: _openTocSheet,
                            ),
                            IconButton(
                              tooltip: '閱讀設定',
                              icon: Icon(Icons.tune_rounded, color: topFg),
                              onPressed: _openSettingsSheet,
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
          // 底部滑動動畫工具列
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              offset: _showOverlay ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showOverlay ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showOverlay,
                  child: Container(
                    color: topBg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _currentIndex < widget.chapters.length - 1
                                ? () {
                                    _currentIndex++;
                                    _loadChapter();
                                  }
                                : null,
                            icon: Icon(Icons.chevron_left, color: topFg),
                            label: Text('上一話', style: TextStyle(color: topFg)),
                          ),
                          Text(
                            _formatPageLabel(context),
                            style: TextStyle(
                              color: topFg.withOpacity(0.75),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _currentIndex > 0
                                ? () {
                                    _currentIndex--;
                                    _loadChapter();
                                  }
                                : null,
                            icon: Icon(Icons.chevron_right, color: topFg),
                            label: Text('下一話', style: TextStyle(color: topFg)),
                          ),
                        ],
                      ),
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
