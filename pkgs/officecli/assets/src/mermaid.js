import mermaid from "mermaid";
import layoutLoaders from "@mermaid-js/layout-elk";

// Mermaid's ELK loader is registered before the host initializes Mermaid.
mermaid.registerLayoutLoaders(layoutLoaders);
globalThis.officeCliMermaid = mermaid;
