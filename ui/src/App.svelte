<script>
  import * as L from 'leaflet';
  // If you're playing with this in the Svelte REPL, import the CSS using the
  // syntax in svelte:head instead. For normal development, this is better.
  import 'leaflet/dist/leaflet.css';
  let map;

  function createMap(container) {
    let m = L.map(container, {
      zoomControl: false
    }).setView([38.7169, -9.1399], 3);

    L.tileLayer(
      'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
      {
        attribution: `&copy;<a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>,
          &copy;<a href="https://carto.com/attributions" target="_blank">CARTO</a>`,
        subdomains: 'abcd',
        maxZoom: 14
      }
    ).addTo(m);

    L.control.zoom({
        position: 'bottomright'
    }).addTo(m);

    return m;
  }

  function mapAction(container) {
    map = createMap(container);
    return {
      destroy: () => {
        map.remove();
      },
    };
  }
</script>

<svelte:head>
   <!-- In the REPL you need to do this. In a normal Svelte app, use a CSS Rollup plugin and import it from the leaflet package. -->
   <link rel="stylesheet" href="https://unpkg.com/leaflet@1.6.0/dist/leaflet.css"
   integrity="sha512-xwE/Az9zrjBIphAcBb3F6JVqxf46+CDLwfLMHloNu6KEQCAWi6HcDUbeOfBIptF7tcCzusKFjFw2yuvEpDL9wQ=="
   crossorigin=""/>
</svelte:head>

<main>
  <div style="height:100vh;width:100vw" use:mapAction></div>
</main>
