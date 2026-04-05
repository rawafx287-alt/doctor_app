import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Default slide when Firestore [ads] has no usable images (medical stock).
const String kDefaultHomeAdImageUrl =
    'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=1400&q=85';

/// Vertical gap between the ad strip and the specialties block.
const double kHomeAdBannerGap = 8;

/// Height reserved for specialty title + chip row (includes small safety margin).
const double kHomeSpecialtiesBlockExtent = 140;

/// Hero ad height — targets ~200–220px for a professional banner.
double homeAdBannerHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  return (h * 0.265).clamp(200.0, 220.0);
}

/// Total pinned header: ad + gap + specialties (search bar is separate).
double pinnedHomeHeaderTotalHeight(BuildContext context) {
  return homeAdBannerHeight(context) +
      kHomeAdBannerGap +
      kHomeSpecialtiesBlockExtent;
}

/// Firestore-backed promo carousel for patient home (collection: `ads`).
class HomeAdCarousel extends StatelessWidget {
  const HomeAdCarousel({super.key, required this.height});

  final double height;

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

        return _HomeAdCarouselBody(
          height: height,
          slides: slides,
        );
      },
    );
  }
}

class _HomeAdCarouselBody extends StatefulWidget {
  const _HomeAdCarouselBody({
    required this.height,
    required this.slides,
  });

  final double height;
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
    final h = widget.height;
    final n = slides.length;
    final multi = n > 1;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 7),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: h,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                CarouselSlider(
                    carouselController: _carouselController,
                    items: slides
                        .map(
                          (url) => SizedBox(
                            width: double.infinity,
                            height: h,
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: h,
                              memCacheWidth: 1200,
                              fadeInDuration:
                                  const Duration(milliseconds: 380),
                              placeholder: (c, _) => Container(
                                color: Colors.white.withValues(alpha: 0.45),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                              errorWidget: (c, url, _) => ColoredBox(
                                color: const Color(0xFFE3F2FD),
                                child: Icon(
                                  Icons.medical_services_rounded,
                                  color: Colors.blueGrey.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    options: CarouselOptions(
                      height: h,
                      viewportFraction: 1,
                      autoPlay: multi,
                      autoPlayInterval: const Duration(seconds: 7),
                      autoPlayAnimationDuration:
                          const Duration(milliseconds: 1250),
                      autoPlayCurve: Curves.easeInOutCubic,
                      enlargeCenterPage: false,
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
                  // Inner vignette + premium edge treatment
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.52),
                            width: 1.1,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.14),
                            ],
                            stops: const [0.0, 0.22, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Subtle page indicators (bottom center)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        n,
                        (i) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: multi
                              ? () {
                                  _carouselController.animateToPage(i);
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentPage ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: i == _currentPage ? 0.35 : 0.2,
                                ),
                                width: 0.6,
                              ),
                              color: i == _currentPage
                                  ? Colors.white.withValues(alpha: 0.58)
                                  : Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
