<script lang="ts">
    let { open = $bindable(false) } = $props();
</script>

<main>
    <dialog {open} id="modal-about" class={open ? "" : "hidden"}>
        <article>
            <header>
                <h4>
                    <strong><i class="fas fa-info-circle"></i> About</strong>
                </h4>
            </header>

            <p>
                ...
            </p>
            <p>
                Developed by <a
                    href="https://ushift.tecnico.ulisboa.pt"
                    target="_blank">U-shift</a
                >, a research group from Instituto Superior Técnico, Lisboa,
                Portugal.
            </p>

            <p><a
                href="https://u-shift.github.io/GTFShift/"
                target="_blank"><i class="fa fa-book"></i> GTFShift R package documentation</a
            ></p>
            <p><a
                href="https://github.com/U-Shift/GTFShift/"
                target="_blank"><i class="fa fa-github"></i> GTFShift R package GitHub project</a
            ></p>
            <p><a
                href="https://github.com/U-Shift/GTFShift-web/"
                target="_blank"><i class="fa fa-github"></i> GTFShift web app GitHub project</a
            ></p>

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
