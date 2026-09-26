'use client'
import {useEffect} from 'react'
import {useRouter} from 'next/navigation'
import {supabase} from '../lib/supabase'
export default function Home(){const r=useRouter();useEffect(()=>{supabase.auth.getSession().then(({data})=>r.replace(data.session?'/app':'/login'))},[r]);return <main className="center"><div className="loader">iMersFinora</div></main>}
