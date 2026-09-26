'use client'
import {useEffect} from 'react'
export default function ThemeBoot(){useEffect(()=>{const id=localStorage.getItem('finora-theme')||'finora';document.documentElement.dataset.theme=id;const p=localStorage.getItem('finora-primary');if(p)document.documentElement.style.setProperty('--primary',p)},[]);return null}
