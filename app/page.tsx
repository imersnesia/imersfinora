'use client'
import {useEffect,useState} from 'react'
import {useRouter} from 'next/navigation'
import {getSupabase} from '../lib/supabase'
export default function Home(){const r=useRouter();const[error,setError]=useState('');useEffect(()=>{let alive=true;(async()=>{try{const supabase=await getSupabase();const{data}=await supabase.auth.getSession();if(alive)r.replace(data.session?'/app':'/login')}catch(err:any){if(alive)setError(err?.message||'Konfigurasi aplikasi belum siap.')}})();return()=>{alive=false}},[r]);return <main className="center"><div className={error?'error':'loader'}>{error||'iMersFinora'}</div></main>}
