import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:subiquity_client/subiquity_client.dart';
import 'package:timezone_map/timezone_map.dart';
import 'package:ubuntu_wizard/constants.dart';
import 'package:ubuntu_wizard/widgets.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import '../../l10n.dart';
import '../../services.dart';
import 'where_are_you_model.dart';

/// https://github.com/canonical/ubuntu-desktop-installer/issues/38
class WhereAreYouPage extends StatefulWidget {
  /// Use [WhereAreYouPage.create] instead.
  @visibleForTesting
  const WhereAreYouPage({super.key});

  /// Creates a [WhereAreYouPage] with [WhereAreYouModel].
  static Widget create(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WhereAreYouModel(getService<SubiquityClient>()),
        ),
        ChangeNotifierProvider(
          create: (_) => TimezoneController(service: getService<GeoService>()),
        ),
      ],
      child: const WhereAreYouPage(),
    );
  }

  @override
  WhereAreYouPageState createState() => WhereAreYouPageState();
}

@visibleForTesting
class WhereAreYouPageState extends State<WhereAreYouPage> {
  @override
  void initState() {
    super.initState();

    final model = Provider.of<WhereAreYouModel>(context, listen: false);
    final controller = Provider.of<TimezoneController>(context, listen: false);
    model.init().then((timezone) {
      controller.searchTimezone(timezone).then((timezones) {
        controller.selectTimezone(timezones.firstOrNull);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TimezoneMap.precacheAssets(context);
    });
  }

  String formatLocation(GeoLocation? location) {
    return location?.toDisplayString() ?? '';
  }

  String formatTimezone(GeoLocation? location) {
    return location?.toTimezoneString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<TimezoneController>(context);
    final lang = AppLocalizations.of(context);

    return WizardPage(
      title: YaruWindowTitleBar(
        title: Text(lang.whereAreYouPageTitle),
      ),
      contentPadding: EdgeInsets.zero,
      content: Column(
        children: <Widget>[
          Padding(
            padding: kContentPadding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Autocomplete<GeoLocation>(
                    initialValue: TextEditingValue(
                      text: formatLocation(controller.selectedLocation),
                    ),
                    fieldViewBuilder:
                        (context, editor, focusNode, onSubmitted) {
                      if (!focusNode.hasFocus) {
                        editor.text =
                            formatLocation(controller.selectedLocation);
                      }
                      return TextFormField(
                        focusNode: focusNode,
                        controller: editor,
                        decoration: InputDecoration(
                          labelText: lang.whereAreYouLocationLabel,
                        ),
                        onFieldSubmitted: (value) => onSubmitted(),
                      );
                    },
                    displayStringForOption: formatLocation,
                    optionsBuilder: (value) {
                      return controller.searchLocation(value.text);
                    },
                    onSelected: controller.selectLocation,
                  ),
                ),
                const SizedBox(width: kContentSpacing),
                Expanded(
                  child: Autocomplete<GeoLocation>(
                    initialValue: TextEditingValue(
                      text: formatTimezone(controller.selectedLocation),
                    ),
                    fieldViewBuilder:
                        (context, editor, focusNode, onFieldSubmitted) {
                      if (!focusNode.hasFocus) {
                        editor.text =
                            formatTimezone(controller.selectedLocation);
                      }
                      return TextFormField(
                        focusNode: focusNode,
                        controller: editor,
                        decoration: InputDecoration(
                          labelText: lang.whereAreYouTimezoneLabel,
                        ),
                        onFieldSubmitted: (value) => onFieldSubmitted(),
                      );
                    },
                    displayStringForOption: formatTimezone,
                    optionsBuilder: (value) {
                      return controller.searchTimezone(value.text);
                    },
                    onSelected: controller.selectTimezone,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kContentSpacing),
          Expanded(
            child: TimezoneMap(
              offset: controller.selectedLocation?.offset,
              marker: controller.selectedLocation?.coordinates,
              onPressed: (coordinates) => controller
                  .searchMap(coordinates)
                  .then(controller.selectLocation),
            ),
          ),
        ],
      ),
      actions: <WizardAction>[
        WizardAction.back(
          context,
          enabled: false,
        ),
        WizardAction.next(
          context,
          onNext: () {
            final model = Provider.of<WhereAreYouModel>(context, listen: false);
            return model.save(controller.selectedLocation?.timezone);
          },
        ),
      ],
    );
  }
}

extension on TimezoneController {
  // Searches for the nearest location on the map but returns a simplified
  // location entry with the administration area and country details removed,
  // and the location name set to the name of the largest city in the timezone
  // to match the behavior of Ubiquity.
  //
  // This ensures that clicking around the timezone map keeps the pin as close
  // as possible to the clicked location (the timezone's largest city could be
  // far away), yet the presented textual result is not too granular i.e. not
  // some small unknown village but the timezone's largest city.
  Future<GeoLocation?> searchMap(LatLng coordinates) async {
    final location = await searchCoordinates(coordinates)
        .then((values) => values.firstOrNull);
    final timezone = await searchTimezone(location?.timezone ?? '')
        .then((values) => values.firstOrNull);
    return location?.copyWith(
      name: timezone?.name ?? location.name,
      admin: '',
      country: '',
    );
  }
}
