import { App } from "cdk8s";
import { organizeK8sFiles } from "./lib/organize";
import { PodinfoChart } from "./charts/podinfo";
import { NatsChart } from "./charts/nats";

const OUTPUT_DIR = "./dist";
const app = new App({ outdir: OUTPUT_DIR });

new PodinfoChart(app, "podinfo");
new NatsChart(app, "nats-operator", {});

app.synth();
organizeK8sFiles(OUTPUT_DIR);
