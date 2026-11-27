'use client';

import { useRef, useState } from 'react';
import { roleGuide } from '@/lib/workflowPresentation';
import styles from './soft-launch.module.css';

const issuePriorities = ['P1 - Pekerjaan terblokir', 'P0 - Risiko data / akses'];
const labIssueTypes = ['Bug fitur', 'Login atau hak akses', 'Data atau hasil uji', 'Tampilan atau navigasi', 'Pertanyaan / saran', 'Lainnya'];
const labIssueFeatures = [
  'Antrean & hasil uji', 'Permintaan atau serah terima sampel', 'Catatan uji rutin', 'Review QA', 'MC Lab',
  'Revalidation 1–3', 'Unduh form PDF / Excel', 'Buku pengujian Lab', 'Pemantauan kerja Lab', 'Sumber Mutu Plant',
  'Histori Excel', 'Login & akses', 'Panduan & laporan kendala', 'Lainnya',
];
const labReportDate = new Intl.DateTimeFormat('id-ID', {
  timeZone: 'Asia/Jakarta', day: 'numeric', month: 'long', year: 'numeric',
});
const labReportClock = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Jakarta', hourCycle: 'h23', hour: '2-digit', minute: '2-digit', second: '2-digit',
});
const plantPilotBatch = 'SL-20261112';

