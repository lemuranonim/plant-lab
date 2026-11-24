'use client';
import {previewTsw,tswNumber,tswState,type TswRaw} from '@/lib/piTsw';
import styles from '../plant-operations/operations.module.css';
export function TswSummary({raw,preview=false}:{raw:TswRaw;preview?:boolean}){
 return <div className={styles.guide}><strong>{preview?'Pratinjau timbangan; hasil simpan dihitung ulang server':'Rincian TSW tersimpan'}</strong><p>8 ulangan × 100 benih = 800 benih ditimbang. Hasil TSW dikonversi per 1.000 benih; bukan menimbang 1.000 benih langsung.</p>
 <p>{raw.entered_count}/8 timbangan · {tswState(raw.calculation_state)}</p><p>Rata-rata 100 benih: {tswNumber(raw.mean_100_g)} g · CV: {tswNumber(raw.cv_percent)}%<br/>TSW: {tswNumber(raw.tsw_g)} g per 1.000 benih<br/>Kernel/kg (hasil hitung): {tswNumber(raw.kernel_per_kg)}</p>
 {!preview&&<p>Berat per 100 benih (g): {raw.weights_g.map(x=>x===null?'belum dicatat':tswNumber(x)).join(' / ')}</p>}
 <p>CV memakai variance populasi (dibagi 8), mengikuti file acuan. Pemeriksaan memakai angka asli, bukan angka tampilan yang dibulatkan. Batas 4% adalah acuan hitung file, bukan spesifikasi mutu baru, approval Lab, atau pelepasan lot.</p></div>;
}
export default function TswWeights({weights,onChange}:{weights:(number|null)[];onChange:(weights:(number|null)[])=>void}){
 return <section><h3>Timbangan 8× 100 benih</h3><p>Masukkan gram hasil timbangan per 100 benih, bukan hasil TSW. Kosong berarti belum dicatat. Nol tetap nol dan perlu diperiksa, bukan diganti otomatis.</p><div className={styles.grid}>{weights.map((v,i)=><label key={i}>Ulangan {i+1} · berat 100 benih (g)<input type="number" min={0} max={100000} step="any" value={v??''} onChange={e=>onChange(weights.map((x,j)=>j===i?(e.target.value===''?null:Number(e.target.value)):x))}/></label>)}</div><TswSummary raw={previewTsw(weights)} preview/></section>;
}
