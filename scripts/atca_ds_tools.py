import numpy as np
import numpy.ma as ma
import matplotlib.pyplot as plt
from astropy.time import Time
import astropy.units as u

def get_time_freq_atca(tfile, ffile, band = 'L'):
    """load in and format the time and frequency arrays output by getcols.py
    inputs:
    tfile=filename of time data file
    ffile=filename of frequency data file
    band=which ATCA observing band - required to know whether to flip frequency array or not
    outputs:
    t0:start time of observation, as an astropy.time.Time object
    t_data:time from observation start (t0) in hours
    f_data:frequencies of observation in MHz
    dts:time gaps between each integration and the previous one. required to know where calibrator scan breaks start
    dts2:similar to dt2, but for time gaps between each integation and the subsequent one. required to know where calibrator scan breaks end
    scan_start_indices: indices of t_data where an on-source scan starts
    scan_end_indices: indices of t_data where an on-source calibrator scan ends

    usage:

    t0, t_data, f_data, dts, dts2, scan_start_indices, scan_end_indices = get_time_freq_atca(tfile, ffile)
    """
    
    t_data = u.Quantity(np.load(tfile, allow_pickle = True)*u.s)
    t_data = t_data.to(u.hour).value
    #t_data = Time(t_data.value, format = 'mjd')
    #t_data /= 3600.0 #convert to hours

    f_data = np.load(ffile, allow_pickle = True)
    f_data /= 1.0e6 #convert to MHz
    f_data = f_data[1:] #cut off first element because f_data is 2049 elements long, should check if this is right...
    if band == 'L' or band == '16cm' or band == 16:
        f_data = np.flip(f_data, axis = 0) #reverse order of freqeuncy data
    
    t0 = Time(t_data[0]/24.0, format='mjd', scale='utc')
    tN = Time(t_data[-1]/24.0, format='mjd', scale='utc')
    #print(t0)
    t0.format='iso'
    tN.format='iso'

    print("Time range: %s - %s (%.1f s or %.1f h)" %(t0, tN, sorted(t_data)[-1]-sorted(t_data)[0], (sorted(t_data)[-1]-sorted(t_data)[0])/3600.0))

    
    t_data -= t_data[0] #relative time
    
    dts = [0]
    dts.extend([t_data[i] - t_data[i-1] for i in range(1, len(t_data))])
    dts = np.array(dts)
    scan_start_indices = np.where(np.abs(dts) > 0.0028)[0]
    s = [0]
    s.extend(list(scan_start_indices))
    scan_start_indices = np.array(s)
    dts2 = [t_data[i] - t_data[i+1] for i in range(0, len(t_data)-1)]
    scan_end_indices = list(np.where(np.abs(dts2) > 0.0028)[0])
    scan_end_indices.append(len(t_data)-1)
    scan_end_indices = np.array(scan_end_indices)
    
    
    
    return t0, t_data, f_data, dts, dts2, scan_start_indices, scan_end_indices

