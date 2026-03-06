<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";

    let { open = $bindable(false) } = $props();
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[999] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel: same margins as the left sidebar -->
    <div
        class="fixed z-[1000] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden h-fit max-h-[calc(100vh-2rem)]"
        style="top: 1rem; left: calc(1rem + 350px + 0.5rem); right: 1rem;"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-4 border-b shrink-0"
        >
            <div>
                <h2 class="text-lg font-bold flex items-center gap-2">
                    <i class="fas fa-info-circle text-primary"></i>
                    About GTFShift
                </h2>
                <p class="text-sm text-muted-foreground mt-0.5">
                    R package and dashboard for bus lane implementation
                    prioritization.
                </p>
            </div>
            <Button
                variant="ghost"
                size="sm"
                onclick={() => (open = false)}
                class="h-8 w-8 p-0 shrink-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Content -->
        <div
            class="flex-1 overflow-y-auto px-5 py-4 space-y-4 text-sm leading-relaxed"
        >
            <p>
                <strong class="text-primary">GTFShift</strong> is an R package to
                assist in bus lane implementation prioritization.
            </p>
            <p>
                It provides a comprehensive bundle of methods that cover several
                dimensions of this problem, namely bus frequency, infrastructure
                availability, traffic conditions and network continuity.
                Together, these can be used to identify road segments where bus
                lanes should be implemented, enabling for a transparent and
                data-driven decision-making process, suitable to different
                contexts and criteria.
            </p>
            <p>
                This interactive dashboard presents the results of its
                application for some case studies, aiming to illustrate its
                potential and capabilities to a non-technical audience, while
                disseminating the outputs of these real world scenarios.
            </p>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
                <Button
                    variant="outline"
                    href="https://github.com/U-Shift/GTFShift-web/issues/new?template=new-region.yml"
                    target="_blank"
                    class="w-full justify-start"
                >
                    <i class="fa fa-globe mr-2"></i> Suggest a new region
                </Button>
                <Button
                    variant="outline"
                    href="https://u-shift.github.io/GTFShift/"
                    target="_blank"
                    class="w-full justify-start"
                >
                    <i class="fa fa-book mr-2"></i> R package docs
                </Button>
                <Button
                    variant="outline"
                    href="https://github.com/U-Shift/GTFShift-web/"
                    target="_blank"
                    class="w-full justify-start"
                >
                    <i class="fa fa-github mr-2"></i> Web app repository
                </Button>
            </div>

            <div class="pt-4 border-t">
                <h4 class="font-bold mb-2">Developers</h4>
                <div class="space-y-1">
                    <p class="flex items-center gap-2">
                        Gonçalo Matos
                        <span class="text-xs text-muted-foreground"
                            >(Author, Maintainer)</span
                        >
                        <a
                            href="https://orcid.org/0009-0001-3489-1732"
                            target="_blank"
                            class="text-[#A6CE39] hover:opacity-80"
                        >
                            <i class="fab fa-orcid"></i>
                        </a>
                    </p>
                    <p class="flex items-center gap-2">
                        Rosa Félix
                        <span class="text-xs text-muted-foreground"
                            >(Author)</span
                        >
                        <a
                            href="https://orcid.org/0000-0002-5642-6006"
                            target="_blank"
                            class="text-[#A6CE39] hover:opacity-80"
                        >
                            <i class="fab fa-orcid"></i>
                        </a>
                    </p>
                </div>
            </div>

            <div class="pt-4 border-t">
                <h4 class="font-bold mb-1">Acknowledgement</h4>
                <p class="mb-4">
                    Developed by <a
                        href="https://ushift.tecnico.ulisboa.pt"
                        target="_blank"
                        class="text-primary hover:underline">U-Shift</a
                    >, a research group from Instituto Superior Técnico, Lisboa,
                    Portugal.
                </p>
                <a
                    href="https://ushift.tecnico.ulisboa.pt"
                    target="_blank"
                    class="block w-48"
                >
                    <img
                        src="static/logo_acknowledgement.png"
                        alt="U-shift research group"
                        class="w-full object-contain"
                    />
                </a>
            </div>
        </div>

        <!-- Footer -->
        <div class="shrink-0 px-5 py-3 border-t flex justify-end">
            <Button variant="secondary" onclick={() => (open = false)}
                >Close</Button
            >
        </div>
    </div>
{/if}
