'use client'
import {useEffect} from 'react'
import {getSupabase} from '../lib/supabase'
export default function BrandingBoot(){useEffect(()=>{(async()=>{try{const s=await getSupabase();const {data}=await s.from('app_branding').select('pwa_icon_url').limit(1).maybeSingle();if(!data?.pwa_icon_url)return;let l=document.querySelector("link[rel='icon']") as HTMLLinkElement|null;if(!l){l=document.createElement('link');l.rel='icon';document.head.appendChild(l)}l.href=data.pwa_icon_url;let a=document.querySelector("link[rel='apple-touch-icon']") as HTMLLinkElement|null;if(!a){a=document.createElement('link');a.rel='apple-touch-icon';document.head.appendChild(a)}a.href=data.pwa_icon_url}catch{}})()},[]);return null}
