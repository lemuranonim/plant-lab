import 'package:flutter/material.dart';
import 'workflow_presentation.dart';

class PreviewLotPair {
  const PreviewLotPair({
    required this.testedStage,
    required this.dssCode,
    required this.dcsCode,
  });

  factory PreviewLotPair.fromJson(Map<String, dynamic> json) => PreviewLotPair(
    testedStage: json['tested_stage_code'] as String,
    dssCode: json['dss_lot_code'] as String,
    dcsCode: json['dcs_lot_code'] as String,
  );

  final String testedStage;
  final String dssCode;
  final String dcsCode;
}

class StandaloneLotReference extends StatelessWidget {
  const StandaloneLotReference({
    super.key,
    required this.testedCode,
    this.pair,
  });

  final String? testedCode;
  final PreviewLotPair? pair;

  @override
  Widget build(BuildContext context) {
    final reference = pair;
    final stage = reference == null ? '' : ' (${reference.testedStage})';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lot diuji: ${testedCode ?? '—'}$stage'),
        if (reference != null) ...[
          const SizedBox(height: 4),
          const Text('Rujukan pasangan DSS–DCS'),
          Text('DSS: ${reference.dssCode}'),
          Text('DCS: ${reference.dcsCode}'),
        ],
      ],
    );
  }
}

class StandaloneRequestHeading extends StatelessWidget {
  const StandaloneRequestHeading({
    super.key,
    required this.requestCode,
    required this.status,
    required this.lotCode,
    required this.details,
    this.pair,
  });

  final String requestCode;
  final String status;
  final String? lotCode;
  final String details;
  final PreviewLotPair? pair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LOT DIUJI', style: textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(lotCode ?? 'Belum tersedia', style: textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WorkflowStatusBadge(status: status),
              if (pair != null)
                Text(pair!.testedStage, style: textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          if (details.isNotEmpty) ...[const SizedBox(height: 4), Text(details)],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: const Text('Detail permintaan & pasangan lot'),
            children: [
              Text('Nomor permintaan', style: textTheme.labelMedium),
              SelectableText(requestCode),
              Text('Status sistem: $status', style: textTheme.bodySmall),
              const SizedBox(height: 10),
              StandaloneLotReference(testedCode: lotCode, pair: pair),
            ],
          ),
        ],
      ),
    );
  }
}
