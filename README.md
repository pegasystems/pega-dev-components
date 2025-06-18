# design-components

List of components available for Pega Platform Design Time.

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
