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

            <main>
                <p>
                    <b>GTFShift</b> is an R package to assist in bus lane implementation
                    prioritization.
                </p>
                <p>
                    It provides a comprehensive bundle of methods that cover
                    several dimensions of this problem, namely bus frequency,
                    infrastcructure availability, traffic conditions and network
                    continuity. Together, these can be used to identify road
                    segments where bus lanes should be implemented, enabling for
                    a transparent and data-driven decision-making process,
                    suitable to different contexts and criteria.
                </p>
                <p>
                    This interactive dashboard presents the results of its
                    application for some case studies, aiming to illustrate its
                    potential and capabilities to a non-technical audience,
                    while disseminating the outputs of these real world
                    scenarios. You can suggest new case studies or provide
                    feedback by creating a new issue on out GitHub.
                </p>
                <div class="grid">
                    <a
                        href="https://github.com/U-Shift/GTFShift-web/issues/new?template=new-region.yml"
                        target="_blank"
                    >
                        <button class="outline secondary" style="width: 100%;">
                            <i class="fa fa-globe"></i> Suggest a new region
                        </button>
                    </a>
                    <a
                        href="https://u-shift.github.io/GTFShift/"
                        target="_blank"
                        style="width: 100%;"
                    >
                        <button class="outline secondary" style="width: 100%;">
                            <i class="fa fa-book"></i> R package docs
                        </button>
                    </a>
                    <a
                        href="https://github.com/U-Shift/GTFShift-web/"
                        target="_blank"
                        style="width: 100%;"
                    >
                        <button class="outline secondary" style="width: 100%;">
                            <i class="fa fa-github"></i> Web app repository
                        </button>
                    </a>
                </div>
                <p style="margin-top: 1rem;">
                    Developed by <a
                        href="https://ushift.tecnico.ulisboa.pt"
                        target="_blank">U-Shift</a
                    >, a research group from Instituto Superior Técnico, Lisboa,
                    Portugal.
                </p>

                <a href="https://ushift.tecnico.ulisboa.pt" target="_blank" style="margin-top: 1rem;">
                    <img src="static/logo_acknowledgement.png" 
                        width="90%" 
                        alt="U-shift research group, Instituto Superiro Técnico, University of Lisbon, Portugal"
                    />
                </a>
            </main>

            <footer>
                <div role="group">
                    <button
                        class="secondary outline modal-close"
                        onclick={() => (open = false)}>Go back</button
                    >
                </div>
            </footer>
        </article>
    </dialog>
</main>
