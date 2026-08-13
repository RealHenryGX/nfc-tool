import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tools_panels.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final _txController = TextEditingController(text: '30 00');
  final _pwdController = TextEditingController(text: 'FF FF FF FF');
  final _packController = TextEditingController(text: '00 00');
  final _pwdPageController = TextEditingController(text: '229');
  final _packPageController = TextEditingController(text: '230');
  final _classicKeyController = TextEditingController(text: 'FF FF FF FF FF FF');
  final _classicSectorController = TextEditingController(text: '0');
  final _classicBlockController = TextEditingController(text: '0');
  final _classicDataController =
      TextEditingController(text: '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00');

  @override
  void dispose() {
    _txController.dispose();
    _pwdController.dispose();
    _packController.dispose();
    _pwdPageController.dispose();
    _packPageController.dispose();
    _classicKeyController.dispose();
    _classicSectorController.dispose();
    _classicBlockController.dispose();
    _classicDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const CloneCard(),
          const UltralightMemoryPanel(),
          TransceivePanel(controller: _txController),
          ClassicPanel(
            keyController: _classicKeyController,
            sectorController: _classicSectorController,
            blockController: _classicBlockController,
            dataController: _classicDataController,
          ),
          PasswordPanel(
            pwdController: _pwdController,
            packController: _packController,
            pwdPageController: _pwdPageController,
            packPageController: _packPageController,
          ),
        ],
      ),
    );
  }
}
