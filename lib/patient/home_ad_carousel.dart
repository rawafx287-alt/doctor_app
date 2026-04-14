import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Default slide when Firestore [ads] has no usable images (medical stock).
const String kDefaultHomeAdImageUrl =
    'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1400&q=85';

/// Vertical gap between the ad strip and the specialties block.
const double kHomeAdBannerGap = 12;

/// Height reserved for specialty title + chip row (includes small safety margin).
const double kHomeSpecialtiesBlockExtent = 140;

const Color _kAdGold = Color(0xFFD4AF37);
const Color _kAdGoldBorderSoft = Color(0x4DD4AF37);

/// Width ÷ height for the ad strip (16:9 standard for all promo images).
const double kHomeAdCarouselAspectRatio = 16 / 9;

/// Firestore-backed promo carousel for patient home (collection: `ads`).
class HomeAdCarousel extends StatelessWidget {
  const HomeAdCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (context, snapshot) {
        final urls = <String>[];
        if (snapshot.hasData) {
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data!.docs,
          );
          docs.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) {
              return ta.compareTo(tb);
            }
            return a.id.compareTo(b.id);
          });
          for (final d in docs) {
            final u = (d.data()['imageUrl'] ?? '').toString().trim();
            if (u.isNotEmpty) {
              urls.add(u);
            }
          }
        }
        final slides = urls.isEmpty ? <String>[kDefaultHomeAdImageUrl] : urls;

        return _HomeAdCarouselBody(slides: slides);
      },
    );
  }
}

class _HomeAdCarouselBody extends StatefulWidget {
  const _HomeAdCarouselBody({required this.slides});

  final List<String> slides;

  @override
  State<_HomeAdCarouselBody> createState() => _HomeAdCarouselBodyState();
}

class _HomeAdCarouselBodyState extends State<_HomeAdCarouselBody> {
  int _currentPage = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void didUpdateWidget(covariant _HomeAdCarouselBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slides.length != oldWidget.slides.length && mounted) {
      final maxIdx = (widget.slides.length - 1).clamp(0, 999);
      if (_currentPage > maxIdx) {
        setState(() => _currentPage = maxIdx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final n = slides.length;
    final multi = n > 1;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    const radius = 20.0;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackW = constraints.maxWidth;
          final bannerH = trackW / kHomeAdCarouselAspectRatio;
          final memW = (trackW * dpr).round().clamp(480, 1600);

          Widget slideImage(String url) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: double.infinity,
                height: bannerH,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: bannerH,
                  memCacheWidth: memW,
                  fadeInDuration: const Duration(milliseconds: 380),
                  placeholder: (c, _) => ColoredBox(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (c, _, _) => ColoredBox(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                    child: Icon(
                      Icons.medical_services_rounded,
                      color: Colors.blueGrey.withValues(alpha: 0.75),
                      size: 36,
                    ),
                  ),
                ),
              ),
            );
          }

          return AspectRatio(
            aspectRatio: kHomeAdCarouselAspectRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: _kAdGoldBorderSoft, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: _kAdGold.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      CarouselSlider(
                        carouselController: _carouselController,
                        items: slides.map(slideImage).toList(),
                        options: CarouselOptions(
                          height: bannerH,
                          viewportFraction: 1.0,
                          enlargeCenterPage: false,
                          autoPlay: multi,
                          autoPlayInterval: const Duration(seconds: 4),
                          autoPlayAnimationDuration:
                              const Duration(milliseconds: 850),
                          autoPlayCurve: Curves.easeInOut,
                          enableInfiniteScroll: multi,
                          pauseAutoPlayOnTouch: true,
                          scrollPhysics: multi
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          onPageChanged: (index, reason) {
                            setState(() => _currentPage = index);
                          },
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(radius),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.12),
                                ],
                                stops: const [0.0, 0.2, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 22,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(
                            n,
                            (i) {
                              final active = i == _currentPage;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: multi
                                    ? () {
                                        _carouselController.animateToPage(i);
                                      }
                                    : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: active ? 22 : 7,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: active
                                        ? _kAdGold
                                        : const Color(0xFFB3E5FC)
                                            .withValues(alpha: 0.85),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: _kAdGold.withValues(
                                                alpha: 0.45,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
