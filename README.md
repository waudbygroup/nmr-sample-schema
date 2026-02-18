# NMR Sample Schema

[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.17427433-blue)](https://doi.org/10.5281/zenodo.17427433)

JSON schema definitions for standardising NMR sample metadata across different applications and workflows.

## Overview

This repository contains the authoritative schema definitions for recording metadata about NMR samples, including sample preparation details, experimental conditions, buffer composition, and measurement parameters. The schemas provide a structured, validated format for storing this information alongside experimental data.

## Purpose

Modern NMR experiments generate rich datasets, but associated information about sample preparation (e.g. buffer conditions, protein constructs, labelling schemes) is often recorded inconsistently. These schemas address this by providing:

- Standardised structure for recording sample metadata
- Validation to ensure completeness and consistency
- Version tracking so datasets remain interpretable as the schema evolves
- Interoperability across different tools and applications

## Ecosystem

Currently, sample management is implemented by two applications:

- [topspin-samples](https://github.com/waudbygroup/topspin-samples) - An integrated sample manager for Topspin (v3 upwards)
- [nmr-samples](http://github.com/waudbygroup/nmr-samples) - A web-based sample manager, accessible at [waudbylab.org/nmr-samples](https://waudbylab.org/nmr-samples)

Support for sample information is integrated into [NOMAD](https://github.com/nomad-nmr) (v3.6.3 onwards).

Sample parsing is supported by [NMRTools.jl](https://github.com/waudbygroup/NMRTools.jl), and has been integrated into [NMR TITAN](https://www.nmr-titan.com) (development version).

## Schema Versions

Schemas are versioned using semantic versioning and tagged in this repository. Each dataset should record the schema version it was created with, ensuring backwards compatibility as the schema evolves.

The schema is currently in the 0.x phase, indicating that the domain model is still being refined through practical use. Breaking changes may occur during this exploratory period. A stable 1.0 release will follow once the model has been validated across multiple use cases.

## Accessing Schemas

Schemas are organised by version, with each version in its own directory:

```
versions/v0.0.1/schema.json
versions/v0.0.2/schema.json
versions/v0.0.3/schema.json
versions/v0.1.0/schema.json
current/schema.json
```

The `current` directory is a copy of the latest tagged release.

To reference a specific schema version in your application:
```
https://github.com/waudbygroup/nmr-sample-schema/blob/main/versions/v0.1.0/schema.json
```

To always use the latest schema:
```
https://github.com/waudbygroup/nmr-sample-schema/blob/main/current/schema.json
```

## Patching schema updates

The file `current/patch.json` contains methods to update files to the latest schema version. This is written in a simple json DSL:

```json
[
  {
    "from_version": "0.0.2",
    "operations": [
      {"op": "move", "path": "/Users", "to": "/people/users"}
    ]
  }
]
```

| Op | Fields | Behaviour |
|---|---|---|
| `set` | `path`, `value` | Set value at path. Creates intermediate objects if absent. |
| `remove` | `path` | Remove key at path. No-op if absent. |
| `rename_key` | `path`, `to` | Rename final key segment. No-op if key absent. Error if `to` already exists. |
| `map` | `path`, `from`, `to` | If value at path equals `from`, replace with `to`. Otherwise no-op. |
| `move` | `path`, `to` | Move value to a new path. Creates intermediates. No-op if absent |

Paths: JSON Pointer with `*` wildcard for array elements. Missing intermediate paths → no-op (except `set` which creates them).



## Changelog

### v0.1.0

**Breaking Changes:**
- Changed `sample.components[].concentration` to `concentration_or_amount` to better reflect that this field can represent either concentration or absolute amounts
- Changed `nmr_tube.diameter` from enum of specific string values ("1.7 mm", "3 mm", "5 mm") to a numeric field (type: number) with min/max validation (0.1-10 mm)
- Renamed `nmr_tube.samplejet_rack_id` to `nmr_tube.rack_id`
- Removed `nmr_tube.samplejet_rack_position` field

**New Features:**
- Added `sample.physical_form` field to specify physical state (solution, aligned, solid)
- Added `nmr_tube.sample_mass_mg` field for recording sample mass
- Added `nmr_tube.rotor_serial` field for solid-state NMR rotors
- Expanded `nmr_tube.type` enum to include rotor types: "zirconia rotor", "silicon nitride rotor", "sapphire rotor"
- Added units for absolute amounts in `sample.components[].unit`: "mg", "umol", "nmol"
- Enhanced `sample.components[].isotopic_labelling` options with deuteration patterns:
  - "2H,15N", "2H,Ile-δ1-13CH3", "2H,Leu/Val-13CH3", "2H,ILV-13CH3"
  - "2H,Met-13CH3", "2H,ILVM-13CH3", "2H,ILVA-13CH3", "2H,ILVMA-13CH3", "2H,ILVMAT-13CH3"
- Reorganized some isotopic labelling options (e.g., separated "Ile-δ1-13CH3,15N" and "ILV-13CH3,15N")

**Description Updates:**
- Updated `people.groups` description to clarify "Research groups (surnames)"
- Changed `nmr_tube` title from "NMR Tube" to "NMR Tube / Rotor"
- Updated `nmr_tube.diameter` description to include rotors
- Updated `nmr_tube.type` description to mention rotors
- Clarified `sample.components[].name` as "Molecule name"
- Improved `sample.components[].concentration_or_amount` description

**Migration Support:**
- Added migration tools in Python and Julia (see `migration-code/`)
- Added `current/patch.json` with automated migration rules
- See [Patching schema updates](#patching-schema-updates) section for migration details

## Contributing

The schema is being developed through practical use in the Waudby laboratory at UCL School of Pharmacy. If you're using these schemas in your own work and have suggestions for improvements or extensions, please open an issue to discuss or contact [Chris](mailto:c.waudby@ucl.ac.uk) directly. We're especially interested in hearing from groups who might want to adopt or extend these schemas for their own workflows.
