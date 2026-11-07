import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/files/file_pick.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/patient_file_controllers.dart';
import '../domain/patient_file_models.dart';

/// Aba Fotos ou Exames: galeria por data, envio de varios arquivos, filtro
/// por categoria, visualizacao, download, edicao e exclusao.
class PatientFilesTab extends ConsumerStatefulWidget {
  const PatientFilesTab({
    super.key,
    required this.nrPatient,
    required this.type,
  });

  final int nrPatient;
  final PatientFileType type;

  @override
  ConsumerState<PatientFilesTab> createState() => _PatientFilesTabState();
}

class _PatientFilesTabState extends ConsumerState<PatientFilesTab> {
  FileCategory? _filter;
  String? _progress;

  PatientFileKey get _key => (nrPatient: widget.nrPatient, type: widget.type);
  PatientFileActions get _actions => ref.read(patientFileActionsProvider);

  Future<void> _upload() async {
    final picked = await FilePick.files(extensions: widget.type.extensions);
    if (picked.isEmpty || !mounted) return;
    final tooBig = picked.where((f) => f.bytes.length > PatientFiles.maxBytes);
    if (tooBig.isNotEmpty) {
      AppSnack.error(context, Strings.fileTooLarge(tooBig.first.name));
      return;
    }
    final meta = await _FileMetaDialog.show(
      context,
      type: widget.type,
      title: Strings.filesSelected(picked.length),
    );
    if (meta == null || !mounted) return;
    var done = 0;
    final failed = <String>[];
    for (final f in picked) {
      setState(() => _progress = Strings.uploading(done + 1, picked.length));
      final mime = PatientFiles.mimeOf(f.name);
      if (mime == null) {
        failed.add(f.name);
        continue;
      }
      try {
        await _actions.upload(
          _key,
          name: f.name,
          mime: mime,
          bytes: f.bytes,
          fields: meta,
        );
        done++;
      } catch (e) {
        failed.add('${f.name}: ${describeError(e)}');
      }
    }
    _actions.refresh(_key);
    if (!mounted) return;
    setState(() => _progress = null);
    if (failed.isEmpty) {
      AppSnack.success(context, Strings.filesUploaded(done));
    } else {
      AppSnack.error(context, Strings.filesFailed(failed.join('; ')));
    }
  }

