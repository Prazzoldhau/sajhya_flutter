// lib/screens/video_player_screen.dart
//
// Exercise video player backed by the YouTube IFrame Player API.
//
// YouTube's own chrome is fully disabled (no title, channel, YouTube logo,
// CC/settings icons, "More videos" overlay) and replaced with our own branded
// control layer:
//   * showControls / showFullscreenButton / showVideoAnnotations = false
//   * enableCaption = false               (no burned-in caption toggle UI)
//   * strictRelatedVideos = true          (related videos limited to channel)
//   * pointerEvents = none                (iframe ignores taps; our overlay
//                                          handles all interaction)
// YouTube still re-shows its chrome in every NON-playing state (cued, paused,
// buffering, ended), so we cover the frame with our own opaque mask whenever
// the video isn't actively playing.
//
// Play/pause is driven by our OWN intent, not the package's playerState stream:
// that stream is unreliable here because metaData updates reset playerState
// back to its default (observed as a permanent `unknown`). Position and
// duration ARE reliable, so we use them to detect playback start and the
// natural end (the latter also feeds milestone 4's auto-advance).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../theme/app_theme.dart';

/// A single playable exercise: its display name and the resolved YouTube id.
/// [videoId] is null when the source URL could not be parsed into an id, in
/// which case the item is shown but not playable.
class ExerciseVideo {
  final String title;
  final String? videoId;

  /// The original stored `exercise_url`. It may be a YouTube link OR — as in
  /// production today — a direct illustration image (e.g. a .png).
  final String? rawUrl;

  const ExerciseVideo({required this.title, required this.videoId, this.rawUrl});

  /// Builds an item from an exercise name and a stored URL (YouTube watch URL,
  /// youtu.be link, bare id, or a direct image URL).
  factory ExerciseVideo.fromUrl(String title, String? url) {
    return ExerciseVideo(title: title, videoId: videoIdFromUrl(url), rawUrl: url);
  }

  /// Extracts the id from a full YouTube watch URL or youtu.be short link,
  /// falling back to the raw input if it already looks like a bare 11-char id.
  /// Returns null if nothing usable is found.
  static String? videoIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final parsed = YoutubePlayerController.convertUrlToId(url);
    if (parsed != null && parsed.isNotEmpty) return parsed;
    final bare = RegExp(r'^[A-Za-z0-9_-]{11}$');
    return bare.hasMatch(url) ? url : null;
  }

  static final _imageExt =
      RegExp(r'\.(png|jpe?g|gif|webp|bmp)(\?|#|$)', caseSensitive: false);

  /// True when this exercise has a playable YouTube video.
  bool get hasVideo => videoId != null;

  /// The stored URL when it points directly at an illustration image (i.e.
  /// it's not a video). Shown as a fallback when there's no video.
  String? get imageUrl => (videoId == null &&
          rawUrl != null &&
          _imageExt.hasMatch(rawUrl!))
      ? rawUrl
      : null;

  /// Card thumbnail: the YouTube poster for videos, otherwise the exercise
  /// illustration image. Null only when neither is available.
  String? get thumbnailUrl => videoId != null
      ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
      : imageUrl;
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
  });

  /// The prescribed exercises, in feed order.
  final List<ExerciseVideo> playlist;

  /// Index within [playlist] to start playing.
  final int initialIndex;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final YoutubePlayerController _controller;
  late int _index;

  ExerciseVideo get _current => widget.playlist[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.playlist.length - 1);
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        // Strip every piece of YouTube's own UI; we render our own controls.
        showControls: false,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        enableCaption: false,
        strictRelatedVideos: true,
        playsInline: true,
        // The iframe ignores pointer events, so clicking the video never
        // triggers YouTube's title bar / pause suggestions / "More videos".
        pointerEvents: PointerEvents.none,
      ),
    );
    final id = _current.videoId;
    if (id != null) {
      _controller.cueVideoById(videoId: id);
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _current.videoId;

    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_current.title),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: id != null
                    ? AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            player,
                            _ExerciseVideoControls(
                              controller: _controller,
                              poster: _current.thumbnailUrl,
                            ),
                          ],
                        ),
                      )
                    : _buildFallback(),
              ),
              const SizedBox(height: 16),
              Text(
                _current.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exercise ${_index + 1} of ${widget.playlist.length}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shown when the current exercise has no playable video. Instead of a lone
  /// still image, we fall back to a slideshow of every image-based exercise in
  /// the prescription, starting on the current one when it is itself an image.
  Widget _buildFallback() {
    final slides = widget.playlist.where((e) => e.imageUrl != null).toList();
    if (slides.isEmpty) return _unavailable();
    var start = slides.indexOf(_current);
    if (start < 0) start = 0;
    return _ExerciseSlideshow(slides: slides, initialIndex: start);
  }

  Widget _unavailable() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFFEDF3FA),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This exercise has no video attached yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Branded control layer drawn on top of the (pointer-inert) YouTube iframe.
