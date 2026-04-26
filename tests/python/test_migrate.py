"""Unit tests for the Python migration engine (migration-code/migrate.py)."""

import copy
import json
import os

import pytest

from conftest import FIXTURES_DIR, PATCH_PATH

import migrate


LATEST_VERSION = "0.4.0"
LATEST_SCHEMA_SOURCE = (
    "https://raw.githubusercontent.com/nmr-samples/schema/main/versions/v0.4.0/schema.json"
)


def _load(name):
    with open(os.path.join(FIXTURES_DIR, name), "r") as f:
        return json.load(f)


def _migrate(data):
    return migrate.update_to_latest_schema(data, migrations_path=PATCH_PATH)


# ── Core DSL unit tests ─────────────────────────────────────────────────────


def test_set_creates_intermediate_dicts():
    data = {}
    migrate._apply_set(data, {"op": "set", "path": "/a/b/c", "value": 42})
    assert data == {"a": {"b": {"c": 42}}}


def test_set_wildcard_on_array_adds_field_to_every_element():
    data = {"items": [{"name": "a"}, {"name": "b"}, {"name": "c"}]}
    migrate._apply_set(data, {"op": "set", "path": "/items/*/flag", "value": None})
    assert data["items"] == [
        {"name": "a", "flag": None},
        {"name": "b", "flag": None},
        {"name": "c", "flag": None},
    ]


def test_set_wildcard_on_empty_array_is_noop():
    data = {"items": []}
    migrate._apply_set(data, {"op": "set", "path": "/items/*/flag", "value": None})
    assert data == {"items": []}


def test_set_wildcard_on_missing_key_is_noop():
    data = {}
    migrate._apply_set(data, {"op": "set", "path": "/items/*/flag", "value": None})
    assert data == {}


def test_rename_key_wildcard_renames_on_every_element():
    data = {"items": [{"Old": 1}, {"Old": 2}, {"Other": 3}]}
    migrate._apply_rename_key(
        data, {"op": "rename_key", "path": "/items/*/Old", "to": "new"}
    )
    assert data["items"] == [{"new": 1}, {"new": 2}, {"Other": 3}]


def test_map_wildcard_replaces_only_matching_values():
    data = {"items": [{"u": "equiv"}, {"u": "mM"}, {"u": "equiv"}]}
    migrate._apply_map(
        data, {"op": "map", "path": "/items/*/u", "from": "equiv", "to": ""}
    )
    assert data["items"] == [{"u": ""}, {"u": "mM"}, {"u": ""}]


def test_remove_wildcard_drops_key_from_each_element():
    data = {"items": [{"keep": 1, "drop": 2}, {"keep": 3, "drop": 4}]}
    migrate._apply_remove(data, {"op": "remove", "path": "/items/*/drop"})
    assert data["items"] == [{"keep": 1}, {"keep": 3}]


def test_move_relocates_value():
    data = {"old": {"k": 1}}
    migrate._apply_move(data, {"op": "move", "path": "/old", "to": "/new/inner"})
    assert data == {"new": {"inner": {"k": 1}}}


def test_parse_path_rejects_missing_leading_slash():
    with pytest.raises(ValueError):
        migrate._parse_path("no-leading-slash")


def test_parse_path_unescapes_pointer_syntax():
    assert migrate._parse_path("/a~1b/c~0d") == ["a/b", "c~d"]


# ── End-to-end migration tests ──────────────────────────────────────────────


def _assert_current(data):
    assert data["metadata"]["schema_version"] == LATEST_VERSION
    assert data["metadata"]["schema_source"] == LATEST_SCHEMA_SOURCE


def test_migrate_v002_multi_component_renames_every_key():
    data = _load("sample_v0.0.2_multi.json")
    _migrate(data)
    _assert_current(data)

    # top-level renames
    for old in ("Sample", "Buffer", "NMR Tube", "Laboratory Reference", "Notes", "Metadata", "Users"):
        assert old not in data
    assert "sample" in data and "buffer" in data and "nmr_tube" in data
    assert "people" in data and data["people"]["users"] == ["Alice", "Bob"]

    # per-component renames happen on ALL array entries
    comps = data["sample"]["components"]
    assert len(comps) == 3
    for c in comps:
        assert "Name" not in c and "Concentration" not in c and "Unit" not in c
        assert "Isotopic labelling" not in c
        assert "name" in c
        assert "concentration_or_amount" in c
        assert "unit" in c
        assert "isotopic_labelling" in c
        # v0.3.0 added molecular_weight; v0.4.0 added type
        assert "molecular_weight" in c
        assert "type" in c and c["type"] is None

    # equiv unit is stripped across every component
    units = [c["unit"] for c in comps]
    assert "equiv" not in units

    # diameter string gets mapped to number AND renamed to diameter_mm
    assert "diameter" not in data["nmr_tube"]
    assert data["nmr_tube"]["diameter_mm"] == 5.0


def test_migrate_v020_wildcard_map_and_set_hit_every_element():
    data = _load("sample_v0.2.0_multi.json")
    comps_before = copy.deepcopy(data["sample"]["components"])
    assert sum(1 for c in comps_before if c["unit"] == "equiv") == 2

    _migrate(data)
    _assert_current(data)

    comps = data["sample"]["components"]
    assert len(comps) == 3
    for c in comps:
        assert c["unit"] != "equiv"
        assert "molecular_weight" in c
        assert "type" in c and c["type"] is None


def test_migrate_v030_adds_type_to_every_component():
    data = _load("sample_v0.3.0_multi.json")
    _migrate(data)
    _assert_current(data)

    comps = data["sample"]["components"]
    assert len(comps) == 3
    for c in comps:
        assert "type" in c and c["type"] is None
        # existing fields are preserved
        assert "molecular_weight" in c
        assert "isotopic_labelling" in c


def test_migrate_empty_components_is_noop_for_wildcard_ops():
    data = _load("sample_v0.2.0_empty_components.json")
    _migrate(data)
    _assert_current(data)
    assert data["sample"]["components"] == []


def test_migrate_missing_components_is_silent_noop():
    data = _load("sample_v0.2.0_no_components.json")
    _migrate(data)
    _assert_current(data)
    # no components key should have been invented by wildcard set
    assert "components" not in data["sample"]


def test_migrate_already_current_is_noop():
    data = _load("sample_v0.4.0_already_current.json")
    before = copy.deepcopy(data)
    _migrate(data)
    assert data == before


def test_migrate_is_idempotent():
    data = _load("sample_v0.0.2_multi.json")
    _migrate(data)
    first = copy.deepcopy(data)
    _migrate(data)
    assert data == first


def test_migrate_preserves_19f_labelling():
    data = _load("sample_v0.4.0_already_current.json")
    _migrate(data)
    assert data["sample"]["components"][0]["isotopic_labelling"] == "19F"


def test_migrate_large_component_array():
    """Stress test: wildcard operations on a 50-element array."""
    data = {
        "sample": {
            "components": [
                {"Name": "c%d" % i, "Concentration": i, "Unit": "equiv" if i % 2 else "mM"}
                for i in range(50)
            ]
        },
        "metadata": {"schema_version": "0.0.2"},
    }
    _migrate(data)
    comps = data["sample"]["components"]
    assert len(comps) == 50
    for c in comps:
        assert "name" in c
        assert "concentration_or_amount" in c
        assert c["unit"] != "equiv"
        assert c["type"] is None
        assert "molecular_weight" in c
