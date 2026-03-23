import { SkeletonRegime, SkeletonTable } from "@/components/ui/LoadingSkeleton";

export default function Loading() {
  return (
    <div className="space-y-8">
      <div>
        <div className="w-48 h-7 bg-zinc-800 rounded animate-pulse mb-2" />
        <div className="w-80 h-4 bg-zinc-800 rounded animate-pulse" />
      </div>
      <SkeletonRegime />
      <div className="grid grid-cols-2 gap-3">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-lg p-4 animate-pulse">
            <div className="w-24 h-4 bg-zinc-800 rounded mb-1" />
            <div className="w-32 h-3 bg-zinc-800 rounded" />
          </div>
        ))}
      </div>
      <SkeletonTable />
    </div>
  );
}
