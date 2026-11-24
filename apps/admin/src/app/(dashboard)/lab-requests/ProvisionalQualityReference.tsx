export type QualityReference = {
  crop_category_code: string;
  programme_code?: string;
  test_code: string;
  minimum_percent: number;
  version: number;
  validation_status: string;
  business_confirmation_status?: string;
  assessment?: string;
};

export type MethodContract = {
  method_code: string; method_name: string; replicate_count: number;
  seeds_per_replicate: number; minimum_radicle_mm: number | null;
  duration_days: number | null; operational_workflow_enabled: boolean;
};
export type ConfirmedLabContracts = {
  rules: QualityReference[]; methods: MethodContract[];
  lot_registration: { creation_event: string; automatic_code_generation_enabled: boolean };
};
const programmes = ['COMMERCIAL', 'PARENT_SEED'] as const;
const programmeLabel = (code?: string) => code === 'COMMERCIAL' ? 'Komersial'
  : code === 'PARENT_SEED' ? 'Parent Seed (PS)'
    : code === 'UNRESOLVED_EQUAL_LIMITS' ? 'Programme belum dipastikan; batas Germinasi sama' : '';

export function ProvisionalQualityReference({ contracts, vigourEnabled = false, retEnabled = false }: { contracts: ConfirmedLabContracts | null; vigourEnabled?: boolean; retEnabled?: boolean }) {
  const rules = contracts?.rules;
  const expected = new Set(programmes.flatMap(programme => ['FC', 'SWC'].flatMap(crop =>
    ['GERMINATION', 'VIGOUR'].map(test => `${programme}:${crop}:${test}`))));
  if (!Array.isArray(rules) || rules.length !== 8 || rules.some(rule =>
    !expected.delete(`${rule.programme_code}:${rule.crop_category_code}:${rule.test_code}`) ||
    rule.validation_status !== 'PENDING_CONTROLLED_SOP' || rule.business_confirmation_status !== 'USER_CONFIRMED' ||
    !Number.isFinite(rule.minimum_percent) || rule.minimum_percent < 0 || rule.minimum_percent > 100) || expected.size) {
    return <p role="alert">Acuan mutu belum bisa dimuat. Tidak menggunakan nilai tebakan.</p>;
  }
  return <details className="card" style={{ padding: 16, marginBottom: 16 }}>
    <summary>Acuan mutu FC / Sweet Corn · Angka dikonfirmasi tim</summary>
    <p>Konfirmasi 11 November 2026. Jenis jagung (FC/SWC) dan programme (komersial/PS) adalah dua klasifikasi terpisah.</p>
    {programmes.map(programme => <section key={programme}>
      <h3>{programmeLabel(programme)}</h3>
      <ul>{rules.filter(rule => rule.programme_code === programme).map(rule => <li key={rule.crop_category_code + rule.test_code}>
        {rule.crop_category_code} · {rule.test_code === 'GERMINATION' ? 'Germinasi' : 'Vigor'} ≥{rule.minimum_percent}% · versi {rule.version}
      </li>)}</ul>
    </section>)}
    <p>Programme lot yang belum pasti tidak diberi batas Vigor otomatis. Hasil approved lama tidak dievaluasi ulang.</p>
    <h3>Ketentuan input pengujian baru</h3>
    {Array.isArray(contracts?.methods) && contracts.methods.length === 6 ? <ul>
      {contracts.methods.map(method => <li key={method.method_code} style={{ overflowWrap: 'anywhere' }}>
        {method.method_name}: {method.replicate_count} × {method.seeds_per_replicate} benih
        {method.method_code === 'RET_16C_72H' && <> · radikula ≥{method.minimum_radicle_mm} mm · {method.duration_days} hari</>}
      </li>)}
    </ul> : <p role="alert">Ketentuan metode belum lengkap; jangan memakai nilai tebakan.</p>}
    <p>Germinasi baru: normal + abnormal + mati = 100 benih per ulangan, 2 ulangan. {vigourEnabled
      ? `Soak/Cold Test, AAT, SCT dan AAT Extend aktif: 2×100, pembulatan dan toleransi mengikuti Excel. ${retEnabled ? 'RET aktif: radikula ≥2 mm, 4×100, minimal 72 jam sejak penempatan pada 16°C, toleransi 4 Reps.' : 'RET belum tersedia pada klien ini.'}`
      : 'Kontrak Vigor dikonfirmasi; form hasil Vigor belum aktif. Perhitungan Vigor selain RET masih dicocokkan dengan Excel.'}</p>
    <h3>Pembuatan kode lot</h3>
    <p>Plant Officer membuat kode saat pertama masuk BIN, berdasarkan product spec QA. Format resmi belum tersedia; kode tidak dibuat otomatis.</p>
    <p>Acuan bisnis terkonfirmasi, belum menggantikan SOP/spesifikasi produk terkendali dan bukan izin pelepasan lot.</p>
  </details>;
}

export function ProvisionalResultSnapshot({ snapshot }: { snapshot?: QualityReference | null }) {
  if (!snapshot) return <p>Evaluasi terhadap acuan mutu belum tersedia pada hasil ini. Jangan menyimpulkan lulus spesifikasi dari status approval saja. Hasil lama tidak dievaluasi ulang.</p>;
  const assessment = snapshot.assessment === 'MEETS_PROVISIONAL_REFERENCE' ? 'Memenuhi acuan sementara'
    : snapshot.assessment === 'BELOW_PROVISIONAL_REFERENCE' ? 'Di bawah acuan sementara' : 'Evaluasi sementara belum tersedia';
  return <p>{assessment} · minimum {snapshot.minimum_percent}% · versi {snapshot.version}.
    {' '}{programmeLabel(snapshot.programme_code)}{' '}
    {' '}{snapshot.business_confirmation_status === 'USER_CONFIRMED' ? 'Angka dikonfirmasi tim' :
      snapshot.validation_status === 'PENDING_RESKI' ? 'Menunggu validasi Reski' : 'Status konfirmasi mengikuti snapshot sumber'};
    {' '}bukan izin pelepasan lot.</p>;
}
