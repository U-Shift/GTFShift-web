<script lang="ts">
    import type { FeatureCollection } from "geojson";


    let {
        open,
        geoData,
        rt_data,
    }: {
        open: boolean;
        geoData: FeatureCollection | null;
        rt_data: boolean;
    } = $props();
</script>

<style>
    @media (min-width: 768px) {
        dialog > article {
            max-width: 95vw!important;
        }
    }
</style>


<main>
    <dialog {open} id="modal-about" class={open ? "" : "hidden"}>
        <article>
            <header>
                <h4>
                    <strong
                        ><i class="fas fa-code"></i> Details</strong
                    >
                </h4>
            </header>

            <footer>
                <div role="group">
                    <button
                        class="secondary outline modal-close"
                        on:click={() => (open = false)}>Go back</button
                    >
                </div>
            </footer>
        </article>
    </dialog>
</main>