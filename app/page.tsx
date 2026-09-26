'use client'
import {useEffect} from 'react'
import {useRouter} from 'next/navigation'
import {getSupabase} from '../lib/supabase'
export default function Home(){const r=useRouter();useEffect(()=>{const supabase=getSupabase();supabase.auth.getSession().then(({data})=>r.replace(data.session?'/app':'/login'))},[r]);return <main className="center"><div className="loader">iMersFinora</div></main>}
