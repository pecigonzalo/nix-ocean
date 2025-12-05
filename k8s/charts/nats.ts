import { Chart, type ChartProps } from "cdk8s";
import { Construct } from "constructs";
import { Nats } from "../../imports/nats";

export interface NatsProps {
  readonly name?: string;
  readonly config?: {
    readonly cluster: { readonly enabled: boolean };
    readonly jetstream: { readonly enabled: boolean };
  };
}

export class NatsChart extends Chart {
  constructor(
    scope: Construct,
    id: string,
    props?: NatsProps,
    chartProps: ChartProps = {},
  ) {
    super(scope, id, chartProps);

    const p = {
      name: "default",
      config: {
        cluster: { enabled: true },
        jetstream: { enabled: true },
      },
      ...props,
    };

    new Nats(this, "nats-operator", {
      helmFlags: ["--skip-tests", "--include-crds"],
      releaseName: p.name,
      values: {
        config: {
          cluster: {
            enabled: p.config.cluster.enabled,
            replicas: 3,
          },
          jetstream: { enabled: p.config.jetstream.enabled },
        },
      },
    });
  }
}
