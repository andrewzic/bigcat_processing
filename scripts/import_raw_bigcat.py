
import os
import sys
import numpy as np
import argparse


# ------------------------------
# CASA 5 / CASA 6 compatibility
# ------------------------------
try:
    # CASA 6
    from casatools import table as tbtool, measures as metool, quanta as qatool
    tb = tbtool()
    me = metool()
    qa = qatool()
except ImportError:
    # CASA 5
    from taskinit import tb, me, qa


def hmsdms_to_rad(ra_str, dec_str):
    d = me.direction('J2000', ra_str, dec_str)
    return d['m0']['value'], d['m1']['value']


def ang_sep(ra1, dec1, ra2, dec2):
    dra = ra2 - ra1
    ddec = dec2 - dec1

    a = (
        np.sin(ddec/2)**2 +
        np.cos(dec1)*np.cos(dec2)*np.sin(dra/2)**2
    )
    return 2 * np.arcsin(np.sqrt(a))

# def ang_sep(ra1, dec1, ra2, dec2):
#     return np.arccos(
#         np.sin(dec1)*np.sin(dec2) +
#         np.cos(dec1)*np.cos(dec2)*np.cos(ra1-ra2)
#     )


def build_catalog(default_coords):
    cat = {}
    for name in default_coords:
        try:
            cat[name] = hmsdms_to_rad(*default_coords[name])
        except:
            print("Failed to parse", name)
    return cat


def parse_obsname(ms_path):
    """
    Extract '2026-04-28_1623_C3707' from path
    """
    # e.g. /.../2026-04-28_1623_C3707/raw.ms
    return os.path.basename(os.path.dirname(ms_path.replace(".ms/", ".ms"))) #ensure no trailing /


def make_uvfits_name(ms):
    if isinstance(ms, list):
        # Take first entry as reference
        first = parse_obsname(ms[0])
        parts = first.split("_")

        # Defensive in case format changes slightly
        if len(parts) >= 3:
            date = parts[0]
            proj = parts[-1]
            return "{}_combined_{}.uvfits".format(date, proj)
        else:
            return "combined.uvfits"

    else:
        base = parse_obsname(ms)
        return "{}.uvfits".format(base)



def fix_mislabeled_scans(msname, default_coords, tol_arcsec=30):

    print("---- Correcting mislabeled scans in %s ----" % msname)

    tb.open(msname + '/FIELD')
    names = tb.getcol('NAME')
    phase_dir = tb.getcol('PHASE_DIR')[:, 0, :].T
    tb.close()

    catalog = build_catalog(default_coords)
    tol = np.deg2rad(tol_arcsec / 3600.0)
    
    field_match = {}

    for fid in range(len(names)):
        # the real observed phase_dir direction
        ra, dec = phase_dir[fid]

        best_name = None
        best_sep = 1e9
        
        for cname in catalog:
            cra, cdec = catalog[cname]
            sep = ang_sep(ra, dec, cra, cdec)
            if sep < best_sep:
                best_sep = sep
                best_name = cname
                
        if best_sep < tol:
            field_match[fid] = best_name
        else:
            field_match[fid] = None

    print(field_match)
    
    tb.open(msname, nomodify=False)

    field_ids = tb.getcol('FIELD_ID')
    scans = tb.getcol('SCAN_NUMBER')

    unique_scans = np.unique(scans)

    changes = 0

    for scan in unique_scans:
        idx = np.where(scans == scan)[0]

        fid = field_ids[idx[0]]
        current_name = names[fid]
        true_name = field_match.get(fid)
        

        if true_name is None:
            continue

        if current_name != true_name:

            correct_fid = None
            for i in range(len(names)):
                if names[i] == true_name:
                    correct_fid = i
                    break

            if correct_fid is None:
                print("WARNING: no FIELD entry for %s" % true_name)
                continue

            print("Scan %d: %s -> %s" %
                  (scan, current_name, true_name))

            field_ids[idx] = correct_fid
            changes += 1

    tb.putcol('FIELD_ID', field_ids)
    tb.close()

    print("---- Done: %d scans fixed ----" % changes)



