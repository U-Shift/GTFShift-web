<script lang="ts">
    import type { StatisticsBundle } from "../types/GeoPrioritization";

    let {
        census_1,
        census_2,
        census_1_label,
        census_2_label,
    }: {
        census_1: StatisticsBundle;
        census_2?: StatisticsBundle;
        census_1_label?: string;
        census_2_label?: string;
    } = $props();
</script>

<main>
    <table class="table-census">
        <tbody>
            <tr>
                <th colspan={census_1_label && census_2_label ? 1 : 2}
                    ><b>Measures of Central Tendency and Spread</b></th
                >
                {#if census_1_label && census_2_label}
                    <th>{census_1_label}</th>
                    <th>{census_2_label}</th>
                {/if}
            </tr>
            <tr>
                <th>Mean</th>
                <td>{census_1.mean.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.mean.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>P5</th>
                <td>{census_1.p5.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.p5.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>P25</th>
                <td>{census_1.p25.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.p25.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>Median</th>
                <td>{census_1.median.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.median.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>P75</th>
                <td>{census_1.p75.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.p75.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>P95</th>
                <td>{census_1.p95.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.p95.toFixed(2)}</td>
                {/if}
            </tr>
            <tr>
                <th>Standard Deviation</th>
                <td>{census_1.sd.toFixed(2)}</td>
                {#if census_2}
                    <td>{census_2.sd.toFixed(2)}</td>
                {/if}
            </tr>
        </tbody>
    </table>
    {#if census_1_label}
        <small
            >Measures weighted by
            {census_1_label.toLowerCase()}
            {#if census_2_label}
                and {census_2_label.toLowerCase()}
            {/if}
        </small>
    {/if}
</main>

<style>
    .table-census {
        font-size: 0.75rem !important;
        margin-top: 1rem;
    }
    .table-census th,
    .table-census td {
        padding: 0.1rem !important;
        color: #6a6a6a !important;
    }
</style>
