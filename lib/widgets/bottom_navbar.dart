import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/provider/nav_provider.dart';


class BottomNavbar extends StatelessWidget {
  const BottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavProvider>(
      builder: (BuildContext context, provider, Widget? child) {
        return NavigationBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          selectedIndex: provider.index,
          indicatorColor: Theme.of(context).colorScheme.primary,
          onDestinationSelected: provider.setIndex,
          destinations: <Widget>[
            NavigationDestination(
              // icon: Badge(child: Icon(Icons.hourglass_bottom_outlined)),
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              // icon: Badge(child: Icon(Icons.timer_outlined)),
              icon: Icon(Icons.mic_outlined),
              label: 'Record',
            ),
            NavigationDestination(
              // icon: Badge(child: Icon(Icons.timer_outlined)),
              icon: Icon(Icons.person_outline),
              label: 'About',
            ),
          ],
        );
      },
    );
  }
}