def get_ipol_data(XXfile, XYfile, YXfile, YYfile, times, dts, scan_start_indices = [0], scan_end_indices = [-1]):
    """
    get instrumental polarisation data for ATCA and reformat to include cal-scan breaks (how annoying...)
    inputs:
    XXfile (str): filename for XX instrumental pol.
    XYfile (str): filename for XY instrumental pol.
    YXfile (str): filename for YX instrumental pol.
    YYfile (str): filename for YY instrumental pol.
    times (numpy array): array of times returned by get_time_freq_atca
    freqs (numpy array): array of frequencies returned by get_time_freq_atca
    scan_start_indices (list or np array): time indices where target scans begin
    scan_end_indices (list or np array): time indices where target scans end
    dts (np array): time gap between successive integrations returned by get_time_freq_atca
    """
    XX = np.load(XXfile, allow_pickle = True)
    XY = np.load(XYfile, allow_pickle = True)
    YX = np.load(YXfile, allow_pickle = True)
    YY = np.load(YYfile, allow_pickle = True)

    ts_phasecal = (times[scan_start_indices[1:]] - times[scan_end_indices[:-1]])/np.median(dts[0:scan_end_indices[0]])

    nints_phasecal = (times[scan_start_indices[1:]] - times[scan_end_indices[:-1]])/np.nanmedian(dts[:scan_end_indices[1]])
    
    new_data_XX = np.zeros((1, XX.shape[1]))
    new_data_XY = np.zeros((1, XY.shape[1]))
    new_data_YX = np.zeros((1, YX.shape[1]))
    new_data_YY = np.zeros((1, YY.shape[1]))
    
    for start_index, end_index, nint in zip(scan_start_indices[:-1], scan_end_indices[:-1], nints_phasecal):
        XX_chunk = XX[start_index:end_index, :]
        XY_chunk = XY[start_index:end_index, :]
        YX_chunk = YX[start_index:end_index, :]
        YY_chunk = YY[start_index:end_index, :]
        nan_chunk = np.full((int(nint), XX.shape[1]), np.nan)
        #print(XX.shape, nan_chunk.shape, XX_chunk.shape)
        new_chunk_XX = np.vstack([XX_chunk, nan_chunk])
        new_chunk_XY = np.vstack([XY_chunk, nan_chunk])
        new_chunk_YX = np.vstack([YX_chunk, nan_chunk])
        new_chunk_YY = np.vstack([YY_chunk, nan_chunk])
        new_data_XX = np.vstack([new_data_XX, new_chunk_XX])
        new_data_XY = np.vstack([new_data_XY, new_chunk_XY])
        new_data_YX = np.vstack([new_data_YX, new_chunk_YX])
        new_data_YY = np.vstack([new_data_YY, new_chunk_YY])

        
    XX = ma.masked_invalid(new_data_XX[1:])
    XY = ma.masked_invalid(new_data_XY[1:])
    YX = ma.masked_invalid(new_data_YX[1:])
    YY = ma.masked_invalid(new_data_YY[1:])

    XX = ma.masked_where(XX == 0, XX)
    XY = ma.masked_where(XY == 0,  XY)
    YX = ma.masked_where(YX == 0, YX)
    YY = ma.masked_where(YY == 0, YY)

    return(XX, XY, YX, YY)

def get_ipol_data_simple(XXfile, XYfile, YXfile, YYfile):
    """
    get instrumental polarisation data for ATCA without reformatting to include cal-scan breaks
    inputs:
    XXfile (str): filename for XX instrumental pol.
    XYfile (str): filename for XY instrumental pol.
    YXfile (str): filename for YX instrumental pol.
    YYfile (str): filename for YY instrumental pol.
    """
    XX = np.load('uvceti.2100_dynamic_spectra_XX.npy', allow_pickle = True)
    XY = np.load('uvceti.2100_dynamic_spectra_XY.npy', allow_pickle = True)
    YX = np.load('uvceti.2100_dynamic_spectra_YX.npy', allow_pickle = True)
    YY = np.load('uvceti.2100_dynamic_spectra_YY.npy', allow_pickle = True)

        
    XX = ma.masked_invalid(XX)
    XY = ma.masked_invalid(XY)
    YX = ma.masked_invalid(YX)
    YY = ma.masked_invalid(YY)

    XX = ma.masked_where(XX == 0, XX)
    XY = ma.masked_where(XY == 0,  XY)
    YX = ma.masked_where(YX == 0, YX)
    YY = ma.masked_where(YY == 0, YY)

    return(XX, XY, YX, YY)

def form_stokes(XX, XY, YX, YY, band = 'L'):
    """
    form stokes parameters from supplied instrumental polarisations
    input:
    XX: array of complex XX instrumental polarisation data
    XY: array of complex XY instrumental polarisation data
    YX: array of complex YX instrumental polarisation data
    YY: array of complex YY instrumental polarisation data
    band (str or int, default = 'L'): specify if in L-band by entering 'L', '16cm', or 16. This will flip the direction of the frequency axis
    """
    
    if band == 'L' or band == '16cm' or band == 16:
        flip = True
    else:
        flip = False

    I = (XX + YY)/2.0
    Q = (XX - YY)/2.0
    U = (XY  + YX)/2.0
    V = 1j * ( XY - YX)/2.0
    
    if flip == True:
        I = np.flip(I[:, :], axis = 1)
        Q = np.flip(Q, axis = 1)
        U = np.flip(U, axis = 1)
        V = np.flip(V[:, :], axis = 1)
        
    return np.real(I), np.real(Q), np.real(U), np.real(V)

