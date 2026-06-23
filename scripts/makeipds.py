#!/usr/bin/env python



import numpy as np
import argparse
from casacore.tables import table, taql

XX = 0
XY = 1
YX = 2
YY = 3

pols = ["XX", "XY", "YX", "YY"]


def main():
    parser = argparse.ArgumentParser(description="Create dynamic spectra from MS files")
    parser.add_argument("src_name", help="Source name")
    parser.add_argument("freqs", nargs="+", help="Frequencies (e.g. 5500 9000)")
    parser.add_argument("--ms-pattern", required=True,
                        help="MS path pattern, use {freq} and {src} (e.g. '../data/{src_name}.{freq}.ms')")
    args = parser.parse_args()

    src_name = args.src_name

    for freq in args.freqs:
        msname = args.ms_pattern.format(freq=freq, src=src_name)
        t = table(msname)
        ta = table(f"{msname}/ANTENNA")
        nant = len(ta)

        for pol in [XX, XY, YX, YY]:
            outfile = f"{src_name}.{freq}_dynamic_spectra_{pols[pol]}.npy"

            print(nant)

            waterfall = []
            nsub = 999999

            for ant1 in range(nant - 1):
                for ant2 in range(ant1 + 1, nant):
                    print(ant1, ant2)
                    t1 = taql("select * from $t where ANTENNA1 == $ant1 and ANTENNA2 == $ant2")
                    vis_data = t1.getcol("DATA")[:, :2048, pol]
                    nsub_bl = vis_data.shape[0]
                    if nsub_bl < nsub:
                        nsub = nsub_bl

            for ant1 in range(nant - 1):
                for ant2 in range(ant1 + 1, nant):
                    print(ant1, ant2)
                    t1 = taql("select * from $t where ANTENNA1 == $ant1 and ANTENNA2 == $ant2")
                    try:
                        vis_flag = t1.getcol("FLAG")[:nsub, :, pol]
                        vis_data = t1.getcol("DATA")[:nsub, :, pol]
                        print(f"Processing baseline {ant1}-{ant2}", vis_data.shape)
                        waterfall.append(np.ma.masked_where(vis_flag == True, vis_data))
                    except IndexError:
                        continue

            waterfall = np.ma.mean(waterfall, axis=0)
            waterfall.dump(outfile)

        t.close()


if __name__ == "__main__":
    main()
