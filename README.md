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

Each package can have multiple versions supporting different Pega Platform releases, with their respective binaries and documentation links.

## Homepage display settings

The homepage uses [`catalog-display.json`](catalog-display.json) to control visibility without changing the public catalog API in `index.json`. Hidden entries remain available through `index.json` and are still included in catalog verification.

Use `hiddenPackages` for package IDs and `hiddenVersions` for catalog entries. A hidden-version rule can match a component version (the `latestVersion` value), a Pega platform version, or both. The optional `package` field scopes a rule to one package; without it, the rule applies to all packages. Keep visibility entries in `catalog-display.json` so they have a single source of truth.

If a package has no versions left after filtering, its card is not shown. Remove an ID or version entry from `catalog-display.json` to show it again.
