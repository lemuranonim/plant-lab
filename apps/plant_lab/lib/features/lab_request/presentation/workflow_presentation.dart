import 'package:flutter/material.dart';
import '../../../app/theme/lab_theme.dart';

// Presentation only: never use these labels to authorize or submit commands.
String workflowStatus(String code) =>
    const {
      'REQUESTED': 'Menunggu diterima Lab',
      'ACCEPTED': 'Siapkan sampel',
      'PREPARED': 'Sampel siap dikirim',
      'SENT': 'Dalam pengiriman',
      'RECEIVED': 'Sampel diterima Lab',
      'TESTING': 'Pengujian berjalan',
      'IN_PROGRESS': 'Pengujian berjalan',
      'IN_REVIEW': 'Menunggu review QA',
      'APPROVED': 'Hasil disetujui',
      'RETEST': 'Perlu uji ulang',
      'CANCELLED': 'Dibatalkan',
      'CLOSED': 'Ditutup',
      'REJECTED': 'Ditolak',
      'DRAFT': 'Draft',
      'SUBMITTED': 'Menunggu pemeriksaan',
      'NEED_REVISION': 'Perlu perbaikan',
      'VERIFIED': 'Sumber terverifikasi',
      'PENDING': 'Belum dimulai',
    }[code] ??
    code;

String workflowTest(String code) =>
    const {'GERMINATION': 'Germinasi', 'VIGOUR': 'Vigor'}[code] ?? code;

String workflowGroup(String status) {
  if (status == 'APPROVED') return 'approved';
  if (status == 'IN_REVIEW') return 'review';
  if (['CANCELLED', 'CLOSED', 'REJECTED'].contains(status)) return 'closed';
  return 'active';
}

({String title, String text}) workflowRoleGuide(
  bool plant,
  List<String> roles,
) {
  if (!plant) {
    return roles.contains('LAB_QA_APPROVER')
        ? (
            title: 'Pemeriksaan hasil Lab',
            text:
                'Periksa hitungan, toleransi, metode, dan catatan analis. Setujui hasil atau minta uji ulang. Hasil yang disetujui tidak otomatis melepas lot.',
          )
        : (
            title: 'Pekerjaan analis Lab',
            text:
                'Terima permintaan dan sampel fisik, mulai pengujian, lalu catat pengamatan aktual untuk diperiksa QA.',
          );
  }
  if (roles.contains('PLANT_PI')) {
    return (
      title: 'Pengukuran mutu PI',
      text:
          'Catat PP, MC, dan TSW beserta metode, alat, waktu nyata, dan foto. Buka menu Mutu PI; akses mengikuti penugasan lot dan site.',
    );
  }
  if (roles.contains('PLANT_SPV')) {
    return (
      title: 'Pengawasan Plant',
      text:
          'Periksa catatan harian tim dan konflik pasangan lot di web Plant. Pantau sampel dan baca hasil yang sudah disetujui Lab.',
    );
  }
  return (
    title: 'Pekerjaan operator Plant',
    text:
        'Catat pekerjaan harian, ajukan pengujian untuk lot yang benar, lalu siapkan dan kirim sampel fisik ke Lab.',
  );
}

String workflowNextStep(String status, bool plant, {bool reviewer = false}) {
  switch (status) {
    case 'REQUESTED':
      return plant
          ? 'Menunggu Lab menerima permintaan.'
          : 'Periksa permintaan, lalu terima bila siap dikerjakan.';
    case 'ACCEPTED':
      return plant
          ? 'Siapkan sampel fisik dan catat berat serta kemasannya.'
          : 'Menunggu Plant menyiapkan sampel fisik.';
    case 'PREPARED':
      return plant
          ? 'Tandai dikirim setelah sampel benar-benar diserahkan.'
          : 'Menunggu Plant mengirim sampel.';
    case 'SENT':
      return plant
          ? 'Menunggu konfirmasi penerimaan fisik dari Lab.'
          : 'Cocokkan label, timbang, dan terima sampel fisik.';
    case 'RECEIVED':
      return plant
          ? 'Sampel sudah di Lab. Menunggu analis memulai uji.'
          : reviewer
          ? 'Menunggu analis memulai pengujian.'
          : 'Buka metode di bawah untuk memulai pengujian nyata.';
    case 'TESTING':
    case 'IN_PROGRESS':
      return plant
          ? 'Pengujian sedang berlangsung di Lab.'
          : reviewer
          ? 'Menunggu analis mengirim hasil untuk review.'
          : 'Buka metode; isi pengamatan setelah waktu uji terpenuhi.';
    case 'IN_REVIEW':
      return plant
          ? 'Menunggu QA Lab memeriksa hasil.'
          : reviewer
          ? 'Buka hasil pengujian dan lakukan review QA independen.'
          : 'Hasil sudah dikirim. Menunggu review QA independen.';
    case 'RETEST':
      return plant
          ? 'QA meminta uji ulang. Pantau pelaksanaannya di Lab.'
          : reviewer
          ? 'Menunggu analis melaksanakan uji ulang.'
          : 'Buka metode untuk memulai percobaan ulang baru.';
    case 'APPROVED':
      return 'Hasil analisis sudah disetujui QA. Buka hasil di bawah; ini bukan pelepasan lot.';
    case 'CANCELLED':
    case 'CLOSED':
    case 'REJECTED':
      return 'Tidak ada tindakan lanjutan pada permintaan ini.';
    default:
      return 'Periksa detail dan penugasan sebelum melanjutkan.';
  }
}

String labQueueCue(
  String status, {
  required bool writes,
  required bool analyst,
  required bool reviewer,
}) {
  if (workflowGroup(status) == 'closed') return 'Tidak ada tindakan lanjutan';
  if (!writes) return 'Lihat detail · baca saja';
  return switch (status) {
    'REQUESTED' => 'Periksa permintaan masuk',
    'ACCEPTED' || 'PREPARED' => 'Menunggu kiriman Plant',
    'SENT' => 'Cocokkan sampel fisik',
    'RECEIVED' => analyst ? 'Mulai pengujian' : 'Menunggu Analis memulai uji',
    'TESTING' ||
    'IN_PROGRESS' => analyst ? 'Catat pengamatan' : 'Menunggu kiriman hasil',
    'IN_REVIEW' => reviewer ? 'Periksa hasil QA' : 'Menunggu pemeriksaan QA',
    'RETEST' => analyst ? 'Siapkan uji ulang' : 'Menunggu uji ulang',
    'APPROVED' => 'Lihat hasil analisis',
    _ => 'Periksa detail permintaan',
  };
}

class WorkflowNote extends StatelessWidget {
  const WorkflowNote({
    super.key,
    required this.title,
    required this.text,
    this.compact = false,
  });
  final String title, text;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          text,
          style: compact ? Theme.of(context).textTheme.bodySmall : null,
        ),
      ],
    ),
  );
}

class WorkflowStatusBadge extends StatelessWidget {
  const WorkflowStatusBadge({super.key, required this.status, this.label});
  final String status;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = Theme.of(context).extension<LabPalette>()?.status(status);
    return Tooltip(
      message: label ?? status,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tone?.surface ?? scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label ?? workflowStatus(status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tone?.ink ?? scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
