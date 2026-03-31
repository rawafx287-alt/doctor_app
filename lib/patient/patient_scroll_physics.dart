import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iOS-style bounce vs Android clamp — use on primary lists for natural feel.
ScrollPhysics get patientPlatformScrollPhysics {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => const BouncingScrollPhysics(),
    _ => const ClampingScrollPhysics(),
  };
}

/// [CustomScrollView] home feed: pull-to-overscroll + platform parent physics.
ScrollPhysics get patientHomePrimaryScrollPhysics {
  return AlwaysScrollableScrollPhysics(parent: patientPlatformScrollPhysics);
}
