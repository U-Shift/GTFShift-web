import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

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
    value: number,
    min: number,
    max: number,
    gradient: string[],
) {
    if (min === max) return gradient[0];
    const percent = Math.min(Math.max((value - min) / (max - min), 0), 1);
    const index = percent * (gradient.length - 1);
    const lowIndex = Math.floor(index);
    const highIndex = Math.ceil(index);
    const fraction = index - lowIndex;

    const hexToRgb = (hex: string) => {
        const r = parseInt(hex.substring(1, 3), 16);
        const g = parseInt(hex.substring(3, 5), 16);
        const b = parseInt(hex.substring(5, 7), 16);
        return [r, g, b];
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