  Future<void> _download(PatientFile f) async {
    try {
      final bytes = await _actions.download(_key, f.nrFile);
      await FileDownload.saveFile(fileName: f.vcName, bytes: bytes);
      if (mounted) AppSnack.success(context, Strings.attachDownloaded);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _open(PatientFileView view, PatientFile f) async {
    final action = await _FileViewerDialog.show(
      context,
      file: f,
      url: view.urls[f.nrFile],
      canUpdate: view.list.canUpdate,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ViewerAction.download:
        await _download(f);
      case _ViewerAction.edit:
        final meta = await _FileMetaDialog.show(
          context,
          type: widget.type,
          title: f.vcName,
          file: f,
        );
        if (meta == null || !mounted) return;
        try {
          await _actions.update(_key, f.nrFile, meta);
          if (mounted) AppSnack.success(context, Strings.savedSuccess);
        } catch (e) {
          if (mounted) AppSnack.error(context, describeError(e));
        }
      case _ViewerAction.delete:
        final ok = await AppConfirmDialog.show(
          context,
          title: Strings.deleteFile,
          message: Strings.deleteFileConfirm,
          confirmLabel: Strings.remove,
        );
        if (!ok || !mounted) return;
        try {
          await _actions.delete(_key, f.nrFile);
          if (mounted) AppSnack.success(context, Strings.fileDeleted);
        } catch (e) {
          if (mounted) AppSnack.error(context, describeError(e));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(patientFilesProvider(_key));
    final isPhoto = widget.type == PatientFileType.photo;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(patientFilesProvider(_key)),
      ),
      data: (view) {
        final used = {for (final f in view.list.files) f.category};
        final files = _filter == null
            ? view.list.files
            : view.list.files.where((f) => f.category == _filter).toList();
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text(Strings.allCount(view.list.files.length)),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final c in widget.type.categories)
                        if (used.contains(c))
                          ChoiceChip(
                            label: Text(c.label),
                            selected: _filter == c,
                            onSelected: (_) => setState(() => _filter = c),
                          ),
                    ],
                  ),
                ),
                if (view.list.canCreate)
                  AppButton(
                    label:
                        _progress ??
                        (isPhoto ? Strings.addPhotos : Strings.addExams),
                    icon: Icons.upload_rounded,
                    loading: _progress != null,
                    onPressed: _upload,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (files.isEmpty)
              AppEmptyState(
                icon: isPhoto
                    ? Icons.photo_library_outlined
                    : Icons.medical_services_outlined,
                title: isPhoto ? Strings.noPhotos : Strings.noExams,
                subtitle: Strings.filesHint,
              ),
            if (files.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final f in files)
                    _FileTile(
                      file: f,
                      url: view.urls[f.nrFile],
                      onTap: () => _open(view, f),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.url, required this.onTap});

  final PatientFile file;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Icon(
      file.isPdf
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      size: 48,
      color: AppColors.primary,
    );
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 130,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: url == null
                    ? icon
                    : Image.network(
                        url!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 130,
                        errorBuilder: (_, _, _) => icon,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.vcDescription ?? file.vcName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        Dates.format(file.dtFile),
                        file.category.label,
                        if (file.vcTooth != null) file.vcTooth!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ViewerAction { download, edit, delete }

class _FileViewerDialog extends StatelessWidget {
  const _FileViewerDialog({
    required this.file,
    required this.url,
    required this.canUpdate,
  });

  final PatientFile file;
  final String? url;
  final bool canUpdate;

  static Future<_ViewerAction?> show(
    BuildContext context, {
    required PatientFile file,
    required String? url,
    required bool canUpdate,
  }) => showDialog<_ViewerAction>(
    context: context,
    builder: (_) =>
        _FileViewerDialog(file: file, url: url, canUpdate: canUpdate),
  );

  @override
  Widget build(BuildContext context) {
    final f = file;
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(f.vcDescription ?? f.vcName),
      content: SizedBox(
        width: size.width * 0.8 > 900 ? 900 : size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (url != null)
              Flexible(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(url!, fit: BoxFit.contain),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  Strings.fileNoPreview,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                f.vcName,
                PatientFiles.size(f.qtBytes),
                Dates.format(f.dtFile),
                f.category.label,
                if (f.vcTooth != null) '${Strings.tooth} ${f.vcTooth}',
                if (f.vcUser != null) f.vcUser!,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        if (canUpdate) ...[
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_ViewerAction.delete),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text(Strings.remove),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_ViewerAction.edit),
            icon: const Icon(Icons.edit_outlined),
            label: const Text(Strings.edit),
          ),
        ],
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(_ViewerAction.download),
          icon: const Icon(Icons.download_rounded),
          label: const Text(Strings.download),
        ),
        AppButton(
          label: Strings.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Categoria, data, dente e descricao (no envio valem para todos os arquivos).
class _FileMetaDialog extends StatefulWidget {
  const _FileMetaDialog({required this.type, required this.title, this.file});

  final PatientFileType type;
  final String title;
  final PatientFile? file;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required PatientFileType type,
    required String title,
    PatientFile? file,
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _FileMetaDialog(type: type, title: title, file: file),
  );

  @override
  State<_FileMetaDialog> createState() => _FileMetaDialogState();
}

class _FileMetaDialogState extends State<_FileMetaDialog> {
  final _formKey = GlobalKey<FormState>();
  late FileCategory _category =
      widget.file?.category ??
      (widget.type == PatientFileType.photo
          ? FileCategory.intraoral
          : FileCategory.periapical);
  late final _date = TextEditingController(
    text: Dates.toField(widget.file?.dtFile ?? DateTime.now()),
  );
  late final _tooth = TextEditingController(text: widget.file?.vcTooth ?? '');
  late final _description = TextEditingController(
    text: widget.file?.vcDescription ?? '',
  );

  @override
  void dispose() {
    _date.dispose();
    _tooth.dispose();
    _description.dispose();
    super.dispose();
  }

  void _ok() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dt = Dates.parseField(_date.text)!;
    Navigator.of(context).pop({
      'it_category': _category.code,
      'dt_file': Dates.toIso(dt),
      'vc_tooth': _tooth.text.trim(),
      'vc_description': _description.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<FileCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: Strings.category),
              items: [
                for (final c in widget.type.categories)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: Strings.fileDate,
                    controller: _date,
                    mask: MaskType.date,
                    validator: (v) {
                      final d = Dates.parseField(v);
                      if (d == null) return Strings.invalidDate;
                      if (d.isAfter(DateTime.now())) return Strings.futureDate;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: Strings.toothOrRegion,
                    controller: _tooth,
                    maxLength: 40,
                  ),
                ),
              ],
            ),
            AppTextField(
              label: Strings.description,
              controller: _description,
              maxLength: 300,
            ),
          ],
        ),
      ),
    ),
    actions: [
      AppButton(
        label: Strings.cancel,
        variant: AppButtonVariant.text,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton(label: Strings.save, onPressed: _ok),
    ],
  );
}
