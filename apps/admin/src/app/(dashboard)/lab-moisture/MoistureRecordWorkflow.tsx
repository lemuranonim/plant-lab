'use client';
import {useRef,useState} from 'react';
import {createClient} from '@/lib/supabase/client';
import {canonicalWritesEnabled,isolatedApiSchema} from '@/lib/supabase/config';
import type {MoistureDraft} from '@/lib/labMoisture';
import styles from '../lab-routine/routine.module.css';
import { MoistureSampleFacts } from './MoistureEvidence';

export default function MoistureRecordWorkflow({record,disabled,onChanged}:{record:MoistureDraft;disabled:boolean;onChanged:()=>void}){
 const [open,setOpen]=useState(false),[busy,setBusy]=useState(false),[confirmed,setConfirmed]=useState(false);
 const [name,setName]=useState(''),[note,setNote]=useState(''),[decision,setDecision]=useState<'VERIFY_RECORD'|'RETURN'>('VERIFY_RECORD');
 const [error,setError]=useState(''),[message,setMessage]=useState('');
 const action=useRef<{payload:string;id:string}|null>(null);
 const submit=record.can_submit===true,review=record.can_review===true;
 if(!canonicalWritesEnabled||(!submit&&!review))return null;
 async function execute(){
  if(busy||disabled||!confirmed||(!submit&&(!name.trim()||(decision==='RETURN'&&!note.trim()))))return;
  const args=submit?{p_draft_id:record.id,p_expected_revision:record.revision}:{p_draft_id:record.id,p_expected_revision:record.revision,p_submission_id:record.submission_id,p_decision:decision,p_reviewer_name:name.trim(),p_note:note.trim()||null};
  const payload=JSON.stringify(args);if(action.current?.payload!==payload)action.current={payload,id:crypto.randomUUID()};
  setBusy(true);setError('');setMessage('');
  try{
   const result=await createClient().schema(isolatedApiSchema).rpc(submit?'submit_lab_moisture_record':'review_lab_moisture_record',{...args,p_action_id:action.current.id});
   if(result.error){setError(['40001','PT409','55000'].includes(result.error.code)?'Catatan atau status sudah berubah. Muat ulang daftar; jangan kirim revisi lama.':'Belum berhasil. Periksa kelengkapan, nama petugas dan akses akun. Isian tetap ada.');return;}
   action.current=null;setOpen(false);setConfirmed(false);setMessage(submit?'Catatan dikirim ke QA. Revisi ini dikunci.':decision==='RETURN'?'Catatan dikembalikan ke Analis. Alasan perbaikan tersimpan.':'Catatan telah diverifikasi QA; bukan keputusan lulus/gagal.');onChanged();
  }catch{setError('Koneksi terputus. Coba lagi dengan isian sama untuk memastikan; jangan membuat catatan kedua.');}finally{setBusy(false);}
 }
 return <section className={styles.workflow} aria-label="Verifikasi catatan MC" data-testid="mc-record-workflow">
  {error&&<p role="alert">{error}</p>}{message&&<p role="status">{message}</p>}
  {!open?<button className="btn" disabled={disabled||busy} onClick={()=>{setOpen(true);setError('');setMessage('');}}>{submit?'Kirim catatan MC ke QA':'Verifikasi catatan MC'}</button>:<fieldset disabled={disabled||busy}>
   <legend>{submit?'Kirim catatan MC tersimpan':'Pemeriksaan catatan oleh QA'} · {record.lot_code} · revisi {record.revision}</legend>
   <MoistureSampleFacts content={record.content} compact/>
   {!submit&&<><label>Nama petugas QA yang memeriksa<input maxLength={120} value={name} onChange={e=>setName(e.target.value)}/></label><label>Keputusan catatan<select value={decision} onChange={e=>setDecision(e.target.value as 'VERIFY_RECORD'|'RETURN')}><option value="VERIFY_RECORD">Verifikasi catatan</option><option value="RETURN">Kembalikan untuk diperbaiki</option></select></label><label>{decision==='RETURN'?'Alasan perbaikan (wajib)':'Catatan QA (boleh kosong)'}<textarea maxLength={1000} value={note} onChange={e=>setNote(e.target.value)}/></label></>}
   <label className={styles.check}><input type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>{submit?'Saya sudah memeriksa revisi tersimpan. Setelah dikirim, isian dikunci.':'Saya sudah memeriksa catatan ini. Ini bukan keputusan mutu lulus/gagal.'}</label>
   {!submit&&<p>Verifikasi catatan bukan pelepasan lot.</p>}
   <div className={styles.actions}><button className="btn btn-primary" disabled={!confirmed||(!submit&&(!name.trim()||(decision==='RETURN'&&!note.trim())))} onClick={()=>void execute()}>{busy?'Menyimpan…':submit?'Ya, kirim revisi ini':decision==='RETURN'?'Kembalikan ke Analis':'Simpan verifikasi catatan'}</button><button className="btn" onClick={()=>setOpen(false)}>Batal</button></div>
  </fieldset>}
 </section>;
}
