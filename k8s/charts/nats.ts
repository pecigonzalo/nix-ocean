import { Chart, type ChartProps } from "cdk8s";
import { Construct } from "constructs";
import { Natsoperator } from "../../imports/nats-operator";

export interface NatsoperatorProps {
  readonly name: string;
  readonly cluster?: {
    create?: boolean;
  };
}

export class NatsoperatorChart extends Chart {
  constructor(
    scope: Construct,
    id: string,
    props?: NatsoperatorProps,
    chartProps: ChartProps = {},
  ) {
    super(scope, id, chartProps);

    const finalProps = {
      name: "default",
      cluster: {
        create: false,
      },
      ...props,
    };

    new Natsoperator(this, "nats-operator", {
      helmFlags: ["--skip-tests", "--include-crds"],
      releaseName: finalProps.name,
      values: {
        cluster: {
          create: finalProps.cluster.create,
        },
      },
    });
  }
}