def main(ms):

    default_coords = {
        'J1424-6126': ('14h24m31.4s', '-61d26m10.8s'),
        '1353-63': ('13h55m46.61168s', '-63d26m42.5760s'),
        '0823-500': ('08h25m26.869s', '-50d10m38.49s'),
        '1646-50': ('16h50m16.635s', '-50d44m48.37s'),
        'J1627-5235': ('16h27m59.5s', '-52d35m04.3s'),
        '1714-336': ('17h17m36.0300s', '-33d42m08.764s'),
        'J1727-3431': ('17h27m55s', '-34d31m19s'),
        '1748-253': ('17h51m51.263047s', '-25d24m00.060610s'),
        'GCRTJ1745-3009': ('17h45m05.1s', '-30d09m56s'),
        'J1751-2551': ('17h51m54.89s', '-25d51m35.3s'),
        'J1755-2527': ('17h55m34.9s', '-25d27m49.1s'),
        '1819-096': ('18h22m28.7042s', '-09d38m56.835s'),
        'J1832-0911': ('18h32m48.45s', '-09d11m15.19s'),
        'J1839-10': ('18h39m02.0s', '-10d31m49.37s'),
        'j1919-4543': ('19h19m16.69217s', '-45d43m38.5770s'),
        'J1912-4410': ('19h12m13.72s', '-44d10m45.1s'),
        '1923+210': ('19h25m59.605370s', '+21d06m26.162180s'),
        'J1935+2145': ('19h35m05.1s', '+21d48m41.0s'),
        '1934-638': ('19h39m25.026s', '-63d42m45.63s'),
        'PKSB1934-638': ('19h39m25.02s', '-63d42m45.63s')
    }

    if isinstance(ms, str):
        mir_ms = ms.replace(".ms", ".mir.ms").replace("rawdata/", "data/")
        print(mir_ms)

        if not os.path.exists(os.path.dirname(mir_ms)):
            os.system('mkdir -p {}'.format(os.path.dirname(mir_ms)))

        # Combine 128 MHz spectral windows
        mstransform(
            vis=str(ms),
            combinespws=True,
            datacolumn="all",
            outputvis=str(mir_ms),
        )

        # Fix mislabeled scans BEFORE further processing
        fix_mislabeled_scans(mir_ms, default_coords)

        # Flag autocorrelations
        flagdata(
            vis=str(mir_ms),
            mode="manual",
            autocorr=True,
        )

        
        # Export to UVfits
        out_uvfits = make_uvfits_name(mir_ms)
        fitsfile = mir_ms.replace(".mir.ms", ".uvfits")
        exportuvfits(
            vis=str(mir_ms),
            fitsfile=str(out_uvfits),
            combinespw=True,
        )

    elif isinstance(ms, list):
        mslist = ms
        out_ms = []

        for ms in mslist:
            mir_ms = ms.replace(".ms", ".mir.ms").replace("rawdata/", "data/")
            out_ms.append(mir_ms)
            print(mir_ms)

            if not os.path.exists(os.path.dirname(mir_ms)):
                os.system('mkdir -p {}'.format(os.path.dirname(mir_ms)))

            # Combine 128 MHz spectral windows
            mstransform(
                vis=str(ms),
                combinespws=True,
                datacolumn="all",
                outputvis=str(mir_ms),
            )

            # Fix mislabeled scans for each MS before concat
            fix_mislabeled_scans(mir_ms, default_coords)

            # Flag autocorrelations
            flagdata(
                vis=str(mir_ms),
                mode="manual",
                autocorr=True,
            )

        obsdir = os.path.basename(os.path.dirname(out_ms[0]))
        concatvis_base = "/{}".format("/".join(os.path.dirname(out_ms[0]).split("/")[:-1]))
        out_uvfits = "/{}/{}".format(concatvis_base, make_uvfits_name(out_ms))
        concat_ms = "/{}".format(out_uvfits.replace(".uvfits", ".ms"))
        concatvis = "/{}/{}_combined_{}.mir.ms".format(
            concatvis_base,
            obsdir.split("_")[0],
            obsdir.split("_")[2]
        )
        print("concatenating {} to {}".format(out_ms, concat_ms))
        concat(vis=out_ms, concatvis=concat_ms)

        # Final safety pass after concat (important)
        #fix_mislabeled_scans(concatvis, default_coords)

        # Export to UVfits
        fitsfile = concatvis.replace(".mir.ms", ".uvfits")
        exportuvfits(
            vis=str(concat_ms),
            fitsfile=str(out_uvfits),
            combinespw=True,
        )

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process raw MS files (CASA 5/6 compatible)")
    parser.add_argument("ms", nargs="+", help="Input measurement set(s)")
    args = parser.parse_args()
    
    main(args.ms)