def form_imag_stokes(XX, XY, YX, YY, band = 'L'):
    """
    form stokes parameters from supplied instrumental polarisations
    input:
    XX: array of complex XX instrumental polarisation data
    XY: array of complex XY instrumental polarisation data
    YX: array of complex YX instrumental polarisation data
    YY: array of complex YY instrumental polarisation data
    band (str or int, default = 'L'): specify if in L-band by entering 'L', '16cm', or 16. This will flip the direction of the frequency axis
    """
    
    if band == 'L' or band == '16cm' or band == 16:
        flip = True
    else:
        flip = False

    I = (XX + YY)/2.0
    Q = (XX - YY)/2.0
    U = (XY  + YX)/2.0
    V = 1j * ( XY - YX)/2.0
    
    if flip == True:
        I = np.flip(I[:, :], axis = 1)
        Q = np.flip(Q, axis = 1)
        U = np.flip(U, axis = 1)
        V = np.flip(V[:, :], axis = 1)
        
    return np.imag(I), np.imag(Q), np.imag(U), np.imag(V)


def average_stokes_ds(arr, aT, aF):
    nT = arr.shape[0]
    nF = arr.shape[1]
    arr_ = arr.copy()
    if nT % aT != 0:
        print('padding')
        extra_t = np.nan*np.zeros((aT - nT%aT, nF))
        arr_ = np.concatenate((arr_, extra_t), axis = 0)
        nT = arr_.shape[0]
        #print(nT)
    if nF % aF != 0:
        print('padding')
        extra_f = np.nan*np.zeros((nT, aF - nF%aF))
        arr_ = np.concatenate((arr_, extra_f), axis = 1)
        nF = arr_.shape[1]
    arr_ = np.nanmean(arr_.reshape(nT//aT, aT, nF), axis = 1)
    arr_ = np.nanmean(arr_.reshape(nT//aT, nF//aF, aF), axis = 2)

    return arr_

def std_stokes_ds(arr, aT, aF):
    nT = arr.shape[0]
    nF = arr.shape[1]
    arr_ = arr.copy()
    if nT % aT != 0:
        extra_t = np.nan*np.zeros((aT - nT%aT, nF))
        arr_ = np.concatenate((arr_, extra_t), axis = 0)
        nT = arr_.shape[0]
    if nF % aF != 0:
        extra_f = np.nan*np.zeros((nT, aF - nF%aF))
        arr_ = np.concatenate((arr_, extra_f), axis = 1)
        nF = arr_.shape[1]
    arr_ = np.nanstd(arr_.reshape(nT//aT, aT, nF), axis = 1)/np.sqrt(aT)
    arr_ = np.nanstd(arr_.reshape(nT//aT, nF//aF, aF), axis = 2)/np.sqrt(aF)

    return arr_

def average_time_freq(arr, avg_factor):
    arr_ = arr.copy()
    nX = arr.shape[0]
    if nX % avg_factor != 0:
        extra_t = np.nan*np.zeros((avg_factor - nX%avg_factor))
        arr_ = np.concatenate((arr_, extra_t), axis = 0)
        nX = arr_.shape[0]
    
    return np.nanmean(arr_.reshape(nX//avg_factor, avg_factor), axis = 1)

def std_time_freq(arr, avg_factor):
    arr_ = arr.copy()
    nX = arr.shape[0]
    if nX % avg_factor != 0:
        extra_t = np.nan*np.zeros((avg_factor - nX%avg_factor))
        arr_ = np.concatenate((arr_, extra_t), axis = 0)
        nX = arr_.shape[0]
    
    return np.nanstd(arr_.reshape(nX//avg_factor, avg_factor), axis = 1)/np.sqrt(nX)

def plot_stokes_ds(I, Q, U, V, times, freqs, clim_I = None, clim_Q = None, clim_U = None, clim_V = None):
    


    if clim_I == None:
        mI = np.real(np.nanmean(I))
        sI = np.real(np.std(I))
        clim_I = (mI - 1.0*sI, mI + 2.0*sI)
        #print(clim_I)

    if clim_Q == None:
        mQ = np.real(np.nanmean(Q))
        sQ = np.real(np.std(Q))
        clim_Q = (mQ - 2*sQ, mQ + 2*sQ)
        #print(clim_Q)

    if clim_U == None:
        mU = np.real(np.nanmean(U))
        sU = np.real(np.std(U))
        clim_U = (mU - 2*sU, mU + 2*sU)
        #print(clim_U)

    if clim_V == None:
        mV = np.real(np.nanmean(V))
        sV = np.real(np.std(V))
        clim_V = (mV - 2*sV, mV + 2*sV)
        #print(clim_V)

    fig, axes  = plt.subplots(4,1, figsize = (14, 14), sharex = True)#, constrained_layout = True)

    im_list = []
    #fig.subplots_adjust(right=0.8)
    
    for ax, stoke_ds, clim in zip(axes, [I, Q, U, V], [clim_I, clim_Q, clim_U, clim_V]):
        im_ = ax.imshow(np.real(stoke_ds).T,
                        aspect = 'auto',
                        origin = 'lower',
                        cmap = 'inferno',
                        interpolation = 'none',
                        clim = clim,
                        extent = [times[0], times[-1], freqs[0], freqs[-1]]
                        )
        plt.sca(ax)
        #plt.colorbar(im_).set_label('Flux Density (Jy)', fontsize = 14)
        ax.set_ylabel('Frequency (GHz)', fontsize = 14)
        for tick in ax.xaxis.get_major_ticks():
            tick.label.set_fontsize(12)

        for tick in ax.yaxis.get_major_ticks():
            tick.label.set_fontsize(12)
            
        ax_pos = ax.get_position()
        ax_width = ax_pos.xmax - ax_pos.xmin
        ax_height = ax_pos.ymax - ax_pos.ymin
        cb_ax = fig.add_axes([ax_pos.xmax + 0.005*ax_width, ax_pos.ymin, 0.015*ax_width, ax_height])
        cbar = fig.colorbar(im_, cax=cb_ax)
        cbar.set_label(r'Flux Density (mJy)', fontsize = 14)
        im_list.append(im_)

    
    axes[-1].set_xlabel('Time from obs. start (hour)'.format(times[0]), fontsize = 14)

    return(fig, axes, im_list)


def plot_ds(I, times, freqs, clim_I = None):


    if clim_I == None:
        mI = np.real(np.nanmean(I))
        sI = np.real(np.std(I))
        clim_I = (mI - 1.0*sI, mI + 2.0*sI)
        #print(clim_I)


    fig, ax  = plt.subplots(1,1, figsize = (14, 6), sharex = True, constrained_layout = True)

    im_list = []
    fig.subplots_adjust(right=0.8)
    
    for ax, stoke_ds, clim in zip([ax], [I], [clim_I]):
        im_ = ax.imshow(np.real(stoke_ds).T,
                        aspect = 'auto',
                        origin = 'lower',
                        cmap = 'inferno',
                        interpolation = 'bicubic',
                        clim = clim,
                        extent = [times[0], times[-1], freqs[0], freqs[-1]]
                        )
        plt.sca(ax)
        #plt.colorbar(im_).set_label('Flux Density (Jy)', fontsize = 14)
        ax.set_ylabel('Frequency (GHz)', fontsize = 14)
        for tick in ax.xaxis.get_major_ticks():
            tick.label.set_fontsize(12)

        for tick in ax.yaxis.get_major_ticks():
            tick.label.set_fontsize(12)
            
        ax_pos = ax.get_position()
        ax_width = ax_pos.xmax - ax_pos.xmin
        ax_height = ax_pos.ymax - ax_pos.ymin
        cb_ax = fig.add_axes([ax_pos.xmax + 0.005*ax_width, ax_pos.ymin, 0.015*ax_width, ax_height])
        cbar = fig.colorbar(im_, cax=cb_ax)
        cbar.set_label(r'Flux Density (mJy)', fontsize = 14)
        im_list.append(im_)

    
    [ax][-1].set_xlabel('Time from obs. start (hour)'.format(times[0]), fontsize = 14)

    return(fig, [ax], im_list)
