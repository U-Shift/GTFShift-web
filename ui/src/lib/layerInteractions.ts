import * as L from "leaflet";

const WAY_HOVER_STYLE: L.PathOptions = {
    color: "#FCF1DD",
    weight: 5,
};

export function bindWayValueTooltip(layer: L.Layer, label: string): void {
    const tooltipLayer = layer as L.Layer & {
        bindTooltip?: (content: string, options?: L.TooltipOptions) => unknown;
    };

    tooltipLayer.bindTooltip?.(label, {
        direction: "top",
        sticky: true,
        opacity: 1,
        className: "map-way-hover-tooltip",
        offset: L.point(0, -2),
    });
}

export function handleWayMouseOver(
    layer: L.Layer,
    wayId: string | undefined,
    selectedWayId: string | undefined,
): void {
    const tooltipLayer = layer as L.Layer & { openTooltip?: () => unknown };
    tooltipLayer.openTooltip?.();

    if (wayId && wayId !== selectedWayId) {
        const path = layer as L.Path;
        path.setStyle(WAY_HOVER_STYLE);
        path.bringToFront();
    }
}

export function handleWayMouseOut(
    layer: L.Layer,
    wayId: string | undefined,
    selectedWayId: string | undefined,
    getBaseStyle: (wayId: string) => L.PathOptions,
): void {
    const tooltipLayer = layer as L.Layer & { closeTooltip?: () => unknown };
    tooltipLayer.closeTooltip?.();

    if (wayId && wayId !== selectedWayId) {
        const path = layer as L.Path;
        path.setStyle(getBaseStyle(wayId));
    }
}