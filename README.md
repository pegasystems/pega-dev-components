# Pegasystems Development Components

This repository hosts the link to the latest version of development components used by the Pega Platform.

To view the list of components: [https://pegasystems.github.io/pega-dev-components](https://pegasystems.github.io/pega-dev-components/)

For API access, use : [https://pegasystems.github.io/pega-dev-components/index.json](https://pegasystems.github.io/pega-dev-components/index.json)

## index.json Schema

The [index.json](https://github.com/pegasystems/pega-dev-components/index.json) file contains information about available packages, their versions, and associated resources.

```json
{
  "packages": [
    // Array of package definitions
    {
      "name": "name", // Friendly name of the package to display to user
      "package": "package-name", // Name of the package - use dash for word separation - all lowercase (e.g., "blueprint-import")
      "versions": [
        // Array of available versions for this package
        {
          // Compatibility with Pega Platform version (e.g., "23.1.0" or "23.1")
          // For multi-version support, use a comma separated list like "8.8,23.1,...
          "platformVersion": "xx.x.x",
          "latestVersion": "x.x.x", // Latest version of this package (e.g., "1.0.1")
          "updateDate": "YYYY-MM-DD", // Date when package was last updated
          "binaries": [
            // Array of downloadable binary files - You should have at least one entry in the array
            {
              // Name of the binary ("MAIN" is required)
              // You can include other types of binaries with link if needed
              "name": "binary-name",
              "url": "binary-url" // URL to download the binary file
            }
          ],
          "documentation": [
            // Array of documentation resources
            {
              // Name of the documentation ("README" is required for documentation)
              // You can include other types of documentations and link if needed
              "name": "doc-name",
              "url": "doc-url" // URL to access the documentation - could be from this repo or from a different domain
            }
          ]
        }
      ]
    }
  ]
}
```

### AI Authoring Rules (`ai-authoring-rules`) — split version fields

The `ai-authoring-rules` package tracks each sub-component independently instead of using the shared `latestVersion` field. Its version entries use:

```json
{
  "platformVersion": "xx.x.x",
  "latestRulesVersion": "x.x.x",      // GenAI rules bundle version (primary artifact)
  "latestSkillVersion": "x.x.x",      // Skill component version
  "latestMcpVersion": "x.x.x",        // MCP component version
  "latestAutopilotVersion": "x.x.x",  // Autopilot component version
  "isAutopilotDependent": false,       // true when this release requires an Autopilot update
  "updateDate": "YYYY-MM-DD",
  "binaries": [ ... ]
}
```

Use `genai_release.sh` to release this component — it accepts per-sub-component version flags and manages `isAutopilotDependent` automatically.

Each package can have multiple versions supporting different Pega Platform releases, with their respective binaries and documentation links.
