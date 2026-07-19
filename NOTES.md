# Notes

A Monte Carlo option engine, cheap enough to run inside a view call.

A quote should carry its own error, so the reader can tell the estimate from
the noise. That is the whole shape.

The walk carries a variance that feeds on itself. With alpha and beta at zero
the walk is geometric Brownian motion, which the vanilla call has a closed form
for, so the engine can be checked in that limit against Black-Scholes.

The variance recursion has three coefficients. omega is a constant per step,
alpha weights the last squared return, beta weights the last variance. Setting
alpha and beta to zero freezes the variance and recovers the Brownian walk
exactly.

The natural contract for a chain to settle is one on the average price of a
session. The average of a feed's own prints is what the feed already publishes.
That option has no closed form, and it is next on the list.
