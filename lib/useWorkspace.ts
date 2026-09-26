'use client'
import {useEffect,useState} from 'react'
import {useRouter} from 'next/navigation'
import {getSupabase} from './supabase'
export function useWorkspace(){
 const r=useRouter(); const [state,setState]=useState<any>({loading:true,user:null,family:null,role:null,error:null})
 useEffect(()=>{let alive=true;(async()=>{try{
   const s=await getSupabase(); const {data:{user},error:ue}=await s.auth.getUser(); if(ue)throw ue
   if(!user){r.replace('/login');return}
   const {data:familyId,error:be}=await s.rpc('bootstrap_my_workspace'); if(be)throw be
   if(!familyId)throw new Error('Data keluarga gagal disiapkan.')
   const [{data:f,error:fe},{data:m,error:me}]=await Promise.all([
     s.from('families').select('id,name,currency').eq('id',familyId).single(),
     s.from('family_members').select('role').eq('family_id',familyId).eq('user_id',user.id).single()
   ])
   if(fe)throw fe; if(me)throw me
   if(alive)setState({loading:false,user,family:f,role:m?.role||'member',error:null})
 }catch(e:any){console.error(e);if(alive)setState({loading:false,user:null,family:null,role:null,error:e?.message||'Data keluarga gagal disiapkan.'})}})();return()=>{alive=false}},[r])
 return state
}
