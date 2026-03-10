<script lang="ts">
	import { Select as SelectPrimitive } from "bits-ui";
	import { cn } from "$lib/utils.js";

	let {
		ref = $bindable(null),
		class: className,
		placeholder,
		...restProps
	}: any = $props();
</script>

<SelectPrimitive.Value
	bind:ref
	{placeholder}
	class={cn("data-[placeholder]:text-muted-foreground", className)}
	{...restProps}
/>
