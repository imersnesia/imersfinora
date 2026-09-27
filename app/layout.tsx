import './globals.css'
import type {Metadata,Viewport} from 'next'
import PwaRegister from '../components/PwaRegister'
import ThemeBoot from '../components/ThemeBoot'
import BrandingBoot from '../components/BrandingBoot'
export const metadata:Metadata={title:'iMersFinora',description:'Personal & family finance PWA',manifest:'/api/manifest',icons:{icon:[{url:'/icons/icon-192.png',sizes:'192x192',type:'image/png'},{url:'/icons/icon-512.png',sizes:'512x512',type:'image/png'}],apple:'/icons/icon-192.png'}}
export const viewport:Viewport={themeColor:'#111827',width:'device-width',initialScale:1,viewportFit:'cover'}
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="id"><body><PwaRegister/><ThemeBoot/><BrandingBoot/>{children}</body></html>}
