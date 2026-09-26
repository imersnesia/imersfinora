'use client'
import {useEffect,useState} from 'react'
import {useRouter} from 'next/navigation'
import {getSupabase} from './supabase'
export function useWorkspace(){const r=useRouter();const [state,setState]=useState<any>({loading:true,user:null,family:null,role:null});useEffect(()=>{(async()=>{try{const s=await getSupabase();const {data:{user}}=await s.auth.getUser();if(!user){r.replace('/login');return}await s.rpc('bootstrap_my_workspace');const {data:m}=await s.from('family_members').select('family_id,role,families(id,name,currency)').eq('user_id',user.id).order('joined_at').limit(1).single();setState({loading:false,user,family:(m as any)?.families||null,role:m?.role||null})}catch(e){console.error(e);setState((x:any)=>({...x,loading:false,error:e}))}})()},[r]);return state}
