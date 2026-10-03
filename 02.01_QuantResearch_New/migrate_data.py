"""
migrate_data.py — Copy existing data from the old 02_QuantResearch_VPEA project.

You do NOT need to re-run backtests. The old project's Data/ folder has
the same VP_Funnel_*.csv / VP_Trades_*.csv format that the new project uses.

This script copies (or symlinks) those files into the new project's Data/ folder.

Usage
-----
    # Copy all files (safe default — keeps both projects independent)
    python migrate_data.py

    # Copy only specific symbols
    python migrate_data.py --symbols XAUUSDm EURUSDm GBPUSDm

    # Symlink instead of copy (saves disk space, read-only)
    python migrate_data.py --symlink

    # Preview what would be copied
    python migrate_data.py --dry-run

After running, verify with:
    python data_collect.py --list
"""
import argparse
import shutil
import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).parent.resolve()
OLD_DATA_DIR = _PROJECT_ROOT.parent / "02_QuantResearch_VPEA" / "Data"
NEW_DATA_DIR = _PROJECT_ROOT / "Data"


def migrate(
    symbols: list[str] | None = None,
    symlink: bool = False,
    dry_run: bool = False,
) -> dict:
    """Copy or symlink CSVs from old Data/ to new Data/.

    Returns dict with 'copied', 'skipped', 'failed' counts.
    """
    if not OLD_DATA_DIR.exists():
        print(f"[ERROR] Old data directory not found: {OLD_DATA_DIR}")
        print("  Check that 02_QuantResearch_VPEA is in the expected location.")
        return {"copied": 0, "skipped": 0, "failed": 0}

    if not dry_run:
        NEW_DATA_DIR.mkdir(parents=True, exist_ok=True)

    old_files = sorted(OLD_DATA_DIR.glob("VP_*.csv"))
    if not old_files:
        print(f"[WARN] No VP_*.csv files found in {OLD_DATA_DIR}")
        return {"copied": 0, "skipped": 0, "failed": 0}

    # Filter by symbol if requested
    if symbols:
        filtered = []
        for f in old_files:
            # VP_Funnel_XAUUSDm_01.2026.csv → extract symbol
            rest = f.stem
            for kind in ("VP_Funnel_", "VP_Trades_"):
                if rest.startswith(kind):
                    rest = rest[len(kind):]
                    break
            sym = rest.rsplit("_", 1)[0] if "_" in rest else rest
            if sym in symbols:
                filtered.append(f)
        old_files = filtered

    mode = "DRY RUN" if dry_run else ("SYMLINK" if symlink else "COPY")
    print(f"{'=' * 60}")
    print(f"MIGRATE DATA [{mode}]")
    print(f"  From: {OLD_DATA_DIR}")
    print(f"  To  : {NEW_DATA_DIR}")
    print(f"  Files: {len(old_files)}")
    print(f"{'=' * 60}")

    copied = skipped = failed = 0

    for src in old_files:
        dst = NEW_DATA_DIR / src.name

        if dst.exists():
            skipped += 1
            continue

        if dry_run:
            print(f"  [WOULD] {src.name}")
            copied += 1
            continue

        try:
            if symlink:
                dst.symlink_to(src)
                print(f"  [LINK] {src.name}")
            else:
                shutil.copy2(src, dst)
                print(f"  [COPY] {src.name}")
            copied += 1
        except Exception as e:
            print(f"  [ERR ] {src.name}: {e}")
            failed += 1

    print(f"\n  {'Would process' if dry_run else 'Done'}:")
    print(f"    {copied} {'would be copied' if dry_run else 'copied/linked'}")
    print(f"    {skipped} skipped (already exist)")
    if failed:
        print(f"    {failed} FAILED")

    return {"copied": copied, "skipped": skipped, "failed": failed}


def _summarise():
    """Print a quick summary of what's in both data directories."""
    def _count(d: Path, kind: str) -> int:
        return len(list(d.glob(f"{kind}_*.csv"))) if d.exists() else 0

    print(f"\nOld project Data/:")
    print(f"  {OLD_DATA_DIR}")
    print(f"  Funnel files : {_count(OLD_DATA_DIR, 'VP_Funnel')}")
    print(f"  Trades files : {_count(OLD_DATA_DIR, 'VP_Trades')}")

    print(f"\nNew project Data/:")
    print(f"  {NEW_DATA_DIR}")
    print(f"  Funnel files : {_count(NEW_DATA_DIR, 'VP_Funnel')}")
    print(f"  Trades files : {_count(NEW_DATA_DIR, 'VP_Trades')}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Copy data from 02_QuantResearch_VPEA/Data/ to new project.",
    )
    parser.add_argument("--symbols", nargs="+", default=None,
                        help="Only migrate these symbols (e.g. XAUUSDm EURUSDm).")
    parser.add_argument("--symlink", action="store_true",
                        help="Create symlinks instead of copies (saves disk space).")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without making any changes.")
    parser.add_argument("--status", action="store_true",
                        help="Show file counts in both data directories and exit.")
    args = parser.parse_args()

    if args.status:
        _summarise()
        sys.exit(0)

    migrate(
        symbols=args.symbols,
        symlink=args.symlink,
        dry_run=args.dry_run,
    )

    print()
    _summarise()
