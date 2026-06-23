#!/usr/bin/env python

import numpy as np
import argparse
from casacore.tables import table


def main():
    parser = argparse.ArgumentParser(description="Extract time and frequency columns from MS files")
    parser.add_argument("src_name", help="Source name")
    parser.add_argument("freqs", nargs="+", type=int, help="Frequencies (e.g. 5500 9000)")
    parser.add_argument("--ms-pattern", required=True,
                        help="MS path pattern, use {freq} and {src} placeholders (e.g. '../data/ds_tuc_a.{freq}.{src}.ms')")
    args = parser.parse_args()

    src_name = args.src_name

    for freq in args.freqs:
        ms = args.ms_pattern.format(freq=freq, src=src_name)

        t = table(ms)
        tf = table(f"{ms}/SPECTRAL_WINDOW")

        vis_time = t.getcol('TIME')

        times = []
        prev_time = -1.0
        for t_index in range(len(vis_time)):
            if vis_time[t_index] != prev_time:
                times.append(vis_time[t_index])
                prev_time = times[-1]

        np.array(times).dump(f"{src_name}.time.{freq}.npy")
        tf[0]["CHAN_FREQ"].dump(f"{src_name}.freq.{freq}.npy")


if __name__ == "__main__":
    main()
