import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import '../../l10n.dart';
import 'connect_model.dart';
import 'ethernet_model.dart';
import 'wifi_model.dart';

class NoConnectView extends StatelessWidget {
  const NoConnectView({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ConnectMode? value;
  final ValueChanged<ConnectMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    final ethernet = context
        .select((EthernetModel m) => m.isEnabled && m.devices.isNotEmpty);
    final wifi =
        context.select((WifiModel m) => m.isEnabled && m.devices.isNotEmpty);

    return YaruRadioButton<ConnectMode>(
      title: Text(lang.noInternet),
      value: ConnectMode.none,
      contentPadding: const EdgeInsets.only(top: 8),
      groupValue: value,
      onChanged: ethernet || wifi ? onChanged : null,
    );
  }
}
