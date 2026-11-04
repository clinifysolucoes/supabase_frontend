import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/patient_models.dart';
import '../../profiles/application/profiles_controller.dart';

/// Busca de paciente para a consulta (ad.patient_list: nome, CPF, celular).
/// Devolve o paciente escolhido ou null.
class PatientPickerDialog extends ConsumerStatefulWidget {
  const PatientPickerDialog({super.key});

  static Future<Patient?> show(BuildContext context) => showDialog<Patient>(
    context: context,
    builder: (_) => const PatientPickerDialog(),
  );

  @override
  ConsumerState<PatientPickerDialog> createState() =>
      _PatientPickerDialogState();
}

class _PatientPickerDialogState extends ConsumerState<PatientPickerDialog> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Patient> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(text));
  }

  Future<void> _load(String text) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(patientRepositoryProvider)
          .list(
            nrCompany: nrCompany,
            nrBranch: nrBranch,
            filters: PatientFilters(search: text, pageSize: 30),
          );
      if (mounted) setState(() => _items = page.patients);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Strings.choosePatient,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.search,
                hint: Strings.searchPatientHint,
                controller: _search,
                autofocus: true,
                prefixIcon: Icons.search_rounded,
                onChanged: _onChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty && !_loading
                    ? const Center(
                        child: Text(
                          Strings.noPatientsFound,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _items[i];
                          final mobile = p.vcMobile;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.mint,
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            title: Text(
                              p.vcName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (p.age != null) '${p.age} anos',
                                if (mobile != null)
                                  Masks.format(MaskType.phone, mobile),
                              ].join(' · '),
                            ),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
