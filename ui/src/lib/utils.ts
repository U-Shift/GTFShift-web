import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import type { GeoPrioritization } from "../types/GeoPrioritization";
import type { LineWeightMetric } from "../types/LineWeightMetric";

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChild<T> = T extends { child?: any } ? Omit<T, "child"> : T;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChildren<T> = T extends { children?: any } ? Omit<T, "children"> : T;
export type WithoutChildrenOrChild<T> = WithoutChildren<WithoutChild<T>>;
export type WithElementRef<T, U extends HTMLElement = HTMLElement> = T & { ref?: U | null };

/**
 * Interpolates a color from a gradient based on a value and a range.
 */
export function getColorFromGradient(
    value: number | string | undefined | null,
    min: number | string | undefined | null,
    max: number | string | undefined | null,
    gradient: string[],
) {
    if (!gradient || gradient.length === 0) return "#000000";
    if (gradient.length === 1) return gradient[0];

    const v = typeof value === "number" ? value : parseFloat(String(value));
    const mn = typeof min === "number" ? min : parseFloat(String(min));
    const mx = typeof max === "number" ? max : parseFloat(String(max));

    if (isNaN(v) || isNaN(mn) || isNaN(mx)) return gradient[0];
    if (mn === mx) return gradient[0];

    const percent = Math.min(Math.max((v - mn) / (mx - mn), 0), 1);
    const index = percent * (gradient.length - 1);
    const lowIndex = Math.floor(index);
    const highIndex = Math.ceil(index);
    const fraction = index - lowIndex;

    const hexToRgb = (hex: string) => {
        if (!hex || typeof hex !== "string" || hex[0] !== "#") return [0, 0, 0];
        const r = parseInt(hex.substring(1, 3), 16);
        const g = parseInt(hex.substring(3, 5), 16);
        const b = parseInt(hex.substring(5, 7), 16);
        return [isNaN(r) ? 0 : r, isNaN(g) ? 0 : g, isNaN(b) ? 0 : b];
    };

    const rgbToHex = (r: number, g: number, b: number) => {
        return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
    };

    const color1 = hexToRgb(gradient[lowIndex]);
    const color2 = hexToRgb(gradient[highIndex]);

    const r = Math.round(color1[0] + (color2[0] - color1[0]) * fraction);
    const g = Math.round(color1[1] + (color2[1] - color1[1]) * fraction);
    const b = Math.round(color1[2] + (color2[2] - color1[2]) * fraction);

    return rgbToHex(r, g, b);
}

export function getWayHourlyFrequency(
    wayProps:
        | {
              hour_frequency?: Record<string | number, number | string | undefined>;
          }
        | undefined,
    criteriaHour: number,
): number {
    const frequency = Number(wayProps?.hour_frequency?.[criteriaHour]);
    return Number.isNaN(frequency) ? 0 : frequency;
}

export function getFrequencyWeightedLineWidth(
    frequency: number | string | undefined | null,
    p5: number | string | undefined | null,
    p95: number | string | undefined | null,
    minWeight = 2.5,
    maxWeight = 7,
    fallbackWeight = 3.5,
    invert = false,
): number {
    const freq = Number(frequency);
    const minFreq = Number(p5);
    const maxFreq = Number(p95);

    if (Number.isNaN(freq) || Number.isNaN(minFreq) || Number.isNaN(maxFreq)) {
        return fallbackWeight;
    }
    if (maxFreq <= minFreq) return (minWeight + maxWeight) / 2;

    const ratio = (freq - minFreq) / (maxFreq - minFreq);
    const normalizedRatio = invert ? 1 - ratio : ratio;
    const clampedRatio = Math.max(0, Math.min(1, normalizedRatio));
    return minWeight + clampedRatio * (maxWeight - minWeight);
}

function toNumberOrUndefined(value: unknown): number | undefined {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? undefined : parsed;
}

export function getWayMetricValue(
    wayProps: Record<string, any> | undefined,
    criteriaHour: number,
    lineWeightBy: LineWeightMetric,
): number | undefined {
    if (lineWeightBy === "none") return undefined;
    if (lineWeightBy === "frequency") {
        return getWayHourlyFrequency(wayProps, criteriaHour);
    }
    if (lineWeightBy === "lanes") {
        return toNumberOrUndefined(wayProps?.n_lanes_circulation_direction);
    }
    if (lineWeightBy === "speed_min") {
        return toNumberOrUndefined(wayProps?.speed_avg);
    }
    if (lineWeightBy === "speed_max") {
        return toNumberOrUndefined(wayProps?.speed_avg);
    }
    if (lineWeightBy === "demand") {
        return toNumberOrUndefined(wayProps?.demand);
    }
    return undefined;
}

export function getLineWeight(
    geoData: GeoPrioritization,
    wayProps: Record<string, any> | undefined,
    criteriaHour: number,
    lineWeightBy: LineWeightMetric,
): number {
    if (lineWeightBy === "none") return 3.5;

    const value = getWayMetricValue(wayProps, criteriaHour, lineWeightBy);
    if (value === undefined) return 3.5;

    if (lineWeightBy === "frequency") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p5,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p95,
        );
    }
    if (lineWeightBy === "lanes") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.lanes_length?.p5,
            geoData.metadata.data_census.lanes_length?.p95,
        );
    }
    if (lineWeightBy === "speed_min") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.speed_avg_length?.p5,
            geoData.metadata.data_census.speed_avg_length?.p95,
            2.5,
            7,
            3.5,
            true,
        );
    }
    if (lineWeightBy === "speed_max") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.speed_avg_length?.p5,
            geoData.metadata.data_census.speed_avg_length?.p95,
        );
    }
    if (lineWeightBy === "demand") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.demand_length?.p5,
            geoData.metadata.data_census.demand_length?.p95,
        );
    }

    return 3.5;
}
