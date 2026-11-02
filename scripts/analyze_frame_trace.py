"""Summarize bounded native timings without treating loading gaps as gameplay."""
import argparse
import csv
import statistics


def percentile(values, fraction):
    values = sorted(values)
    return values[min(len(values) - 1, int((len(values) - 1) * fraction))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace')
    args = parser.parse_args()
    with open(args.trace, encoding='utf-8', newline='') as stream:
        rows = list(csv.DictReader(stream))
    keys = ('gap_ms', 'update_ms', 'composite_ms', 'limiter_ms', 'swap_ms')
    print('gap = scripts + binding/GVL + other work between Graphics.update calls')
    print('composite/limiter/swap are portions of update_ms; do not sum them with update_ms')
    print('Windows exclude gaps or updates over 250 ms (loading/pauses); scene must be checked against trial log.')
    for offset in range(0, len(rows), 120):
        window = rows[offset:offset + 120]
        active = [row for row in window if float(row['gap_ms']) <= 250 and float(row['update_ms']) <= 250 and int(row['sample']) > 1]
        if not active:
            continue
        duration = [float(r['gap_ms']) + float(r['update_ms']) for r in active]
        print(f"\nsamples {window[0]['sample']}-{window[-1]['sample']}, "
              f"frame {window[0]['frame']}-{window[-1]['frame']}, "
              f"monotonic_s={float(window[0]['monotonic_ms']) / 1000:.3f}, "
              f"accepted={len(active)}/{len(window)}")
        print(f"interval median/p95/max = {statistics.median(duration):.2f}/"
              f"{percentile(duration, .95):.2f}/{max(duration):.2f} ms")
        for key in keys:
            data = [float(row[key]) for row in active]
            print(f"  {key}: mean={statistics.mean(data):.2f} p95={percentile(data, .95):.2f}")


if __name__ == '__main__':
    main()
