import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

/// Campo de texto com sugestoes enquanto digita (auto complete).
///
/// O texto continua livre: as sugestoes so ajudam. [suggestions] recebe o
/// texto digitado e devolve as opcoes (filtradas pelo chamador); escolher uma
/// chama [onSelected] (o chamador decide o que preencher, inclusive o texto
/// do proprio campo pelo [controller]).
///
/// ```dart
/// AppAutocompleteField<Item>(
///   label: 'Procedimento',
///   controller: _name,
///   suggestions: (text) => items.where((i) => i.name.contains(text)),
///   optionTitle: (i) => i.name,
///   onSelected: (i) => _fill(i),
/// )
/// ```
class AppAutocompleteField<T extends Object> extends StatefulWidget {
  const AppAutocompleteField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    required this.optionTitle,
    required this.onSelected,
    this.optionSubtitle,
    this.optionIcon,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.validator,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.maxOptionsHeight = 320,
  });

  final String label;
  final TextEditingController controller;
  final Iterable<T> Function(String text) suggestions;
  final String Function(T option) optionTitle;
  final String? Function(T option)? optionSubtitle;
  final IconData Function(T option)? optionIcon;
  final ValueChanged<T> onSelected;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final double maxOptionsHeight;

  @override
  State<AppAutocompleteField<T>> createState() =>
      _AppAutocompleteFieldState<T>();
}

class _AppAutocompleteFieldState<T extends Object>
    extends State<AppAutocompleteField<T>> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<T>(
        textEditingController: widget.controller,
        focusNode: _focus,
        displayStringForOption: widget.optionTitle,
        optionsBuilder: (value) =>
            widget.enabled ? widget.suggestions(value.text) : const [],
        onSelected: widget.onSelected,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
            AppTextField(
              label: widget.label,
              controller: controller,
              focusNode: focusNode,
              hint: widget.hint,
              helperText: widget.helperText,
              prefixIcon: widget.prefixIcon,
              validator: widget.validator,
              maxLength: widget.maxLength,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              textCapitalization: widget.textCapitalization,
              onFieldSubmitted: (_) => onSubmitted(),
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.maxOptionsHeight,
                maxWidth: constraints.maxWidth,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  final subtitle = widget.optionSubtitle?.call(option);
                  final highlighted =
                      AutocompleteHighlightedOption.of(context) == i;
                  return ListTile(
                    dense: true,
                    tileColor: highlighted ? AppColors.mint : null,
                    leading: widget.optionIcon == null
                        ? null
                        : Icon(
                            widget.optionIcon!(option),
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                    title: Text(
                      widget.optionTitle(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: subtitle == null
                        ? null
                        : Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
