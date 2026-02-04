<script lang="ts">
    import type { StatisticsBundle } from "../types/GeoPrioritization";


    let {
        census,
    }: {
        census: StatisticsBundle;
    } = $props();
</script>

<main>
    <table class="table-census">
        <tbody>
            <tr>
                <th colspan="2"><b>Measures of Central Tendency and Spread</b></th>
            </tr>
            <tr>
                <th>Mean</th>
                <td>{census.mean.toFixed(2)}</td>
            </tr>
            <tr>
                <th>P25</th>
                <td>{census.p25.toFixed(2)}</td>
            </tr>
            <tr>
                <th>Median</th>
                <td>{census.median.toFixed(2)}</td>
            </tr>
            <tr>
                <th>P75</th>
                <td>{census.p75.toFixed(2)}</td>
            </tr>
            <tr>
                <th>Standard Deviation</th>
                <td>{census.sd.toFixed(2)}</td>
            </tr>
        </tbody>
    </table>
</main>

<style>
    .table-census {
        font-size: 0.75rem !important;
        margin-top: 1rem;
    }
    .table-census th,
    .table-census td {
        padding: 0.1rem !important;
        color: #6a6a6a!important;
    }
</style>
