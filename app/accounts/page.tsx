'use client'
import {useCallback,useEffect,useState} from 'react'
import AppNav from '../../components/AppNav'
import {getSupabase} from '../../lib/supabase'
import {useWorkspace} from '../../lib/useWorkspace'

const money=(n:number)=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(n||0)
const typeLabel:any={cash:'Tunai',bank:'Bank',ewallet:'E-Wallet',wallet:'Dompet',other:'Lainnya'}

export default function Accounts(){
 const w=useWorkspace(); const [rows,setRows]=useState<any[]>([]); const [name,setName]=useState(''); const [type,setType]=useState('bank'); const [balance,setBalance]=useState('0'); const [msg,setMsg]=useState(''); const [loading,setLoading]=useState(true); const [error,setError]=useState('')
 const load=useCallback(async()=>{
   if(w.loading)return
   if(!w.family?.id){setLoading(false);setError('Workspace belum tersedia. Muat ulang halaman atau login kembali.');return}
   setLoading(true);setError('')
   try{
     const s=await getSupabase()
     let q=await s.from('accounts').select('*').eq('family_id',w.family.id).eq('is_active',true).order('created_at')
     if(q.error) throw q.error
     let data=q.data||[]
     if(data.length===0){
       const made=await s.rpc('ensure_default_account',{p_family_id:w.family.id})
       if(made.error) throw made.error
       q=await s.from('accounts').select('*').eq('family_id',w.family.id).eq('is_active',true).order('created_at')
       if(q.error) throw q.error
       data=q.data||[]
     }
     setRows(data)
   }catch(e:any){setRows([]);setError(e?.message||'Akun gagal dimuat. Silakan coba lagi.')}
   finally{setLoading(false)}
 },[w.loading,w.family?.id])
 useEffect(()=>{load()},[load])
 async function add(e:any){e.preventDefault();if(!w.family?.id||!w.user?.id)return;setMsg('Menyimpan…');try{const s=await getSupabase();const {error}=await s.from('accounts').insert({family_id:w.family.id,owner_user_id:w.user.id,name:name.trim(),type,opening_balance:Number(balance||0),current_balance:Number(balance||0)});if(error)throw error;setMsg('Akun berhasil ditambahkan.');setName('');setBalance('0');await load()}catch(e:any){setMsg(e?.message||'Gagal menambah akun.')}}
 if(w.loading)return <main className="splash">Memuat…</main>
 return <main className="walletPage innerPage">
  <header className="pageHeader"><a href="/app">‹</a><div><small>WALLET</small><h1>Akun</h1></div><span/></header>
  <section className="panel accountIntro"><div className="sectionHead"><div><small>SUMBER DANA</small><h2>Dompet & rekening</h2></div></div><p className="muted">Akun adalah tempat uang kamu disimpan: Tunai, rekening bank, atau e-wallet. Pilih akun ini saat mencatat pemasukan, pengeluaran, dan transfer.</p></section>
  <section className="accountBigGrid">
   {loading?<div className="emptyState"><div className="loadingDot">●</div><strong>Memuat akun…</strong><span>Sedang mengambil dompet dan rekening kamu.</span></div>:
    error?<div className="emptyState"><div>⚠️</div><strong>Akun belum dapat dimuat</strong><span>{error}</span><button className="primaryBtn" type="button" onClick={load}>Coba lagi</button></div>:
    rows.length?rows.map((a,i)=><article className={'accountBig c'+i%3} key={a.id}><small>{typeLabel[a.type]||a.type}</small><strong>{a.name}</strong><b>{money(Number(a.current_balance))}</b><span>Saldo tersedia</span></article>):
    <div className="emptyState"><div>💳</div><strong>Belum ada akun</strong><span>Tambahkan Tunai, bank, atau e-wallet untuk mulai mencatat transaksi.</span></div>}
  </section>
  {['owner','admin'].includes(w.role)&&<section className="panel"><div className="sectionHead"><div><small>AKUN BARU</small><h2>Tambah dompet / rekening</h2></div></div><form onSubmit={add}><label className="field"><span>Nama akun</span><input required value={name} onChange={e=>setName(e.target.value)} placeholder="BCA, Cash, GoPay..."/></label><label className="field"><span>Jenis</span><select value={type} onChange={e=>setType(e.target.value)}><option value="cash">Tunai / Cash</option><option value="bank">Bank</option><option value="ewallet">E-Wallet</option><option value="wallet">Dompet</option><option value="other">Lainnya</option></select></label><label className="field"><span>Saldo awal</span><input inputMode="numeric" value={balance} onChange={e=>setBalance(e.target.value.replace(/[^0-9]/g,''))}/></label><button className="primaryBtn">Tambah akun</button></form>{msg&&<p className="formMsg">{msg}</p>}</section>}
  <AppNav/>
 </main>
}
