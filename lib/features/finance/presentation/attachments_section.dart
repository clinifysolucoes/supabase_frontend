import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/files/file_pick.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_snack.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import '../domain/phase4_models.dart';

/// Anexos da conta (documento: nota/boleto; comprovante de pagamento):
/// lista, baixar, anexar e excluir. O arquivo vai para o Storage pela Edge
/// Function fin-attachment.
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.entry,
    required this.canUpdate,
    this.pick = FilePick.file,
  });

  final FinEntry entry;
  final bool canUpdate;

  /// Escolha do arquivo (trocada nos testes).
  final Future<({String name, Uint8List bytes})?> Function({
    required List<String> extensions,
  })
  pick;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  bool _busy = false;

  Future<void> _add(int type) async {
    final file = await widget.pick(extensions: FinAttachment.extensions);
    if (file == null || !mounted) return;
    final mime = FinAttachment.mimeOf(file.name);
    if (mime == null) {
      AppSnack.error(context, Strings.attachTypeInvalid);
      return;
    }
    if (file.bytes.length > FinAttachment.maxBytes) {
      AppSnack.error(context, Strings.attachTooLarge);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(financeActionsProvider)
          .uploadAttachment(
            nrEntry: widget.entry.nrEntry,
            itType: type,
            name: file.name,
            mime: mime,
            bytes: file.bytes,
          );
      if (mounted) AppSnack.success(context, Strings.attachDone);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(FinAttachment a) async {
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(financeActionsProvider)
          .downloadAttachment(a.nrAttachment);
      await FileDownload.saveFile(fileName: a.vcName, bytes: bytes);
      if (mounted) AppSnack.success(context, Strings.attachDownloaded);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FinAttachment a) async {
    if (!await AppConfirmDialog.show(
          context,
          title: Strings.remove,
          message: Strings.attachDeleteConfirm,
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(financeActionsProvider).deleteAttachment(a.nrAttachment);
      if (mounted) AppSnack.success(context, Strings.attachDeleted);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list =
        ref.watch(attachmentsProvider(widget.entry.nrEntry)).valueOrNull ??
        const <FinAttachment>[];
    final canAdd = widget.canUpdate && !widget.entry.isCancelled && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text(
              Strings.attachments,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (_busy) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              Strings.attachNone,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final a in list)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              a.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            ),
            title: Text(a.vcName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                AttachmentType.label(a.itType),
                if (a.dhCreated != null) Dates.format(a.dhCreated),
                ?a.vcUser,
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: Strings.attachDownload,
                  icon: const Icon(Icons.download_rounded),
                  onPressed: _busy ? null : () => _download(a),
                ),
                if (widget.canUpdate)
                  IconButton(
                    tooltip: Strings.remove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.danger,
                    onPressed: _busy ? null : () => _delete(a),
                  ),
              ],
            ),
          ),
        if (widget.canUpdate && !widget.entry.isCancelled)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: canAdd ? () => _add(AttachmentType.document) : null,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text(Strings.attachAddDocument),
              ),
              TextButton.icon(
                onPressed: canAdd ? () => _add(AttachmentType.receipt) : null,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text(Strings.attachAddReceipt),
              ),
            ],
          ),
      ],
    );
  }
}
