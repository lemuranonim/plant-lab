import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'workflow_presentation.dart';

String softLaunchReport({
  required bool plant,
  required List<String> roles,
  required String sites,
  required String priority,
  required String lot,
  required String request,
  required String steps,
  required String expected,
  required String actual,
  required DateTime reportedAt,
}) => [
  'LAPORAN SOFT LAUNCH PLANT/LAB',
  'Batch: SL-20261112',
  'Aplikasi: APK ${plant ? 'Plant' : 'Lab'}',
  'Versi APK: (lihat Info Aplikasi)',
  'Role: ${roles.join(', ')}',
  'Site: $sites',
  'Waktu laporan: ${reportedAt.toUtc().toIso8601String()}',
  'Prioritas: $priority',
  'Lot: ${lot.trim().isEmpty ? '(isi bila terkait)' : lot.trim()}',
  'Permintaan / run: ${request.trim().isEmpty ? '(isi bila terkait)' : request.trim()}',
  'Langkah kejadian: ${steps.trim().isEmpty ? '(jelaskan)' : steps.trim()}',
  'Yang diharapkan: ${expected.trim().isEmpty ? '(jelaskan)' : expected.trim()}',
  'Yang terjadi: ${actual.trim().isEmpty ? '(jelaskan)' : actual.trim()}',
  'Bukti: screenshot tanpa password/token/data pribadi.',
  'Catatan: laporan ini belum dikirim atau disimpan ke server.',
].join('\n');

class SoftLaunchGuideScreen extends StatefulWidget {
  const SoftLaunchGuideScreen({
    super.key,
    required this.plant,
    required this.roles,
    required this.sites,
  });
  final bool plant;
  final List<String> roles;
  final String sites;
  @override
  State<SoftLaunchGuideScreen> createState() => _SoftLaunchGuideScreenState();
}

class _SoftLaunchGuideScreenState extends State<SoftLaunchGuideScreen> {
  final lot = TextEditingController(),
      request = TextEditingController(),
      steps = TextEditingController(),
      expected = TextEditingController(),
      actual = TextEditingController();
  String priority = 'P2 - Pertanyaan / saran', report = '', notice = '';
  @override
  void dispose() {
    for (final c in [lot, request, steps, expected, actual]) {
      c.dispose();
    }
    super.dispose();
  }

