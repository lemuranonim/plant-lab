// Display only. Canonical codes, permissions and decisions stay on the server.
export const statusLabel = (code: string) => ({
  REQUESTED: 'Menunggu diterima Lab', ACCEPTED: 'Siapkan sampel',
  PREPARED: 'Sampel siap dikirim', SENT: 'Dalam pengiriman',
  RECEIVED: 'Sampel diterima Lab', TESTING: 'Pengujian berjalan',
  IN_PROGRESS: 'Pengujian berjalan', IN_REVIEW: 'Menunggu review QA',
  APPROVED: 'Hasil disetujui', RETEST: 'Perlu uji ulang',
  CANCELLED: 'Dibatalkan', CLOSED: 'Ditutup', REJECTED: 'Ditolak',
  DRAFT: 'Draft', SUBMITTED: 'Menunggu pemeriksaan',
  NEED_REVISION: 'Perlu perbaikan', VERIFIED: 'Sumber terverifikasi',
  PENDING: 'Belum dimulai',
} as Record<string, string>)[code] ?? code;

export const testLabel = (code: string) => ({
  GERMINATION: 'Germinasi', VIGOUR: 'Vigor',
} as Record<string, string>)[code] ?? code;

export function roleGuide(module: string, roles: string[]) {
  if (module === 'LAB') return roles.includes('LAB_QA_APPROVER')
    ? { title: 'Pemeriksaan hasil Lab', text: 'Periksa hitungan, toleransi, metode, dan catatan analis. Setujui hasil atau minta uji ulang. Hasil yang disetujui tidak otomatis melepas lot.' }
    : { title: 'Pekerjaan analis Lab', text: 'Terima permintaan dan sampel fisik, mulai pengujian, lalu catat pengamatan aktual untuk diperiksa QA.' };
  if (roles.includes('PLANT_PI')) return { title: 'Pengukuran mutu PI', text: 'Catat PP, MC, dan TSW beserta metode, alat, waktu nyata, dan foto. Buka menu Mutu PI; akses mengikuti penugasan lot dan site.' };
  if (roles.includes('PLANT_SPV')) return { title: 'Pengawasan Plant', text: 'Periksa catatan harian tim dan konflik pasangan lot. Pantau sampel dan baca hasil yang sudah disetujui Lab.' };
  return { title: 'Pekerjaan operator Plant', text: 'Catat pekerjaan harian, ajukan pengujian untuk lot yang benar, lalu siapkan dan kirim sampel fisik ke Lab.' };
}

export function nextStep(status: string, module: string, reviewer = false) {
  const plant = module === 'PLANT';
  switch (status) {
    case 'REQUESTED': return plant ? 'Menunggu Lab menerima permintaan.' : 'Periksa permintaan, lalu terima bila siap dikerjakan.';
    case 'ACCEPTED': return plant ? 'Siapkan sampel fisik dan catat berat serta kemasannya.' : 'Menunggu Plant menyiapkan sampel fisik.';
    case 'PREPARED': return plant ? 'Tandai dikirim setelah sampel benar-benar diserahkan.' : 'Menunggu Plant mengirim sampel.';
    case 'SENT': return plant ? 'Menunggu konfirmasi penerimaan fisik dari Lab.' : 'Cocokkan label, timbang, dan terima sampel fisik.';
    case 'RECEIVED': return plant ? 'Sampel sudah di Lab. Menunggu analis memulai uji.' : reviewer ? 'Menunggu analis memulai pengujian.' : 'Buka metode di bawah untuk memulai pengujian nyata.';
    case 'TESTING': case 'IN_PROGRESS': return plant ? 'Pengujian sedang berlangsung di Lab.' : reviewer ? 'Menunggu analis mengirim hasil untuk review.' : 'Buka metode; isi pengamatan setelah waktu uji terpenuhi.';
    case 'IN_REVIEW': return plant ? 'Menunggu QA Lab memeriksa hasil.' : reviewer ? 'Buka hasil pengujian dan lakukan review QA independen.' : 'Hasil sudah dikirim. Menunggu review QA independen.';
    case 'RETEST': return plant ? 'QA meminta uji ulang. Pantau pelaksanaannya di Lab.' : reviewer ? 'Menunggu analis melaksanakan uji ulang.' : 'Buka metode untuk memulai percobaan ulang baru.';
    case 'APPROVED': return 'Hasil analisis sudah disetujui QA. Buka hasil di bawah; ini bukan pelepasan lot.';
    case 'CANCELLED': case 'CLOSED': case 'REJECTED': return 'Tidak ada tindakan lanjutan pada permintaan ini.';
    default: return 'Periksa detail dan penugasan sebelum melanjutkan.';
  }
}

export function queueGroup(status: string) {
  if (status === 'APPROVED') return 'approved';
  if (status === 'IN_REVIEW') return 'review';
  if (['CANCELLED', 'CLOSED', 'REJECTED'].includes(status)) return 'closed';
  return 'active';
}

// Display and navigation only. Keep canonical action guards in the panels.
export function labQueueCue(status: string, writes: boolean, analyst: boolean, reviewer: boolean) {
  if (queueGroup(status) === 'closed') return { label: 'Tidak ada tindakan lanjutan' };
  if (!writes) return { label: 'Lihat detail · baca saja' };
  switch (status) {
    case 'REQUESTED': return { label: 'Periksa permintaan masuk' };
    case 'ACCEPTED': case 'PREPARED': return { label: 'Menunggu kiriman Plant' };
    case 'SENT': return { label: 'Cocokkan sampel fisik' };
    case 'RECEIVED': return analyst ? { label: 'Mulai pengujian', section: 'observations' as const } : { label: 'Menunggu Analis memulai uji' };
    case 'TESTING': case 'IN_PROGRESS': return analyst ? { label: 'Catat pengamatan', section: 'observations' as const } : { label: 'Menunggu kiriman hasil' };
    case 'IN_REVIEW': return reviewer ? { label: 'Periksa hasil QA', section: 'observations' as const } : { label: 'Menunggu pemeriksaan QA' };
    case 'RETEST': return analyst ? { label: 'Siapkan uji ulang', section: 'observations' as const } : { label: 'Menunggu uji ulang' };
    case 'APPROVED': return { label: 'Lihat hasil analisis' };
    default: return { label: 'Periksa detail permintaan' };
  }
}
