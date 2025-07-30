import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/view_models/home.vm.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  HomeViewModel homeViewModel = HomeViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.reactive(
      viewModelBuilder: () => homeViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return const Scaffold(
          backgroundColor: Color(0xFF007BFF),
        );
      },
    );
  }
}
