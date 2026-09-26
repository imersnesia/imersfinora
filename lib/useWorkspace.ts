'use client'
import {useEffect,useState} from 'react'
import {useRouter} from 'next/navigation'
import {getSupabase} from './supabase'
export function useWorkspace(){
 const r=useRouter(); const [state,setState]=useState<any>({loading:true,user:null,family:null,role:null,error:null})
 useEffect(()=>{let alive=true;(async()=>{try{
   const s=await getSupabase(); const {data:{user},error:ue}=await s.auth.getUser(); if(ue)throw ue
   if(!user){r.replace('/login');return}
   const {data:ctx,error:ce}=await s.rpc('get_my_context'); if(ce)throw ce
   if(!ctx?.id)throw new Error('Data keluarga gagal disiapkan.')
   if(alive)setState({loading:false,user,family:{id:ctx.id,name:ctx.name,currency:ctx.currency||'IDR'},role:ctx.role||'member',error:null})
 }catch(e:any){console.error(e);if(alive)setState({loading:false,user:null,family:null,role:null,error:e?.message||'Data keluarga gagal disiapkan.'})}})();return()=>{alive=false}},[r])
 return state
}