export default function SoftLaunchGuide({ plant, roles, sites, reportWhatsAppNumber }: { plant: boolean; roles: string[]; sites: string; reportWhatsAppNumber?: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [lot, setLot] = useState('');
  const [request, setRequest] = useState('');
  const [steps, setSteps] = useState('');
  const [expected, setExpected] = useState('');
  const [actual, setActual] = useState('');
  const [priority, setPriority] = useState(plant ? 'P2 - Pertanyaan / saran' : 'P2 - Kendala ringan / saran');
  const [issueApp, setIssueApp] = useState('Web Lab');
  const [issueType, setIssueType] = useState('');
  const [issueFeature, setIssueFeature] = useState('');
  const [report, setReport] = useState('');
  const [notice, setNotice] = useState('');
  const guide = roleGuide(plant ? 'PLANT' : 'LAB', roles);
  const whatsAppNumber = plant ? undefined : reportWhatsAppNumber;
  const lotReference = lot.trim();
  const runReference = request.trim();
  const referenceFields = <>
    <label>Kode lot terkait<input value={lot} onChange={e => setLot(e.target.value)} maxLength={100} /></label>
    <label>Nomor permintaan / run<input value={request} onChange={e => setRequest(e.target.value)} maxLength={100} /></label>
  </>;

  function prepareReport() {
    const now = new Date();
    const reportTime = plant ? now.toISOString() : `${labReportDate.format(now)}, ${labReportClock.format(now)} WIB`;
    return [
      plant ? 'LAPORAN SOFT LAUNCH PLANT/LAB' : 'LAPORAN KENDALA LAB',
      ...(plant ? [`Batch: ${plantPilotBatch}`] : []),
      `Aplikasi: ${plant ? 'Web Plant' : issueApp}`, `Role: ${roles.join(', ') || 'Belum tersedia'}`, `Site: ${sites || 'Belum tersedia'}`,
      `${!plant && issueApp === 'APK Lab' ? 'Halaman pelaporan (Web Lab)' : 'Halaman'}: ${window.location.origin}${window.location.pathname}`, `Waktu laporan: ${reportTime}`,
      `Prioritas: ${priority}`,
      ...(!plant && issueType ? [`Jenis kendala: ${issueType}`] : []),
      ...(!plant && issueFeature ? [`Fitur terkait: ${issueFeature}`] : []),
      ...(plant || lotReference ? [`Lot: ${lotReference || '(isi bila terkait)'}`] : []),
      ...(plant || runReference ? [`Permintaan / run: ${runReference || '(isi bila terkait)'}`] : []),
      `Langkah kejadian: ${steps.trim() || '(jelaskan)'}`, `Yang diharapkan: ${expected.trim() || '(jelaskan)'}`, `Yang terjadi: ${actual.trim() || '(jelaskan)'}`,
      'Bukti: lampirkan screenshot yang sudah diperiksa, tanpa password/token/data pribadi.',
    ].join('\n');
  }

  async function copyReport() {
    const text = `${prepareReport()}\nCatatan: laporan ini belum dikirim atau disimpan ke server.`;
    setReport(text);
    try {
      await navigator.clipboard.writeText(text);
      setNotice('Laporan disalin. Kirim sendiri ke PIC/dev yang ditunjuk; belum dikirim atau disimpan ke server.');
    } catch {
      setNotice('Salin otomatis tidak tersedia. Pilih dan salin teks laporan di bawah, lalu kirim ke PIC/dev. Belum dikirim ke server.');
    }
  }

  function openWhatsApp() {
    if (!whatsAppNumber || !actual.trim()) return;
    const text = prepareReport();
    const chat = new URL(`https://wa.me/${whatsAppNumber}`);
    chat.searchParams.set('text', text);
    setReport(text);
    // Keep long, heavily encoded reports available for manual copy instead of risking a truncated link.
    if (chat.href.length > 7500) {
      setNotice('Laporan terlalu panjang untuk tautan WhatsApp. Salin teks di bawah dan kirim ke PIC.');
      return;
    }
    window.open(chat.href, '_blank', 'noopener,noreferrer');
    setNotice('Periksa draf di WhatsApp, lalu tekan Kirim di sana. Jika WhatsApp tidak terbuka, salin teks di bawah.');
  }
  return <>
    <button type="button" className={styles.helpButton} onClick={() => dialog.current?.showModal()}>Panduan uji</button>
    <dialog ref={dialog} className={styles.dialog} aria-labelledby="soft-launch-title">
      <div className={styles.dialogHeader}><div><p className={styles.eyebrow}>{plant ? `SOFT LAUNCH · ${plantPilotBatch}` : 'SOFT LAUNCH LAB'}</p><h2 id="soft-launch-title">Panduan uji & laporan kendala</h2></div><button type="button" className="btn btn-outline" onClick={() => dialog.current?.close()}>Tutup panduan</button></div>
      <p className={styles.callout}>Online, data asli, pengguna terbatas. Gunakan akun yang ditugaskan kepada Anda; jangan bagikan password di grup. Ini belum go-live penuh atau izin pelepasan lot.</p>
      <section><h3>{guide.title}</h3><p>{guide.text}</p>
        {plant ? <ol><li>Pastikan role dan site pada header benar.</li><li>Buka Input Harian Plant untuk mencatat pekerjaan aktual; simpan draft atau kirim ke SPV jika lengkap.</li><li>Di Permintaan & hasil Lab, pilih lot asli dan uji yang benar-benar akan dikerjakan.</li><li>Setelah Lab menerima, siapkan sampel; tandai dikirim hanya setelah serah terima fisik.</li><li>Pantau status dan hasil QA. SPV memeriksa catatan tim dan konflik pasangan lot berbukti.</li></ol>
          : <ol><li>Pastikan role dan site pada header benar.</li><li>Terima permintaan. Terima sampel fisik hanya setelah label, berat, dan kemasan diperiksa.</li><li>Analis membuka metode, mencatat waktu/kondisi nyata, lalu mengisi hitungan pengamatan.</li><li>QA yang independen memeriksa hasil dan toleransi; setujui analisis atau minta uji ulang.</li><li>Jika antrean kosong, periksa site, filter dan koneksi. Jangan membuat transaksi contoh agar antrean terisi.</li></ol>}
      </section>
      <section><h3>Fitur yang dapat diuji sekarang</h3><ul><li>Permintaan, serah terima sampel, Germinasi, empat metode Vigor dan RET, review QA, serta retest terkontrol.</li><li>Catatan uji rutin: Analis memilih lot tanpa request Plant, mengisi pengamatan nyata, lalu menyimpan draft. Setelah lengkap, tutup isian → Periksa sebelum kirim ke QA → konfirmasi → Kirim revisi ini ke QA. Revisi yang dikirim dikunci.</li><li>Referensi sampel: tekan Pilih label tercatat, cari nomor atau label, lalu cocokkan dengan label fisik. Daftar hanya untuk lot dan Lab ini; label draft belum diverifikasi. Jika belum ditemukan, gunakan Isi manual. Pilihan hanya mengisi referensi, bukan waktu atau hitungan. Referensi retest tetap memakai sampel semula.</li><li>QA membuka Catatan uji rutin untuk memeriksa hasil, bukan mengubah angka Analis. QA dapat menyetujui analisis jika toleransi terpenuhi atau meminta uji ulang dengan alasan. Analis membuat catatan uji ulang baru; hasil sebelumnya tetap tersimpan. Plant membaca hasil rutin yang sudah disetujui di bagian terpisah dari permintaan.</li><li>Form Germinasi dan Vigor rutin: isi tanaman/spesies, nama pelaksana, tanggal tanam, waktu first count, jenis abnormal dan catatan per subulangan. Tanggal tanam Vigor dipisah dari mulai perlakuan. QA mengisi nama pemeriksa. Unduh PDF atau Excel per pengujian, bukan semua form digabung. Status dan revisi ikut tercetak. RET tetap terpisah. Revalidation 1–3 memakai persetujuan manual Admin Lab melalui Catatan uji rutin. Disetujui QA bukan izin pelepasan lot.</li><li>Delapan form awal Plant, draft, review SPV, revisi dan laporan harian di web Plant.</li><li>Histori Excel baca-saja; bukan hasil operasional yang otomatis approved.</li><li>Verifikasi konflik pasangan lot oleh SPV pada web Plant.</li></ul></section>
      {!plant && <section><h3>MC Lab mandiri</h3><p>Buka MC Lab, pilih lot dan label sampel, lalu catat 3 pembacaan persen, tanggal/jam sampel tersedia dan pengukuran, petugas, alat/metode serta catatan. Simpan dahulu, tutup isian lalu kirim revisi tersimpan ke QA; setelah dikirim isian dikunci. QA independen mengisi nama pemeriksa, memverifikasi catatan atau mengembalikan dengan alasan. Koreksi disimpan sebagai revisi baru sebelum dikirim lagi; revisi lama tetap tersimpan. Rata-rata muncul jika ketiga angka lengkap. Unduh PDF/Excel per catatan sesuai status terbaru. MC Lab tidak menyalin atau menimpa MC PI/Plant. Verifikasi catatan bukan keputusan toleransi/lulus-gagal atau pelepasan lot. Batas 32% gleondong Plant tidak dipakai sebagai batas MC Lab.</p></section>}
      {!plant && <section><h3>Unduh form RET rutin</h3><p>Di Catatan uji rutin, buka catatan RET tersimpan lalu pilih Unduh form PDF atau Excel. Satu pengujian menjadi satu form RET, terpisah dari Germinasi dan Vigor biasa. Form memuat4 ulangan×100, radikula minimal2 mm, waktu penempatan16°C dan pengamatan final, serta hasil/toleransi dari analisis tersimpan. Draft belum menerbitkan hasil atau persetujuan. Nama analis/QA yang belum dicatat tidak dibuat otomatis; ID akun tetap ditampilkan. Simpan perubahan dahulu dan muat ulang jika revisi berubah. Ini cetakan RET rutin; bukan cetakan permintaan Plant atau pelepasan lot.</p></section>}
      <section><h3>TSW rinci dari PI</h3><p>PI berizin dapat memilih timbang langsung 1.000 benih atau 8 ulangan× 100 benih, sebelum simpan pertama. Untuk8× 100, isi gram tiap ulangan;800 benih ditimbang lalu hasil dikonversi per 1.000 benih. Server menghitung rata-rata, CV populasi dan kernel/kg. Jika belum lengkap atau CV melewati acuan 4% pada file, TSW/kernel belum diterbitkan. Draft boleh dicicil; setelah dikirim ke SPV sumber terkunci. Lab hanya membaca sumber terkait permintaannya. Unduh TSW PDF atau Excel dari satu catatan tersimpan, terpisah dari form lain. Status sumber dan versi ikut dicetak; jika versi berubah, muat ulang. Pada timbang langsung, delapan bacaan/CV/kernel yang tidak dicatat tetap kosong. Pemeriksa ditampilkan dengan ID akun; nama belum dicatat, bukan tanda tangan. Acuan CV file bukan spesifikasi mutu baru atau pelepasan lot. Input tetap memerlukan assignment PI terpisah. Akun Bagaskara yang ditunjuk owner sudah ditugaskan khusus PRASAD; Operator/SPV tidak otomatis PI.</p></section>
      {!plant && <section><h3>Form Germinasi dan Vigor permintaan Plant</h3><p>Di Antrean &amp; hasil uji, buka Germinasi atau metode Vigor, lalu pilih Unduh Germinasi/Vigor PDF atau Excel. Satu file per percobaan, bukan semua metode digabung. Percobaan lama dapat diunduh dari riwayatnya. Jumlah benih mengikuti sumber: catatan lama 2×50 tetap 2×50, tidak diubah menjadi 2×100 atau dipecah menjadi subulangan. First count yang ada dicetak terpisah. Fresh/hard, jenis abnormal, nama, tanggal tanam dan rincian yang belum dicatat tetap kosong. Untuk pengamatan Germinasi baru, buka Buka pengamatan & petugas: isi tanggal pekerjaan nyata, nama Analis, first/final, fresh, hard, jenis abnormal dan catatan. Simpan dahulu lalu kirim revisi tersimpan ke QA; QA mencatat nama pemeriksa. Waktu tindakan aplikasi tetap terpisah. Catatan lama tanpa rincian tidak diisi ulang otomatis. Cetakan tidak mengubah hasil atau QA.</p></section>}
      {!plant && <section><h3>Uji ulang Germinasi dari permintaan Plant</h3><p>QA memilih Minta uji ulang dan wajib mengisi alasan. Analis membuka pengujian yang berstatus Perlu uji ulang, mencocokkan sampel yang sama masih tersedia di Lab, lalu memilih Mulai uji ulang Germinasi. Percobaan baru memakai 2×100 benih dengan isian kosong, bukan menyalin angka lama. Hanya Analis yang memulai percobaan itu dapat mengisi finalnya. QA independen memeriksa kembali; toleransi yang belum tersedia atau terlampaui menahan approval. Hasil, alasan QA dan cetakan sebelumnya tetap tersimpan. Jika sampel tidak tersedia, jangan konfirmasi; koordinasikan pengambilan/penerimaan sampel baru melalui alur resminya. Jangan membuka hasil approved sebagai uji ulang tanpa keputusan QA. Gunakan APK Lab 1.0.24+25 atau lebih baru; muat ulang bila percobaan/status berubah. Bukan pelepasan lot.</p></section>}
      {!plant && <section><h3>Form RET permintaan Plant</h3><p>Di Antrean &amp; hasil uji, buka bagian Vigor/RET pada permintaan, lalu pilih Unduh RET PDF atau Unduh RET Excel. Satu file untuk satu percobaan dengan nomor request, label sampel, pengiriman dan penerimaan terkait. Percobaan lama tetap dapat diunduh dari Riwayat percobaan sebelumnya. Uji yang masih berjalan belum punya hasil final. Jika status berubah, muat ulang dahulu. Nama/tanda tangan yang belum dicatat tidak dibuat otomatis. Cetakan tidak mengubah hasil, keputusan QA atau izin pelepasan lot.</p></section>}
      {!plant && <section><h3>Buku pengujian Lab</h3><p>Buka Buku pengujian Lab untuk mencari lot, hybrid, label, atau nomor uji. Saring asal catatan, metode, status dan rentang tanggal WIB, lalu tekan Tampilkan catatan. Dasar tanggal bisa pertama dicatat atau pengamatan final/ukur MC aktual. Ringkasan menghitung semua catatan yang cocok, bukan hanya halaman ini. Uji ulang tetap terpisah; verifikasi catatan MC tidak dihitung sebagai analisis disetujui QA. Bukan jumlah lot atau rata-rata mutu. Menu ini baca saja, tidak mengubah isian atau melepas lot. Histori Excel tetap di menu Histori. Setelah filter diterapkan, pilih Unduh rekap Excel. File memuat seluruh catatan yang cocok, bukan hanya 50 pada halaman ini. Maksimal 2000 catatan; persempit tanggal/filter jika lebih. Waktu pengambilan data terbaru dicetak di file. Draft, hasil QA dan uji ulang tetap dibedakan. Rekap bukan gabungan form atau izin pelepasan lot.</p></section>}
      <section className={styles.callout}><h3>Batas yang perlu diketahui</h3><ul><li>Input PI membutuhkan assignment PI yang sah. Penugasan PI diberikan terpisah; Operator/SPV tidak otomatis menjadi PI.</li><li>Registrasi lot baru/format kode QA, seluruh detail blueprint, dan operasi offline belum lengkap. Gunakan lot berizin yang tersedia; jangan memilih lot pengganti.</li><li>Germinasi rutin dapat memilih 2× 100 atau 4× 100 sebelum simpan pertama, default 2× 100. Toleransi mengikuti jumlah ulangan; setelah disimpan pilihan dikunci. Germinasi request Plant tetap 2× 100. Vigor lain 2× 100; RET radikula ≥2 mm, 4× 100, minimal 72 jam sejak penempatan pada 16°C.</li><li>Toleransi yang tidak tersedia (termasuk lookup 0/1/100) menahan approval. Jangan mengubah angka supaya lolos.</li><li>Draft tersimpan setelah server mengonfirmasi. Jangan menutup halaman saat perubahan belum tersimpan; ikuti prosedur resmi tim yang masih wajib selama soft launch.</li><li>Penugasan pilot diperpanjang sampai akhir 30 November 2026 WIB. Akun QA juga mendapat wewenang terbatas persetujuan Revalidation Lab, bukan admin modul lain. Di Catatan uji rutin, buka Revalidation 1–3 lalu Muat Revalidation. Admin memilih sumber approved, mengisi nama, alasan, rencana sampel dan rujukan. Analis mencocokkan sampel fisik serta waktu tersedia sebelum menyiapkan draft kosong. Tahap berikutnya menunggu QA tahap sebelumnya; uji ulang QA tetap tahap yang sama. Tidak ada jadwal otomatis atau angka lama yang disalin.</li></ul></section>
      <section><h3>Laporkan kendala</h3><p>Salah lot, hasil tidak sesuai, atau akses di luar role? Hentikan alur terkait dan laporkan P0. Jangan mengubah hasil approved. {whatsAppNumber ? 'Tulis apa yang terjadi untuk membuka draf WhatsApp. Jangan masukkan password, token, atau data pribadi.' : 'Form ini hanya menyiapkan teks; bukan tiket yang terkirim otomatis.'}</p>
        <form onSubmit={event => { event.preventDefault(); void copyReport(); }} onChange={() => { setNotice(''); setReport(''); }}>
          <div className={styles.grid}>
          {!plant && <>
            <label>Aplikasi yang bermasalah<select value={issueApp} onChange={e => setIssueApp(e.target.value)}><option>Web Lab</option><option>APK Lab</option></select></label>
            <label>Jenis kendala<select value={issueType} onChange={e => setIssueType(e.target.value)}>
              <option value="">Pilih jenis kendala</option>{labIssueTypes.map(type => <option key={type}>{type}</option>)}
            </select></label>
            <label>Fitur terkait<select value={issueFeature} onChange={e => setIssueFeature(e.target.value)}>
              <option value="">Pilih fitur (opsional)</option>{labIssueFeatures.map(feature => <option key={feature}>{feature}</option>)}
            </select></label>
          </>}
          <label>Prioritas kendala<select value={priority} onChange={e => setPriority(e.target.value)}>
            <option>{plant ? 'P2 - Pertanyaan / saran' : 'P2 - Kendala ringan / saran'}</option>
            {issuePriorities.map(option => <option key={option}>{option}</option>)}
          </select></label>
          {plant ? referenceFields : <details className={styles.issueReferences}>
            <summary>{lotReference || runReference ? 'Referensi lot/run · terisi' : 'Tambah referensi lot/run (opsional)'}</summary>
            <div className={styles.grid}>{referenceFields}</div>
          </details>}
          <label>Langkah sebelum kendala<textarea value={steps} onChange={e => setSteps(e.target.value)} maxLength={1000} /></label>
          <label>Hasil yang diharapkan<textarea value={expected} onChange={e => setExpected(e.target.value)} maxLength={1000} /></label>
          <label>Hasil yang terjadi<textarea value={actual} onChange={e => setActual(e.target.value)} maxLength={1000} /></label></div>
          <div className={styles.reportActions}>
            {whatsAppNumber && <button type="button" className="btn btn-primary" onClick={openWhatsApp} disabled={!actual.trim()}>Kirim via WhatsApp</button>}
            <button type="submit" className={whatsAppNumber ? 'btn btn-outline' : 'btn btn-primary'}>Salin laporan kendala</button>
          </div>
        </form>
        {notice && <p role="status" className={styles.notice}>{notice}</p>}
        {report && <label>Teks laporan (belum dikirim)<textarea readOnly value={report} rows={12} /></label>}
      </section>
    </dialog>
  </>;
}
