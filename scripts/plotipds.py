import numpy as np
import numpy.ma as ma
import matplotlib.pyplot as plt
from astropy.time import Time
import astropy.units as u
from astropy.coordinates import SkyCoord, EarthLocation, solar_system_ephemeris
import argparse

solar_system_ephemeris.set("de430")
atca_loc = EarthLocation.from_geocentric(-4750915.837, 2792906.182, -3200483.747, unit=u.m)

from atca_ds_tools import *


def main():
    parser = argparse.ArgumentParser(description="Plot ATCA dynamic spectra and light curves")
    parser.add_argument("src_name", help="Source name")
    parser.add_argument("src_coord", help="Source coordinates (not currently used downstream)")
    parser.add_argument("freqs", nargs="+", type=float, help="Frequencies in MHz")
    args = parser.parse_args()

    src_name = args.src_name
    src_coord = args.src_coord
    freqs = args.freqs

    if any([freq < 3000.0 for freq in freqs]):
        band = "L"
    elif any([freq < 16000.0 for freq in freqs]):
        band = "CX"
    elif any([freq < 24000.0 for freq in freqs]):
        band = "K"

    for freq in freqs:
        print(f"PLOTTING {src_name} FOR {freq} MHz")

        tfile = f"{src_name}.time.{freq}.npy"
        ffile = f"{src_name}.freq.{freq}.npy"
        XXfile = f"{src_name}.{freq}_dynamic_spectra_XX.npy"
        XYfile = f"{src_name}.{freq}_dynamic_spectra_XY.npy"
        YXfile = f"{src_name}.{freq}_dynamic_spectra_YX.npy"
        YYfile = f"{src_name}.{freq}_dynamic_spectra_YY.npy"

        t0, times, freqs_arr, dts, dt2, scan_start_indices, scan_end_indices = get_time_freq_atca(tfile, ffile)

        Times = Time(t0 + times * u.h, location=atca_loc)
        ltt_bary = Times.light_travel_time(SkyCoord(src_coord), ephemeris="jpl")
        Times_bary = Times + ltt_bary
        times = (Times_bary - Times_bary[0]).to(u.hour).value

        freqs_arr = freqs_arr / 1e3

        XX = np.load(XXfile, allow_pickle=True)
        YX = np.load(YXfile, allow_pickle=True)
        XY = np.load(XYfile, allow_pickle=True)
        YY = np.load(YYfile, allow_pickle=True)

        if XX.shape[0] < len(times):
            times = times[:XX.shape[0]]
            Times_bary = Times_bary[:XX.shape[0]]

        I, Q, U, V = form_stokes(XX, XY, YX, YY, band=band)
        iI, iQ, iU, iV = form_imag_stokes(XX, XY, YX, YY, band=band)

        np.savez(f"{src_name}.{freq}.IQUV_ds.npz",
                 time=(Times_bary.tdb).mjd, freq=freqs_arr, I=I, Q=Q, U=U, V=V)

        np.savez(f"{src_name}.{freq}.IQUV_lc.npz",
                 time=(Times_bary.tdb).mjd,
                 I=np.nanmean(I, axis=1),
                 Q=np.nanmean(Q, axis=1),
                 U=np.nanmean(U, axis=1),
                 V=np.nanmean(V, axis=1))

        I = average_stokes_ds(I, aT, aF)
        Q = average_stokes_ds(Q, aT, aF)
        U = average_stokes_ds(U, aT, aF)
        V = average_stokes_ds(V, aT, aF)

        times = average_time_freq(times, aT)
        freqs_arr = average_time_freq(freqs_arr, aF)

        fig, axes, im_list = plot_stokes_ds(I, Q, U, V, times, freqs_arr)
        fig.savefig(f"{src_name}.{freq}.IQUV_ds.png", bbox_inches='tight', dpi=300)
        fig.savefig(f"{src_name}.{freq}.IQUV_ds.pdf", bbox_inches='tight')
        plt.close()

        fig = plt.figure(figsize=(14, 5))
        I_lc = np.nanmean(I, axis=1)
        plt.plot(times, I_lc, '.')
        plt.xlabel("Time (h)")
        plt.ylabel("Flux density (Jy)")
        fig.savefig(f"{src_name}.{freq}.I_lc.png", bbox_inches="tight", dpi=300)
        fig.savefig(f"{src_name}.{freq}.I_lc.pdf", bbox_inches="tight")
        plt.close()


if __name__ == "__main__":
    main()
