import { Chart, type ChartProps } from "cdk8s";
import { Construct } from "constructs";
import { Podinfo } from "../../imports/podinfo";

export interface PodinfoProps {
  readonly name?: string;
  readonly image?: string;
  readonly replicas?: number;
}

export class PodinfoChart extends Chart {
  constructor(
    scope: Construct,
    id: string,
    props?: PodinfoProps,
    chartProps: ChartProps = {},
  ) {
    super(scope, id, chartProps);

    const finalProps = {
      name: "default",
      image: "ghcr.io/stefanprodan/podinfo:latest",
      replicas: 2,
      ...props,
    };

    const imageName = finalProps.image.split(":")[0];
    const imageTag = finalProps.image.split(":")[1] || "latest";

    new Podinfo(this, "podinfo", {
      helmFlags: ["--skip-tests"],
      releaseName: finalProps.name,
      values: {
        // We can override Helm values here programmatically
        ui: {
          message: "Hello from CDK8s + Kapp!",
          color: "#34577c",
        },
        replicaCount: finalProps.replicas,
        ingress: {
          enabled: true,
          annotations: {
            "traefik.ingress.kubernetes.io/router.middlewares":
              "default-stripprefix@kubernetescrd",
          },
          hosts: [
            {
              paths: [
                {
                  path: `/podinfo/${finalProps.name}`,
                  pathType: "ImplementationSpecific",
                },
              ],
            },
          ],
        },
        image: {
          repository: imageName,
          tag: imageTag,
        },
      },
    });
  }
}
