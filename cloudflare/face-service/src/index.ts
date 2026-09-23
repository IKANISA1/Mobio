import { Container } from "@cloudflare/containers";
import { type FaceEnv, handle } from "./handler.ts";
export class FaceContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "5m";
  enableInternet = false;
}
export default { fetch: handle } satisfies ExportedHandler<FaceEnv>;
