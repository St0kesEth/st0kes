# Notes

A Monte Carlo option engine, cheap enough to run inside a view call.

A quote should carry its own error, so the reader can tell the estimate from
the noise. That is the whole shape.

The walk carries a variance that feeds on itself. With alpha and beta at zero
the walk is geometric Brownian motion, which the vanilla call has a closed form
for, so the engine can be checked in that limit against Black-Scholes.