  void changed(String _) => setState(() {
    report = '';
    notice = '';
  });
  Future<void> copyReport() async {
    final text = softLaunchReport(
      plant: widget.plant,
      roles: widget.roles,
      sites: widget.sites,
      priority: priority,
      lot: lot.text,
      request: request.text,
      steps: steps.text,
      expected: expected.text,
      actual: actual.text,
      reportedAt: DateTime.now(),
    );
    setState(() => report = text);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        setState(
          () => notice =
              'Laporan disalin. Kirim sendiri ke PIC/dev yang ditunjuk; belum dikirim atau disimpan ke server.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'Salin otomatis gagal. Pilih teks laporan di bawah dan kirim ke PIC/dev. Belum dikirim ke server.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = workflowRoleGuide(widget.plant, widget.roles);
    final heading = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan uji')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Soft launch · SL-20261112', style: heading),
          const WorkflowNote(
            title: 'Online, data asli, pengguna terbatas',
            text:
                'Gunakan akun yang ditugaskan kepada Anda. Jangan bagikan password di grup. Ini belum go-live penuh atau izin pelepasan lot.',
          ),
          WorkflowNote(title: guide.title, text: guide.text),
          Text('Mulai dari sini', style: heading),
          if (widget.plant)
            const Text(
              '1. Pastikan role dan site pada header benar.\n2. Buka Input harian untuk pekerjaan nyata; simpan draft atau kirim ke SPV jika lengkap.\n3. Ajukan uji untuk lot asli yang benar-benar dikerjakan.\n4. Setelah diterima Lab, siapkan sampel dan tandai dikirim sesudah serah terima fisik.\n5. Pantau hasil QA; SPV memeriksa catatan dan konflik pasangan di web Plant.',
            )
          else
            const Text(
              '1. Pastikan role dan site benar.\n2. Terima permintaan, lalu periksa label, berat, dan kemasan sampel fisik.\n3. Analis mencatat waktu/kondisi dan hitungan pengamatan nyata.\n4. QA independen memeriksa hasil/toleransi atau meminta uji ulang.\n5. Jika antrean kosong, periksa filter/site/koneksi; jangan membuat data contoh.',
            ),
          const SizedBox(height: 20),
          Text('Yang dapat diuji', style: heading),
          if (!widget.plant)
            const Text(
              'Form RET permintaan Plant: di Antrean & hasil uji, buka Vigor/RET lalu pilih Unduh RET PDF atau Unduh RET Excel. Satu file per percobaan dengan nomor request, label sampel, pengiriman dan penerimaan terkait. Percobaan lama dapat diunduh dari Riwayat percobaan sebelumnya. Uji berjalan belum punya hasil final. Muat ulang jika status berubah. Nama atau tanda tangan yang belum dicatat tidak dibuat otomatis. Bukan pelepasan lot.',
            ),
          if (!widget.plant)
            const Text(
              'Form Germinasi dan Vigor permintaan Plant: buka Germinasi atau metode Vigor di Antrean & hasil uji, lalu Unduh Germinasi/Vigor PDF atau Excel. Satu file per percobaan; hasil lama ada di riwayat. Jumlah benih sesuai sumber: catatan lama 2x50 tetap 2x50, tidak diubah menjadi 2x100 atau dipecah menjadi subulangan. First count yang ada tetap terpisah. Fresh/hard, jenis abnormal, nama, tanggal tanam dan rincian yang belum dicatat tetap kosong. Untuk pengamatan Germinasi baru, buka Pengamatan & petugas: isi tanggal pekerjaan nyata, nama Analis, first/final, fresh, hard, jenis abnormal dan catatan. Simpan dahulu, lalu kirim revisi tersimpan ke QA; QA mencatat nama pemeriksa. Waktu tindakan aplikasi tetap terpisah. Catatan lama tidak diisi otomatis. Cetakan tidak mengubah hasil atau QA.',
            ),
          if (!widget.plant)
            const Text(
              'Uji ulang Germinasi request: QA memilih Minta uji ulang dengan alasan. Analis mencocokkan sampel yang sama masih tersedia di Lab, lalu Mulai uji ulang Germinasi. Percobaan baru 2x100 memakai isian kosong, bukan angka lama. Hanya Analis yang memulai percobaan dapat mengisi finalnya; QA independen memeriksa lagi. Hasil/cetakan lama tetap tersimpan. Jika sampel tidak tersedia, jangan konfirmasi; koordinasikan sampel baru lewat alur resmi. Approved tidak dibuka ulang tanpa keputusan QA. Gunakan APK Lab 1.0.24+25 atau lebih baru; muat ulang bila status/percobaan berubah. Bukan pelepasan lot.',
            ),
          if (!widget.plant)
            const Text(
              'Form RET rutin: dari Hasil & pemeriksaan pada catatan RET tersimpan, pilih Unduh form PDF atau Excel. Satu pengujian menjadi satu form RET. Memuat4 ulangan x100, radikula minimal2mm, waktu penempatan16 C dan pengamatan final. Hasil/toleransi mengambil analisis tersimpan. Draft tetap draft, kosong bukan nol; ID analis/QA bukan nama atau tanda tangan buatan. Simpan perubahan dulu. Cetakan ini untuk RET rutin, bukan permintaan Plant atau pelepasan lot.',
            ),
          const Text(
            'Permintaan dan serah terima sampel; Germinasi; empat metode Vigor serta RET; review QA dan retest. Delapan form awal Plant, draft, review SPV dan revisi. Laporan/CSV Plant dan verifikasi konflik pasangan tersedia di web. Histori Excel tetap baca-saja.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Catatan uji rutin: pilih lot tanpa request Plant. Pilih label tercatat atau isi manual jika belum ditemukan; cocokkan dengan label fisik. Pilihan tidak mengisi waktu atau hitungan. Isi pengamatan nyata lalu simpan. Buka Periksa / kirim QA setelah lengkap. Revisi yang dikirim dikunci; QA independen menyetujui analisis atau meminta uji ulang. Retest membuat catatan baru, bukan menimpa hasil lama. Plant membaca hasil rutin yang sudah disetujui di bagian terpisah.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Form Germinasi dan Vigor rutin: isi tanaman/spesies, nama pelaksana, waktu tanam dan first count, jenis abnormal serta catatan per subulangan. Tanam Vigor dipisah dari mulai perlakuan. QA mengisi nama pemeriksa. Dari Hasil & pemeriksaan, unduh PDF atau Excel per pengujian; pilih tujuan penyimpanan setelah file siap. Status dan revisi ikut tercetak. RET tetap terpisah. Revalidation 1–3 memakai persetujuan manual Admin Lab melalui Catatan uji rutin. Persetujuan QA bukan izin pelepasan lot.',
          ),
          if (!widget.plant)
            const Text(
              'MC Lab mandiri: pilih lot/label, catat 3 pembacaan persen, waktu sampel tersedia dan pengukuran, petugas, alat/metode serta catatan. Rata-rata muncul jika ketiganya lengkap. Simpan dahulu, tutup isian lalu kirim revisi tersimpan ke QA; setelah dikirim isian dikunci. QA independen mengisi nama pemeriksa, memverifikasi catatan atau mengembalikan dengan alasan. Koreksi disimpan sebagai revisi baru sebelum dikirim lagi; revisi lama tetap tersimpan. Unduh PDF/Excel per catatan sesuai status terbaru. MC Lab bukan MC PI/Plant; verifikasi catatan bukan keputusan toleransi/lulus-gagal atau pelepasan lot. Batas 32% gleondong Plant tidak dipakai sebagai batas MC Lab.',
            ),
          if (!widget.plant)
            const Text(
              'Buku pengujian Lab: cari lot, hybrid, label, atau nomor uji; saring asal, metode, status dan tanggal WIB, lalu tekan Tampilkan catatan. Pilih tanggal pertama dicatat atau pengamatan final/ukur MC aktual. Ringkasan menghitung seluruh catatan yang cocok. Uji ulang tetap terpisah; verifikasi catatan MC tidak dihitung sebagai analisis disetujui QA. Bukan jumlah lot atau rata-rata mutu. Menu ini baca saja. Histori Excel tetap terpisah. Setelah filter diterapkan, pilih Unduh rekap Excel. File memuat seluruh catatan yang cocok, bukan hanya 50 pada halaman ini. Maksimal 2000 catatan; persempit tanggal/filter jika lebih. Waktu pengambilan data terbaru dicetak di file. Draft, hasil QA dan uji ulang tetap dibedakan. Rekap bukan gabungan form atau izin pelepasan lot.',
            ),
          const Text(
            'TSW rinci dari PI: pilih timbang langsung 1.000 benih atau 8 ulangan× 100 sebelum simpan pertama. Untuk8× 100, isi gram tiap ulangan;800 benih ditimbang lalu dikonversi per 1.000. Server menghitung rata-rata, CV populasi dan kernel/kg. Belum lengkap atau CV melewati acuan 4% file: TSW/kernel belum diterbitkan. Draft dapat dicicil, sumber terkunci setelah dikirim ke SPV. Lab hanya membaca sumber terkait permintaannya. Unduh PDF atau Excel TSW dari satu catatan tersimpan, terpisah dari form lain. Status sumber dan versi ikut dicetak; muat ulang jika versi berubah. Pada timbang langsung, delapan bacaan/CV/kernel yang tidak dicatat tetap kosong. Pemeriksa memakai ID akun; nama belum dicatat, bukan tanda tangan. Bukan approval Lab, spesifikasi mutu baru atau pelepasan lot. Assignment PI terpisah sudah diberikan pada akun Bagaskara yang ditunjuk owner, khusus PRASAD. Operator/SPV tidak otomatis PI.',
          ),
          const WorkflowNote(
            title: 'Batas soft launch',
            text:
                'Input PI memerlukan assignment PI yang sah dan terpisah. Operator/SPV tidak otomatis PI. Registrasi lot baru/format QA, seluruh detail blueprint dan offline belum lengkap. Gunakan lot berizin yang tersedia, bukan lot pengganti.',
          ),
          const WorkflowNote(
            title: 'Hitungan dan waktu bukan data contoh',
            text:
                'Germinasi rutin memilih 2× 100 atau 4× 100 sebelum simpan pertama, default 2× 100. Toleransi mengikuti jumlah ulangan; pilihan dikunci setelah disimpan. Germinasi request Plant tetap 2× 100, Vigor lain 2× 100. RET radikula ≥2 mm, 4× 100, minimal 72 jam sejak penempatan pada 16°C. Toleransi yang belum tersedia (termasuk lookup 0/1/100) menahan approval. Jangan mengubah angka agar lolos.',
          ),
          const Text(
            'Draft tersimpan setelah server mengonfirmasi. Jangan tutup halaman jika belum tersimpan; ikuti prosedur resmi tim yang masih wajib selama soft launch. Penugasan pilot diperpanjang sampai akhir 30 November 2026 WIB. Akun QA juga mendapat wewenang terbatas persetujuan Revalidation Lab, bukan admin modul lain. Di Catatan uji rutin, buka Revalidation 1–3 lalu Muat Revalidation. Admin memilih sumber approved, mengisi nama, alasan, rencana sampel dan rujukan. Analis mencocokkan sampel fisik dan waktu tersedia sebelum menyiapkan draft kosong. Tahap berikutnya menunggu QA tahap sebelumnya; uji ulang QA tetap tahap yang sama. Bukan jadwal otomatis atau salinan angka lama.',
          ),
          const SizedBox(height: 20),
          Text('Laporkan kendala', style: heading),
          const Text(
            'Salah lot, hasil tidak sesuai, atau akses di luar role? Hentikan alur terkait dan laporkan P0. Jangan mengubah hasil approved. Form ini hanya menyiapkan teks, bukan tiket yang dikirim otomatis.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: priority,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Prioritas kendala'),
            items:
                const [
                      'P2 - Pertanyaan / saran',
                      'P1 - Pekerjaan terblokir',
                      'P0 - Risiko data / akses',
                    ]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                priority = value;
                changed('');
              }
            },
          ),
          for (final field in [
            (lot, 'Kode lot terkait', 100),
            (request, 'Nomor permintaan / run', 100),
            (steps, 'Langkah sebelum kendala', 1000),
            (expected, 'Hasil yang diharapkan', 1000),
            (actual, 'Hasil yang terjadi', 1000),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: field.$1,
                maxLength: field.$3,
                minLines: field.$3 > 100 ? 2 : 1,
                maxLines: field.$3 > 100 ? 4 : 1,
                onChanged: changed,
                decoration: InputDecoration(labelText: field.$2),
              ),
            ),
          FilledButton.icon(
            onPressed: copyReport,
            icon: const Icon(Icons.copy),
            label: const Text('Salin laporan kendala'),
          ),
          if (notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(notice, semanticsLabel: notice),
            ),
          if (report.isNotEmpty) SelectableText(report),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
