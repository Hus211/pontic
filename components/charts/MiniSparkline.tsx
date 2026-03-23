"use client";

import { LineChart, Line, ResponsiveContainer, Tooltip } from "recharts";

interface Props {
  data:   { value: number }[];
  color?: string;
  height?: number;
}

export default function MiniSparkline({
  data, color = "#3b82f6", height = 40
}: Props) {
  if (!data?.length) return null;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data}>
        <Line
          type="monotone"
          dataKey="value"
          stroke={color}
          strokeWidth={1.5}
          dot={false}
          isAnimationActive={false}
        />
        <Tooltip
          content={() => null}
          cursor={{ stroke: "#52525b", strokeWidth: 1 }}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
