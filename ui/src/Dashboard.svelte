<svelte:head>
    <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/@picocss/pico/css/pico.min.css"
    />
    <script src="https://kit.fontawesome.com/17e93d90c5.js" crossorigin="anonymous"></script>
</svelte:head>

<style>
    @import "./dashboard.css";
</style>

<script>
    import { basemapTheme } from './lib/theme';
    
    export let map;

    const toggleTheme = () => {
        basemapTheme.update(t => t === 'light' ? 'dark' : 'light');
    };
</script>

<main id="controls-panel" class="overflow-auto">
    <div class="container-fluid" style="text-align: left;">
        <h3
            style="margin: 0; margin-bottom: 0.5rem; color: #363636; text-align: left;"
        >
            GTFShift
        </h3>
        <p class="small">
            Bus lane prioritization tool
        </p>
    </div>
    <div class="container-fluid" role="group">
        <button class="secondary outline" id="toggle-color" on:click={toggleTheme}>
            {@html $basemapTheme === 'light' ? '<i class="fa-solid fa-circle-half-stroke"></i> Dark mode' : '<i class="fa-solid fa-circle-half-stroke"></i> Light mode'}
        </button>
        <button class="secondary outline" id="toggle-detail"></button>
    </div>
</main>


