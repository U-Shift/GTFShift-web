<script lang="ts">
    import { API_URL } from "../data";

    let gtfsUrl: string = "";
    let osmQueries: Array<{ key: string; value: string; key_exact?: boolean }> =
        [
            { key: "route", value: "bus" },
            { key: "network", value: "" },
        ];
    let referenceDate: string = "";
    let isLoading: boolean = false;

    export let onSubmit: (data: any) => void = () => {};
    export let onLoading: (loading: boolean) => void = () => {};

    const handleSubmit = async () => {
        if (!gtfsUrl || !referenceDate) {
            alert("Please fill in GTFS URL and Reference date");
            return;
        }

        // Filter out empty OSM queries
        const filteredOsmQueries = osmQueries
            .filter((q) => q.key && q.value)
            .map((q) => ({
                key: q.key,
                value: q.value,
                ...(q.key_exact && { key_exact: q.key_exact }),
            }));

        if (filteredOsmQueries.length === 0) {
            alert("Please add at least one OSM query");
            return;
        }

        const requestBody = {
            gtfs_url: gtfsUrl,
            osm_q: filteredOsmQueries,
            date: referenceDate,
        };

        isLoading = true;
        onLoading(true);

        try {
            console.log("Sending request to API:", requestBody);
            const response = await fetch(`${API_URL}/prioritize_lanes`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(requestBody),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(
                    errorData.message || `API error: ${response.status}`,
                );
            }

            const data = await response.json();
            console.log("API response:", data);
            onSubmit(data);
        } catch (error) {
            console.error("Error calling API:", error);
            alert(`Error: ${error instanceof Error ? error.message : String(error)}`);
        } finally {
            isLoading = false;
            onLoading(false);
        }
    };

    const addOsmQuery = () => {
        osmQueries = [...osmQueries, { key: "", value: "" }];
    };

    const removeOsmQuery = (index: number) => {
        osmQueries = osmQueries.filter((_, i) => i !== index);
    };

    const updateOsmQuery = (
        index: number,
        field: string,
        value: any,
    ) => {
        osmQueries[index] = { ...osmQueries[index], [field]: value };
    };
</script>

<div class="container-fluidtext-left">
    <h5 style="margin-bottom: 0.1rem;" class="text-primary">
        Compute with GTFShift API
    </h5>
    <p class="small text-primary">
        Use <a
            href="https://u-shift.github.io/GTFShift/index.html"
            target="_blank">GTFShift API</a
        > to compute data for a given GTFS
    </p>

    <p class="small text-secondary" style="margin: 0;">
        GTFS URL
    </p>
    <input
        type="text"
        name="gtfsUrl"
        placeholder="https://operator.com/gtfs.zip"
        aria-label="GTFS URL"
        bind:value={gtfsUrl}
        disabled={isLoading}
    />

    <p class="small text-secondary" style="margin: 0.75rem 0 0 0;">
        Overpass queries
    </p>
    <p class="small text-tertiary" style="margin: 0.25rem 0 0.5rem 0;">
        Add one or more OSM feature filters
    </p>

    {#each osmQueries as query, index (index)}
        <fieldset role="group" style="margin-bottom: 0.5rem;">
            <input
                type="text"
                placeholder="OSM key (e.g., route)"
                aria-label="OSM key"
                bind:value={query.key}
                on:change={() => updateOsmQuery(index, "key", query.key)}
                disabled={isLoading}
            />
            <input
                type="text"
                placeholder="OSM value (e.g., bus)"
                aria-label="OSM value"
                bind:value={query.value}
                on:change={() => updateOsmQuery(index, "value", query.value)}
                disabled={isLoading}
            />
            <button
                type="button"
                class="secondary outline"
                aria-label="Remove query"
                on:click={() => removeOsmQuery(index)}
                disabled={isLoading || osmQueries.length <= 1}
                style="padding: 0.5rem 1rem;"
            >
                <i class="fa-solid fa-trash"></i>
            </button>
        </fieldset>

        <div style="margin-bottom: 0.5rem;">
            <label for="key_exact_{index}" class="small text-secondary">
                <input
                    type="checkbox"
                    id="key_exact_{index}"
                    bind:checked={query.key_exact}
                    on:change={() =>
                        updateOsmQuery(index, "key_exact", query.key_exact)}
                    disabled={isLoading}
                />
                Exact key match
            </label>
        </div>
    {/each}

    <button
        type="button"
        class="secondary outline"
        on:click={addOsmQuery}
        disabled={isLoading}
        style="margin-bottom: 0.75rem;"
    >
        <i class="fa-solid fa-plus"></i> Add OSM query
    </button>

    <p class="small text-secondary" style="margin: 0;">
        Reference date
    </p>
    <input
        type="date"
        name="date"
        aria-label="Reference date"
        placeholder="YYYY-MM-DD"
        lang="en-GB"
        bind:value={referenceDate}
        disabled={isLoading}
    />

    <button
        type="button"
        class="primary"
        on:click={handleSubmit}
        disabled={isLoading}
        style="margin-top: 1rem;"
    >
        {#if isLoading}
            <i class="fa-solid fa-spinner fa-spin"></i> Computing...
        {:else}
            <i class="fa-solid fa-play"></i> Compute
        {/if}
    </button>
</div>
