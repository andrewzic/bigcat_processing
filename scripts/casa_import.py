import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description="Process one or more FITS files."
    )

    parser.add_argument(
        "fitsfiles",
        nargs="+",  # one or more inputs
        help="Path(s) to FITS file(s)"
    )


    parser.add_argument(
       "--clobber",
       action="store_true",
       help="Overwrite existing files"
    )
    
    return parser.parse_args()

def import_uvfits(fitsfiles, clobber=True):

    try:
        from casatasks import importuvfits  # CASA 6
    except Exception:
        from tasks import importuvfits      # CASA 5

   msnames = []
   for fitsfile in fitsfiles:      
      msname = fitsfile.replace(".uvfits", ".ms")
      if os.path.exists(msname) and clobber:
         os.system('rm -rf {}'.format(msname))
      importuvfits(fitsfile=fitsfile, vis=msname)
      msnames.append(msname)
      
   return msnames



def main():
   args = parse_args()

   msnames = import_uvfits(args.fitsfiles, args.clobber)

if __name__ == "__main__":
   main()
   
   
