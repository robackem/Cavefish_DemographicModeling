#!/usr/bin/env python3
"""A Python 3-compatible rewrite of the SEA lab modification to dadi."""

import os
import sys
import numpy as np
from numpy import logical_and, logical_not
from dadi import Misc, Numerics
from scipy.special import gammaln
import scipy.optimize

_theta_store = {}
_counter = 0
_out_of_bounds_val = -1e8

def _object_func(params, data, model_func, pts,
                 lower_bound=None, upper_bound=None,
                 verbose=0, multinom=True, flush_delay=0,
                 func_args=None, func_kwargs=None, fixed_params=None, ll_scale=1,
                 output_stream=sys.stdout, store_thetas=False):
    global _counter
    _counter += 1

    func_args = func_args or []
    func_kwargs = func_kwargs or {}

    params_up = _project_params_up(params, fixed_params)

    if lower_bound is not None:
        for pval, bound in zip(params_up, lower_bound):
            if bound is not None and pval < bound:
                return -_out_of_bounds_val / ll_scale
    if upper_bound is not None:
        for pval, bound in zip(params_up, upper_bound):
            if bound is not None and pval > bound:
                return -_out_of_bounds_val / ll_scale

    ns = data.sample_sizes
    all_args = [params_up, ns] + list(func_args)
    func_kwargs = func_kwargs.copy()
    func_kwargs["pts"] = pts

    sfs = model_func(*all_args, **func_kwargs)
    result = ll_multinom(sfs, data) if multinom else ll(sfs, data)

    if store_thetas:
        _theta_store[tuple(params)] = optimal_sfs_scaling(sfs, data)

    if np.isnan(result):
        result = _out_of_bounds_val

    if verbose > 0 and (_counter % verbose == 0):
        param_str = 'array([%s])' % ', '.join(f'{v: -12g}' for v in params_up)
        output_stream.write(f"{_counter:<8d}, {result:<12g}, {param_str}{os.linesep}")
        Misc.delayed_flush(delay=flush_delay)

    return -result / ll_scale

def _object_func_log(log_params, *args, **kwargs):
    return _object_func(np.exp(log_params), *args, **kwargs)

def optimize_log(*args, **kwargs):
    return _optimize_wrapper(scipy.optimize.fmin_bfgs, _object_func_log, transform="log", *args, **kwargs)

def optimize_log_fmin(*args, **kwargs):
    return _optimize_wrapper(scipy.optimize.fmin, _object_func_log, transform="log", *args, **kwargs)

def optimize(*args, **kwargs):
    return _optimize_wrapper(scipy.optimize.fmin_bfgs, _object_func, transform=None, *args, **kwargs)

def _optimize_wrapper(opt_func, objective_func, transform, p0, data, model_func, pts,
                      lower_bound=None, upper_bound=None,
                      verbose=0, flush_delay=0.5, epsilon=1e-3,
                      gtol=1e-5, multinom=True, maxiter=None, full_output=False,
                      func_args=None, func_kwargs=None, fixed_params=None,
                      ll_scale=1, output_file=None):
    func_args = func_args or []
    func_kwargs = func_kwargs or []

    output_stream = open(output_file, 'w') if output_file else sys.stdout

    args = (data, model_func, pts, lower_bound, upper_bound, verbose,
            multinom, flush_delay, func_args, func_kwargs, fixed_params,
            ll_scale, output_stream)

    p0_opt = _project_params_down(p0, fixed_params)
    if transform == "log":
        p0_opt = np.log(p0_opt)

    outputs = opt_func(objective_func, p0_opt, args=args,
                       epsilon=epsilon, gtol=gtol,
                       full_output=True, disp=False, maxiter=maxiter)

    xopt = outputs[0]
    xopt = np.exp(xopt) if transform == "log" else xopt
    xopt = _project_params_up(xopt, fixed_params)

    if output_file:
        output_stream.close()

    return outputs if full_output else xopt

def minus_ll(model, data):
    return -ll(model, data)

def ll(model, data):
    return ll_per_bin(model, data).sum()

