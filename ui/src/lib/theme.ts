import { writable } from 'svelte/store';

export const basemapTheme = writable<'light' | 'dark'>('light');

