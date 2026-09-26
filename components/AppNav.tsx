'use client'
import {usePathname} from 'next/navigation'
const items=[['/app','⌂','Home'],['/transactions','↕','Transaksi'],['/insights','◔','Insight'],['/settings/appearance','◎','Tema']]
export default function AppNav(){const p=usePathname();return <nav className="appNav" aria-label="Navigasi utama">{items.map(([href,icon,label])=><a key={href} href={href} className={p===href?'active':''}><b>{icon}</b><span>{label}</span></a>)}<a className="navFab" href="/transactions?new=1" aria-label="Tambah transaksi"><b>＋</b></a></nav>}
