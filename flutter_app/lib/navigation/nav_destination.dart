import 'package:flutter/material.dart';

enum NavDestination { home, events, profile }

extension NavDestinationX on NavDestination {
  String get label {
    switch (this) {
      case NavDestination.home:
        return 'Home';
      case NavDestination.events:
        return 'Events';
      case NavDestination.profile:
        return 'Profile';
    }
  }

  IconData get icon {
    switch (this) {
      case NavDestination.home:
        return Icons.home_outlined;
      case NavDestination.events:
        return Icons.event_outlined;
      case NavDestination.profile:
        return Icons.person_outline;
    }
  }

  String get path {
    switch (this) {
      case NavDestination.home:
        return '/home';
      case NavDestination.events:
        return '/events';
      case NavDestination.profile:
        return '/settings/profile/edit';
    }
  }
}
