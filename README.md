# NMR Sample Schema

JSON schema definitions for standardising NMR sample metadata across different applications and workflows.

## Overview

This repository contains the authoritative schema definitions for recording metadata about NMR samples, including sample preparation details, experimental conditions, buffer composition, and measurement parameters. The schemas provide a structured, validated format for storing this information alongside experimental data.

## Purpose

Modern NMR experiments generate rich datasets, but associated information about sample preparation (e.g. buffer conditions, protein constructs, labelling schemes) is often recorded inconsistently. These schemas address this by providing:

- Standardised structure for recording sample metadata
- Validation to ensure completeness and consistency
- Version tracking so datasets remain interpretable as the schema evolves
- Interoperability across different tools and applications

## Schema Versions

Schemas are versioned using semantic versioning and tagged in this repository. Each dataset should record the schema version it was created with, ensuring backwards compatibility as the schema evolves.

The schema is currently in the 0.x phase, indicating that the domain model is still being refined through practical use. Breaking changes may occur during this exploratory period. A stable 1.0 release will follow once the model has been validated across multiple use cases.

## Accessing Schemas

Schemas are organised by version, with each version in its own directory:

```
v0.0.1/schema.json
v0.0.2/schema.json
v0.1.0/schema.json
current/schema.json
```

The `current` directory is a symbolic link to the latest tagged release.

To reference a specific schema version in your application:
```
https://github.com/waudbygroup/nmr-sample-schema/blob/main/versions/v0.1.0/schema.json
```

To always use the latest schema:
```
https://github.com/waudbygroup/nmr-sample-schema/blob/main/current/schema.json
```

## Applications

This schema is used by:

- [topspin-samples](https://github.com/waudbygroup/topspin-samples) - Topspin-integrated sample manager
- [nmr-samples](http://github.com/waudbygroup/nmr-samples) - Web-based sample manager, accessed at [waudbylab.org/nmr-samples](https://waudbylab.org/nmr-samples)

## Contributing

The schema is being developed through practical use in the Waudby laboratory at UCL School of Pharmacy. If you're using these schemas in your own work and have suggestions for improvements or extensions, please open an issue to discuss or contact [Chris](mailto:c.waudby@ucl.ac.uk) directly. We're especially interested in hearing from groups who might want to adopt or extend these schemas for their own workflows.