/// Owns play/pause, ±10s, a scrubber with buffered indicator, time readout and
/// a fullscreen toggle. Auto-hides while playing; stays up otherwise.
class _ExerciseVideoControls extends StatefulWidget {
  const _ExerciseVideoControls({required this.controller, this.poster});

  final YoutubePlayerController controller;

  /// Thumbnail shown as our own poster (pre-play) and paused/ended mask, so
  /// YouTube's own title/channel/"More videos"/logo chrome is never visible.
  final String? poster;

  @override
  State<_ExerciseVideoControls> createState() => _ExerciseVideoControlsState();
}

class _ExerciseVideoControlsState extends State<_ExerciseVideoControls> {
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  Timer? _hideTimer;

  bool _everTapped = false; // user has tapped the poster at least once
  bool _playing = false; // our intent: should the video be playing?
  bool _started = false; // playback has actually advanced past zero
  bool _ended = false; // reached (near) the end
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _buffered = 0;
  bool _visible = true;
  double? _dragSeconds; // non-null while the user is scrubbing

  // Frames are actually on screen only when we intend to play, playback has
  // started, and we haven't hit the end. The mask lifts exactly then.
  bool get _showingVideo => _playing && _started && !_ended;

  @override
  void initState() {
    super.initState();
    // Duration is the only field we trust from the value stream.
    _valueSub = widget.controller.stream.listen((value) {
      if (!mounted) return;
      final d = value.metaData.duration;
      if (d > Duration.zero && d != _duration) {
        setState(() => _duration = d);
      }
    });
    // Position/buffer are reliable and drive start/end detection.
    _stateSub = widget.controller.videoStateStream.listen((state) {
      if (!mounted) return;
      final pos = state.position;
      final justStarted = _playing && !_started && pos > Duration.zero;
      setState(() {
        if (_dragSeconds == null) _position = pos;
        _buffered = state.loadedFraction;
        if (_playing && pos > Duration.zero) _started = true;
        if (_duration > Duration.zero &&
            pos >= _duration - const Duration(milliseconds: 900)) {
          // Natural end (also the hook for milestone 4 auto-advance).
          _ended = true;
          _playing = false;
        } else if (_ended && pos < _duration - const Duration(seconds: 1)) {
          _ended = false; // user scrubbed back from the end
        }
      });
      if (justStarted) _showControls(); // hide a few seconds after playback
      if (!_showingVideo) _showControls(autoHide: false);
    });
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    _stateSub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showingVideo) setState(() => _visible = false);
    });
  }

  void _showControls({bool autoHide = true}) {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
    if (autoHide && _showingVideo) _scheduleHide();
  }

  void _togglePlay() {
    if (_ended) {
      _replay();
      return;
    }
    if (_playing) {
      widget.controller.pauseVideo();
      setState(() => _playing = false);
      _showControls(autoHide: false);
    } else {
      widget.controller.playVideo();
      setState(() => _playing = true);
      _showControls();
    }
  }

  void _replay() {
    widget.controller.seekTo(seconds: 0, allowSeekAhead: true);
    widget.controller.playVideo();
    setState(() {
      _ended = false;
      _started = false;
      _position = Duration.zero;
      _playing = true;
    });
    _showControls();
  }

  void _seekBy(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final maxMs =
        _duration.inMilliseconds == 0 ? target.inMilliseconds : _duration.inMilliseconds;
    final clamped = Duration(milliseconds: target.inMilliseconds.clamp(0, maxMs));
    widget.controller.seekTo(seconds: clamped.inMilliseconds / 1000, allowSeekAhead: true);
    setState(() => _position = clamped);
    _showControls();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    // Before the first tap, our poster masks YouTube's pre-play screen.
    if (!_everTapped) return _buildPoster();

    final totalSecs = _duration.inMilliseconds / 1000;
    final posSecs = _dragSeconds ?? _position.inMilliseconds / 1000;
    final maxSecs = totalSecs <= 0 ? 1.0 : totalSecs;
    final loading = _playing && !_started; // tapped play, frames not in yet

    return Stack(
      fit: StackFit.expand,
      children: [
        // Always-active surface beneath the controls. A tap here toggles
        // control visibility. It is a SIBLING of (not a parent of) the
        // transport buttons, so the gesture arena can never let it steal a
        // button tap — which previously made play/pause register as "hide".
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_visible) {
                if (_showingVideo) setState(() => _visible = false);
              } else {
                _showControls();
              }
            },
          ),
        ),
        // Non-playing mask: covers YouTube's chrome whenever not actively
        // playing (cued / paused / buffering / ended). Lifts on playback.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showingVideo ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: _maskCover(),
            ),
          ),
        ),
        // Controls layer: fades out and stops absorbing taps when hidden, so
        // the surface above can receive the tap that brings the controls back.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    // --- Center transport: -10s | play/pause | +10s ---
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _circleButton(
                            icon: Icons.replay_10_rounded,
                            size: 40,
                            onTap: () => _seekBy(-10),
                          ),
                          const SizedBox(width: 28),
                          _circleButton(
                            icon: loading
                                ? null
                                : _ended
                                    ? Icons.replay_rounded
                                    : _playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                            size: 56,
                            busy: loading,
                            onTap: _togglePlay,
                          ),
                          const SizedBox(width: 28),
                          _circleButton(
                            icon: Icons.forward_10_rounded,
                            size: 40,
                            onTap: () => _seekBy(10),
                          ),
                        ],
                      ),
                    ),
                    // --- Bottom bar: time, scrubber, fullscreen ---
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 6,
                      child: Row(
                        children: [
                          Text(
                            _fmt(Duration(milliseconds: (posSecs * 1000).round())),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.3),
                                secondaryActiveTrackColor:
                                    Colors.white.withValues(alpha: 0.5),
                                thumbColor: Colors.white,
                                overlayColor:
                                    AppColors.primary.withValues(alpha: 0.2),
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                              ),
                              child: Slider(
                                min: 0,
                                max: maxSecs,
                                value: posSecs.clamp(0, maxSecs),
                                secondaryTrackValue:
                                    (_buffered * maxSecs).clamp(0, maxSecs),
                                onChanged: totalSecs <= 0
                                    ? null
                                    : (v) {
                                        _hideTimer?.cancel();
                                        setState(() => _dragSeconds = v);
                                      },
                                onChangeEnd: totalSecs <= 0
                                    ? null
                                    : (v) {
                                        widget.controller.seekTo(
                                            seconds: v, allowSeekAhead: true);
                                        setState(() {
                                          _position = Duration(
                                              milliseconds: (v * 1000).round());
                                          _dragSeconds = null;
                                        });
                                        _showControls();
                                      },
                              ),
                            ),
                          ),
                          Text(
                            _fmt(_duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.fullscreen_rounded,
                                color: Colors.white),
                            onPressed: () {
                              widget.controller.toggleFullScreen();
                              _showControls();
                            },
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
      ],
    );
  }

  /// Opaque cover for the pre-play / paused / ended states, masking YouTube's
  /// overlay. Uses the exercise thumbnail under a heavy scrim, or solid dark.
  Widget _maskCover() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.poster != null)
          Image.network(
            widget.poster!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black),
        Container(color: Colors.black.withValues(alpha: 0.82)),
      ],
    );
  }

  Widget _buildPoster() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.controller.playVideo();
        setState(() {
          _everTapped = true;
          _playing = true;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _maskCover(),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.primary, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    IconData? icon,
    required double size,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

/// Fallback shown when an exercise has no video: an auto-advancing slideshow of
/// every image-based exercise in the prescription. Users can also swipe or tap
/// the dots to move manually; any manual move restarts the auto-advance timer.
class _ExerciseSlideshow extends StatefulWidget {
  const _ExerciseSlideshow({
    required this.slides,
    this.initialIndex = 0,
  });

  /// Image-only exercises to cycle through (each has a non-null [imageUrl]).
  final List<ExerciseVideo> slides;
  final int initialIndex;

  /// How long each slide stays up before auto-advancing.
  static const Duration interval = Duration(seconds: 4);

  @override
  State<_ExerciseSlideshow> createState() => _ExerciseSlideshowState();
}

class _ExerciseSlideshowState extends State<_ExerciseSlideshow> {
  late final PageController _pageController;
  late int _index;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.slides.length - 1);
    _pageController = PageController(initialPage: _index);
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// (Re)start the timer. A single slide has nothing to cycle, so we skip it.
  void _startAutoAdvance() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(_ExerciseSlideshow.interval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _goTo(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _startAutoAdvance(); // manual jump resets the timer
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.slides.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _startAutoAdvance(); // swipe resets the timer too
            },
            itemBuilder: (_, i) => _slideImage(widget.slides[i].imageUrl!),
          ),
          // Bottom scrim: current exercise name + page dots.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.slides[_index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.slides.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.slides.length, (i) {
                        final active = i == _index;
                        return GestureDetector(
                          onTap: () => _goTo(i),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
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

  Widget _slideImage(String url) {
    return Container(
      color: const Color(0xFFEDF3FA),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Image could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
