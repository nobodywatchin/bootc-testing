import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema("/modules/dnf-latest.json")
model RpmOstreeModuleLatest {
  ...RpmOstreeModuleV1;
}

@jsonSchema("/modules/dnf-v1.json")
model RpmOstreeModuleV1 {
  /** The dnf module offers pseudo-declarative package and repository management using dnf.
   * https://blue-build.org/reference/modules/dnf/
   */
  type: "dnf" | "dnf@v1" | "dnf@latest";

  /** List of links to .repo files to download into /etc/yum.repos.d/. */
  repos?: Array<string>;

  /** List of links to key files to import for installing from custom repositories. */
  keys?: Array<string>;

  /** List of folder names under /opt/ to enable for installing into. */
  optfix?: Array<string>;

  /** List of RPM packages to install. */
  install?: Array<string>;

  /** List of RPM packages to remove. */
  remove?: Array<string>;

  /** List of configurations for `dnf override replace`ing packages. */
  replace?: Array<{
    /** URL to the source COPR repo for the new packages. */
    `from-repo`: string;

    /** List of packages to replace using packages from the defined repo. */
    packages: Array<string>;
  }>;
}
