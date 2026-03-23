// Pontic — App Shell

"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { clsx } from "clsx";
import {
  BarChart2, Globe, TrendingUp, Activity, Zap
} from "lucide-react";

const NAV = [
  { href: "/",           label: "Regime",     icon: Zap       },
  { href: "/signals",    label: "Signals",    icon: Activity  },
  { href: "/indicators", label: "Indicators", icon: BarChart2 },
  { href: "/countries",  label: "Countries",  icon: Globe     },
  { href: "/markets",    label: "Markets",    icon: TrendingUp},
];

export default function Shell({ children }: { children: React.ReactNode }) {
  const path = usePathname();

  return (
    <div className="min-h-screen bg-[#09090b] flex flex-col">
      {/* Top nav */}
      <header className="border-b border-zinc-800 bg-[#09090b]/95 backdrop-blur sticky top-0 z-50">
        <div className="max-w-screen-xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-8">
            {/* Logo */}
            <Link href="/" className="flex items-center gap-2">
              <span className="text-blue-500 font-bold text-lg tracking-tight">PONTIC</span>
              <span className="text-zinc-600 text-xs font-mono mt-0.5">MACRO</span>
            </Link>
            {/* Nav links */}
            <nav className="flex items-center gap-1">
              {NAV.map(({ href, label, icon: Icon }) => (
                <Link
                  key={href}
                  href={href}
                  className={clsx(
                    "flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm transition-colors",
                    path === href
                      ? "bg-zinc-800 text-white"
                      : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50"
                  )}
                >
                  <Icon size={14} />
                  {label}
                </Link>
              ))}
            </nav>
          </div>
          {/* Status indicator */}
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            Live · 3min refresh
          </div>
        </div>
      </header>

      {/* Page content */}
      <main className="flex-1 max-w-screen-xl mx-auto w-full px-6 py-8">
        {children}
      </main>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-4 text-center text-xs text-zinc-600">
        Pontic · Global Macro Intelligence · Data: FRED, World Bank, OECD, ECB, BLS, Yahoo Finance
      </footer>
    </div>
  );
}
