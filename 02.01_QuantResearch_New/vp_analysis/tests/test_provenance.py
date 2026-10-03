import pandas as pd
import pytest

from vp_analysis.core.provenance import (
    hash_dataframe,
    hash_dict,
    hash_file,
    hash_files,
    hash_string,
)


def test_hash_string_deterministic():
    assert hash_string("hello") == hash_string("hello")
    assert hash_string("hello") != hash_string("world")
    assert hash_string("hello").startswith("sha256:")


def test_hash_dict_order_independent():
    assert hash_dict({"a": 1, "b": 2}) == hash_dict({"b": 2, "a": 1})


def test_hash_dict_different_values():
    assert hash_dict({"a": 1}) != hash_dict({"a": 2})


def test_hash_dict_handles_nan_deterministically():
    assert hash_dict({"x": float("nan")}) == hash_dict({"x": float("nan")})


def test_hash_dict_handles_inf():
    assert hash_dict({"x": float("inf")}) == hash_dict({"x": float("inf")})
    assert hash_dict({"x": float("inf")}) != hash_dict({"x": float("-inf")})


def test_hash_dict_nested_structures():
    a = {"x": {"y": [1, 2, 3]}}
    b = {"x": {"y": [1, 2, 3]}}
    assert hash_dict(a) == hash_dict(b)


def test_hash_dict_list_order_matters():
    assert hash_dict({"a": [1, 2]}) != hash_dict({"a": [2, 1]})


def test_hash_dataframe_deterministic():
    df1 = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})
    df2 = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})
    assert hash_dataframe(df1) == hash_dataframe(df2)


def test_hash_dataframe_detects_change():
    df1 = pd.DataFrame({"a": [1, 2, 3]})
    df2 = pd.DataFrame({"a": [1, 2, 4]})
    assert hash_dataframe(df1) != hash_dataframe(df2)


def test_hash_dataframe_excludes_columns():
    df1 = pd.DataFrame({"a": [1, 2], "meta": [10, 20]})
    df2 = pd.DataFrame({"a": [1, 2], "meta": [99, 99]})
    assert (
        hash_dataframe(df1, exclude_cols=["meta"])
        == hash_dataframe(df2, exclude_cols=["meta"])
    )


def test_hash_file(tmp_path):
    f = tmp_path / "test.txt"
    f.write_text("hello")
    h1 = hash_file(f)
    f.write_text("world")
    h2 = hash_file(f)
    assert h1 != h2
    assert h1.startswith("sha256:")


def test_hash_files_excludes_patterns(tmp_path):
    (tmp_path / "keep.py").write_text("a")
    (tmp_path / "skip.md").write_text("b")
    h1 = hash_files([tmp_path], exclude_patterns=["**/*.md"])
    (tmp_path / "skip.md").write_text("changed")
    h2 = hash_files([tmp_path], exclude_patterns=["**/*.md"])
    assert h1 == h2


def test_hash_files_detects_change(tmp_path):
    f = tmp_path / "code.py"
    f.write_text("v1")
    h1 = hash_files([tmp_path])
    f.write_text("v2")
    h2 = hash_files([tmp_path])
    assert h1 != h2