def ll_per_bin(model, data, missing_model_cutoff=1e-6):
    if data.folded and not model.folded:
        model = model.fold()

    model_masked = np.ma.masked_where(model <= 0, model)
    data_masked = np.ma.masked_array(data, mask=model_masked.mask)
    return -model_masked + data_masked * np.ma.log(model_masked) - gammaln(data_masked + 1)

def ll_multinom(model, data):
    return ll_multinom_per_bin(model, data).sum()

def ll_multinom_per_bin(model, data):
    theta_opt = optimal_sfs_scaling(model, data)
    return ll_per_bin(theta_opt * model, data)

def optimal_sfs_scaling(model, data):
    if data.folded and not model.folded:
        model = model.fold()
    model, data = Numerics.intersect_masks(model, data)
    return data.sum() / model.sum()

def _project_params_down(pin, fixed_params):
    if fixed_params is None:
        return pin
    if len(pin) != len(fixed_params):
        raise ValueError("fixed_params must match length of input params")
    return np.array([p for p, fix in zip(pin, fixed_params) if fix is None])

def _project_params_up(pin, fixed_params):
    if fixed_params is None:
        return pin
    pout = np.zeros(len(fixed_params))
    j = 0
    for i, fix in enumerate(fixed_params):
        pout[i] = pin[j] if fix is None else fix
        if fix is None:
            j += 1
    return pout


from scipy.optimize import dual_annealing


def optimize_anneal(p0, data, model_func, pts,
                    lower_bound=None, upper_bound=None,
                    verbose=0, flush_delay=0.5,
                    multinom=True, maxiter=None, full_output=False,
                    func_args=None, func_kwargs=None, fixed_params=None,
                    ll_scale=1, output_file=None,
                    Tini=None, Tfin=None, learn_rate=None, schedule=None):

    from scipy.optimize import dual_annealing

    func_args = func_args or []
    func_kwargs = func_kwargs or {}

    output_stream = open(output_file, 'w') if output_file else sys.stdout

    args = (data, model_func, pts, lower_bound, upper_bound, verbose,
            multinom, flush_delay, func_args, func_kwargs, fixed_params,
            ll_scale, output_stream)

    p0_down = _project_params_down(p0, fixed_params)

    bounds = []
    for i, (lo, hi) in enumerate(zip(lower_bound, upper_bound)):
        lo = 1e-5 if lo is None or lo <= 0 or np.isnan(lo) else lo
        hi = 100.0 if hi is None or hi <= lo or np.isnan(hi) else hi
        try:
            log_lo = np.log(lo)
            log_hi = np.log(hi)
            bounds.append((log_lo, log_hi))
        except ValueError:
            raise ValueError(f"Invalid bounds at index {i}: lo={lo}, hi={hi}")

    result = dual_annealing(_object_func_log,
                            bounds=bounds,
                            args=args,
                            maxiter=maxiter or 500,
                            no_local_search=True)

    xopt = np.exp(result.x)
    xopt = _project_params_up(xopt, fixed_params)

    if output_file:
        output_stream.close()

    if not full_output:
        return xopt
    else:
        return xopt, result.fun, result.nit, result.nfev, result.message

    func_args = func_args or []
    func_kwargs = func_kwargs or {}

    output_stream = open(output_file, 'w') if output_file else sys.stdout

    args = (data, model_func, pts, lower_bound, upper_bound, verbose,
            multinom, flush_delay, func_args, func_kwargs, fixed_params,
            ll_scale, output_stream)

    p0_down = _project_params_down(p0, fixed_params)

    bounds = []
    for lo, hi in zip(lower_bound, upper_bound):
        lo = lo if lo is not None else 1e-5
        hi = hi if hi is not None else 100
        bounds.append((np.log(lo), np.log(hi)))

    result = dual_annealing(_object_func_log,
                            bounds=bounds,
                            args=args,
                            maxiter=maxiter or 500,
                            no_local_search=True)

    xopt = np.exp(result.x)
    xopt = _project_params_up(xopt, fixed_params)

    if output_file:
        output_stream.close()

    if not full_output:
        return xopt
    else:
        return xopt, result.fun, result.nit, result.nfev, result.message
