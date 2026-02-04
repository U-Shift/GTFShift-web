<script lang="ts">
  import { untrack } from "svelte";
  import * as L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  import Dashboard from './Dashboard.svelte';

  import {MAP_DARK, MAP_LIGHT, MAP_INIT_ZOOM, MAP_INIT_CENTER} from './data';

  let map: L.Map | null = $state(null);
  let tileLayer: L.TileLayer | null = $state(null);
  let light_mode = $state(true);

  const createMap = (container: HTMLElement) => {
    let m = L.map(container, {
      zoomControl: false
    }).setView(MAP_INIT_CENTER, MAP_INIT_ZOOM);

    tileLayer = L.tileLayer(
      MAP_LIGHT,
      {
        attribution: `&copy;<a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>,
          &copy;<a href="https://carto.com/attributions" target="_blank">CARTO</a>`,
        maxZoom: 14
      }
    ).addTo(m);

    L.control.zoom({
        position: 'topright'
    }).addTo(m);

    return m;
  }

  const mapAction = (container: HTMLElement) => {
    map = createMap(container);
    return {
      destroy: () => {
        map?.remove();
      },
    };
  }

  // Subscribe to theme changes and swap tile layer
  $effect(() => {
    const tileUrl = light_mode ? MAP_LIGHT : MAP_DARK;
    untrack(() => {
        if (map && tileLayer) {
          map.removeLayer(tileLayer);
          tileLayer = L.tileLayer(tileUrl).addTo(map);
        }
      });
  });
</script>

<svelte:head>
   <!-- In the REPL you need to do this. In a normal Svelte app, use a CSS Rollup plugin and import it from the leaflet package. -->
   <link rel="stylesheet" href="https://unpkg.com/leaflet@1.6.0/dist/leaflet.css"
   integrity="sha512-xwE/Az9zrjBIphAcBb3F6JVqxf46+CDLwfLMHloNu6KEQCAWi6HcDUbeOfBIptF7tcCzusKFjFw2yuvEpDL9wQ=="
   crossorigin=""/>
</svelte:head>


<main>
  {#if map}
  <Dashboard {map} bind:light_mode />
  {/if}

  <div id="map" style="height:100vh;width:100vw" use:mapAction></div>

  <div id="logo">
      <img src="/static/logo_acknowledgement.png" width="100%" style="margin-right: 8px;" alt="U-shift research group, Instituto Superiro Técnico, University of Lisbon, Portugal" />
  </div>

</main>
