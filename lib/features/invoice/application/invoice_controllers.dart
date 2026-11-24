import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/invoice_models.dart';

/// Filtro da aba: uma situacao (null = todas menos canceladas) e a busca.
final invoiceStatusFilterProvider = StateProvider.autoDispose<InvoiceStatus?>(
  (_) => null,
);
final invoiceSearchProvider = StateProvider.autoDispose<String>((_) => '');

final invoiceListProvider = FutureProvider.autoDispose<InvoiceListData>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const InvoiceListData();
  final status = ref.watch(invoiceStatusFilterProvider);
  final search = ref.watch(invoiceSearchProvider);
  return InvoiceListData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('invoice_list', {
      'nr_company': c,
      'nr_branch': b,
      'it_status': ?status?.code,
      if (search.isNotEmpty) 'vc_search': search,
    }),
  );
});

/// Cria (I), altera (U) ou descarta (D) uma nota e recarrega a lista.
final invoiceSaveProvider =
    Provider<
      Future<int> Function(
        String action,
        int? nrInvoice,
        Map<String, dynamic> fields,
      )
    >(
      (ref) => (action, nrInvoice, fields) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        final r = await ref.read(supabaseGatewayProvider).rpc('invoice_save', {
          'nr_company': c,
          'nr_branch': b,
          'vc_action': action,
          'nr_invoice': ?nrInvoice,
          ...fields,
        });
        ref.invalidate(invoiceListProvider);
        return (r['nr_invoice'] as num).toInt();
      },
    );

/// Emite (ISSUE) ou cancela (CANCEL) pela Edge Function invoice-issue.
/// Devolve a resposta: it_status e, se deu erro no emissor, Message.
final invoiceIssueProvider =
    Provider<
      Future<Map<String, dynamic>> Function(
        int nrInvoice,
        String action, {
        String? reason,
      })
    >(
      (ref) => (nrInvoice, action, {reason}) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        try {
          return await ref
              .read(supabaseGatewayProvider)
              .invokeFunction('invoice-issue', {
                'nr_company': c,
                'nr_branch': b,
                'nr_invoice': nrInvoice,
                'vc_action': action,
                'vc_cancel_reason': ?reason,
              });
        } finally {
          ref.invalidate(invoiceListProvider);
        }
      },
    );

final invoiceSettingsProvider = FutureProvider.autoDispose<InvoiceSettings>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const InvoiceSettings();
  return InvoiceSettings.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('invoice_settings_get', {
      'nr_company': c,
      'nr_branch': b,
    }),
  );
});

final invoiceSettingsSaveProvider =
    Provider<Future<void> Function(Map<String, dynamic> fields)>(
      (ref) => (fields) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        await ref.read(supabaseGatewayProvider).rpc('invoice_settings_save', {
          'nr_company': c,
          'nr_branch': b,
          ...fields,
        });
        ref.invalidate(invoiceSettingsProvider);
        ref.invalidate(invoiceListProvider);
      },
    );
